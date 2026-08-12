import XCTest
@testable import PulseCore
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

    func testIdentityUpdateRefreshesSnapshotWithoutChangingFacts() async throws {
        let context = try makeContext()
        await context.model.start()
        let initialWidgetReloadCount = context.widgetReloader.reloadCount
        await context.model.checkIn()
        let habitID = context.model.habit?.id
        let recordID = context.model.todayRecord?.id

        let didUpdate = await context.model.updateHabitIdentity(
            name: "  Daily Reading  ",
            purpose: "  Stay curious  "
        )

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(context.model.habit?.id, habitID)
        XCTAssertEqual(context.model.habit?.name, "Daily Reading")
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
        await waitUntil { context.scheduler.snapshots.last?.checkedDays == context.model.checkedDays }
        XCTAssertEqual(context.scheduler.snapshots.last?.checkedDays, context.model.checkedDays)
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
            deliveryCapabilities: ReminderDeliveryCapabilities(
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
        XCTAssertEqual(context.model.notificationPermission, .notDetermined)
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

    func testPurchasedUserCanPersistPremiumWidgetStyle() async throws {
        let context = try makeContext()
        await context.model.start()
        let initialWidgetReloadCount = context.widgetReloader.reloadCount

        context.model.requestWidgetStyle(.ripplePath)

        XCTAssertEqual(context.model.settings.widgetStyle, .ripplePath)
        XCTAssertEqual(context.widgetReloader.reloadCount, initialWidgetReloadCount + 1)

        context.model.requestWidgetStyle(.ripplePath)
        XCTAssertEqual(context.widgetReloader.reloadCount, initialWidgetReloadCount + 1)
    }

    func testFreeUserCannotPersistPremiumWidgetStyle() async throws {
        let context = try makeContext(hasEnhancement: false)
        await context.model.start()
        let initialWidgetReloadCount = context.widgetReloader.reloadCount

        context.model.requestWidgetStyle(.morningDew)

        XCTAssertEqual(context.model.settings.widgetStyle, .breathingOrbit)
        XCTAssertEqual(context.widgetReloader.reloadCount, initialWidgetReloadCount)
        XCTAssertNotNil(context.model.errorMessage)
    }

    func testFreeUserStartNormalizesPersistedPremiumWidgetStyle() async throws {
        let context = try makeContext(
            hasEnhancement: false,
            initialWidgetStyle: .grassWindow
        )

        await context.model.start()

        XCTAssertEqual(context.model.settings.widgetStyle, .breathingOrbit)
        XCTAssertNil(context.model.errorMessage)
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
        deliveryCapabilities: ReminderDeliveryCapabilities = .init(
            supportsScheduledLiveActivities: false,
            liveActivitiesEnabled: false
        ),
        initialWidgetStyle: PulseWidgetStyle = .breathingOrbit
    ) throws -> TestContext {
        let clock = MutablePulseClock(now: makeDate(day: 10, hour: 12))
        let repository = SwiftDataPulseRepository(
            container: try PersistenceController.makeInMemoryContainer(),
            clock: clock,
            primaryHabitProvisioning: .createIfMissing(
                try HabitIdentity(userName: "Test Habit", userPurpose: nil)
            )
        )
        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseAppModelTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: workingDirectory,
            withIntermediateDirectories: true
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: workingDirectory) }
        let mediaService = ImprintMediaService(
            repository: repository,
            fileStore: try PulseMediaFileStore(
                rootURL: workingDirectory.appendingPathComponent("Media", isDirectory: true)
            ),
            clock: clock
        )
        let suiteName = "PulseAppModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = try AppSettings(
            sharedInterfacePreferences: PulseSharedInterfacePreferences(defaults: defaults),
            defaults: defaults
        )
        settings.widgetStyle = initialWidgetStyle
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
        let model = PulseAppModel(
            repository: repository,
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
            widgetTimelineReloader: widgetReloader
        )
        return TestContext(
            model: model,
            clock: clock,
            scheduler: scheduler,
            haptics: haptics,
            widgetReloader: widgetReloader
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
    let clock: MutablePulseClock
    let scheduler: TestReminderScheduler
    let haptics: TestHaptics
    let widgetReloader: TestWidgetTimelineReloader
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
    let deliveryCapabilities: ReminderDeliveryCapabilities
    var suspendPermissionRequest = false
    private(set) var snapshots: [ReminderScheduleSnapshot] = []
    private(set) var removeAllCount = 0
    private(set) var permissionRequestCount = 0
    private var permissionContinuation: CheckedContinuation<Bool, Never>?

    init(
        permission: NotificationPermissionState,
        deliveryCapabilities: ReminderDeliveryCapabilities
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
        guard suspendPermissionRequest else {
            return permission == .authorized
        }
        return await withCheckedContinuation { continuation in
            permissionContinuation = continuation
        }
    }

    func completePermissionRequest(granted: Bool) {
        permission = granted ? .authorized : .denied
        permissionContinuation?.resume(returning: granted)
        permissionContinuation = nil
    }

    func reconcile(_ snapshot: ReminderScheduleSnapshot) async throws -> ReminderDeliveryMode {
        snapshots.append(snapshot)
        if snapshot.enabled,
           snapshot.deliveryMode == .localNotification,
           permission != .authorized {
            throw PulseAppError.notificationPermissionDenied
        }
        return snapshot.deliveryMode
    }

    func removeAllPulseNotifications() async {
        removeAllCount += 1
    }
}
