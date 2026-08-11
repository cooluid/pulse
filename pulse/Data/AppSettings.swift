import Foundation
import Observation

enum WeekStart: Int, CaseIterable, Identifiable, Sendable {
    case sunday = 1
    case monday = 2

    var id: Int { rawValue }

    func localizedName(locale: Locale) -> String {
        switch self {
        case .sunday:
            PulseLocalization.string("settings.week_start.sunday", locale: locale)
        case .monday:
            PulseLocalization.string("settings.week_start.monday", locale: locale)
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    func localizedName(locale: Locale) -> String {
        switch self {
        case .system:
            PulseLocalization.string("settings.theme.system", locale: locale)
        case .light:
            PulseLocalization.string("settings.theme.light", locale: locale)
        case .dark:
            PulseLocalization.string("settings.theme.dark", locale: locale)
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        case .english, .simplifiedChinese: Locale(identifier: rawValue)
        }
    }

    func localizedName(locale: Locale) -> String {
        switch self {
        case .system:
            PulseLocalization.string("settings.language.system", locale: locale)
        case .english:
            PulseLocalization.string("settings.language.english", locale: locale)
        case .simplifiedChinese:
            PulseLocalization.string("settings.language.simplified_chinese", locale: locale)
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    enum StorageKey {
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let reminderEnabled = "settings.reminderEnabled"
        static let reminderTimeMinutes = "settings.reminderTimeMinutes"
        static let weekStart = "settings.weekStart"
        static let theme = "settings.theme"
        static let language = "settings.language"
        static let resetPending = "maintenance.resetPending"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isLoading = true

    var hapticsEnabled: Bool {
        didSet { persist(StorageKey.hapticsEnabled, value: hapticsEnabled) }
    }

    private(set) var reminderEnabled: Bool {
        didSet { persist(StorageKey.reminderEnabled, value: reminderEnabled) }
    }

    var reminderTime: ReminderTime {
        didSet { persist(StorageKey.reminderTimeMinutes, value: reminderTime.minutesFromMidnight) }
    }

    var weekStart: WeekStart {
        didSet { persist(StorageKey.weekStart, value: weekStart.rawValue) }
    }

    var theme: AppTheme {
        didSet { persist(StorageKey.theme, value: theme.rawValue) }
    }

    var language: AppLanguage {
        didSet { persist(StorageKey.language, value: language.rawValue) }
    }

    var locale: Locale { language.locale }

    init(defaults: UserDefaults = .standard) throws {
        self.defaults = defaults
        defaults.register(defaults: [
            StorageKey.hapticsEnabled: true,
            StorageKey.reminderEnabled: false,
            StorageKey.reminderTimeMinutes: ReminderTime.standard.minutesFromMidnight,
            StorageKey.weekStart: WeekStart.monday.rawValue,
            StorageKey.theme: AppTheme.system.rawValue,
            StorageKey.language: AppLanguage.system.rawValue
        ])
        guard let loadedReminderTime = ReminderTime(
            minutesFromMidnight: defaults.integer(forKey: StorageKey.reminderTimeMinutes)
        ), let loadedWeekStart = WeekStart(rawValue: defaults.integer(forKey: StorageKey.weekStart)),
        let loadedTheme = AppTheme(rawValue: defaults.string(forKey: StorageKey.theme) ?? ""),
        let loadedLanguage = AppLanguage(rawValue: defaults.string(forKey: StorageKey.language) ?? "") else {
            throw PulseAppError.invalidSettings
        }

        hapticsEnabled = defaults.bool(forKey: StorageKey.hapticsEnabled)
        reminderEnabled = defaults.bool(forKey: StorageKey.reminderEnabled)
        reminderTime = loadedReminderTime
        weekStart = loadedWeekStart
        theme = loadedTheme
        language = loadedLanguage
        isLoading = false
    }

    func setReminderEnabled(_ enabled: Bool) {
        reminderEnabled = enabled
    }

    func reset() {
        isLoading = true
        Self.clearStoredValues(defaults: defaults)

        hapticsEnabled = true
        reminderEnabled = false
        reminderTime = .standard
        weekStart = .monday
        theme = .system
        language = .system
        isLoading = false
    }

    var isResetPending: Bool {
        defaults.bool(forKey: StorageKey.resetPending)
    }

    func markResetPending() {
        defaults.set(true, forKey: StorageKey.resetPending)
    }

    func finishReset() {
        defaults.removeObject(forKey: StorageKey.resetPending)
    }

    static func clearStoredValues(defaults: UserDefaults = .standard) {
        [
            StorageKey.hapticsEnabled,
            StorageKey.reminderEnabled,
            StorageKey.reminderTimeMinutes,
            StorageKey.weekStart,
            StorageKey.theme,
            StorageKey.language
        ].forEach(defaults.removeObject(forKey:))
    }

    private func persist(_ key: String, value: Any) {
        guard !isLoading else { return }
        defaults.set(value, forKey: key)
    }
}
