import Foundation

public struct JournalNote: Equatable, Sendable {
    public static let maximumCharacterCount = 120
    public static let maximumLineCount = 4

    public let text: String

    public init(userText: String) throws {
        let canonicalText = Self.canonicalize(userText)
        guard !canonicalText.isEmpty else {
            throw PulseCoreError.invalidJournalNote
        }
        try Self.validate(canonicalText)
        text = canonicalText
    }

    init(storedText: String) throws {
        guard storedText == Self.canonicalize(storedText), !storedText.isEmpty else {
            throw PulseCoreError.invalidJournalNote
        }
        try Self.validate(storedText)
        text = storedText
    }

    public static func canonicalText(userInput: String?) throws -> String? {
        guard let userInput else { return nil }
        let canonicalText = canonicalize(userInput)
        guard !canonicalText.isEmpty else { return nil }
        return try JournalNote(userText: canonicalText).text
    }

    static func validatedStoredText(_ storedText: String?) throws -> String? {
        guard let storedText else { return nil }
        return try JournalNote(storedText: storedText).text
    }

    public static func accepts(userInput: String) -> Bool {
        do {
            _ = try canonicalText(userInput: userInput)
            return true
        } catch {
            return false
        }
    }

    private static func canonicalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func validate(_ value: String) throws {
        guard value.count <= maximumCharacterCount,
              value.split(separator: "\n", omittingEmptySubsequences: false).count
                <= maximumLineCount,
              !containsDisallowedScalars(value) else {
            throw PulseCoreError.invalidJournalNote
        }
    }

    private static func containsDisallowedScalars(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            if scalar.value == 0x0A {
                return false
            }
            if scalar.properties.generalCategory == .control {
                return true
            }
            guard scalar.properties.generalCategory == .format else {
                return false
            }
            switch scalar.value {
            case 0x200C, 0x200D, 0xE0020...0xE007F:
                return false
            default:
                return true
            }
        }
    }
}
