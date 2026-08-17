import Foundation
import PulseCore

enum PulseFormatting {
    static func fullDate(_ day: LogicalDay, timeZone: TimeZone, locale: Locale) -> String {
        formatter(
            template: "yMMMMEEEEd",
            timeZone: timeZone,
            locale: locale
        ).string(from: day.date(timeZone: timeZone))
    }

    static func monthOnly(_ day: LogicalDay, timeZone: TimeZone, locale: Locale) -> String {
        formatter(
            template: "MMMM",
            timeZone: timeZone,
            locale: locale
        ).string(from: day.date(timeZone: timeZone))
    }

    static func year(_ day: LogicalDay, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = .pulseGregorian(timeZone: timeZone)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy"
        return formatter.string(from: day.date(timeZone: timeZone))
    }

    static func numericYearAndMonth(_ day: LogicalDay, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = .pulseGregorian(timeZone: timeZone)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy.MM"
        return formatter.string(from: day.date(timeZone: timeZone))
    }

    static func numericDate(_ day: LogicalDay, timeZone: TimeZone, locale: Locale) -> String {
        formatter(
            template: "yMd",
            timeZone: timeZone,
            locale: locale
        ).string(from: day.date(timeZone: timeZone))
    }

    static func fullWeekday(_ day: LogicalDay, timeZone: TimeZone, locale: Locale) -> String {
        formatter(
            template: "EEEE",
            timeZone: timeZone,
            locale: locale
        ).string(from: day.date(timeZone: timeZone))
    }

    static func shortWeekday(_ day: LogicalDay, timeZone: TimeZone, locale: Locale) -> String {
        formatter(
            template: "EEEEE",
            timeZone: timeZone,
            locale: locale
        ).string(from: day.date(timeZone: timeZone))
    }

    static func numberOfDaysInMonth(_ day: LogicalDay, timeZone: TimeZone) -> Int {
        let calendar = Calendar.pulseGregorian(timeZone: timeZone)
        guard let range = calendar.range(
            of: .day,
            in: .month,
            for: day.date(timeZone: timeZone)
        ) else {
            preconditionFailure("Gregorian calendar must provide a day range for a valid month.")
        }
        return range.count
    }

    static func time(_ date: Date, timeZone: TimeZone, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = .pulseGregorian(timeZone: timeZone)
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func weekdayHeaders(weekStart: WeekStart, locale: Locale) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        guard var symbols = formatter.veryShortStandaloneWeekdaySymbols,
              symbols.count == 7 else {
            preconditionFailure("The active locale must provide seven weekday symbols.")
        }
        if weekStart == .monday {
            symbols.append(symbols.removeFirst())
        }
        return symbols
    }

    private static func formatter(
        template: String,
        timeZone: TimeZone,
        locale: Locale
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = .pulseGregorian(timeZone: timeZone)
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}
