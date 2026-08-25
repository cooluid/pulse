import XCTest
@testable import PulseCore
@testable import PulseWatchShared
@testable import pulse

@MainActor
final class PulseAppModelTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "Asia/Shanghai")!

    func testStartLoadsEmptyTodayState() async throws {
        let context = try makeContext()

        await context.model.start()

        XCTAssertEqual(context.model.loadState, .ready)
        XCTAssertNil(context.model.todayRecord)
        XCTAssertEqual(context.model.statistics, .empty)
        XCTAssertEqual(context.scheduler.snapshots.last?.enabled, false)
        XCTAssertFalse(context.model.habit?.isIdentityConfirmed ?? true)
    }

    func testUnpurchasedUserCanSelectOnlyTheFreeInterfaceTheme() async throws {
        let context = try makeContext(hasEnhancement: false)
        await context.model.start()

        XCTAssertEqual(context.model.settings.visualTheme, .editorialJournal)
        XCTAssertTrue(context.model.requestVisualTheme(.editorialJournal))
        XCTAssertFalse(context.model.requestVisualTheme(.quietField))
        XCTAssertFalse(context.model.requestVisualTheme(.sunlitDay))
        XCTAssertEqual(context.model.resolvedVisualTheme, .editorialJournal)
    }

    func testPurchasedUserCanSelectEveryInterfaceTheme() async throws {
        let context = try makeContext(hasEnhancement: true)
        await context.model.start()

        XCTAssertTrue(context.model.requestVisualTheme(.quietField))
        XCTAssertEqual(context.model.resolvedVisualTheme, .quietField)
        XCTAssertTrue(context.model.requestVisualTheme(.sunlitDay))
        XCTAssertEqual(context.model.resolvedVisualTheme, .sunlitDay)
    }

    func testUnavailablePersistedPaidThemeIsExplicitlyResetOnStart() async throws {
        let context = try makeContext(hasEnhancement: false)
        context.model.settings.visualTheme = .sunlitDay

        XCTAssertEqual(context.model.resolvedVisualTheme, .editorialJournal)
        await context.model.start()

        XCTAssertEqual(context.model.settings.visualTheme, .editorialJournal)
        XCTAssertEqual(context.model.resolvedVisualTheme, .editorialJournal)
        XCTAssertTrue(context.model.themeAccessNoticePresented)
        context.model.dismissThemeAccessNotice()
        XCTAssertFalse(context.model.themeAccessNoticePresented)
    }

    func testIdentityUpdateRefreshesSnapshotWithoutChangingFacts() async throws {
        let context = try makeContext()
        await context.model.start()
        let initialWidgetReloadCount = context.widgetReloader.reloadCount
        await context.model.checkIn()
        let habitID = context.model.habit?.id
        let recordID = context.model.todayRecord?.id

        let didUpdate = await context.model.updateHabitIdentity(
            name: "  Daily Focus  ",
            purpose: "  Stay curious  "
        )

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(context.model.habit?.id, habitID)
        XCTAssertEqual(context.model.habit?.name, "Daily Focus")
        XCTAssertEqual(context.model.habit?.purpose, "Stay curious")
        XCTAssertTrue(context.model.habit?.isIdentityConfirmed ?? false)
        XCTAssertEqual(context.model.todayRecord?.id, recordID)
        XCTAssertEqual(context.model.statistics.totalCount, 1)
        XCTAssertEqual(context.widgetReloader.reloadCount, initialWidgetReloadCount + 2)
    }

    func testInvalidIdentityDoesNotMutateHabit() async throws {
        let context = try makeContext()
        await context.model.start()
        let originalName = context.model.habit?.name

        let didUpdate = await context.model.updateHabitIdentity(name: "  ", purpose: nil)

        XCTAssertFalse(didUpdate)
        XCTAssertEqual(context.model.habit?.name, originalName)
        XCTAssertFalse(context.model.habit?.isIdentityConfirmed ?? true)
        XCTAssertNotNil(context.model.errorMessage)
    }

    func testCheckInUpdatesAllDerivedStateAndHapticsOnce() async throws {
        let context = try makeContext()
        await context.model.start()
        let initialWidgetReloadCount = context.widgetReloader.reloadCount
        let initialReminderSnapshotCount = context.scheduler.snapshots.count

        let first = await context.model.checkIn()
        let second = await context.model.checkIn()

        XCTAssertNotNil(context.model.todayRecord)
        XCTAssertEqual(first?.disposition, .created)
        XCTAssertNil(second)
        XCTAssertEqual(context.model.statistics.currentStreak, 1)
        XCTAssertEqual(context.model.statistics.longestStreak, 1)
        XCTAssertEqual(context.model.statistics.totalCount, 1)
        XCTAssertEqual(context.haptics.successCount, 1)
        XCTAssertEqual(context.widgetReloader.reloadCount, initialWidgetReloadCount + 1)
        XCTAssertEqual(context.scheduler.snapshots.count, initialReminderSnapshotCount)
        XCTAssertEqual(context.scheduler.completedLiveActivityDays, [context.model.today!])
    }

    func testCommittedCheckInIsNotReclassifiedWhenProjectionRefreshFails() async throws {
        let context = try makeContext(failsProjectionReadsAfterCheckIn: true)
        await context.model.start()
        let habit = try XCTUnwrap(context.model.habit)
        let initialWidgetReloadCount = context.widgetReloader.reloadCount

        let receipt = await context.model.checkIn()

        XCTAssertEqual(receipt?.disposition, .created)
        XCTAssertEqual(try context.repository.allRecords(habitID: habit.id).count, 1)
        XCTAssertEqual(context.model.loadState, .failed)
        XCTAssertEqual(context.haptics.successCount, 1)
        XCTAssertEqual(context.widgetReloader.reloadCount, initialWidgetReloadCount + 1)
        XCTAssertEqual(
            context.scheduler.completedLiveActivityDays,
            [receipt?.logicalDay].compactMap { $0 }
        )
        XCTAssertEqual(
            context.model.errorMessage,
            PulseLocalization.string(
                "error.check_in_saved_refresh_failed",
                locale: context.model.settings.locale
            )
        )
    }

    func testWatchCommandCommitsThroughRepositoryAndPublishesConfirmedSnapshot() async throws {
        let context = try makeContext()
        await context.model.start()
        let identityUpdated = await context.model.updateHabitIdentity(
            name: "Test Habit",
            purpose: nil
        )
        XCTAssertTrue(identityUpdated)
        let habit = try XCTUnwrap(context.model.habit)
        let command = PulseWatchCheckInCommand(
            projectID: habit.id,
            projectRevision: PulseWatchProjectRevision.make(
                projectID: habit.id,
                startLogicalDay: habit.startLogicalDay.storageValue,
                timeZoneIdentifier: habit.timeZoneIdentifier
            ),
            occurredAt: context.clock.now,
            projectTimeZoneIdentifierSnapshot: habit.timeZoneIdentifier
        )

        let receipt = await context.model.handleWatchCheckIn(command)

        guard case .committed(let logicalDay, let checkedAt, let disposition) = receipt?.outcome else {
            return XCTFail("Expected a committed Watch receipt.")
        }
        XCTAssertEqual(logicalDay, context.model.today?.storageValue)
        XCTAssertEqual(checkedAt, context.clock.now)
        XCTAssertEqual(disposition, .created)
        XCTAssertEqual(context.model.statistics.totalCount, 1)
        XCTAssertEqual(
            context.watchConnectivity.snapshots.compactMap { $0 }.last?.isCheckedToday,
            true
        )
        XCTAssertEqual(context.scheduler.completedLiveActivityDays, [context.model.today!])
    }

    func testWatchReceivesCommittedReceiptWhenPhoneProjectionRefreshFails() async throws {
        let context = try makeContext(failsProjectionReadsAfterCheckIn: true)
        await context.model.start()
        let didConfirmIdentity = await context.model.updateHabitIdentity(
            name: "Test Habit",
            purpose: nil
        )
        XCTAssertTrue(didConfirmIdentity)
        let habit = try XCTUnwrap(context.model.habit)
        let command = PulseWatchCheckInCommand(
            projectID: habit.id,
            projectRevision: PulseWatchProjectRevision.make(
                projectID: habit.id,
                startLogicalDay: habit.startLogicalDay.storageValue,
                timeZoneIdentifier: habit.timeZoneIdentifier
            ),
            occurredAt: context.clock.now,
            projectTimeZoneIdentifierSnapshot: habit.timeZoneIdentifier
        )

        let receipt = await context.model.handleWatchCheckIn(command)

        guard case .committed(let logicalDay, _, let disposition) = receipt?.outcome else {
            return XCTFail("A persisted Watch command must remain committed.")
        }
        XCTAssertEqual(disposition, .created)
        XCTAssertEqual(logicalDay, habit.logicalDay(at: context.clock.now).storageValue)
        XCTAssertEqual(try context.repository.allRecords(habitID: habit.id).count, 1)
        XCTAssertEqual(context.model.loadState, .failed)
    }

    func testWatchSnapshotRequestReadsTheCurrentRepositoryFact() async throws {
        let context = try makeContext()
        await context.model.start()
        let identityUpdated = await context.model.updateHabitIdentity(
            name: "Test Habit",
            purpose: nil
        )
        XCTAssertTrue(identityUpdated)
        _ = await context.model.checkIn()

        let handler = try XCTUnwrap(context.watchConnectivity.snapshotHandler)
        let snapshot = try await handler()

        XCTAssertEqual(snapshot?.projectID, context.model.habit?.id)
        XCTAssertEqual(snapshot?.todayLogicalDay, context.model.today?.storageValue)
        XCTAssertEqual(snapshot?.isCheckedToday, true)
    }

    func testWatchWaveMotionSettingPersistsAndPublishesSnapshot() async throws {
        let context = try makeContext()
        await context.model.start()
        let identityUpdated = await context.model.updateHabitIdentity(
            name: "Test Habit",
            purpose: nil
        )
        XCTAssertTrue(identityUpdated)

        context.model.setWatchWaveMotionEnabled(false)

        XCTAssertFalse(context.model.settings.watchWaveMotionEnabled)
        XCTAssertEqual(
            context.watchConnectivity.snapshots.compactMap { $0 }.last?.waveMotionEnabled,
            false
        )
        let handler = try XCTUnwrap(context.watchConnectivity.snapshotHandler)
        let requestedSnapshot = try await handler()
        XCTAssertEqual(requestedSnapshot?.waveMotionEnabled, false)
    }

    func testWatchConnectionStatusTracksConnectivityChanges() throws {
        let context = try makeContext()
        XCTAssertEqual(context.model.watchConnectionStatus, .installed)

        context.watchConnectivity.connectionStatus = .notInstalled

        XCTAssertEqual(context.model.watchConnectionStatus, .notInstalled)
    }

    func testWatchConnectionStatusShowsOpenWatchAppActionOnlyWhenNeeded() {
        XCTAssertTrue(PulseWatchConnectionStatus.notInstalled.showsOpenWatchAppAction)
        XCTAssertTrue(PulseWatchConnectionStatus.unpaired.showsOpenWatchAppAction)
        XCTAssertFalse(PulseWatchConnectionStatus.installed.showsOpenWatchAppAction)
        XCTAssertFalse(PulseWatchConnectionStatus.activating.showsOpenWatchAppAction)
        XCTAssertFalse(PulseWatchConnectionStatus.unsupported.showsOpenWatchAppAction)
    }

    func testExternalSystemSurfaceCommitRefreshesAppAndWatchSnapshot() async throws {
        let context = try makeContext()
        await context.model.start()
        let identityUpdated = await context.model.updateHabitIdentity(
            name: "Test Habit",
            purpose: nil
        )
        XCTAssertTrue(identityUpdated)
        let habit = try XCTUnwrap(context.model.habit)

        _ = try context.repository.checkIn(habitID: habit.id, journalNote: nil)
        PulseExternalCheckInSignal.post()

        await waitUntil { context.model.todayRecord != nil }
        XCTAssertEqual(context.model.statistics.totalCount, 1)
        XCTAssertEqual(
            context.watchConnectivity.snapshots.compactMap { $0 }.last?.isCheckedToday,
            true
        )
    }

    func testCheckInUsesCommittedLogicalDayForSystemSurfaceCompletionAcrossMidnight() async throws {
        let context = try makeContext()
        await context.model.start()
        context.clock.now = makeDate(day: 11, hour: 0)

        let receipt = await context.model.checkIn()

        let committedDay = LogicalDay(year: 2026, month: 8, day: 11)
        XCTAssertEqual(receipt?.logicalDay, committedDay)
        XCTAssertEqual(context.model.today, committedDay)
        XCTAssertEqual(context.scheduler.completedLiveActivityDays, [committedDay])
    }

    func testJournalNoteUpdateRefreshesSnapshotWithoutChangingCheckInFacts() async throws {
        let context = try makeContext()
        await context.model.start()
        let receipt = await context.model.checkIn()
        let originalStatistics = context.model.statistics
        let originalCheckedAt = context.model.todayRecord?.checkedAt

        let didUpdate = await context.model.updateJournalNote(
            recordID: try XCTUnwrap(receipt?.recordID),
            journalNote: "  今天保持了专注  "
        )

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(context.model.todayRecord?.journalNote, "今天保持了专注")
        XCTAssertEqual(context.model.todayRecord?.checkedAt, originalCheckedAt)
        XCTAssertEqual(context.model.statistics, originalStatistics)
        XCTAssertNil(context.model.operation)
    }

    func testRejectedCheckInReturnsNoReceiptOrSuccessFeedback() async throws {
        let context = try makeContext()
        await context.model.start()
        let initialWidgetReloadCount = context.widgetReloader.reloadCount
        let reminderSnapshotCount = context.scheduler.snapshots.count
        context.clock.now = makeDate(day: 9, hour: 12)

        let receipt = await context.model.checkIn()

        XCTAssertNil(receipt)
        XCTAssertNil(context.model.todayRecord)
        XCTAssertEqual(context.model.statistics, .empty)
        XCTAssertEqual(context.haptics.successCount, 0)
        XCTAssertEqual(context.widgetReloader.reloadCount, initialWidgetReloadCount)
        XCTAssertEqual(context.scheduler.snapshots.count, reminderSnapshotCount)
        XCTAssertNotNil(context.model.errorMessage)
    }

    func testAdvancingClockToTomorrowPreservesYesterdayStreak() async throws {
        let context = try makeContext()
        await context.model.start()
        await context.model.checkIn()

        context.clock.now = makeDate(day: 11, hour: 12)
        await context.model.handleSceneActivation()

        XCTAssertEqual(context.model.today, LogicalDay(year: 2026, month: 8, day: 11))
        XCTAssertNil(context.model.todayRecord)
        XCTAssertEqual(context.model.statistics.currentStreak, 1)
    }

    func testSceneActivationDuringLongOperationReloadsAfterTheOperationFinishes() async throws {
        let context = try makeContext()
        await context.model.start()

        let exportTask = Task { @MainActor in
            try await context.model.makeBackupExport(passphrase: "1234")
        }
        await waitUntil { context.model.operation == .exportBackup }
        context.clock.now = makeDate(day: 11, hour: 0)
        await context.model.handleSceneActivation()

        let export = try await exportTask.value
        await waitUntil {
            context.model.operation == nil
                && context.model.today == LogicalDay(year: 2026, month: 8, day: 11)
        }

        XCTAssertEqual(context.model.today, LogicalDay(year: 2026, month: 8, day: 11))
        _ = export
    }

    func testAcceptedTimeZoneChangePreservesStartAndRecordProvenance() async throws {
        let context = try makeContext()
        await context.model.start()
        await context.model.checkIn()
        let originalStart = context.model.habitStartDay
        let originalRecordTimeZone = context.model.todayRecord?.timeZoneIdentifier

        let didUpdate = await context.model.updateTimeZone(identifier: "UTC")

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(context.model.habitStartDay, originalStart)
        XCTAssertEqual(context.model.habit?.creationTimeZoneIdentifier, timeZone.identifier)
        XCTAssertEqual(context.model.habit?.timeZoneIdentifier, "UTC")
        XCTAssertEqual(context.model.todayRecord?.timeZoneIdentifier, originalRecordTimeZone)
        XCTAssertEqual(context.model.statistics.totalCount, 1)
    }

    func testDeniedNotificationPermissionDoesNotEnableReminder() async throws {
        let context = try makeContext(notificationPermission: .denied)
        await context.model.start()

        context.model.requestReminderEnabled(true)
        await waitUntil { context.model.errorMessage != nil }

        XCTAssertFalse(context.model.settings.reminderEnabled)
        XCTAssertFalse(context.model.displayedReminderEnabled)
        XCTAssertEqual(context.model.notificationPermission, .denied)
        XCTAssertNotNil(context.model.errorMessage)
    }

    func testUnpurchasedUserCanEnableAndScheduleFreeLocalNotification() async throws {
        let context = try makeContext(
            notificationPermission: .authorized,
            hasEnhancement: false
        )
        await context.model.start()

        context.model.requestReminderEnabled(true)
        await waitUntil {
            context.model.reminderSyncState == .synced
                && context.model.settings.reminderEnabled
        }

        XCTAssertTrue(context.model.settings.reminderEnabled)
        XCTAssertTrue(context.model.displayedReminderEnabled)
        XCTAssertEqual(context.model.reminderDeliveryMode, .localNotification)
        XCTAssertEqual(context.scheduler.snapshots.last?.deliveryMode, .localNotification)
        XCTAssertEqual(context.scheduler.permissionRequestCount, 0)
        XCTAssertNil(context.model.errorMessage)
    }

    func testPurchasedIOS26PathRequestsBasicNotificationPermissionButUsesLiveActivity() async throws {
        let context = try makeContext(
            notificationPermission: .notDetermined,
            deliveryCapabilities: PulseReminderDeliveryCapabilities(
                supportsScheduledLiveActivities: true,
                liveActivitiesEnabled: true
            )
        )
        await context.model.start()

        context.model.requestReminderEnabled(true)
        await waitUntil {
            context.model.reminderSyncState == .synced
                && context.model.settings.reminderEnabled
        }

        XCTAssertEqual(context.model.reminderDeliveryMode, .scheduledLiveActivity)
        XCTAssertEqual(
            context.scheduler.snapshots.last?.deliveryMode,
            .scheduledLiveActivity
        )
        XCTAssertEqual(context.scheduler.permissionRequestCount, 1)
        XCTAssertEqual(context.model.notificationPermission, .authorized)
    }

    func testStalePermissionResultCannotOverrideNewerDisabledIntent() async throws {
        let context = try makeContext(notificationPermission: .notDetermined)
        context.scheduler.suspendPermissionRequest = true
        await context.model.start()

        context.model.requestReminderEnabled(true)
        await waitUntil { context.scheduler.hasPendingPermissionRequest }
        context.model.requestReminderEnabled(false)
        context.scheduler.completePermissionRequest(granted: true)
        await waitUntil { context.model.reminderSyncState == .synced }

        XCTAssertFalse(context.model.settings.reminderEnabled)
        XCTAssertFalse(context.model.displayedReminderEnabled)
        XCTAssertFalse(context.scheduler.snapshots.last?.enabled ?? true)
    }

    func testExternallyRevokedPermissionKeepsIntentVisibleAndReportsSyncFailure() async throws {
        let context = try makeContext(notificationPermission: .authorized)
        await context.model.start()
        context.model.requestReminderEnabled(true)
        await waitUntil {
            context.model.reminderSyncState == .synced
                && context.model.settings.reminderEnabled
        }

        context.scheduler.permission = .denied
        await context.model.handleSceneActivation()

        XCTAssertTrue(context.model.settings.reminderEnabled)
        XCTAssertTrue(context.model.displayedReminderEnabled)
        XCTAssertEqual(context.model.notificationPermission, .denied)
        XCTAssertEqual(context.model.reminderSyncState, .failed)
        XCTAssertNotNil(context.model.errorMessage)
    }

    func testChangingLanguageReschedulesReminderContentWithSelectedLocale() async throws {
        let context = try makeContext(notificationPermission: .authorized)
        await context.model.start()
        let initialWidgetReloadCount = context.widgetReloader.reloadCount
        context.model.requestReminderEnabled(true)
        await waitUntil {
            context.model.reminderSyncState == .synced
                && context.model.settings.reminderEnabled
        }

        context.model.requestLanguage(.english)
        await waitUntil {
            context.scheduler.snapshots.last?.localeIdentifier == "en"
                && context.model.reminderSyncState == .synced
        }

        XCTAssertEqual(context.model.settings.language, .english)
        XCTAssertEqual(context.scheduler.snapshots.last?.localeIdentifier, "en")
        XCTAssertTrue(context.scheduler.snapshots.last?.enabled ?? false)
        XCTAssertEqual(context.widgetReloader.reloadCount, initialWidgetReloadCount + 1)

        context.model.requestLanguage(.english)
        XCTAssertEqual(context.widgetReloader.reloadCount, initialWidgetReloadCount + 1)
    }

    func testPendingResetJournalIsRecoveredOnStart() async throws {
        let context = try makeContext()
        await context.model.start()
        await context.model.checkIn()
        let originalHabitID = context.model.habit?.id
        context.model.settings.markResetPending()

        await context.model.start()

        XCTAssertEqual(context.model.loadState, .ready)
        XCTAssertNotEqual(context.model.habit?.id, originalHabitID)
        XCTAssertTrue(context.model.records.isEmpty)
        XCTAssertFalse(context.model.settings.isResetPending)
        XCTAssertEqual(context.scheduler.removeAllCount, 1)
        XCTAssertFalse(context.model.habit?.isIdentityConfirmed ?? true)
    }

    private func makeContext(
        notificationPermission: NotificationPermissionState = .authorized,
        hasEnhancement: Bool = true,
        failsProjectionReadsAfterCheckIn: Bool = false,
        deliveryCapabilities: PulseReminderDeliveryCapabilities = .init(
            supportsScheduledLiveActivities: false,
            liveActivitiesEnabled: false
        )
    ) throws -> TestContext {
        let clock = MutablePulseClock(now: makeDate(day: 10, hour: 12))
        let repository = SwiftDataPulseRepository(
            container: try PersistenceController.makeInMemoryContainer(),
            clock: clock,
            primaryHabitProvisioning: .createIfMissing(
                try HabitIdentity(userName: "Test Habit", userPurpose: nil)
            )
        )
        let modelRepository: any PulseRepositoryProtocol = failsProjectionReadsAfterCheckIn
            ? PostCommitProjectionFailingRepository(base: repository)
            : repository
        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseAppModelTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: workingDirectory,
            withIntermediateDirectories: true
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: workingDirectory) }
        let mediaService = ImprintMediaService(
            repository: modelRepository,
            fileStore: try PulseMediaFileStore(
                rootURL: workingDirectory.appendingPathComponent("Media", isDirectory: true)
            ),
            clock: clock
        )
        let suiteName = "PulseAppModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = try AppSettings(
            sharedSettings: PulseSharedSettings(defaults: defaults),
            defaults: defaults
        )
        let scheduler = TestReminderScheduler(
            permission: notificationPermission,
            deliveryCapabilities: deliveryCapabilities
        )
        let featureAccess = FeatureAccessController(
            client: UITestStoreKitAccessClient(
                hasEntitlement: hasEnhancement
            ),
            listensForTransactionUpdates: false
        )
        let haptics = TestHaptics()
        let widgetReloader = TestWidgetTimelineReloader()
        let watchConnectivity = TestWatchConnectivity()
        let model = PulseAppModel(
            repository: modelRepository,
            mediaService: mediaService,
            archiveWorkingDirectoryURL: workingDirectory.appendingPathComponent(
                "ArchiveWork",
                isDirectory: true
            ),
            settings: settings,
            featureAccess: featureAccess,
            reminderScheduler: scheduler,
            clock: clock,
            hapticFeedback: haptics,
            widgetTimelineReloader: widgetReloader,
            watchConnectivity: watchConnectivity
        )
        return TestContext(
            model: model,
            repository: repository,
            clock: clock,
            scheduler: scheduler,
            haptics: haptics,
            widgetReloader: widgetReloader,
            watchConnectivity: watchConnectivity
        )
    }

    private func waitUntil(
        _ predicate: @escaping @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<100 {
            if predicate() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Timed out waiting for asynchronous state.", file: file, line: line)
    }

    private func makeDate(day: Int, hour: Int) -> Date {
        Calendar.pulseGregorian(timeZone: timeZone).date(
            from: DateComponents(year: 2026, month: 8, day: day, hour: hour)
        )!
    }
}

