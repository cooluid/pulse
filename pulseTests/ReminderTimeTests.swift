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
        XCTAssertEqual(settings.visualTheme, .editorialJournal)
        XCTAssertEqual(settings.language, .system)
        XCTAssertTrue(settings.watchWaveMotionEnabled)

        settings.theme = .dark
        settings.visualTheme = .sunlitDay
        settings.language = .english
        settings.watchWaveMotionEnabled = false

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
        XCTAssertFalse(reloaded.watchWaveMotionEnabled)
        XCTAssertEqual(reloaded.locale.identifier, "en")
    }

    /// An unknown interface style or language is a load failure. An unknown *visual theme* is not:
    /// a retired theme must fall back so appearance can never stop the app from opening.
    func testInvalidPersistedAppearanceOrLanguageFailsInitialization() throws {
        let invalidThemeSuite = "AppSettingsTests.Theme.\(UUID().uuidString)"
        let invalidThemeDefaults = try XCTUnwrap(UserDefaults(suiteName: invalidThemeSuite))
        invalidThemeDefaults.set("sepia", forKey: AppSettings.StorageKey.theme)
        XCTAssertThrowsError(try makeSettings(defaults: invalidThemeDefaults))
        invalidThemeDefaults.removePersistentDomain(forName: invalidThemeSuite)

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
        settings.watchWaveMotionEnabled = false

        settings.reset()

        XCTAssertEqual(settings.theme, .system)
        XCTAssertEqual(settings.visualTheme, .editorialJournal)
        XCTAssertEqual(settings.language, .system)
        XCTAssertTrue(settings.watchWaveMotionEnabled)
        let reloaded = try makeSettings(defaults: defaults)
        XCTAssertEqual(reloaded.theme, .system)
        XCTAssertEqual(reloaded.visualTheme, .editorialJournal)
        XCTAssertEqual(reloaded.language, .system)
        XCTAssertTrue(reloaded.watchWaveMotionEnabled)
    }

    func testInvalidPersistedReminderTimeFailsInitialization() throws {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set(1_440, forKey: PulseSharedSettings.StorageKey.reminderTimeMinutes)

        XCTAssertThrowsError(try makeSettings(defaults: defaults))
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testInvalidPersistedBooleansFailInsteadOfBeingCoerced() throws {
        let localSuiteName = "AppSettingsTests.LocalBool.\(UUID().uuidString)"
        let localDefaults = try XCTUnwrap(UserDefaults(suiteName: localSuiteName))
        localDefaults.set(2, forKey: AppSettings.StorageKey.watchWaveMotionEnabled)
        XCTAssertThrowsError(try makeSettings(defaults: localDefaults))
        localDefaults.removePersistentDomain(forName: localSuiteName)

        let integerSuiteName = "AppSettingsTests.Integer.\(UUID().uuidString)"
        let integerDefaults = try XCTUnwrap(UserDefaults(suiteName: integerSuiteName))
        integerDefaults.set("2", forKey: AppSettings.StorageKey.weekStart)
        XCTAssertThrowsError(try makeSettings(defaults: integerDefaults))
        integerDefaults.removePersistentDomain(forName: integerSuiteName)

        let sharedSuiteName = "AppSettingsTests.SharedBool.\(UUID().uuidString)"
        let sharedDefaults = try XCTUnwrap(UserDefaults(suiteName: sharedSuiteName))
        sharedDefaults.set(
            "not-a-boolean",
            forKey: PulseSharedSettings.StorageKey.reminderEnabled
        )
        XCTAssertThrowsError(try makeSettings(defaults: sharedDefaults)) { error in
            XCTAssertEqual(
                error as? PulseAppError,
                .invalidSettings
            )
        }
        sharedDefaults.removePersistentDomain(forName: sharedSuiteName)

        let timeSuiteName = "AppSettingsTests.ReminderTimeType.\(UUID().uuidString)"
        let timeDefaults = try XCTUnwrap(UserDefaults(suiteName: timeSuiteName))
        timeDefaults.set(
            "480",
            forKey: PulseSharedSettings.StorageKey.reminderTimeMinutes
        )
        XCTAssertThrowsError(try makeSettings(defaults: timeDefaults))
        timeDefaults.removePersistentDomain(forName: timeSuiteName)

        let journalSuiteName = "AppSettingsTests.ResetJournal.\(UUID().uuidString)"
        let journalDefaults = try XCTUnwrap(UserDefaults(suiteName: journalSuiteName))
        journalDefaults.set("pending", forKey: AppSettings.StorageKey.resetPending)
        XCTAssertThrowsError(try makeSettings(defaults: journalDefaults))
        AppSettings.discardCorruptedResetJournal(defaults: journalDefaults)
        XCTAssertFalse(try makeSettings(defaults: journalDefaults).isResetPending)
        journalDefaults.removePersistentDomain(forName: journalSuiteName)
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
