import Foundation
import Observation
import PulseCore
import PulseWatchShared
import UIKit

enum AppLoadState: Equatable {
    case loading
    case ready
    case failed
}

enum AppOperation: Equatable {
    case updateHabitIdentity
    case checkIn
    case watchCheckIn
    case updateJournalNote
    case deleteRecord
    case resetData
    case restoreBackup
    case updateTimeZone
    case saveMedia
    case deleteMedia
    case exportBackup
    case exportMedia
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
    private let repository: any PulseRepositoryProtocol
    private let mediaService: ImprintMediaService
    private let archiveWorkingDirectoryURL: URL
    private let reminderScheduler: any ReminderScheduling
    private let clock: any PulseClock
    private let hapticFeedback: any HapticFeedbackProviding
    private let widgetTimelineReloader: any WidgetTimelineReloading
    private let watchConnectivity: any PulseWatchConnectivityProviding
    private var dateBoundaryTask: Task<Void, Never>?
    private var externalCheckInTask: Task<Void, Never>?
    private var reminderReconcileTask: Task<Void, Never>?
    private var reminderReconcileRevision = 0
    private var reminderIntentRevision = 0
    private var reminderEnabledIntent: Bool?
    private var recordsByDay: [LogicalDay: CheckInRecordSnapshot] = [:]
    private var mediaByDay: [LogicalDay: ImprintMediaSnapshot] = [:]
    private var sceneActivationPending = false

    let settings: AppSettings
    let featureAccess: FeatureAccessController

    private(set) var loadState: AppLoadState = .loading
    private(set) var habit: HabitSnapshot?
    private(set) var records: [CheckInRecordSnapshot] = []
    private(set) var media: [ImprintMediaSnapshot] = []
    private(set) var mediaStorageByteCount: Int64 = 0
    private(set) var timeZone: TimeZone?
    private(set) var today: LogicalDay?
    private(set) var habitStartDay: LogicalDay?
    private(set) var checkedDays: Set<LogicalDay> = []
    private(set) var statistics: CheckInStatistics = .empty
    private(set) var operation: AppOperation?
    private(set) var notificationPermission: NotificationPermissionState = .notDetermined
    private(set) var reminderSyncState: ReminderSyncState = .idle
    private(set) var reminderDeliveryMode: PulseReminderDeliveryMode = .disabled
    private(set) var watchConnectionStatus: PulseWatchConnectionStatus = .activating
    private(set) var navigationResetToken = UUID()
    private(set) var themeAccessNoticePresented = false
    var selectedMonth: LogicalDay?
    var errorMessage: String?

