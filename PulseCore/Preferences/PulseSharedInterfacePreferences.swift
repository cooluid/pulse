import Foundation

public enum PulseInterfaceLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    public var id: String { rawValue }

    public var locale: Locale {
        switch self {
        case .system:
            .autoupdatingCurrent
        case .english, .simplifiedChinese:
            Locale(identifier: rawValue)
        }
    }
}

public enum PulseSharedInterfacePreferenceError: Error, Equatable, Sendable {
    case invalidAppGroupIdentifier
    case unavailableSuite
    case invalidStoredLanguage(String)
    case invalidStoredWidgetStyle(String)
}

public struct PulseSharedInterfacePreferences {
    public static let defaultLanguage = PulseInterfaceLanguage.system
    public static let defaultWidgetStyle = PulseWidgetStyle.faultField
    public static let languageStorageKey = "interface.language"
    public static let widgetStyleStorageKey = "widget.style"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public init(appGroupIdentifier: String) throws {
        guard appGroupIdentifier.hasPrefix("group."),
              !appGroupIdentifier.contains("$(") else {
            throw PulseSharedInterfacePreferenceError.invalidAppGroupIdentifier
        }
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            throw PulseSharedInterfacePreferenceError.unavailableSuite
        }
        self.defaults = defaults
    }

    public func loadLanguage() throws -> PulseInterfaceLanguage {
        guard let storedValue = defaults.object(forKey: Self.languageStorageKey) else {
            return Self.defaultLanguage
        }
        guard let rawValue = storedValue as? String,
              let language = PulseInterfaceLanguage(rawValue: rawValue) else {
            throw PulseSharedInterfacePreferenceError.invalidStoredLanguage(
                String(describing: storedValue)
            )
        }
        return language
    }

    public func saveLanguage(_ language: PulseInterfaceLanguage) {
        defaults.set(language.rawValue, forKey: Self.languageStorageKey)
    }

    public func loadWidgetStyle() throws -> PulseWidgetStyle {
        guard let storedValue = defaults.object(forKey: Self.widgetStyleStorageKey) else {
            return Self.defaultWidgetStyle
        }
        guard let rawValue = storedValue as? String,
              let style = PulseWidgetStyle(rawValue: rawValue) else {
            throw PulseSharedInterfacePreferenceError.invalidStoredWidgetStyle(
                String(describing: storedValue)
            )
        }
        return style
    }

    public func saveWidgetStyle(_ style: PulseWidgetStyle) {
        defaults.set(style.rawValue, forKey: Self.widgetStyleStorageKey)
    }

    public func reset() {
        defaults.removeObject(forKey: Self.languageStorageKey)
        defaults.removeObject(forKey: Self.widgetStyleStorageKey)
    }
}
