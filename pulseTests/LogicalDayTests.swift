import XCTest
@testable import pulse

final class LogicalDayTests: XCTestCase {
    private let shanghai = TimeZone(identifier: "Asia/Shanghai")!
    private let newYork = TimeZone(identifier: "America/New_York")!

    func testStorageValueRoundTrip() throws {
        let day = LogicalDay(year: 2026, month: 8, day: 10)

        XCTAssertEqual(day.storageValue, "2026-08-10")
        XCTAssertEqual(LogicalDay(storageValue: day.storageValue), day)
        XCTAssertNil(LogicalDay(storageValue: "2026/08/10"))
        XCTAssertNil(LogicalDay(storageValue: "2026-02-30"))
    }

    func testMidnightCreatesANewLogicalDay() {
        let beforeMidnight = makeDate(
            year: 2026,
            month: 8,
            day: 10,
            hour: 23,
            minute: 59,
            second: 59,
            timeZone: shanghai
        )
        let midnight = makeDate(
            year: 2026,
            month: 8,
            day: 11,
            hour: 0,
            minute: 0,
            second: 0,
            timeZone: shanghai
        )

        XCTAssertEqual(
            LogicalDay.resolve(at: beforeMidnight, timeZone: shanghai),
            LogicalDay(year: 2026, month: 8, day: 10)
        )
        XCTAssertEqual(
            LogicalDay.resolve(at: midnight, timeZone: shanghai),
            LogicalDay(year: 2026, month: 8, day: 11)
        )
    }

    func testYearAndLeapYearBoundaries() {
        XCTAssertEqual(
            LogicalDay(year: 2026, month: 12, day: 31).addingDays(1, timeZone: shanghai),
            LogicalDay(year: 2027, month: 1, day: 1)
        )
        XCTAssertEqual(
            LogicalDay(year: 2028, month: 2, day: 28).addingDays(1, timeZone: shanghai),
            LogicalDay(year: 2028, month: 2, day: 29)
        )
        XCTAssertEqual(
            LogicalDay(year: 2028, month: 2, day: 29).addingDays(1, timeZone: shanghai),
            LogicalDay(year: 2028, month: 3, day: 1)
        )
    }

    func testCalendarDayArithmeticSurvivesDaylightSavingChanges() {
        let springBefore = LogicalDay(year: 2026, month: 3, day: 7)
        let springAfter = springBefore.addingDays(1, timeZone: newYork)
        let fallBefore = LogicalDay(year: 2026, month: 10, day: 31)
        let fallAfter = fallBefore.addingDays(1, timeZone: newYork)

        XCTAssertEqual(springAfter, LogicalDay(year: 2026, month: 3, day: 8))
        XCTAssertEqual(fallAfter, LogicalDay(year: 2026, month: 11, day: 1))
    }

    func testFixedHabitTimeZoneDoesNotFollowDeviceTimeZone() throws {
        let instant = makeDate(
            year: 2026,
            month: 8,
            day: 10,
            hour: 16,
            minute: 30,
            second: 0,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        let habit = Habit(
            name: "Daily",
            createdAt: instant,
            startLogicalDay: LogicalDay(year: 2026, month: 8, day: 11),
            creationTimeZoneIdentifier: shanghai.identifier,
            timeZoneIdentifier: shanghai.identifier
        )

        XCTAssertEqual(
            try habit.logicalDay(at: instant),
            LogicalDay(year: 2026, month: 8, day: 11)
        )
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int,
        timeZone: TimeZone
    ) -> Date {
        let calendar = Calendar.pulseGregorian(timeZone: timeZone)
        return calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )
        )!
    }
}