private struct TestContext {
    let model: PulseAppModel
    let repository: SwiftDataPulseRepository
    let clock: MutablePulseClock
    let scheduler: TestReminderScheduler
    let haptics: TestHaptics
    let widgetReloader: TestWidgetTimelineReloader
    let watchConnectivity: TestWatchConnectivity
}

@MainActor
private final class PostCommitProjectionFailingRepository: PulseRepositoryProtocol {
    private let base: SwiftDataPulseRepository
    private var rejectsProjectionReads = false

    init(base: SwiftDataPulseRepository) {
        self.base = base
    }

    func existingPrimaryHabit() throws -> HabitSnapshot? {
        try base.existingPrimaryHabit()
    }

    func primaryHabit(systemTimeZone: TimeZone) throws -> HabitSnapshot {
        try base.primaryHabit(systemTimeZone: systemTimeZone)
    }

    func allRecords(habitID: UUID) throws -> [CheckInRecordSnapshot] {
        guard !rejectsProjectionReads else { throw ProjectionFailure.unavailable }
        return try base.allRecords(habitID: habitID)
    }

    func allMedia(habitID: UUID) throws -> [ImprintMediaSnapshot] {
        try base.allMedia(habitID: habitID)
    }

    func updateIdentity(habitID: UUID, identity: HabitIdentity) throws -> HabitSnapshot {
        try base.updateIdentity(habitID: habitID, identity: identity)
    }

