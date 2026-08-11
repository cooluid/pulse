import XCTest
@testable import pulse

final class ReminderSchedulePlannerTests: XCTestCase {
    private let shanghai = TimeZone(identifier: "Asia/Shanghai")!
    private let newYork = TimeZone(identifier: "America/New_York")!

    func testDisabledReminderProducesNoPlanWithoutRequiringATimeZone() throws {
        let snapshot = makeSnapshot(enabled: false, timeZoneIdentifier: "invalid")

        XCTAssertEqual(try ReminderSchedulePlanner.makePlan(for: snapshot), [])
    }

    func testEnabledReminderRejectsInvalidTimeZone() {
        let snapshot = makeSnapshot(timeZoneIdentifier: "invalid")

        XCTAssertThrowsError(try ReminderSchedulePlanner.makePlan(for: snapshot)) { error in
            guard case PulseError.invalidTimeZone("invalid") = error else {
                return XCTFail("Expected invalidTimeZone, got \(error)")
            }
        }
    }

    func testPlanUsesSixtyCalendarDayWindowAndIncludesFutureTimeToday() throws {
        let now = makeDate(
            year: 2026,
            month: 8,
            day: 10,
            hour: 12,
            minute: 0,
            timeZone: shanghai
        )
        let snapshot = makeSnapshot(
            time: ReminderTime(hour: 20, minute: 0)!,
            now: now
        )

        let plan = try ReminderSchedulePlanner.makePlan(for: snapshot)

        XCTAssertEqual(ReminderSchedulePolicy.maximumPendingRequests, 64)
        XCTAssertEqual(ReminderSchedulePolicy.reservedPendingRequests, 4)
        XCTAssertEqual(ReminderSchedulePolicy.schedulingWindowDays, 60)
        XCTAssertEqual(plan.count, 60)
        XCTAssertEqual(plan.first?.day, LogicalDay(year: 2026, month: 8, day: 10))
        XCTAssertEqual(plan.last?.day, LogicalDay(year: 2026, month: 10, day: 8))
    }

    func testPlanExcludesPastTimeTodayAndCheckedDays() throws {
        let now = makeDate(
            year: 2026,
            month: 8,
            day: 10,
            hour: 12,
            minute: 0,
            timeZone: shanghai
        )
        let checkedDay = LogicalDay(year: 2026, month: 8, day: 12)
        let snapshot = makeSnapshot(
            time: ReminderTime(hour: 8, minute: 0)!,
            checkedDays: [checkedDay],
            now: now
        )

        let plan = try ReminderSchedulePlanner.makePlan(for: snapshot)

        XCTAssertEqual(plan.count, 58)
        XCTAssertEqual(plan.first?.day, LogicalDay(year: 2026, month: 8, day: 11))
        XCTAssertFalse(plan.contains { $0.day == checkedDay })
        XCTAssertEqual(plan.last?.day, LogicalDay(year: 2026, month: 10, day: 8))
    }

    func testPlanPreservesMinutesAcrossSpringDaylightSavingGap() throws {
        let now = makeDate(
            year: 2026,
            month: 3,
            day: 7,
            hour: 0,
            minute: 0,
            timeZone: newYork
        )
        let snapshot = makeSnapshot(
            time: ReminderTime(hour: 2, minute: 30)!,
            timeZoneIdentifier: newYork.identifier,
            now: now
        )

        let plan = try ReminderSchedulePlanner.makePlan(for: snapshot)
        let springForward = try XCTUnwrap(
            plan.first { $0.day == LogicalDay(year: 2026, month: 3, day: 8) }
        )

        XCTAssertEqual(springForward.triggerComponents.hour, 3)
        XCTAssertEqual(springForward.triggerComponents.minute, 30)
        XCTAssertEqual(
            LogicalDay.resolve(at: springForward.deliveryDate, timeZone: newYork),
            springForward.day
        )
    }

    private func makeSnapshot(
        enabled: Bool = true,
        time: ReminderTime = .standard,
        timeZoneIdentifier: String = "Asia/Shanghai",
        checkedDays: Set<LogicalDay> = [],
        now: Date? = nil
    ) -> ReminderScheduleSnapshot {
        ReminderScheduleSnapshot(
            enabled: enabled,
            time: time,
            timeZoneIdentifier: timeZoneIdentifier,
            localeIdentifier: "en",
            checkedDays: checkedDays,
            now: now ?? makeDate(
                year: 2026,
                month: 8,
                day: 10,
                hour: 12,
                minute: 0,
                timeZone: shanghai
            )
        )
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        timeZone: TimeZone
    ) -> Date {
        Calendar.pulseGregorian(timeZone: timeZone).date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
