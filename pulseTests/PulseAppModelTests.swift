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

    func testDeniedNotificationPermissionDoesNotEnableReminder() async throws {
        let context = try makeContext(notificationPermission: .denied)
        await context.model.start()

        await context.model.setReminderEnabled(true)

        XCTAssertFalse(context.model.settings.reminderEnabled)
        XCTAssertEqual(context.model.notificationPermission, .denied)
        XCTAssertNotNil(context.model.errorMessage)
    }

    private func makeContext(
        notificationPermission: NotificationPermissionState = .authorized
    ) throws -> TestContext {
        let repository = SwiftDataCheckInRepository(
            container: try PersistenceController.makeContainer(inMemory: true)
        )
        let suiteName = "PulseAppModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = try AppSettings(defaults: defaults)
        let clock = MutablePulseClock(now: makeDate(day: 10, hour: 12))
        let scheduler = TestReminderScheduler(permission: notificationPermission)
        let haptics = TestHaptics()
        let model = PulseAppModel(
            repository: repository,
            settings: settings,
            reminderScheduler: scheduler,
            clock: clock,
            hapticFeedback: haptics
        )
        return TestContext(model: model, clock: clock, haptics: haptics)
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

    init(permission: NotificationPermissionState) {
        self.permission = permission
    }

    func permissionState() async -> NotificationPermissionState {
        permission
    }

    func requestPermission() async throws -> Bool {
        permission == .authorized
    }

    func reconcile(
        enabled: Bool,
        time: ReminderTime,
        habit: Habit,
        checkedDays: Set<LogicalDay>,
        now: Date
    ) async throws {
        if enabled && permission != .authorized {
            throw PulseError.notificationPermissionDenied
        }
    }

    func removeAllPulseNotifications() async {}
}
