import Foundation

public enum PulseLocalizedDateFormatting {
    public static func dayNumber(_ day: LogicalDay, locale: Locale) -> String {
        day.day.formatted(.number.locale(locale).grouping(.never))
    }

    public static func monthName(_ day: LogicalDay, locale: Locale) -> String {
        formatter(locale: locale, template: "MMMM")
            .string(from: day.date(timeZone: .gmt))
    }

    public static func monthAndDay(_ day: LogicalDay, locale: Locale) -> String {
        formatter(locale: locale, template: "MMdd")
            .string(from: day.date(timeZone: .gmt))
    }

    public static func monthDayAndWeekday(_ day: LogicalDay, locale: Locale) -> String {
        formatter(locale: locale, template: "MMddEEEE")
            .string(from: day.date(timeZone: .gmt))
    }

    public static func accessibilityDate(_ day: LogicalDay, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar(locale: locale)
        formatter.timeZone = .gmt
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: day.date(timeZone: .gmt))
    }

    private static func formatter(locale: Locale, template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar(locale: locale)
        formatter.timeZone = .gmt
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    private static func calendar(locale: Locale) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = .gmt
        return calendar
    }
}
