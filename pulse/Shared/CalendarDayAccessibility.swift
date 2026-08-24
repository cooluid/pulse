import Foundation
import PulseCore

enum CalendarDayAccessibility {
    static func statusLabel(for status: CalendarDayStatus, locale: Locale) -> String {
        switch status {
        case .beforeHabit:
            PulseLocalization.string("calendar.status.before_habit", locale: locale)
        case .checked:
            PulseLocalization.string("calendar.status.checked", locale: locale)
        case .missed:
            PulseLocalization.string("calendar.status.missed", locale: locale)
        case .todayPending:
            PulseLocalization.string("calendar.status.pending", locale: locale)
        case .future:
            PulseLocalization.string("calendar.status.future", locale: locale)
        }
    }

    static func dateStatusLabel(
        dateText: String,
        status: CalendarDayStatus,
        locale: Locale
    ) -> String {
        String(
            format: PulseLocalization.string("accessibility.date_status_format", locale: locale),
            dateText,
            statusLabel(for: status, locale: locale)
        )
    }

    static func weekDayLabel(
        _ item: CalendarDayItem,
        timeZone: TimeZone,
        locale: Locale
    ) -> String {
        dateStatusLabel(
            dateText: PulseFormatting.fullDate(item.day, timeZone: timeZone, locale: locale),
            status: item.status,
            locale: locale
        )
    }

    static func monthDayLabel(
        _ item: CalendarDayItem,
        locale: Locale,
        hasMedia: Bool
    ) -> String {
        let base = dateStatusLabel(
            dateText: item.day.storageValue,
            status: item.status,
            locale: locale
        )
        guard hasMedia else { return base }
        return String(
            format: PulseLocalization.string("calendar.status.with_media_format", locale: locale),
            base
        )
    }
}
