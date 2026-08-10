import Foundation
import Observation

enum AppLoadState: Equatable {
    case loading
    case ready
    case failed
}

@MainActor
@Observable
final class PulseAppModel {
    private let repository: any CheckInRepositoryProtocol
    private let reminderScheduler: any ReminderScheduling
    private let clock: any PulseClock
    private let hapticFeedback: any HapticFeedbackProviding
    private var dateBoundaryTask: Task<Void, Never>?
    private var hasAppliedUITestReset = false

    let settings: AppSettings

    private(set) var loadState: AppLoadState = .loading
    private(set) var habit: Habit?
    private(set) var records: [CheckInRecord] = []
    private(set) var timeZone: TimeZone?
    private(set) var today: LogicalDay?
    private(set) var habitStartDay: LogicalDay?
    private(set) var referenceNow: Date
    private(set) var isSaving = false
    private(set) var notificationPermission: NotificationPermissionState = .notDetermined
    var selectedMonth: LogicalDay?
    var errorMessage: String?

    init(
        repository: any CheckInRepositoryProtocol,
        settings: AppSettings,
        reminderScheduler: any ReminderScheduling,
        clock: any PulseClock,
        hapticFeedback: any HapticFeedbackProviding
    ) {
        self.repository = repository
        self.settings = settings
        self.reminderScheduler = reminderScheduler
        self.clock = clock
        self.hapticFeedback = hapticFeedback
        referenceNow = clock.now
    }

    var checkedDays: Set<LogicalDay> {
        Set(records.compactMap(\.logicalDay))
    }

    var todayRecord: CheckInRecord? {
        guard let today else { return nil }
        return records.first { $0.logicalDay == today }
    }

    var statistics: CheckInStatistics {
        guard let today, let timeZone else { return .empty }
        return CheckInStatistics.calculate(
            checkedDays: checkedDays,
            today: today,
            timeZone: timeZone
        )
    }

    var recentDays: [CalendarDayItem] {
        guard let today, let timeZone, let habitStartDay else {
            return []
        }

        return (-6...0).map { offset in
            let day = today.addingDays(offset, timeZone: timeZone)
            return CalendarDayItem(
                day: day,
                status: CheckInCalendar.status(
                    for: day,
                    habitStartDay: habitStartDay,
                    today: today,
                    checkedDays: checkedDays
                )
            )
        }
    }

    func start() async {
        await reload(reconcileReminders: true)
#if DEBUG
        if !hasAppliedUITestReset,
           ProcessInfo.processInfo.environment["PULSE_UI_TEST_RESET"] == "1" {
            hasAppliedUITestReset = true
            await resetAllData()
        }
#endif
    }

    func handleSceneActivation() async {
        await reload(reconcileReminders: true)
    }

    func checkIn() async {
        guard !isSaving, todayRecord == nil, let habit else { return }
        isSaving = true
        defer { isSaving = false }

        await Task.yield()
        do {
            _ = try repository.checkIn(habit: habit, at: clock.now)
            try loadSnapshot()
            if settings.hapticsEnabled {
                hapticFeedback.notifySuccess()
            }
            await reconcileReminders()
            scheduleDateBoundaryRefresh()
        } catch {
            present(error)
        }
    }

    func delete(recordID: UUID) async {
        do {
            try repository.delete(recordID: recordID)
            try loadSnapshot()
            await reconcileReminders()
        } catch {
            present(error)
        }
    }

    func resetAllData() async {
        do {
            let newHabit = try repository.resetAll(
                now: clock.now,
                systemTimeZone: .autoupdatingCurrent
            )
            settings.reset()
            await reminderScheduler.removeAllPulseNotifications()
            habit = newHabit
            try loadSnapshot()
            notificationPermission = await reminderScheduler.permissionState()
            scheduleDateBoundaryRefresh()
        } catch {
            present(error)
        }
    }

    func setReminderEnabled(_ enabled: Bool) async {
        if enabled {
            do {
                let allowed: Bool
                switch await reminderScheduler.permissionState() {
                case .authorized:
                    allowed = true
                case .notDetermined:
                    allowed = try await reminderScheduler.requestPermission()
                case .denied:
                    allowed = false
                }

                guard allowed else {
                    settings.setReminderEnabled(false)
                    notificationPermission = .denied
                    throw PulseError.notificationPermissionDenied
                }

                settings.setReminderEnabled(true)
                notificationPermission = .authorized
                await reconcileReminders()
            } catch {
                settings.setReminderEnabled(false)
                present(error)
            }
        } else {
            settings.setReminderEnabled(false)
            await reconcileReminders()
        }
    }

    func updateReminderTime(_ reminderTime: ReminderTime) async {
        settings.reminderTime = reminderTime
        await reconcileReminders()
    }

    func updateTimeZone(identifier: String) async {
        guard let habit else { return }
        do {
            try repository.updateTimeZone(habit: habit, identifier: identifier)
            try loadSnapshot()
            await reconcileReminders()
            scheduleDateBoundaryRefresh()
        } catch {
            present(error)
        }
    }