    init(
        repository: any PulseRepositoryProtocol,
        mediaService: ImprintMediaService,
        archiveWorkingDirectoryURL: URL,
        settings: AppSettings,
        featureAccess: FeatureAccessController,
        reminderScheduler: any ReminderScheduling,
        clock: any PulseClock,
        hapticFeedback: any HapticFeedbackProviding,
        widgetTimelineReloader: any WidgetTimelineReloading,
        watchConnectivity: any PulseWatchConnectivityProviding
    ) {
        self.repository = repository
        self.mediaService = mediaService
        self.archiveWorkingDirectoryURL = archiveWorkingDirectoryURL
        self.settings = settings
        self.featureAccess = featureAccess
        self.reminderScheduler = reminderScheduler
        self.clock = clock
        self.hapticFeedback = hapticFeedback
        self.widgetTimelineReloader = widgetTimelineReloader
        self.watchConnectivity = watchConnectivity
        watchConnectivity.commandHandler = { [weak self] command in
            await self?.handleWatchCheckIn(command)
        }
        watchConnectivity.snapshotHandler = { [weak self] in
            guard let self else { return nil }
            return try self.makeCurrentWatchSnapshot()
        }
        watchConnectionStatus = watchConnectivity.connectionStatus
        watchConnectivity.connectionStatusDidChange = { [weak self] status in
            self?.watchConnectionStatus = status
        }
        externalCheckInTask = Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: PulseExternalCheckInSignal.didCommit
            ) {
                guard let self else { return }
                await self.handleExternalCheckInCommit()
            }
        }
        watchConnectivity.start()
        featureAccess.accessDidChange = { [weak self] hasEnhancement in
            guard let self else { return }
            self.reconcileVisualThemeAccess(
                hasEnhancementEntitlement: hasEnhancement,
                presentsNotice: true
            )
            self.widgetTimelineReloader.reloadDailyImprint()
            _ = self.enqueueReminderReconciliation()
        }
    }

    var isSaving: Bool {
        operation == .checkIn
    }

    var resolvedVisualTheme: PulseVisualTheme {
        PulseVisualThemeAccessPolicy.resolvedTheme(
            requested: settings.visualTheme,
            hasEnhancementEntitlement: featureAccess.hasEnhancement
        )
    }

    var displayedReminderEnabled: Bool {
        reminderEnabledIntent ?? settings.reminderEnabled
    }

    var supportsScheduledLiveActivities: Bool {
        reminderScheduler.deliveryCapabilities.supportsScheduledLiveActivities
    }

    private var preferredReminderDeliveryMode: PulseReminderDeliveryMode {
        PulseReminderDeliveryPolicy.deliveryMode(
            reminderEnabled: displayedReminderEnabled,
            hasEnhancementEntitlement: featureAccess.hasEnhancement,
            capabilities: reminderScheduler.deliveryCapabilities
        )
    }

    var canCheckInToday: Bool {
        guard operation == nil, let today, let habitStartDay else { return false }
        return today >= habitStartDay && todayRecord == nil
    }

    var todayRecord: CheckInRecordSnapshot? {
        guard let today else { return nil }
        return recordsByDay[today]
    }

    var todayMedia: ImprintMediaSnapshot? {
        guard let today else { return nil }
        return mediaByDay[today]
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

    var widgetPresentationSnapshot: PulseWidgetSnapshot? {
        guard let habit else { return nil }
        return try? PulseWidgetProjector.makeTimelinePlan(
            habit: habit,
            records: records,
            at: clock.now
        ).snapshot
    }

    func start() async {
        loadState = .loading
        let featureAccessTask = Task { @MainActor [featureAccess] in
            await featureAccess.start()
        }
        if settings.isResetPending {
            loadState = await resetAllData() ? .ready : .failed
        } else {
            await reload(reconcileReminders: false)
        }
        await featureAccessTask.value
        reconcileVisualThemeAccess(
            hasEnhancementEntitlement: featureAccess.hasEnhancement,
            presentsNotice: true
        )
        if loadState == .ready {
            await auditMediaStorage()
            await enqueueReminderReconciliation().value
        }
    }

    func handleSceneActivation() async {
        guard operation == nil else {
            sceneActivationPending = true
            return
        }
        sceneActivationPending = false
        await reload(reconcileReminders: false)
        await featureAccess.refresh()
        reconcileVisualThemeAccess(
            hasEnhancementEntitlement: featureAccess.hasEnhancement,
            presentsNotice: true
        )
        if loadState == .ready {
            await auditMediaStorage()
            await enqueueReminderReconciliation().value
        }
    }

    private func handleExternalCheckInCommit() async {
        guard operation == nil else {
            sceneActivationPending = true
            return
        }
        await reload(reconcileReminders: false)
    }

    @discardableResult
    func checkIn(journalNote: String? = nil) async -> CheckInCommitReceipt? {
        guard todayRecord == nil,
              let habit,
              let today,
              let habitStartDay,
              today >= habitStartDay else { return nil }
        guard beginOperation(.checkIn) else { return nil }
        defer { finishOperation() }

        await Task.yield()
        do {
            let receipt = try repository.checkIn(
                habitID: habit.id,
                journalNote: journalNote
            )
            try loadSnapshot()
            if settings.hapticsEnabled, receipt.disposition == .created {
                hapticFeedback.notifySuccess()
            }
            widgetTimelineReloader.reloadDailyImprint()
            await reminderScheduler.completeCheckIn(for: receipt.logicalDay)
            scheduleDateBoundaryRefresh()
            return receipt
        } catch {
            present(error)
            return nil
        }
    }

    func handleWatchCheckIn(
        _ command: PulseWatchCheckInCommand
    ) async -> PulseWatchCheckInReceipt? {
        guard beginOperation(.watchCheckIn) else {
            return watchRejectionReceipt(
                for: command,
                reason: .temporarilyUnavailable
            )
        }
        defer { finishOperation() }
        let receipt: CheckInCommitReceipt
        do {
            receipt = try repository.checkIn(watchCommand: command)
        } catch {
            try? loadSnapshot()
            return watchRejectionReceipt(for: command, reason: error)
        }
        do {
            try loadSnapshot()
            widgetTimelineReloader.reloadDailyImprint()
            await reminderScheduler.completeCheckIn(for: receipt.logicalDay)
            scheduleDateBoundaryRefresh()
            let disposition: PulseWatchCommitDisposition = switch receipt.disposition {
            case .created: .created
            case .alreadyPresent: .alreadyPresent
            }
            return PulseWatchCheckInReceipt(
                operationID: command.operationID,
                projectID: command.projectID,
                projectRevision: command.projectRevision,
                outcome: .committed(
                    logicalDay: receipt.logicalDay.storageValue,
                    checkedAt: receipt.checkedAt,
                    disposition: disposition
                ),
                acknowledgedAt: clock.now
            )
        } catch {
            return watchRejectionReceipt(
                for: command,
                reason: .persistenceFailure
            )
        }
    }

    func setWatchWaveMotionEnabled(_ enabled: Bool) {
        guard settings.watchWaveMotionEnabled != enabled else { return }
        settings.watchWaveMotionEnabled = enabled
        publishCurrentWatchSnapshot()
    }

    private func watchRejectionReceipt(
        for command: PulseWatchCheckInCommand,
        reason: PulseWatchRejectionReason
    ) -> PulseWatchCheckInReceipt {
        PulseWatchCheckInReceipt(
            operationID: command.operationID,
            projectID: command.projectID,
            projectRevision: command.projectRevision,
            outcome: .rejected(reason: reason),
            acknowledgedAt: clock.now
        )
    }

    func updateHabitIdentity(name: String, purpose: String?) async -> Bool {
        guard let habit, beginOperation(.updateHabitIdentity) else { return false }
        defer { finishOperation() }
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

    func updateJournalNote(recordID: UUID, journalNote: String?) async -> Bool {
        guard beginOperation(.updateJournalNote) else { return false }
        defer { finishOperation() }
        do {
            _ = try repository.updateJournalNote(
                recordID: recordID,
                journalNote: journalNote
            )
            try loadSnapshot()
            return true
        } catch {
            present(error)
            return false
        }
    }

    func delete(recordID: UUID) async -> Bool {
        guard beginOperation(.deleteRecord) else { return false }
        defer { finishOperation() }
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

    func saveTodayMedia(
        image: UIImage,
        cameraPosition: ImprintCameraPosition
    ) async -> Bool {
        guard let habit, let record = todayRecord, beginOperation(.saveMedia) else {
            return false
        }
        defer { finishOperation() }
        do {
            _ = try await mediaService.save(
                image: image,
                habit: habit,
                record: record,
                cameraPosition: cameraPosition
            )
            try loadSnapshot()
            mediaStorageByteCount = try await mediaService.storageByteCount()
            if settings.hapticsEnabled {
                hapticFeedback.notifySuccess()
            }
            return true
        } catch {
            present(error)
            return false
        }
    }

    func deleteMedia(id: UUID) async -> Bool {
        guard let item = media.first(where: { $0.id == id }),
              beginOperation(.deleteMedia) else {
            return false
        }
        defer { finishOperation() }
        do {
            try await mediaService.delete(item)
            try loadSnapshot()
            mediaStorageByteCount = try await mediaService.storageByteCount()
            return true
        } catch {
            present(error)
            return false
        }
    }

    func thumbnailData(for item: ImprintMediaSnapshot) async throws -> Data {
        try await mediaService.thumbnailData(for: item)
    }

    func originalDataForExport(for item: ImprintMediaSnapshot) async -> Data? {
        guard beginOperation(.exportMedia) else { return nil }
        defer { finishOperation() }
        do {
            return try await mediaService.originalData(for: item)
        } catch {
            present(error)
            return nil
        }
    }

    func media(for day: LogicalDay) -> ImprintMediaSnapshot? {
        mediaByDay[day]
    }

    func hasMedia(for day: LogicalDay) -> Bool {
        mediaByDay[day] != nil
    }

    func resetAllData() async -> Bool {
        guard beginOperation(.resetData) else { return false }
        invalidateReminderIntents()
        defer { finishOperation() }
        do {
            settings.markResetPending()
            let newHabit = try repository.resetAll(systemTimeZone: .autoupdatingCurrent)
            try await mediaService.removeAllFiles()
            settings.reset()
            await reminderReconcileTask?.value
            await reminderScheduler.removeAllPulseNotifications()
            habit = newHabit
            selectedMonth = nil
            try loadSnapshot()
            notificationPermission = await reminderScheduler.permissionState()
            reminderDeliveryMode = .disabled
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
                let deliveryMode = preferredReminderDeliveryMode
                guard deliveryMode != .disabled else {
                    throw PulseAppError.reminderUnavailable
                }

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
                notificationPermission = await reminderScheduler.permissionState()
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

    func requestReminderTime(_ reminderTime: PulseReminderTime) {
        settings.reminderTime = reminderTime
        _ = enqueueReminderReconciliation()
    }

    func purchaseEnhancement() async {
        do {
            _ = try await featureAccess.purchase()
        } catch {
            present(error)
        }
    }

    func restoreEnhancement() async {
        do {
            try await featureAccess.restore()
        } catch {
            present(error)
        }
    }

    func requestLanguage(_ language: PulseInterfaceLanguage) {
        guard settings.language != language else { return }
        settings.language = language
        widgetTimelineReloader.reloadDailyImprint()
        _ = enqueueReminderReconciliation()
    }

    @discardableResult
    func requestVisualTheme(_ visualTheme: PulseVisualTheme) -> Bool {
        guard PulseVisualThemeAccessPolicy.isAvailable(
            visualTheme,
            hasEnhancementEntitlement: featureAccess.hasEnhancement
        ) else {
            return false
        }
        settings.visualTheme = visualTheme
        return true
    }

    func dismissThemeAccessNotice() {
        themeAccessNoticePresented = false
    }

    func notifyPhotoIntentReady() {
        guard settings.hapticsEnabled else { return }
        hapticFeedback.notifyHoldReady()
    }

    func updateTimeZone(identifier: String) async -> Bool {
        guard let habit, beginOperation(.updateTimeZone) else { return false }
        defer { finishOperation() }
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

    func makeBackupExport(passphrase: String) async throws -> PulseBackupExport {
        guard let habit else {
            throw PulseCoreError.backupUnavailable
        }
        guard beginOperation(.exportBackup) else { throw PulseCoreError.backupUnavailable }
        defer { finishOperation() }
        let startLogicalDay = habit.startLogicalDay
        let payload = PulseBackupPayload(
            format: PulseBackupContract.payloadFormatIdentifier,
            schemaVersion: PulseBackupContract.payloadSchemaVersion,
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
                    timeZoneIdentifier: $0.timeZoneIdentifier,
                    journalNote: $0.journalNote,
                    journalNoteModifiedAt: $0.journalNoteModifiedAt
                )
            },
            media: media.map(PulseBackupPayload.MediaPayload.init(snapshot:))
        )
        try FileManager.default.createDirectory(
            at: archiveWorkingDirectoryURL,
            withIntermediateDirectories: true
        )
        try PulseStoreProtection.enforce(in: archiveWorkingDirectoryURL)
        let destinationURL = archiveWorkingDirectoryURL.appendingPathComponent(
            "export-\(UUID().uuidString).\(PulseBackupContract.fileExtension)"
        )
        try await mediaService.writeArchive(
            payload: payload,
            to: destinationURL,
            passphrase: passphrase
        )
        return PulseBackupExport(
            fileURL: destinationURL,
            suggestedFilename: PulseBackupContract.filename(day: today?.storageValue)
        )
    }

    func decodeBackup(from url: URL, passphrase: String) async throws -> PulseDecodedBackup {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let stagingURL = archiveWorkingDirectoryURL.appendingPathComponent(
            "restore-\(UUID().uuidString)",
            isDirectory: true
        )
        return try await Task.detached(priority: .userInitiated) {
            try PulseEncryptedBackupCodec.read(
                from: url,
                stagingDirectoryURL: stagingURL,
                passphrase: passphrase
            )
        }.value
    }

    func restoreBackup(_ decoded: PulseDecodedBackup) async -> Bool {
        guard beginOperation(.restoreBackup) else { return false }
        invalidateReminderIntents()
        defer { finishOperation() }
        do {
            habit = try await mediaService.restore(decoded)
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
        let fetchedMedia = try repository.allMedia(habitID: currentHabit.id)

        let resolvedRecordsByDay = Dictionary(
            uniqueKeysWithValues: fetchedRecords.map { ($0.logicalDay, $0) }
        )
        let resolvedCheckedDays = Set(resolvedRecordsByDay.keys)

        habit = currentHabit
        records = fetchedRecords
        media = fetchedMedia
        timeZone = resolvedTimeZone
        today = resolvedToday
        habitStartDay = resolvedStartDay
        checkedDays = resolvedCheckedDays
        recordsByDay = resolvedRecordsByDay
        mediaByDay = Dictionary(uniqueKeysWithValues: fetchedMedia.map { ($0.logicalDay, $0) })
        statistics = CheckInStatistics.calculate(
            checkedDays: Set(resolvedCheckedDays.filter { $0 <= resolvedToday }),
            today: resolvedToday,
            timeZone: resolvedTimeZone
        )
        if wasShowingCurrentMonth {
            selectedMonth = resolvedToday.firstDayOfMonth()
        }
        if currentHabit.isIdentityConfirmed {
            publishCurrentWatchSnapshot()
        } else {
            watchConnectivity.publish(nil)
        }
    }

    private func makeCurrentWatchSnapshot() throws -> PulseWatchProjectSnapshot? {
        guard let currentHabit = try repository.existingPrimaryHabit(),
              currentHabit.isIdentityConfirmed else {
            return nil
        }
        return try PulseWatchSnapshotProjector.makeSnapshot(
            habit: currentHabit,
            records: repository.allRecords(habitID: currentHabit.id),
            waveMotionEnabled: settings.watchWaveMotionEnabled,
            at: clock.now
        )
    }

    private func publishCurrentWatchSnapshot() {
        do {
            watchConnectivity.publish(try makeCurrentWatchSnapshot())
        } catch {
            watchConnectivity.publish(nil)
        }
    }

    private func auditMediaStorage() async {
        guard let habit else { return }
        do {
            try await mediaService.audit(habitID: habit.id)
            mediaStorageByteCount = try await mediaService.storageByteCount()
        } catch {
            loadState = .failed
            present(error)
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
            deliveryMode: PulseReminderDeliveryPolicy.deliveryMode(
                reminderEnabled: settings.reminderEnabled,
                hasEnhancementEntitlement: featureAccess.hasEnhancement,
                capabilities: reminderScheduler.deliveryCapabilities
            ),
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
                let deliveryMode = try await self.reminderScheduler.reconcile(snapshot)
                guard revision == self.reminderReconcileRevision else { return }
                self.reminderDeliveryMode = deliveryMode
                self.reminderSyncState = .synced
            } catch {
                guard revision == self.reminderReconcileRevision else { return }
                if snapshot.enabled {
                    let permission = await self.reminderScheduler.permissionState()
                    guard revision == self.reminderReconcileRevision else { return }
                    self.notificationPermission = permission
                    self.present(error)
                }
                self.reminderDeliveryMode = .disabled
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

    private func beginOperation(_ nextOperation: AppOperation) -> Bool {
        guard operation == nil else { return false }
        operation = nextOperation
        return true
    }

    private func finishOperation() {
        operation = nil
        guard sceneActivationPending else { return }
        sceneActivationPending = false
        Task { @MainActor [weak self] in
            await self?.handleSceneActivation()
        }
    }

    private func reconcileVisualThemeAccess(
        hasEnhancementEntitlement: Bool,
        presentsNotice: Bool
    ) {
        guard !PulseVisualThemeAccessPolicy.isAvailable(
            settings.visualTheme,
            hasEnhancementEntitlement: hasEnhancementEntitlement
        ) else {
            return
        }
        settings.visualTheme = PulseVisualThemeAccessPolicy.freeTheme
        if presentsNotice {
            themeAccessNoticePresented = true
        }
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
