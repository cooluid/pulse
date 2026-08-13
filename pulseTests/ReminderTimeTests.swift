import XCTest
@testable import PulseCore
@testable import pulse

final class ReminderTimeTests: XCTestCase {
    func testValidTimeUsesOneMinutesFromMidnightValue() throws {
        let time = try XCTUnwrap(ReminderTime(hour: 20, minute: 45))

        XCTAssertEqual(time.minutesFromMidnight, 1_245)
        XCTAssertEqual(time.hour, 20)
        XCTAssertEqual(time.minute, 45)
    }

    func testInvalidTimeIsRejected() {
        XCTAssertNil(ReminderTime(hour: -1, minute: 0))
        XCTAssertNil(ReminderTime(hour: 24, minute: 0))
        XCTAssertNil(ReminderTime(hour: 20, minute: 60))
        XCTAssertNil(ReminderTime(minutesFromMidnight: 1_440))
    }

    func testPickerRoundTripDoesNotUseDeviceTimeZone() throws {
        let original = try XCTUnwrap(ReminderTime(hour: 8, minute: 30))
        let decoded = try XCTUnwrap(ReminderTime(pickerDate: original.pickerDate))

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

    func testThemeAndLanguageDefaultToSystemAndPersistExplicitChoices() throws {
        let appSuiteName = "AppSettingsTests.App.\(UUID().uuidString)"
        let sharedSuiteName = "AppSettingsTests.Shared.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: appSuiteName))
        let sharedDefaults = try XCTUnwrap(UserDefaults(suiteName: sharedSuiteName))
        defer {
            defaults.removePersistentDomain(forName: appSuiteName)
            sharedDefaults.removePersistentDomain(forName: sharedSuiteName)
        }
        let sharedPreferences = PulseSharedInterfacePreferences(defaults: sharedDefaults)

        let settings = try AppSettings(
            sharedInterfacePreferences: sharedPreferences,
            defaults: defaults
        )
        XCTAssertEqual(settings.theme, .system)
        XCTAssertEqual(settings.language, .system)

        settings.theme = .dark
        settings.language = .english

        XCTAssertNil(
            defaults.object(forKey: PulseSharedInterfacePreferences.languageStorageKey)
        )
        XCTAssertEqual(
            sharedDefaults.string(
                forKey: PulseSharedInterfacePreferences.languageStorageKey
            ),
            PulseInterfaceLanguage.english.rawValue
        )

        let reloaded = try AppSettings(
            sharedInterfacePreferences: sharedPreferences,
            defaults: defaults
        )
        XCTAssertEqual(reloaded.theme, .dark)
        XCTAssertEqual(reloaded.language, .english)
        XCTAssertEqual(reloaded.locale.identifier, "en")
    }

    func testInvalidPersistedThemeOrLanguageFailsInitialization() throws {
        let invalidThemeSuite = "AppSettingsTests.Theme.\(UUID().uuidString)"
        let invalidThemeDefaults = try XCTUnwrap(UserDefaults(suiteName: invalidThemeSuite))
        invalidThemeDefaults.set("sepia", forKey: AppSettings.StorageKey.theme)
        XCTAssertThrowsError(try makeSettings(defaults: invalidThemeDefaults))
        invalidThemeDefaults.removePersistentDomain(forName: invalidThemeSuite)

        let invalidLanguageSuite = "AppSettingsTests.Language.\(UUID().uuidString)"
        let invalidLanguageDefaults = try XCTUnwrap(UserDefaults(suiteName: invalidLanguageSuite))
        invalidLanguageDefaults.set(
            "fr",
            forKey: PulseSharedInterfacePreferences.languageStorageKey
        )
        XCTAssertThrowsError(try makeSettings(defaults: invalidLanguageDefaults))
        invalidLanguageDefaults.removePersistentDomain(forName: invalidLanguageSuite)
    }

    func testResetRestoresSystemThemeAndLanguage() throws {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = try makeSettings(defaults: defaults)
        settings.theme = .light
        settings.language = .simplifiedChinese

        settings.reset()

        XCTAssertEqual(settings.theme, .system)
        XCTAssertEqual(settings.language, .system)
        let reloaded = try makeSettings(defaults: defaults)
        XCTAssertEqual(reloaded.theme, .system)
        XCTAssertEqual(reloaded.language, .system)
    }

    func testInvalidPersistedReminderTimeFailsInitialization() throws {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set(1_440, forKey: AppSettings.StorageKey.reminderTimeMinutes)

        XCTAssertThrowsError(try makeSettings(defaults: defaults))
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeSettings(defaults: UserDefaults) throws -> AppSettings {
        try AppSettings(
            sharedInterfacePreferences: PulseSharedInterfacePreferences(defaults: defaults),
            defaults: defaults
        )
    }
}