    func checkIn(habitID: UUID, journalNote: String?) throws -> CheckInCommitReceipt {
        let receipt = try base.checkIn(habitID: habitID, journalNote: journalNote)
        rejectsProjectionReads = true
        return receipt
    }

    func checkIn(
        watchCommand: PulseWatchCheckInCommand
    ) throws(PulseWatchRejectionReason) -> CheckInCommitReceipt {
        let receipt = try base.checkIn(watchCommand: watchCommand)
        rejectsProjectionReads = true
        return receipt
    }

    func updateJournalNote(
        recordID: UUID,
        journalNote: String?
    ) throws -> CheckInRecordSnapshot {
        try base.updateJournalNote(recordID: recordID, journalNote: journalNote)
    }

    func delete(recordID: UUID) throws {
        try base.delete(recordID: recordID)
    }

    func upsertMedia(_ draft: ImprintMediaDraft) throws -> ImprintMediaSnapshot {
        try base.upsertMedia(draft)
    }

    func deleteMedia(id: UUID) throws {
        try base.deleteMedia(id: id)
    }

    func updateTimeZone(habitID: UUID, identifier: String) throws {
        try base.updateTimeZone(habitID: habitID, identifier: identifier)
    }

    func resetAll(systemTimeZone: TimeZone) throws -> HabitSnapshot {
        try base.resetAll(systemTimeZone: systemTimeZone)
    }

