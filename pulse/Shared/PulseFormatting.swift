import Foundation

enum PulseFormatting {
    static func fullDate(_ day: LogicalDay, timeZone: TimeZone) -> String {
        formatter(
            template: "yMMMMEEEEd",
            timeZone: timeZone
        ).string(from: day.date(timeZone: timeZone))
    }

    static func monthAndYear(_ day: LogicalDay, timeZone: TimeZone) -> String {
        formatter(
            template: "yMMMM",
            timeZone: timeZone
        ).string(from: day.date(timeZone: timeZone))
    }

    static func weekday(_ day: LogicalDay, timeZone: TimeZone) -> String {
        formatter(
            template: "EEE",
            timeZone: timeZone
        ).string(from: day.date(timeZone: timeZone))
    }

    static func time(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = .pulseGregorian(timeZone: timeZone)
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func weekdayHeaders(weekStart: WeekStart) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        var symbols = formatter.veryShortStandaloneWeekdaySymbols ?? formatter.veryShortWeekdaySymbols ?? []
        guard symbols.count == 7 else { return symbols }
        if weekStart == .monday {
            symbols.append(symbols.removeFirst())
        }
        return symbols
    }

    private static func formatter(template: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = .pulseGregorian(timeZone: timeZone)
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}

