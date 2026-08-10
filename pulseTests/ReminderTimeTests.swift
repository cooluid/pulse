import XCTest
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
    func testInvalidPersistedReminderTimeFailsInitialization() throws {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set(1_440, forKey: AppSettings.StorageKey.reminderTimeMinutes)

        XCTAssertThrowsError(try AppSettings(defaults: defaults))
        defaults.removePersistentDomain(forName: suiteName)
    }
}
