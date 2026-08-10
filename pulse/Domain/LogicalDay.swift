import Foundation

struct LogicalDay: Hashable, Codable, Comparable, Identifiable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    var id: String { storageValue }

    var storageValue: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    init(year: Int, month: Int, day: Int) {
        precondition(
            Self.isValid(year: year, month: month, day: day),
            "LogicalDay requires valid Gregorian date components."
        )
        self.year = year
        self.month = month
        self.day = day
    }

    init?(storageValue: String) {
        let components = storageValue.split(separator: "-", omittingEmptySubsequences: false)
        guard components.count == 3,
              let year = Int(components[0]),
              let month = Int(components[1]),
              let day = Int(components[2]) else {
            return nil
        }

        guard Self.isValid(year: year, month: month, day: day) else {
            return nil
        }

        self.init(year: year, month: month, day: day)
    }

    static func < (lhs: LogicalDay, rhs: LogicalDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    static func resolve(
        at date: Date,
        timeZone: TimeZone
    ) -> LogicalDay {
        let calendar = Calendar.pulseGregorian(timeZone: timeZone)
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        precondition(
            components.year != nil && components.month != nil && components.day != nil,
            "Gregorian calendar must produce complete date components."
        )

        return LogicalDay(
            year: components.year!,
            month: components.month!,
            day: components.day!
        )
    }

    func addingDays(_ value: Int, timeZone: TimeZone) -> LogicalDay {
        let calendar = Calendar.pulseGregorian(timeZone: timeZone)
        let baseDate = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        let result = calendar.date(byAdding: .day, value: value, to: baseDate)!
        let components = calendar.dateComponents([.year, .month, .day], from: result)
        return LogicalDay(year: components.year!, month: components.month!, day: components.day!)
    }

    func startDate(timeZone: TimeZone) -> Date {
        date(timeZone: timeZone)
    }

    func date(timeZone: TimeZone) -> Date {
        Calendar.pulseGregorian(timeZone: timeZone)
            .date(from: DateComponents(year: year, month: month, day: day))!
    }

    func firstDayOfMonth() -> LogicalDay {
        LogicalDay(year: year, month: month, day: 1)
    }

    func addingMonths(_ value: Int, timeZone: TimeZone) -> LogicalDay {
        let calendar = Calendar.pulseGregorian(timeZone: timeZone)
        let baseDate = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let result = calendar.date(byAdding: .month, value: value, to: baseDate)!
        let components = calendar.dateComponents([.year, .month], from: result)
        return LogicalDay(year: components.year!, month: components.month!, day: 1)
    }

    func daysInMonth(timeZone: TimeZone) -> Int {
        let calendar = Calendar.pulseGregorian(timeZone: timeZone)
        let date = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        return calendar.range(of: .day, in: .month, for: date)!.count
    }

    private static func isValid(year: Int, month: Int, day: Int) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return false
        }
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return components.year == year && components.month == month && components.day == day
    }
}

extension Calendar {
    static func pulseGregorian(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }
}
