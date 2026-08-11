import Foundation
import Observation
import PulseCore

enum AppLoadState: Equatable {
    case loading
    case ready
    case failed
}

enum AppOperation: Equatable {
    case updateHabitIdentity
    case checkIn
    case deleteRecord
    case resetData
    case importData
    case updateTimeZone
}

enum ReminderSyncState: Equatable {
    case idle
    case syncing
    case synced
    case failed
}

@MainActor
@Observable
final class PulseAppModel {
    private let repository: any CheckInRepositoryProtocol
    private let reminderScheduler: any ReminderScheduling
    private let clock: any PulseClock
    private let hapticFeedback: any HapticFeedbackProviding
    private let widgetTimelineReloader: any WidgetTimelineReloading
    private var dateBoundaryTask: Task<Void, Never>?
    private var reminderReconcileTask: Task<Void, Never>?
    private var reminderReconcileRevision = 0
    private var reminderIntentRevision = 0
    private var reminderEnabledIntent: Bool?
    private var hasAppliedUITestReset = false
    private var recordsByDay: [LogicalDay: CheckInRecordSnapshot] = [:]

    let settings: AppSettings

    private(set) var loadState: AppLoadState = .loading
    private(set) var habit: HabitSnapshot?
    private(set) var records: [CheckInRecordSnapshot] = []
    private(set) var timeZone: TimeZone?
    private(set) var today: LogicalDay?
    private(set) var habitStartDay: LogicalDay?
    private(set) var checkedDays: Set<LogicalDay> = []
    private(set) var statistics: CheckInStatistics = .empty
    private(set) var operation: AppOperation?
    private(set) var notificationPermission: NotificationPermissionState = .notDetermined
    private(set) var reminderSyncState: ReminderSyncState = .idle
    private(set) var navigationResetToken = UUID()
    var selectedMonth: LogicalDay?
    var errorMessage: String?

    init(
        repository: any CheckInRepositoryProtocol,
        settings: AppSettings,
        reminderScheduler: any ReminderScheduling,
        clock: any PulseClock,
        hapticFeedback: any HapticFeedbackProviding,
        widgetTimelineReloader: any WidgetTimelineReloading = WidgetTimelineReloader()
    ) {
        self.repository = repository
        self.settings = settings
        self.reminderScheduler = reminderScheduler
        self.clock = clock
        self.hapticFeedback = hapticFeedback
        self.widgetTimelineReloader = widgetTimelineReloader
    }

    var isSaving: Bool {
        operation == .checkIn
    }

    var displayedReminderEnabled: Bool {
        reminderEnabledIntent ?? settings.reminderEnabled
    }

    var canCheckInToday: Bool {
        guard operation == nil, let today, let habitStartDay else { return false }
        return today >= habitStartDay && todayRecord == nil
    }

    var todayRecord: CheckInRecordSnapshot? {
        guard let today else { return nil }
        return recordsByDay[today]
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
        loadState = .loading
#if DEBUG
        if !hasAppliedUITestReset,
           ProcessInfo.processInfo.environment["PULSE_UI_TEST_RESET"] == "1" {
            hasAppliedUITestReset = true
            loadState = await resetAllData() ? .ready : .failed
            return
        }
#endif
        if settings.isResetPending {
            loadState = await resetAllData() ? .ready : .failed
        } else {
            await reload(reconcileReminders: true)
        }
    }

    func handleSceneActivation() async {
        guard operation == nil else { return }
        await reload(reconcileReminders: true)
    }

    @discardableResult
    func checkIn() async -> CheckInCommitReceipt? {
        guard operation == nil,
              todayRecord == nil,
              let habit,
              let today,
              let habitStartDay,
              today >= habitStartDay else { return nil }
        operation = .checkIn
        defer { operation = nil }

        await Task.yield()
        do {
            let receipt = try repository.checkIn(habitID: habit.id)
            try loadSnapshot()
            if settings.hapticsEnabled, receipt.disposition == .created {
                hapticFeedback.notifySuccess()
            }
            widgetTimelineReloader.reloadDailyImprint()
            enqueueReminderReconciliation()
            scheduleDateBoundaryRefresh()
            return receipt
        } catch {
            present(error)
            return nil
        }
    }

    func updateHabitIdentity(name: String, purpose: String?) async -> Bool {
        guard operation == nil, let habit else { return false }
        operation = .updateHabitIdentity
        defer { operation = nil }
        do {
            let identity = try HabitIdentity(userName: name, userPurpose: purpose)
            self.habit = try repository.updateIdentity(
                habitID: habit.id,
                identity: identity
            )
            try loadSnapshot()
            widgetTimelineReloader.reloadDailyImprint()
            return true
        } catch {
            present(error)
            return false
        }
    }