    func replaceAll(with payload: PulseBackupPayload) throws -> HabitSnapshot {
        try base.replaceAll(with: payload)
    }

    private enum ProjectionFailure: Error {
        case unavailable
    }
}

@MainActor
private final class TestWatchConnectivity: PulseWatchConnectivityProviding {
    var commandHandler: (@MainActor (PulseWatchCheckInCommand) async -> PulseWatchCheckInReceipt?)?
    var snapshotHandler: (@MainActor () async throws -> PulseWatchProjectSnapshot?)?
    var connectionStatusDidChange: (@MainActor (PulseWatchConnectionStatus) -> Void)?
    var connectionStatus = PulseWatchConnectionStatus.installed {
        didSet { connectionStatusDidChange?(connectionStatus) }
    }
    private(set) var startCount = 0
    private(set) var snapshots: [PulseWatchProjectSnapshot?] = []

    func start() {
        startCount += 1
        connectionStatusDidChange?(connectionStatus)
    }

    func publish(_ snapshot: PulseWatchProjectSnapshot?) {
        snapshots.append(snapshot)
    }
}

@MainActor
private final class MutablePulseClock: PulseClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

@MainActor
private final class TestHaptics: HapticFeedbackProviding {
    private(set) var holdReadyCount = 0
    private(set) var successCount = 0

