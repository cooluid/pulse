import XCTest
@testable import PulseCore
@testable import pulse

final class ReminderTimeTests: XCTestCase {
    func testValidTimeUsesOneMinutesFromMidnightValue() throws {
        let time = try XCTUnwrap(PulseReminderTime(hour: 20, minute: 45))

        XCTAssertEqual(time.minutesFromMidnight, 1_245)
        XCTAssertEqual(time.hour, 20)
        XCTAssertEqual(time.minute, 45)
    }

    func testInvalidTimeIsRejected() {
        XCTAssertNil(PulseReminderTime(hour: -1, minute: 0))
        XCTAssertNil(PulseReminderTime(hour: 24, minute: 0))
        XCTAssertNil(PulseReminderTime(hour: 20, minute: 60))
        XCTAssertNil(PulseReminderTime(minutesFromMidnight: 1_440))
    }

    func testPickerRoundTripDoesNotUseDeviceTimeZone() throws {
        let original = try XCTUnwrap(PulseReminderTime(hour: 8, minute: 30))
        let decoded = try XCTUnwrap(PulseReminderTime(pickerDate: original.pickerDate))

        XCTAssertEqual(decoded, original)
    }
}

@MainActor
final class AppSettingsTests: XCTestCase {
    func testLocalizationSelectsTheRequestedLanguageBundle() {
        XCTAssertEqual(
            PulseLocalization.string(
                "settings.navigation_title",
                locale: Locale(identifier: "en")
            ),
            "Settings"
        )
        XCTAssertEqual(
            PulseLocalization.string(
                "settings.navigation_title",
                locale: Locale(identifier: "zh-Hans")
            ),
            "设置"
        )
    }

    func testAppearanceVisualThemeAndLanguagePersistExplicitChoices() throws {
        let appSuiteName = "AppSettingsTests.App.\(UUID().uuidString)"
        let sharedSuiteName = "AppSettingsTests.Shared.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: appSuiteName))
        let sharedDefaults = try XCTUnwrap(UserDefaults(suiteName: sharedSuiteName))
        defer {
            defaults.removePersistentDomain(forName: appSuiteName)
            sharedDefaults.removePersistentDomain(forName: sharedSuiteName)
        }
        let sharedPreferences = PulseSharedSettings(defaults: sharedDefaults)

        let settings = try AppSettings(
            sharedSettings: sharedPreferences,
            defaults: defaults
        )
        XCTAssertEqual(settings.theme, .system)
        XCTAssertEqual(settings.visualTheme, .quietField)
        XCTAssertEqual(settings.language, .system)

        settings.theme = .dark
        settings.visualTheme = .sunlitDay
        settings.language = .english

        XCTAssertNil(
            defaults.object(forKey: PulseSharedSettings.StorageKey.language)
        )
        XCTAssertEqual(
            sharedDefaults.string(
                forKey: PulseSharedSettings.StorageKey.language
            ),
            PulseInterfaceLanguage.english.rawValue
        )

        let reloaded = try AppSettings(
            sharedSettings: sharedPreferences,
            defaults: defaults
        )
        XCTAssertEqual(reloaded.theme, .dark)
        XCTAssertEqual(reloaded.visualTheme, .sunlitDay)
        XCTAssertEqual(reloaded.language, .english)
        XCTAssertEqual(reloaded.locale.identifier, "en")
    }

    func testInvalidPersistedThemeOrLanguageFailsInitialization() throws {
        let invalidThemeSuite = "AppSettingsTests.Theme.\(UUID().uuidString)"
        let invalidThemeDefaults = try XCTUnwrap(UserDefaults(suiteName: invalidThemeSuite))
        invalidThemeDefaults.set("sepia", forKey: AppSettings.StorageKey.theme)
        XCTAssertThrowsError(try makeSettings(defaults: invalidThemeDefaults))
        invalidThemeDefaults.removePersistentDomain(forName: invalidThemeSuite)

        let invalidVisualThemeSuite = "AppSettingsTests.VisualTheme.\(UUID().uuidString)"
        let invalidVisualThemeDefaults = try XCTUnwrap(
            UserDefaults(suiteName: invalidVisualThemeSuite)
        )
        invalidVisualThemeDefaults.set(
            "tidalBreath",
            forKey: AppSettings.StorageKey.visualTheme
        )
        XCTAssertThrowsError(try makeSettings(defaults: invalidVisualThemeDefaults))
        invalidVisualThemeDefaults.removePersistentDomain(forName: invalidVisualThemeSuite)

        let invalidLanguageSuite = "AppSettingsTests.Language.\(UUID().uuidString)"
        let invalidLanguageDefaults = try XCTUnwrap(UserDefaults(suiteName: invalidLanguageSuite))
        invalidLanguageDefaults.set(
            "fr",
            forKey: PulseSharedSettings.StorageKey.language
        )
        XCTAssertThrowsError(try makeSettings(defaults: invalidLanguageDefaults))
        invalidLanguageDefaults.removePersistentDomain(forName: invalidLanguageSuite)
    }

    func testResetRestoresDefaultAppearanceVisualThemeAndLanguage() throws {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = try makeSettings(defaults: defaults)
        settings.theme = .light
        settings.visualTheme = .sunlitDay
        settings.language = .simplifiedChinese

        settings.reset()

        XCTAssertEqual(settings.theme, .system)
        XCTAssertEqual(settings.visualTheme, .quietField)
        XCTAssertEqual(settings.language, .system)
        let reloaded = try makeSettings(defaults: defaults)
        XCTAssertEqual(reloaded.theme, .system)
        XCTAssertEqual(reloaded.visualTheme, .quietField)
        XCTAssertEqual(reloaded.language, .system)
    }

    func testInvalidPersistedReminderTimeFailsInitialization() throws {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set(1_440, forKey: PulseSharedSettings.StorageKey.reminderTimeMinutes)

        XCTAssertThrowsError(try makeSettings(defaults: defaults))
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testReminderConfigurationUsesTheSharedTypedAuthority() throws {
        let suiteName = "AppSettingsTests.Reminder.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = try makeSettings(defaults: defaults)

        settings.setReminderEnabled(true)
        settings.reminderTime = try XCTUnwrap(PulseReminderTime(hour: 7, minute: 45))

        let sharedSnapshot = try PulseSharedSettings(defaults: defaults).load()
        XCTAssertTrue(sharedSnapshot.reminderEnabled)
        XCTAssertEqual(sharedSnapshot.reminderTime.minutesFromMidnight, 465)
    }

    private func makeSettings(defaults: UserDefaults) throws -> AppSettings {
        try AppSettings(
            sharedSettings: PulseSharedSettings(defaults: defaults),
            defaults: defaults
        )
    }
}