    func delete(recordID: UUID) async -> Bool {
        guard operation == nil else { return false }
        operation = .deleteRecord
        defer { operation = nil }
        do {
            try repository.delete(recordID: recordID)
            try loadSnapshot()
            widgetTimelineReloader.reloadDailyImprint()
            await enqueueReminderReconciliation().value
            return true
        } catch {
            present(error)
            return false
        }
    }

    func resetAllData() async -> Bool {
        guard operation == nil else { return false }
        operation = .resetData
        invalidateReminderIntents()
        defer { operation = nil }
        do {
            settings.markResetPending()
            let newHabit = try repository.resetAll(systemTimeZone: .autoupdatingCurrent)
            settings.reset()
            await reminderReconcileTask?.value
            await reminderScheduler.removeAllPulseNotifications()
            habit = newHabit
            selectedMonth = nil
            try loadSnapshot()
            notificationPermission = await reminderScheduler.permissionState()
            reminderSyncState = .synced
            settings.finishReset()
            loadState = .ready
            navigationResetToken = UUID()
            scheduleDateBoundaryRefresh()
            widgetTimelineReloader.reloadDailyImprint()
            return true
        } catch {
            present(error)
            return false
        }
    }

    func requestReminderEnabled(_ enabled: Bool) {
        reminderIntentRevision += 1
        let revision = reminderIntentRevision
        reminderEnabledIntent = enabled
        reminderSyncState = .syncing
        Task { [weak self] in
            await self?.applyReminderEnabled(enabled, revision: revision)
        }
    }

