import XCTest
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
    }

    func testCheckInUpdatesAllDerivedStateAndHapticsOnce() async throws {
        let context = try makeContext()
        await context.model.start()

        await context.model.checkIn()
        await context.model.checkIn()

        XCTAssertNotNil(context.model.todayRecord)
        XCTAssertEqual(context.model.statistics.currentStreak, 1)
        XCTAssertEqual(context.model.statistics.longestStreak, 1)
        XCTAssertEqual(context.model.statistics.totalCount, 1)
        XCTAssertEqual(context.haptics.successCount, 1)
        XCTAssertEqual(context.scheduler.snapshots.last?.checkedDays, context.model.checkedDays)
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

    func testExternallyRevokedPermissionFailsClosedInsteadOfLeavingToggleEnabled() async throws {
        let context = try makeContext(notificationPermission: .authorized)
        await context.model.start()
        context.model.requestReminderEnabled(true)
        await waitUntil {
            context.model.reminderSyncState == .synced
                && context.model.settings.reminderEnabled
        }

        context.scheduler.permission = .denied
        await context.model.handleSceneActivation()

        XCTAssertFalse(context.model.settings.reminderEnabled)
        XCTAssertFalse(context.model.displayedReminderEnabled)
        XCTAssertEqual(context.model.notificationPermission, .denied)
        XCTAssertEqual(context.model.reminderSyncState, .failed)
        XCTAssertNotNil(context.model.errorMessage)
    }

    func testChangingLanguageReschedulesReminderContentWithSelectedLocale() async throws {
        let context = try makeContext(notificationPermission: .authorized)
        await context.model.start()
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
    }

    private func makeContext(
        notificationPermission: NotificationPermissionState = .authorized
    ) throws -> TestContext {
        let clock = MutablePulseClock(now: makeDate(day: 10, hour: 12))
        let repository = SwiftDataCheckInRepository(
            container: try PersistenceController.makeContainer(inMemory: true),
            clock: clock
        )
        let suiteName = "PulseAppModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = try AppSettings(defaults: defaults)
        let scheduler = TestReminderScheduler(permission: notificationPermission)
        let haptics = TestHaptics()
        let model = PulseAppModel(
            repository: repository,
            settings: settings,
            reminderScheduler: scheduler,
            clock: clock,
            hapticFeedback: haptics
        )
        return TestContext(
            model: model,
            clock: clock,
            scheduler: scheduler,
            haptics: haptics
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
    private(set) var successCount = 0

    func notifySuccess() {
        successCount += 1
    }
}

@MainActor
private final class TestReminderScheduler: ReminderScheduling {
    var permission: NotificationPermissionState
    var suspendPermissionRequest = false
    private(set) var snapshots: [ReminderScheduleSnapshot] = []
    private(set) var removeAllCount = 0
    private var permissionContinuation: CheckedContinuation<Bool, Never>?

    init(permission: NotificationPermissionState) {
        self.permission = permission
    }

    var hasPendingPermissionRequest: Bool {
        permissionContinuation != nil
    }

    func permissionState() async -> NotificationPermissionState {
        permission
    }

    func requestPermission() async throws -> Bool {
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

    func reconcile(_ snapshot: ReminderScheduleSnapshot) async throws {
        snapshots.append(snapshot)
        if snapshot.enabled && permission != .authorized {
            throw PulseError.notificationPermissionDenied
        }
    }

    func removeAllPulseNotifications() async {
        removeAllCount += 1
    }
}
