import XCTest
import PulseCore
@testable import pulse

@MainActor
final class ReminderSchedulerLiveActivityTests: XCTestCase {
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
        XCTAssertEqual(client.removeAllCount, 1)
    }

    func testCapacityFailureKeepsAnAlreadyAcceptedPrefix() async throws {
        let client = TestReminderLiveActivityScheduler(failingCall: 3)
        let notifications = TestReminderNotificationScheduler(permission: .authorized)
        let scheduler = ReminderScheduler(
            notificationScheduler: notifications,
            liveActivityScheduler: client
        )

        let mode = try await scheduler.reconcile(makeSnapshot())

        XCTAssertEqual(mode, .scheduledLiveActivity)
        XCTAssertEqual(client.scheduledReminders.count, 3)
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
            XCTAssertEqual(error as? PulseAppError, .liveActivitySchedulingFailed)
        }

        XCTAssertEqual(client.removeAllCount, 3)
        XCTAssertTrue(notifications.addedIdentifiers.isEmpty)
    }

    private func makeSnapshot() -> ReminderScheduleSnapshot {
        ReminderScheduleSnapshot(
            enabled: true,
            deliveryMode: .scheduledLiveActivity,
            time: ReminderTime(hour: 13, minute: 0)!,
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

    let capabilities = ReminderDeliveryCapabilities(
        supportsScheduledLiveActivities: true,
        liveActivitiesEnabled: true
    )
    private let failingCall: Int?
    private(set) var scheduledReminders: [PlannedReminder] = []
    private(set) var removeAllCount = 0

    init(failingCall: Int? = nil) {
        self.failingCall = failingCall
    }

    func schedule(_ reminder: PlannedReminder, locale: Locale) async throws {
        scheduledReminders.append(reminder)
        if scheduledReminders.count == failingCall {
            throw Failure.rejected
        }
    }

    func removeAll() async {
        removeAllCount += 1
    }
}
