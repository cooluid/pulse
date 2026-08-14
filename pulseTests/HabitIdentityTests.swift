import XCTest
@testable import PulseCore
@testable import pulse

final class HabitIdentityTests: XCTestCase {
    func testUserInputIsCanonicalizedOnce() throws {
        let identity = try HabitIdentity(
            userName: "  每日阅读  ",
            userPurpose: "  为了保持思考  "
        )

        XCTAssertEqual(identity.name, "每日阅读")
        XCTAssertEqual(identity.purpose, "为了保持思考")
    }

    func testBlankPurposeBecomesNil() throws {
        let identity = try HabitIdentity(userName: "Daily", userPurpose: "  ")
        XCTAssertNil(identity.purpose)
    }

    func testNameAcceptsExactCharacterBounds() throws {
        XCTAssertEqual(
            try HabitIdentity(userName: "Read", userPurpose: nil).name.count,
            HabitIdentity.minimumNameLength
        )
        XCTAssertEqual(
            try HabitIdentity(userName: "abcdefghijkl", userPurpose: nil).name.count,
            HabitIdentity.maximumNameLength
        )
    }

    func testIdentityAllowsEmojiSequencesThatRequireJoiners() throws {
        let identity = try HabitIdentity(
            userName: "Family 👨‍👩‍👧‍👦",
            userPurpose: "Create together 👩🏽‍🎨"
        )

        XCTAssertEqual(identity.name, "Family 👨‍👩‍👧‍👦")
        XCTAssertEqual(identity.purpose, "Create together 👩🏽‍🎨")
    }

    func testStoredIdentityMustAlreadyBeCanonical() {
        XCTAssertThrowsError(
            try HabitIdentity(storedName: " Daily ", storedPurpose: nil)
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidHabitIdentity)
        }
        XCTAssertThrowsError(
            try HabitIdentity(storedName: "Daily", storedPurpose: " Why ")
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidHabitIdentity)
        }
    }

    func testIdentityRejectsUndersizedOversizedAndControlCharacters() {
        XCTAssertThrowsError(try HabitIdentity(userName: "   ", userPurpose: nil))
        XCTAssertThrowsError(try HabitIdentity(userName: "abc", userPurpose: nil))
        XCTAssertThrowsError(
            try HabitIdentity(
                userName: String(repeating: "a", count: HabitIdentity.maximumNameLength + 1),
                userPurpose: nil
            )
        )
        XCTAssertThrowsError(
            try HabitIdentity(
                userName: "Daily\nReading",
                userPurpose: nil
            )
        )
        XCTAssertThrowsError(
            try HabitIdentity(
                userName: "Daily",
                userPurpose: String(
                    repeating: "a",
                    count: HabitIdentity.maximumPurposeLength + 1
                )
            )
        )
        XCTAssertThrowsError(
            try HabitIdentity(
                userName: "Daily\u{2028}Reading",
                userPurpose: nil
            )
        )
        XCTAssertThrowsError(
            try HabitIdentity(
                userName: "Daily\u{202E}Reading",
                userPurpose: nil
            )
        )
    }
}