    func notifyHoldReady() {
        holdReadyCount += 1
    }

    func notifySuccess() {
        successCount += 1
    }
}

@MainActor
private final class TestWidgetTimelineReloader: WidgetTimelineReloading {
    private(set) var reloadCount = 0

    func reloadDailyImprint() {
        reloadCount += 1
    }
}

@MainActor
private final class TestReminderScheduler: ReminderScheduling {
    var permission: NotificationPermissionState
    let deliveryCapabilities: PulseReminderDeliveryCapabilities
    var suspendPermissionRequest = false
    private(set) var snapshots: [ReminderScheduleSnapshot] = []
    private(set) var completedLiveActivityDays: [LogicalDay] = []
    private(set) var removeAllCount = 0
    private(set) var permissionRequestCount = 0
    private var permissionContinuation: CheckedContinuation<Bool, Never>?

    init(
        permission: NotificationPermissionState,
        deliveryCapabilities: PulseReminderDeliveryCapabilities
    ) {
        self.permission = permission
        self.deliveryCapabilities = deliveryCapabilities
    }

    var hasPendingPermissionRequest: Bool {
        permissionContinuation != nil
    }

    func permissionState() async -> NotificationPermissionState {
        permission
    }

    func requestPermission() async throws -> Bool {
        permissionRequestCount += 1
        guard !suspendPermissionRequest else {
            return await withCheckedContinuation { continuation in
                permissionContinuation = continuation
            }
        }
        if permission == .notDetermined {
            permission = .authorized
            return true
        }
        return permission == .authorized
    }

    func completePermissionRequest(granted: Bool) {
        permission = granted ? .authorized : .denied
        permissionContinuation?.resume(returning: granted)
        permissionContinuation = nil
    }

    func reconcile(_ snapshot: ReminderScheduleSnapshot) async throws -> PulseReminderDeliveryMode {
        snapshots.append(snapshot)
        if snapshot.enabled,
           snapshot.deliveryMode == .localNotification,
           permission != .authorized {
            throw PulseAppError.notificationPermissionDenied
        }
        return snapshot.deliveryMode
    }

    func completeCheckIn(for logicalDay: LogicalDay) async {
        completedLiveActivityDays.append(logicalDay)
    }

    func removeAllPulseNotifications() async {
        removeAllCount += 1
    }
}
