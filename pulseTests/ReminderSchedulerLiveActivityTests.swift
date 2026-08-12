import XCTest
import PulseCore
@testable import pulse

@MainActor
final class ReminderSchedulerLiveActivityTests: XCTestCase {
    func testScheduledLiveActivityUsesTheBoundedRollingBudget() async throws {
        let client = TestReminderLiveActivityScheduler()
        let scheduler = ReminderScheduler(liveActivityScheduler: client)

        try await scheduler.reconcile(makeSnapshot())

        XCTAssertEqual(
            client.scheduledReminders.count,
            PulseReminderActivityContract.maximumScheduledActivities
        )
        XCTAssertEqual(client.removeAllCount, 1)
    }

    func testCapacityFailureKeepsAnAlreadyAcceptedPrefix() async throws {
        let client = TestReminderLiveActivityScheduler(failingCall: 3)
        let scheduler = ReminderScheduler(liveActivityScheduler: client)

        try await scheduler.reconcile(makeSnapshot())

        XCTAssertEqual(client.scheduledReminders.count, 3)
        XCTAssertEqual(client.removeAllCount, 1)
    }

    func testFirstSchedulingFailureFailsClosedAndRemovesThePlan() async {
        let client = TestReminderLiveActivityScheduler(failingCall: 1)
        let scheduler = ReminderScheduler(liveActivityScheduler: client)

        do {
            try await scheduler.reconcile(makeSnapshot())
            XCTFail("Expected the first ActivityKit rejection to fail reconciliation.")
        } catch {
            XCTAssertEqual(error as? TestReminderLiveActivityScheduler.Failure, .rejected)
        }

        XCTAssertEqual(client.scheduledReminders.count, 1)
        XCTAssertEqual(client.removeAllCount, 2)
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
