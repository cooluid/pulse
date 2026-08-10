import Foundation

enum PulseLocalization {
    static func string(_ key: String, locale: Locale) -> String {
        let languageIdentifier = localizationIdentifier(for: locale)
        guard let path = Bundle.main.path(
            forResource: languageIdentifier,
            ofType: "lproj"
        ), let localizedBundle = Bundle(path: path) else {
            preconditionFailure("Missing localization bundle for \(languageIdentifier).")
        }
        return localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }

    private static func localizationIdentifier(for locale: Locale) -> String {
        switch locale.language.languageCode?.identifier {
        case "zh":
            "zh-Hans"
        case "en":
            "en"
        default:
            Bundle.main.preferredLocalizations.first {
                $0 == "en" || $0 == "zh-Hans"
            } ?? "en"
        }
    }
}
