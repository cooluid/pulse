import XCTest
import PulseCore
@testable import pulse

@MainActor
final class ReminderSchedulerLiveActivityTests: XCTestCase {
    func testCompletionEchoStaysInsideWidgetKitAnimationBudget() {
        XCTAssertGreaterThan(
            PulseReminderActivityContract.completionEchoDuration,
            .zero
        )
        XCTAssertLessThanOrEqual(
            PulseReminderActivityContract.completionEchoDuration,
            .seconds(2)
        )
    }

    func testScheduledLiveActivityUsesTheBoundedRollingBudget() async throws {
        let client = TestReminderLiveActivityScheduler()
        let notifications = TestReminderNotificationScheduler(permission: .authorized)
        let scheduler = ReminderScheduler(
            notificationScheduler: notifications,
            liveActivityScheduler: client
        )

        let mode = try await scheduler.reconcile(makeSnapshot())

        XCTAssertEqual(mode, .scheduledLiveActivity)
        XCTAssertEqual(
            client.scheduledReminders.count,
            PulseReminderActivityContract.maximumScheduledActivities
        )
        XCTAssertEqual(notifications.addedIdentifiers.count, 53)
        XCTAssertEqual(client.removeAllCount, 1)
        XCTAssertEqual(client.preservedLogicalDays, [
            LogicalDay(year: 2026, month: 8, day: 10),
        ])
    }

    func testCapacityFailureSchedulesNotificationsForEveryUnacceptedDay() async throws {
        let client = TestReminderLiveActivityScheduler(failingCall: 3)
        let notifications = TestReminderNotificationScheduler(permission: .authorized)
        let scheduler = ReminderScheduler(
            notificationScheduler: notifications,
            liveActivityScheduler: client
        )

        let mode = try await scheduler.reconcile(makeSnapshot())

        XCTAssertEqual(mode, .scheduledLiveActivity)
        XCTAssertEqual(client.scheduledReminders.count, 3)
        XCTAssertEqual(notifications.addedIdentifiers.count, 58)
        XCTAssertEqual(client.removeAllCount, 1)
    }

    func testFirstSchedulingFailureUsesAuthorizedBasicLocalNotification() async throws {
        let client = TestReminderLiveActivityScheduler(failingCall: 1)
        let notifications = TestReminderNotificationScheduler(permission: .authorized)
        let scheduler = ReminderScheduler(
            notificationScheduler: notifications,
            liveActivityScheduler: client
        )

        let mode = try await scheduler.reconcile(makeSnapshot())

        XCTAssertEqual(mode, .localNotification)
        XCTAssertEqual(client.scheduledReminders.count, 1)
        XCTAssertEqual(client.removeAllCount, 2)
        XCTAssertEqual(notifications.addedIdentifiers.count, 60)
    }

    func testFirstSchedulingFailureReportsUnavailableWhenBasicNotificationsAreDenied() async {
        let client = TestReminderLiveActivityScheduler(failingCall: 1)
        let notifications = TestReminderNotificationScheduler(permission: .denied)
        let scheduler = ReminderScheduler(
            notificationScheduler: notifications,
            liveActivityScheduler: client
        )

        do {
            _ = try await scheduler.reconcile(makeSnapshot())
            XCTFail("Expected all unavailable delivery channels to fail reconciliation.")
        } catch {
            XCTAssertEqual(
                error as? PulseReminderSchedulingError,
                .liveActivitySchedulingFailed
            )
        }

        XCTAssertEqual(client.removeAllCount, 3)
        XCTAssertTrue(notifications.addedIdentifiers.isEmpty)
    }

    func testCompletionIsForwardedToTheLiveActivityAuthority() async {
        let client = TestReminderLiveActivityScheduler()
        let scheduler = ReminderScheduler(
            notificationScheduler: TestReminderNotificationScheduler(permission: .authorized),
            liveActivityScheduler: client
        )
        let day = LogicalDay(year: 2026, month: 8, day: 10)

        await scheduler.completeLiveActivity(for: day)

        XCTAssertEqual(client.completedDays, [day])
    }

    func testBasicNotificationPlanDoesNotPreserveAnyLiveActivity() async throws {
        let client = TestReminderLiveActivityScheduler()
        let scheduler = ReminderScheduler(
            notificationScheduler: TestReminderNotificationScheduler(permission: .authorized),
            liveActivityScheduler: client
        )

        let mode = try await scheduler.reconcile(
            makeSnapshot(deliveryMode: .localNotification)
        )

        XCTAssertEqual(mode, .localNotification)
        XCTAssertEqual(client.preservedLogicalDays, [nil])
    }

    private func makeSnapshot(
        deliveryMode: PulseReminderDeliveryMode = .scheduledLiveActivity
    ) -> ReminderScheduleSnapshot {
        ReminderScheduleSnapshot(
            enabled: true,
            deliveryMode: deliveryMode,
            time: PulseReminderTime(hour: 13, minute: 0)!,
            timeZoneIdentifier: "UTC",
            localeIdentifier: "en_US",
            checkedDays: [],
            now: makeDate()
        )
    }

    private func makeDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 10, hour: 12)
        )!
    }
}

@MainActor
private final class TestReminderNotificationScheduler: ReminderNotificationScheduling {
    var permission: NotificationPermissionState
    private(set) var addedIdentifiers: [String] = []
    private(set) var pendingIdentifiers: [String] = []
    private(set) var deliveredIdentifiers: [String] = []

    init(permission: NotificationPermissionState) {
        self.permission = permission
    }

    func permissionState() async -> NotificationPermissionState {
        permission
    }

    func requestPermission() async throws -> Bool {
        permission == .authorized
    }

    func pendingRequestIdentifiers() async -> [String] {
        pendingIdentifiers
    }

    func deliveredRequestIdentifiers() async -> [String] {
        deliveredIdentifiers
    }

    func add(
        identifier: String,
        title: String,
        body: String,
        triggerComponents: DateComponents
    ) async throws {
        addedIdentifiers.append(identifier)
        pendingIdentifiers.append(identifier)
    }

    func removePendingRequests(identifiers: [String]) {
        pendingIdentifiers.removeAll { identifiers.contains($0) }
    }

    func removeDeliveredNotifications(identifiers: [String]) {
        deliveredIdentifiers.removeAll { identifiers.contains($0) }
    }
}

@MainActor
private final class TestReminderLiveActivityScheduler: ReminderLiveActivityScheduling {
    enum Failure: Error, Equatable {
        case rejected
    }

    let capabilities = PulseReminderDeliveryCapabilities(
        supportsScheduledLiveActivities: true,
        liveActivitiesEnabled: true
    )
    private let failingCall: Int?
    private(set) var scheduledReminders: [PlannedReminder] = []
    private(set) var completedDays: [LogicalDay] = []
    private(set) var removeAllCount = 0
    private(set) var preservedLogicalDays: [LogicalDay?] = []

    init(failingCall: Int? = nil) {
        self.failingCall = failingCall
    }

    func schedule(_ reminder: PlannedReminder, locale: Locale) async throws {
        scheduledReminders.append(reminder)
        if scheduledReminders.count == failingCall {
            throw Failure.rejected
        }
    }

    func complete(logicalDay: LogicalDay) async {
        completedDays.append(logicalDay)
    }

    func removeAll(preservingActiveLogicalDay: LogicalDay?) async {
        removeAllCount += 1
        preservedLogicalDays.append(preservingActiveLogicalDay)
    }
}
