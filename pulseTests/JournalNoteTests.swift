import XCTest
@testable import PulseCore

final class JournalNoteTests: XCTestCase {
    func testUserInputCanonicalizesWhitespaceAndLineEndings() throws {
        XCTAssertEqual(
            try JournalNote.canonicalText(userInput: "  first\r\nsecond  "),
            "first\nsecond"
        )
        XCTAssertNil(try JournalNote.canonicalText(userInput: " \n "))
    }

    func testExactBoundsAreAccepted() throws {
        let exactCharacters = String(
            repeating: "a",
            count: JournalNote.maximumCharacterCount
        )
        XCTAssertEqual(
            try JournalNote.canonicalText(userInput: exactCharacters),
            exactCharacters
        )
        XCTAssertEqual(
            try JournalNote.canonicalText(userInput: "one\ntwo\nthree\nfour"),
            "one\ntwo\nthree\nfour"
        )
    }

    func testOversizedTooManyLinesAndControlCharactersAreRejected() {
        let oversized = String(
            repeating: "a",
            count: JournalNote.maximumCharacterCount + 1
        )
        for invalid in [oversized, "1\n2\n3\n4\n5", "visible\u{0000}hidden"] {
            XCTAssertThrowsError(try JournalNote.canonicalText(userInput: invalid)) { error in
                XCTAssertEqual(error as? PulseCoreError, .invalidJournalNote)
            }
        }
    }

    func testEmojiJoinersRemainValid() throws {
        XCTAssertEqual(
            try JournalNote.canonicalText(userInput: "今天和家人 👨‍👩‍👧‍👦 一起散步"),
            "今天和家人 👨‍👩‍👧‍👦 一起散步"
        )
    }
}
