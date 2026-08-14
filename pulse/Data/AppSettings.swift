import Foundation
import Observation
import PulseCore

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

extension PulseInterfaceLanguage {
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

extension PulseWidgetStyle {
    func localizedName(locale: Locale) -> String {
        switch self {
        case .place:
            PulseLocalization.string("settings.widget.style.place", locale: locale)
        case .orbit:
            PulseLocalization.string("settings.widget.style.orbit", locale: locale)
        case .stack:
            PulseLocalization.string("settings.widget.style.stack", locale: locale)
        case .bleed:
            PulseLocalization.string("settings.widget.style.bleed", locale: locale)
        case .letter:
            PulseLocalization.string("settings.widget.style.letter", locale: locale)
        case .field:
            PulseLocalization.string("settings.widget.style.field", locale: locale)
        case .path:
            PulseLocalization.string("settings.widget.style.path", locale: locale)
        case .tide:
            PulseLocalization.string("settings.widget.style.tide", locale: locale)
        }
    }

    func localizedDescription(locale: Locale) -> String {
        switch self {
        case .place:
            PulseLocalization.string(
                "settings.widget.style.place.detail",
                locale: locale
            )
        case .orbit:
            PulseLocalization.string(
                "settings.widget.style.orbit.detail",
                locale: locale
            )
        case .stack:
            PulseLocalization.string(
                "settings.widget.style.stack.detail",
                locale: locale
            )
        case .bleed:
            PulseLocalization.string(
                "settings.widget.style.bleed.detail",
                locale: locale
            )
        case .letter:
            PulseLocalization.string(
                "settings.widget.style.letter.detail",
                locale: locale
            )
        case .field:
            PulseLocalization.string(
                "settings.widget.style.field.detail",
                locale: locale
            )
        case .path:
            PulseLocalization.string(
                "settings.widget.style.path.detail",
                locale: locale
            )
        case .tide:
            PulseLocalization.string(
                "settings.widget.style.tide.detail",
                locale: locale
            )
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
        static let resetPending = "maintenance.resetPending"
        static let mediaInvitationEnabled = "settings.mediaInvitationEnabled"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let sharedInterfacePreferences: PulseSharedInterfacePreferences
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

    var mediaInvitationEnabled: Bool {
        didSet { persist(StorageKey.mediaInvitationEnabled, value: mediaInvitationEnabled) }
    }

    var language: PulseInterfaceLanguage {
        didSet {
            guard !isLoading else { return }
            sharedInterfacePreferences.saveLanguage(language)
        }
    }

    var locale: Locale { language.locale }

    init(
        sharedInterfacePreferences: PulseSharedInterfacePreferences,
        defaults: UserDefaults = .standard
    ) throws {
        self.defaults = defaults
        self.sharedInterfacePreferences = sharedInterfacePreferences
        defaults.register(defaults: [
            StorageKey.hapticsEnabled: true,
            StorageKey.reminderEnabled: false,
            StorageKey.reminderTimeMinutes: ReminderTime.standard.minutesFromMidnight,
            StorageKey.weekStart: WeekStart.monday.rawValue,
            StorageKey.theme: AppTheme.system.rawValue,
            StorageKey.mediaInvitationEnabled: true
        ])
        let loadedLanguage: PulseInterfaceLanguage
        do {
            loadedLanguage = try sharedInterfacePreferences.loadLanguage()
        } catch {
            throw PulseAppError.invalidSettings
        }
        guard let loadedReminderTime = ReminderTime(
            minutesFromMidnight: defaults.integer(forKey: StorageKey.reminderTimeMinutes)
        ), let loadedWeekStart = WeekStart(rawValue: defaults.integer(forKey: StorageKey.weekStart)),
        let loadedTheme = AppTheme(rawValue: defaults.string(forKey: StorageKey.theme) ?? "") else {
            throw PulseAppError.invalidSettings
        }

        hapticsEnabled = defaults.bool(forKey: StorageKey.hapticsEnabled)
        reminderEnabled = defaults.bool(forKey: StorageKey.reminderEnabled)
        reminderTime = loadedReminderTime
        weekStart = loadedWeekStart
        theme = loadedTheme
        mediaInvitationEnabled = defaults.bool(forKey: StorageKey.mediaInvitationEnabled)
        language = loadedLanguage
        isLoading = false
    }

    func setReminderEnabled(_ enabled: Bool) {
        reminderEnabled = enabled
    }

    func reset() {
        isLoading = true
        Self.clearStoredValues(
            sharedInterfacePreferences: sharedInterfacePreferences,
            defaults: defaults
        )

        hapticsEnabled = true
        reminderEnabled = false
        reminderTime = .standard
        weekStart = .monday
        theme = .system
        mediaInvitationEnabled = true
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

    static func clearStoredValues(
        sharedInterfacePreferences: PulseSharedInterfacePreferences,
        defaults: UserDefaults = .standard
    ) {
        [
            StorageKey.hapticsEnabled,
            StorageKey.reminderEnabled,
            StorageKey.reminderTimeMinutes,
            StorageKey.weekStart,
            StorageKey.theme,
            StorageKey.mediaInvitationEnabled
        ].forEach(defaults.removeObject(forKey:))
        sharedInterfacePreferences.reset()
    }

    private func persist(_ key: String, value: Any) {
        guard !isLoading else { return }
        defaults.set(value, forKey: key)
    }
}