    func makeExportDocument() throws -> PulseExportDocument {
        guard let habit else { throw PulseError.exportUnavailable }
        let payload = PulseExportPayload(
            schemaVersion: PulseDataContract.exportSchemaVersion,
            exportedAt: clock.now,
            habit: .init(
                id: habit.id,
                name: habit.name,
                createdAt: habit.createdAt,
                timeZoneIdentifier: habit.timeZoneIdentifier,
                dayStartMinutes: habit.dayStartMinutes
            ),
            records: records.map {
                .init(
                    id: $0.id,
                    logicalDay: $0.logicalDayValue,
                    checkedAt: $0.checkedAt,
                    createdAt: $0.createdAt,
                    source: $0.sourceRawValue
                )
            }
        )
        return PulseExportDocument(payload: payload)
    }

    func decodeImport(from url: URL) throws -> PulseExportPayload {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let payload = try PulseExportDocument.decode(data)
        guard payload.schemaVersion == PulseDataContract.exportSchemaVersion else {
            throw PulseError.unsupportedImportVersion(payload.schemaVersion)
        }
        return payload
    }

    func importData(_ payload: PulseExportPayload) async {
        do {
            habit = try repository.replaceAll(with: payload)
            try loadSnapshot()
            await reconcileReminders()
            scheduleDateBoundaryRefresh()
        } catch {
            present(error)
        }
    }

    func moveSelectedMonth(by offset: Int) {
        guard let month = selectedMonth ?? today?.firstDayOfMonth(), let timeZone else { return }
        let candidate = month.addingMonths(offset, timeZone: timeZone)
        if let currentMonth = today?.firstDayOfMonth(), candidate <= currentMonth {
            selectedMonth = candidate
        }
    }

    func calendarItemsForSelectedMonth() -> [CalendarDayItem] {
        guard let today, let timeZone, let habitStartDay else {
            return []
        }

        let month = (selectedMonth ?? today.firstDayOfMonth()).firstDayOfMonth()
        return (1...month.daysInMonth(timeZone: timeZone)).map { dayNumber in
            let day = LogicalDay(year: month.year, month: month.month, day: dayNumber)
            return CalendarDayItem(
                day: day,
                status: CheckInCalendar.status(
                    for: day,
                    habitStartDay: habitStartDay,
                    today: today,
                    checkedDays: checkedDays
                )
            )
        }
    }

    func record(for day: LogicalDay) -> CheckInRecord? {
        records.first { $0.logicalDay == day }
    }

    private func reload(reconcileReminders: Bool) async {
        do {
            try loadSnapshot()
            loadState = .ready
            notificationPermission = await reminderScheduler.permissionState()
            if reconcileReminders {
                await self.reconcileReminders()
            }
            scheduleDateBoundaryRefresh()
        } catch {
            loadState = .failed
            present(error)
        }
    }

    private func loadSnapshot() throws {
        let wasShowingCurrentMonth = selectedMonth == nil
            || selectedMonth == today?.firstDayOfMonth()
        referenceNow = clock.now
        let currentHabit = try repository.primaryHabit(
            now: referenceNow,
            systemTimeZone: .autoupdatingCurrent
        )
        let resolvedTimeZone = try currentHabit.resolvedTimeZone()
        let resolvedToday = try currentHabit.logicalDay(at: referenceNow)
        let resolvedStartDay = try currentHabit.logicalDay(at: currentHabit.createdAt)
        let fetchedRecords = try repository.allRecords(habitID: currentHabit.id)

        for record in fetchedRecords where record.logicalDay == nil {
            throw PulseError.invalidRecordDate(record.logicalDayValue)
        }

        habit = currentHabit
        records = fetchedRecords
        timeZone = resolvedTimeZone
        today = resolvedToday
        habitStartDay = resolvedStartDay
        if wasShowingCurrentMonth {
            selectedMonth = resolvedToday.firstDayOfMonth()
        }
    }

    private func reconcileReminders() async {
        guard let habit else { return }
        do {
            try await reminderScheduler.reconcile(
                enabled: settings.reminderEnabled,
                time: settings.reminderTime,
                habit: habit,
                checkedDays: checkedDays,
                now: clock.now
            )
        } catch {
            if settings.reminderEnabled {
                present(error)
            }
        }
    }

    private func scheduleDateBoundaryRefresh() {
        dateBoundaryTask?.cancel()
        guard let habit, let timeZone, let today else {
            return
        }

        let nextDay = today.addingDays(1, timeZone: timeZone)
        let nextBoundary = nextDay.startDate(
            timeZone: timeZone,
            dayStartMinutes: habit.dayStartMinutes
        )
        let interval = max(nextBoundary.timeIntervalSince(clock.now) + 0.25, 0.25)

        dateBoundaryTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                await self?.handleSceneActivation()
            } catch {
                // Cancellation is the expected outcome when a newer boundary task replaces this one.
            }
        }
    }

    private func present(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription
            ?? String(localized: "error.generic")
    }
}
