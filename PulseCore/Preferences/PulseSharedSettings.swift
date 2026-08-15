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

public enum PulseSharedSettingsError: Error, Equatable, Sendable {
    case invalidAppGroupIdentifier
    case unavailableSuite
    case invalidStoredLanguage(String)
    case invalidStoredReminderTime(Int)
    case invalidStoredReminderActivityStyle(String)
}

public struct PulseSharedSettings {
    public struct Snapshot: Equatable, Sendable {
        public let language: PulseInterfaceLanguage
        public let reminderEnabled: Bool
        public let reminderTime: PulseReminderTime
        public let reminderActivityStyle: PulseReminderActivityStyle

        public init(
            language: PulseInterfaceLanguage,
            reminderEnabled: Bool,
            reminderTime: PulseReminderTime,
            reminderActivityStyle: PulseReminderActivityStyle
        ) {
            self.language = language
            self.reminderEnabled = reminderEnabled
            self.reminderTime = reminderTime
            self.reminderActivityStyle = reminderActivityStyle
        }
    }

    public enum StorageKey {
        public static let language = "interface.language"
        public static let reminderEnabled = "reminder.enabled"
        public static let reminderTimeMinutes = "reminder.timeMinutes"
        public static let reminderActivityStyle = "reminder.activityStyle"
    }

    public static let defaultLanguage = PulseInterfaceLanguage.system
    public static let defaultReminderEnabled = false
    public static let defaultReminderTime = PulseReminderTime.standard
    public static let defaultReminderActivityStyle = PulseReminderActivityStyle.dayRing

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public init(appGroupIdentifier: String) throws {
        guard appGroupIdentifier.hasPrefix("group."),
              !appGroupIdentifier.contains("$(") else {
            throw PulseSharedSettingsError.invalidAppGroupIdentifier
        }
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            throw PulseSharedSettingsError.unavailableSuite
        }
        self.defaults = defaults
    }

    public func load() throws -> Snapshot {
        Snapshot(
            language: try loadLanguage(),
            reminderEnabled: loadReminderEnabled(),
            reminderTime: try loadReminderTime(),
            reminderActivityStyle: try loadReminderActivityStyle()
        )
    }

    public func saveLanguage(_ language: PulseInterfaceLanguage) {
        defaults.set(language.rawValue, forKey: StorageKey.language)
    }

    public func saveReminderEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: StorageKey.reminderEnabled)
    }

    public func saveReminderTime(_ time: PulseReminderTime) {
        defaults.set(time.minutesFromMidnight, forKey: StorageKey.reminderTimeMinutes)
    }

    public func saveReminderActivityStyle(_ style: PulseReminderActivityStyle) {
        defaults.set(style.rawValue, forKey: StorageKey.reminderActivityStyle)
    }

    public func reset() {
        [
            StorageKey.language,
            StorageKey.reminderEnabled,
            StorageKey.reminderTimeMinutes,
            StorageKey.reminderActivityStyle,
        ].forEach(defaults.removeObject(forKey:))
    }

    private func loadLanguage() throws -> PulseInterfaceLanguage {
        guard let storedValue = defaults.object(forKey: StorageKey.language) else {
            return Self.defaultLanguage
        }
        guard let rawValue = storedValue as? String,
              let language = PulseInterfaceLanguage(rawValue: rawValue) else {
            throw PulseSharedSettingsError.invalidStoredLanguage(String(describing: storedValue))
        }
        return language
    }

    private func loadReminderEnabled() -> Bool {
        guard defaults.object(forKey: StorageKey.reminderEnabled) != nil else {
            return Self.defaultReminderEnabled
        }
        return defaults.bool(forKey: StorageKey.reminderEnabled)
    }

    private func loadReminderTime() throws -> PulseReminderTime {
        guard defaults.object(forKey: StorageKey.reminderTimeMinutes) != nil else {
            return Self.defaultReminderTime
        }
        let storedValue = defaults.integer(forKey: StorageKey.reminderTimeMinutes)
        guard let time = PulseReminderTime(minutesFromMidnight: storedValue) else {
            throw PulseSharedSettingsError.invalidStoredReminderTime(storedValue)
        }
        return time
    }

    private func loadReminderActivityStyle() throws -> PulseReminderActivityStyle {
        guard let storedValue = defaults.object(forKey: StorageKey.reminderActivityStyle) else {
            return Self.defaultReminderActivityStyle
        }
        guard let rawValue = storedValue as? String,
              let style = PulseReminderActivityStyle(rawValue: rawValue) else {
            throw PulseSharedSettingsError.invalidStoredReminderActivityStyle(
                String(describing: storedValue)
            )
        }
        return style
    }
}
