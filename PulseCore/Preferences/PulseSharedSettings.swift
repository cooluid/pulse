import CoreFoundation
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
    case invalidStoredReminderEnabled(String)
    case invalidStoredReminderTimeType(String)
    case invalidStoredReminderTime(Int)
}

public struct PulseSharedSettings {
    public struct Snapshot: Equatable, Sendable {
        public let language: PulseInterfaceLanguage
        public let reminderEnabled: Bool
        public let reminderTime: PulseReminderTime

        public init(
            language: PulseInterfaceLanguage,
            reminderEnabled: Bool,
            reminderTime: PulseReminderTime
        ) {
            self.language = language
            self.reminderEnabled = reminderEnabled
            self.reminderTime = reminderTime
        }
    }

    public enum StorageKey {
        public static let language = "interface.language"
        public static let reminderEnabled = "reminder.enabled"
        public static let reminderTimeMinutes = "reminder.timeMinutes"
    }

    public static let defaultLanguage = PulseInterfaceLanguage.system
    public static let defaultReminderEnabled = false
    public static let defaultReminderTime = PulseReminderTime.standard

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
            reminderEnabled: try loadReminderEnabled(),
            reminderTime: try loadReminderTime()
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

    public func reset() {
        [
            StorageKey.language,
            StorageKey.reminderEnabled,
            StorageKey.reminderTimeMinutes,
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

    private func loadReminderEnabled() throws -> Bool {
        guard let storedValue = defaults.object(forKey: StorageKey.reminderEnabled) else {
            return Self.defaultReminderEnabled
        }
        guard let number = storedValue as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else {
            throw PulseSharedSettingsError.invalidStoredReminderEnabled(
                String(describing: storedValue)
            )
        }
        return number.boolValue
    }

    private func loadReminderTime() throws -> PulseReminderTime {
        guard let storedValue = defaults.object(forKey: StorageKey.reminderTimeMinutes) else {
            return Self.defaultReminderTime
        }
        guard let number = storedValue as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              !CFNumberIsFloatType(number) else {
            throw PulseSharedSettingsError.invalidStoredReminderTimeType(
                String(describing: storedValue)
            )
        }
        let minutes = number.intValue
        guard let time = PulseReminderTime(minutesFromMidnight: minutes) else {
            throw PulseSharedSettingsError.invalidStoredReminderTime(minutes)
        }
        return time
    }

}
