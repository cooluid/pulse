import CoreFoundation
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

enum PulseVisualTheme: String, CaseIterable, Identifiable, Sendable {
    case editorialJournal
    case quietField
    case sunlitDay

    var id: String { rawValue }

    func localizedName(locale: Locale) -> String {
        switch self {
        case .editorialJournal:
            PulseLocalization.string("settings.visual_theme.editorial_journal", locale: locale)
        case .quietField:
            PulseLocalization.string("settings.visual_theme.quiet_field", locale: locale)
        case .sunlitDay:
            PulseLocalization.string("settings.visual_theme.sunlit_day", locale: locale)
        }
    }

    func localizedDescription(locale: Locale) -> String {
        switch self {
        case .editorialJournal:
            PulseLocalization.string(
                "settings.visual_theme.editorial_journal.detail",
                locale: locale
            )
        case .quietField:
            PulseLocalization.string(
                "settings.visual_theme.quiet_field.detail",
                locale: locale
            )
        case .sunlitDay:
            PulseLocalization.string(
                "settings.visual_theme.sunlit_day.detail",
                locale: locale
            )
        }
    }
}

enum PulseVisualThemeAccessPolicy {
    static let freeTheme = PulseVisualTheme.editorialJournal

    static var enhancementThemes: [PulseVisualTheme] {
        PulseVisualTheme.allCases.filter(requiresEnhancement)
    }

    static func requiresEnhancement(_ theme: PulseVisualTheme) -> Bool {
        theme != freeTheme
    }

    static func isAvailable(
        _ theme: PulseVisualTheme,
        hasEnhancementEntitlement: Bool
    ) -> Bool {
        !requiresEnhancement(theme) || hasEnhancementEntitlement
    }

    static func resolvedTheme(
        requested theme: PulseVisualTheme,
        hasEnhancementEntitlement: Bool
    ) -> PulseVisualTheme {
        isAvailable(theme, hasEnhancementEntitlement: hasEnhancementEntitlement)
            ? theme
            : freeTheme
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
        PulseLocalization.string("settings.widget.style.\(rawValue)", locale: locale)
    }

    func localizedDescription(locale: Locale) -> String {
        PulseLocalization.string(
            "settings.widget.style.\(rawValue).detail",
            locale: locale
        )
    }
}

@MainActor
@Observable
final class AppSettings {
    enum StorageKey {
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let weekStart = "settings.weekStart"
        static let theme = "settings.theme"
        static let visualTheme = "settings.visualTheme"
        static let resetPending = "maintenance.resetPending"
        static let mediaInvitationEnabled = "settings.mediaInvitationEnabled"
        static let watchWaveMotionEnabled = "settings.watchWaveMotionEnabled"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let sharedSettings: PulseSharedSettings
    @ObservationIgnored private var isLoading = true

    var hapticsEnabled: Bool {
        didSet { persist(StorageKey.hapticsEnabled, value: hapticsEnabled) }
    }

    private(set) var reminderEnabled: Bool {
        didSet {
            guard !isLoading else { return }
            sharedSettings.saveReminderEnabled(reminderEnabled)
        }
    }

    var reminderTime: PulseReminderTime {
        didSet {
            guard !isLoading else { return }
            sharedSettings.saveReminderTime(reminderTime)
        }
    }

    var weekStart: WeekStart {
        didSet { persist(StorageKey.weekStart, value: weekStart.rawValue) }
    }

    var theme: AppTheme {
        didSet { persist(StorageKey.theme, value: theme.rawValue) }
    }

    var visualTheme: PulseVisualTheme {
        didSet { persist(StorageKey.visualTheme, value: visualTheme.rawValue) }
    }

    var mediaInvitationEnabled: Bool {
        didSet { persist(StorageKey.mediaInvitationEnabled, value: mediaInvitationEnabled) }
    }

    var watchWaveMotionEnabled: Bool {
        didSet { persist(StorageKey.watchWaveMotionEnabled, value: watchWaveMotionEnabled) }
    }

    var language: PulseInterfaceLanguage {
        didSet {
            guard !isLoading else { return }
            sharedSettings.saveLanguage(language)
        }
    }

    var locale: Locale { language.locale }

