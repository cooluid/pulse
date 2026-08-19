import Foundation

enum PulseWatchLocalization {
    static func string(_ key: String.LocalizationValue, locale: Locale) -> String {
        String(localized: key, locale: locale)
    }
}
