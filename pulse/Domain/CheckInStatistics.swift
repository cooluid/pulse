import Foundation

struct CheckInStatistics: Equatable, Sendable {
    let currentStreak: Int
    let longestStreak: Int
    let totalCount: Int

    static let empty = CheckInStatistics(currentStreak: 0, longestStreak: 0, totalCount: 0)

    static func calculate(
        checkedDays: Set<LogicalDay>,
        today: LogicalDay,
        timeZone: TimeZone
    ) -> CheckInStatistics {
        guard !checkedDays.isEmpty else { return .empty }

        let currentAnchor = checkedDays.contains(today)
            ? today
            : today.addingDays(-1, timeZone: timeZone)

        var currentStreak = 0
        var currentCursor = currentAnchor
        while checkedDays.contains(currentCursor) {
            currentStreak += 1
            currentCursor = currentCursor.addingDays(-1, timeZone: timeZone)
        }

        let sortedDays = checkedDays.sorted()
        var longestStreak = 0
        var runningStreak = 0
        var previousDay: LogicalDay?

        for day in sortedDays {
            if let previousDay,
               previousDay.addingDays(1, timeZone: timeZone) == day {
                runningStreak += 1
            } else {
                runningStreak = 1
            }

            longestStreak = max(longestStreak, runningStreak)
            previousDay = day
        }

        return CheckInStatistics(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalCount: checkedDays.count
        )
    }
}

enum CalendarDayStatus: Equatable, Sendable {
    case beforeHabit
    case checked
    case missed
    case todayPending
    case future
}

struct CalendarDayItem: Identifiable, Equatable, Sendable {
    let day: LogicalDay
    let status: CalendarDayStatus

    var id: LogicalDay { day }
}

enum CheckInCalendar {
    static func status(
        for day: LogicalDay,
        habitStartDay: LogicalDay,
        today: LogicalDay,
        checkedDays: Set<LogicalDay>
    ) -> CalendarDayStatus {
        if day < habitStartDay { return .beforeHabit }
        if day > today { return .future }
        if checkedDays.contains(day) { return .checked }
        if day == today { return .todayPending }
        return .missed
    }
}