    init(
        sharedSettings: PulseSharedSettings,
        defaults: UserDefaults = .standard
    ) throws {
        self.defaults = defaults
        self.sharedSettings = sharedSettings
        defaults.register(defaults: [
            StorageKey.hapticsEnabled: true,
            StorageKey.weekStart: WeekStart.monday.rawValue,
            StorageKey.theme: AppTheme.system.rawValue,
            StorageKey.visualTheme: PulseVisualThemeAccessPolicy.freeTheme.rawValue,
            StorageKey.mediaInvitationEnabled: true,
            StorageKey.watchWaveMotionEnabled: true,
        ])
        let sharedSnapshot: PulseSharedSettings.Snapshot
        do {
            sharedSnapshot = try sharedSettings.load()
        } catch {
            throw PulseAppError.invalidSettings
        }
        guard let loadedWeekStart = WeekStart(rawValue: try Self.loadInteger(
            defaults: defaults,
            key: StorageKey.weekStart
        )),
              let loadedTheme = AppTheme(rawValue: defaults.string(forKey: StorageKey.theme) ?? "")
        else {
            throw PulseAppError.invalidSettings
        }
        guard let loadedVisualTheme = PulseVisualTheme(
            rawValue: defaults.string(forKey: StorageKey.visualTheme) ?? ""
        ) else {
            throw PulseAppError.invalidSettings
        }
        let loadedHapticsEnabled = try Self.loadBoolean(
            defaults: defaults,
            key: StorageKey.hapticsEnabled
        )
        let loadedMediaInvitationEnabled = try Self.loadBoolean(
            defaults: defaults,
            key: StorageKey.mediaInvitationEnabled
        )
        let loadedWatchWaveMotionEnabled = try Self.loadBoolean(
            defaults: defaults,
            key: StorageKey.watchWaveMotionEnabled
        )
        _ = try Self.loadBoolean(
            defaults: defaults,
            key: StorageKey.resetPending,
            defaultValue: false
        )

        hapticsEnabled = loadedHapticsEnabled
        reminderEnabled = sharedSnapshot.reminderEnabled
        reminderTime = sharedSnapshot.reminderTime
        weekStart = loadedWeekStart
        theme = loadedTheme
        visualTheme = loadedVisualTheme
        mediaInvitationEnabled = loadedMediaInvitationEnabled
        watchWaveMotionEnabled = loadedWatchWaveMotionEnabled
        language = sharedSnapshot.language
        isLoading = false
    }

    func setReminderEnabled(_ enabled: Bool) {
        reminderEnabled = enabled
    }

    func reset() {
        isLoading = true
        Self.clearStoredValues(
            sharedSettings: sharedSettings,
            defaults: defaults
        )

        hapticsEnabled = true
        reminderEnabled = false
        reminderTime = .standard
        weekStart = .monday
        theme = .system
        visualTheme = PulseVisualThemeAccessPolicy.freeTheme
        mediaInvitationEnabled = true
        watchWaveMotionEnabled = true
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
        sharedSettings: PulseSharedSettings,
        defaults: UserDefaults = .standard
    ) {
        [
            StorageKey.hapticsEnabled,
            StorageKey.weekStart,
            StorageKey.theme,
            StorageKey.visualTheme,
            StorageKey.mediaInvitationEnabled,
            StorageKey.watchWaveMotionEnabled,
        ].forEach(defaults.removeObject(forKey:))
        sharedSettings.reset()
    }

    static func discardCorruptedResetJournal(defaults: UserDefaults = .standard) {
        guard let storedValue = defaults.object(forKey: StorageKey.resetPending) else {
            return
        }
        guard let number = storedValue as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else {
            defaults.removeObject(forKey: StorageKey.resetPending)
            return
        }
    }

    private func persist(_ key: String, value: Any) {
        guard !isLoading else { return }
        defaults.set(value, forKey: key)
    }

    private static func loadBoolean(
        defaults: UserDefaults,
        key: String,
        defaultValue: Bool? = nil
    ) throws -> Bool {
        guard let storedValue = defaults.object(forKey: key) else {
            guard let defaultValue else { throw PulseAppError.invalidSettings }
            return defaultValue
        }
        guard let number = storedValue as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else {
            throw PulseAppError.invalidSettings
        }
        return number.boolValue
    }

    private static func loadInteger(defaults: UserDefaults, key: String) throws -> Int {
        guard let storedValue = defaults.object(forKey: key),
              let number = storedValue as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              !CFNumberIsFloatType(number) else {
            throw PulseAppError.invalidSettings
        }
        return number.intValue
    }

}
