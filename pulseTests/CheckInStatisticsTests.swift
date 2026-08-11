import XCTest
@testable import PulseCore
@testable import pulse

final class CheckInStatisticsTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "Asia/Shanghai")!
    private let today = LogicalDay(year: 2026, month: 8, day: 10)

    func testEmptyStatistics() {
        XCTAssertEqual(
            CheckInStatistics.calculate(checkedDays: [], today: today, timeZone: timeZone),
            .empty
        )
    }

    func testTodayStartsAStreak() {
        let result = calculate([today])

        XCTAssertEqual(result.currentStreak, 1)
        XCTAssertEqual(result.longestStreak, 1)
        XCTAssertEqual(result.totalCount, 1)
    }

    func testCurrentStreakRemainsUntilTodayEnds() {
        let yesterday = today.addingDays(-1, timeZone: timeZone)
        let dayBefore = today.addingDays(-2, timeZone: timeZone)

        let result = calculate([dayBefore, yesterday])

        XCTAssertEqual(result.currentStreak, 2)
        XCTAssertEqual(result.longestStreak, 2)
    }

    func testMissedYesterdayBreaksCurrentStreak() {
        let dayBefore = today.addingDays(-2, timeZone: timeZone)

        let result = calculate([dayBefore])

        XCTAssertEqual(result.currentStreak, 0)
        XCTAssertEqual(result.longestStreak, 1)
    }

    func testCheckInAfterAMissedDayStartsNewStreak() {
        let dayBefore = today.addingDays(-2, timeZone: timeZone)

        let result = calculate([dayBefore, today])

        XCTAssertEqual(result.currentStreak, 1)
        XCTAssertEqual(result.longestStreak, 1)
        XCTAssertEqual(result.totalCount, 2)
    }

    func testLongestStreakAcrossMonthBoundary() {
        let days = [
            LogicalDay(year: 2026, month: 7, day: 30),
            LogicalDay(year: 2026, month: 7, day: 31),
            LogicalDay(year: 2026, month: 8, day: 1),
            LogicalDay(year: 2026, month: 8, day: 3)
        ]

        let result = CheckInStatistics.calculate(
            checkedDays: Set(days),
            today: LogicalDay(year: 2026, month: 8, day: 3),
            timeZone: timeZone
        )

        XCTAssertEqual(result.currentStreak, 1)
        XCTAssertEqual(result.longestStreak, 3)
        XCTAssertEqual(result.totalCount, 4)
    }

    func testTenYearsOfDailyFactsRemainOneContinuousStreak() {
        let firstDay = LogicalDay(year: 2016, month: 8, day: 10)
        let checkedDays = Set(
            (0..<3_654).map { firstDay.addingDays($0, timeZone: timeZone) }
        )
        let lastDay = firstDay.addingDays(3_653, timeZone: timeZone)

        let result = CheckInStatistics.calculate(
            checkedDays: checkedDays,
            today: lastDay,
            timeZone: timeZone
        )

        XCTAssertEqual(result.currentStreak, 3_654)
        XCTAssertEqual(result.longestStreak, 3_654)
        XCTAssertEqual(result.totalCount, 3_654)
    }

    func testCalendarClassification() {
        let start = today.addingDays(-2, timeZone: timeZone)
        let yesterday = today.addingDays(-1, timeZone: timeZone)
        let tomorrow = today.addingDays(1, timeZone: timeZone)
        let checked = Set([start])

        XCTAssertEqual(
            CheckInCalendar.status(
                for: start.addingDays(-1, timeZone: timeZone),
                habitStartDay: start,
                today: today,
                checkedDays: checked
            ),
            .beforeHabit
        )
        XCTAssertEqual(
            CheckInCalendar.status(for: start, habitStartDay: start, today: today, checkedDays: checked),
            .checked
        )
        XCTAssertEqual(
            CheckInCalendar.status(for: yesterday, habitStartDay: start, today: today, checkedDays: checked),
            .missed
        )
        XCTAssertEqual(
            CheckInCalendar.status(for: today, habitStartDay: start, today: today, checkedDays: checked),
            .todayPending
        )
        XCTAssertEqual(
            CheckInCalendar.status(for: tomorrow, habitStartDay: start, today: today, checkedDays: checked),
            .future
        )
    }

    private func calculate(_ days: [LogicalDay]) -> CheckInStatistics {
        CheckInStatistics.calculate(
            checkedDays: Set(days),
            today: today,
            timeZone: timeZone
        )
    }
}