    private func applyReminderEnabled(_ enabled: Bool, revision: Int) async {
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

                guard revision == reminderIntentRevision else { return }
                guard allowed else {
                    settings.setReminderEnabled(false)
                    notificationPermission = .denied
                    reminderEnabledIntent = nil
                    throw PulseAppError.notificationPermissionDenied
                }

                settings.setReminderEnabled(true)
                notificationPermission = .authorized
                reminderEnabledIntent = nil
                await enqueueReminderReconciliation().value
            } catch {
                guard revision == reminderIntentRevision else { return }
                settings.setReminderEnabled(false)
                notificationPermission = await reminderScheduler.permissionState()
                reminderEnabledIntent = nil
                await enqueueReminderReconciliation().value
                present(error)
            }
        } else {
            guard revision == reminderIntentRevision else { return }
            settings.setReminderEnabled(false)
            reminderEnabledIntent = nil
            await enqueueReminderReconciliation().value
        }
    }

    func requestReminderTime(_ reminderTime: ReminderTime) {
        settings.reminderTime = reminderTime
        _ = enqueueReminderReconciliation()
    }

    func requestLanguage(_ language: AppLanguage) {
        guard settings.language != language else { return }
        settings.language = language
        _ = enqueueReminderReconciliation()
    }

    func requestWidgetStyle(_ style: PulseWidgetStyle) {
        guard settings.widgetStyle != style else { return }
        settings.widgetStyle = style
        widgetTimelineReloader.reloadDailyImprint()
    }

    func updateTimeZone(identifier: String) async -> Bool {
        guard operation == nil, let habit else { return false }
        operation = .updateTimeZone
        defer { operation = nil }
        do {
            try repository.updateTimeZone(habitID: habit.id, identifier: identifier)
            try loadSnapshot()
            await enqueueReminderReconciliation().value
            scheduleDateBoundaryRefresh()
            widgetTimelineReloader.reloadDailyImprint()
            return true
        } catch {
            present(error)
            return false
        }
    }

    func makeExportDocument() throws -> PulseExportDocument {
        guard let habit else {
            throw PulseCoreError.exportUnavailable
        }
        let startLogicalDay = habit.startLogicalDay
        let payload = PulseExportPayload(
            format: PulseDataContract.formatIdentifier,
            schemaVersion: PulseDataContract.exportSchemaVersion,
            exportedAt: clock.now,
            habit: .init(
                id: habit.id,
                name: habit.name,
                purpose: habit.purpose,
                isIdentityConfirmed: habit.isIdentityConfirmed,
                createdAt: habit.createdAt,
                startLogicalDay: startLogicalDay.storageValue,
                creationTimeZoneIdentifier: habit.creationTimeZoneIdentifier,
                timeZoneIdentifier: habit.timeZoneIdentifier
            ),
            records: records.map {
                .init(
                    id: $0.id,
                    logicalDay: $0.logicalDay.storageValue,
                    checkedAt: $0.checkedAt,
                    createdAt: $0.createdAt,
                    timeZoneIdentifier: $0.timeZoneIdentifier
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

        let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard let fileSize, fileSize <= PulseDataContract.maximumImportBytes else {
            throw PulseCoreError.invalidImport
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let payload: PulseExportPayload
        do {
            payload = try PulseExportDocument.decode(data)
        } catch {
            throw PulseCoreError.invalidImport
        }
        return payload
    }

    func importData(_ payload: PulseExportPayload) async -> Bool {
        guard operation == nil else { return false }
        operation = .importData
        invalidateReminderIntents()
        defer { operation = nil }
        do {
            habit = try repository.replaceAll(with: payload)
            selectedMonth = nil
            try loadSnapshot()
            await enqueueReminderReconciliation().value
            navigationResetToken = UUID()
            scheduleDateBoundaryRefresh()
            widgetTimelineReloader.reloadDailyImprint()
            return true
        } catch {
            present(error)
            return false
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

    func record(for day: LogicalDay) -> CheckInRecordSnapshot? {
        recordsByDay[day]
    }

    private func reload(reconcileReminders: Bool) async {
        do {
            try loadSnapshot()
            loadState = .ready
            notificationPermission = await reminderScheduler.permissionState()
            if reconcileReminders {
                await enqueueReminderReconciliation().value
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
        let referenceNow = clock.now
        let currentHabit = try repository.primaryHabit(
            systemTimeZone: .autoupdatingCurrent
        )
        let resolvedTimeZone = currentHabit.timeZone
        let resolvedToday = currentHabit.logicalDay(at: referenceNow)
        let resolvedStartDay = currentHabit.startLogicalDay
        let fetchedRecords = try repository.allRecords(habitID: currentHabit.id)

        let resolvedRecordsByDay = Dictionary(
            uniqueKeysWithValues: fetchedRecords.map { ($0.logicalDay, $0) }
        )
        let resolvedCheckedDays = Set(resolvedRecordsByDay.keys)

        habit = currentHabit
        records = fetchedRecords
        timeZone = resolvedTimeZone
        today = resolvedToday
        habitStartDay = resolvedStartDay
        checkedDays = resolvedCheckedDays
        recordsByDay = resolvedRecordsByDay
        statistics = CheckInStatistics.calculate(
            checkedDays: Set(resolvedCheckedDays.filter { $0 <= resolvedToday }),
            today: resolvedToday,
            timeZone: resolvedTimeZone
        )
        if wasShowingCurrentMonth {
            selectedMonth = resolvedToday.firstDayOfMonth()
        }
    }

    @discardableResult
    private func enqueueReminderReconciliation() -> Task<Void, Never> {
        reminderReconcileRevision += 1
        let revision = reminderReconcileRevision
        let previousTask = reminderReconcileTask

        guard let habit else {
            reminderSyncState = .idle
            let completedTask = Task<Void, Never> {}
            reminderReconcileTask = completedTask
            return completedTask
        }

        let snapshot = ReminderScheduleSnapshot(
            enabled: settings.reminderEnabled,
            time: settings.reminderTime,
            timeZoneIdentifier: habit.timeZoneIdentifier,
            localeIdentifier: settings.locale.identifier,
            checkedDays: checkedDays,
            now: clock.now
        )
        reminderSyncState = .syncing

        let task = Task { @MainActor [weak self] in
            await previousTask?.value
            guard let self, revision == self.reminderReconcileRevision else { return }
            do {
                try await self.reminderScheduler.reconcile(snapshot)
                guard revision == self.reminderReconcileRevision else { return }
                self.reminderSyncState = .synced
            } catch {
                guard revision == self.reminderReconcileRevision else { return }
                if snapshot.enabled {
                    let permission = await self.reminderScheduler.permissionState()
                    guard revision == self.reminderReconcileRevision else { return }
                    self.settings.setReminderEnabled(false)
                    self.reminderEnabledIntent = nil
                    self.notificationPermission = permission
                    self.present(error)
                }
                self.reminderSyncState = .failed
            }
        }
        reminderReconcileTask = task
        return task
    }

    private func invalidateReminderIntents() {
        reminderIntentRevision += 1
        reminderEnabledIntent = nil
        reminderReconcileRevision += 1
    }

    private func scheduleDateBoundaryRefresh() {
        dateBoundaryTask?.cancel()
        guard let timeZone, let today else {
            return
        }

        let nextDay = today.addingDays(1, timeZone: timeZone)
        let nextBoundary = nextDay.startDate(timeZone: timeZone)
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
        if let message = PulseErrorPresentation.localizedMessage(
            for: error,
            locale: settings.locale
        ) {
            errorMessage = message
            return
        }
        errorMessage = (error as? LocalizedError)?.errorDescription
            ?? PulseLocalization.string("error.generic", locale: settings.locale)
    }

}
