import Foundation

struct HabitIdentity: Equatable, Sendable {
    static let maximumNameLength = 80
    static let maximumPurposeLength = 160

    let name: String
    let purpose: String?

    init(userName: String, userPurpose: String?) throws {
        let normalizedName = Self.normalize(userName)
        let normalizedPurpose = userPurpose.map(Self.normalize)
        try self.init(
            storedName: normalizedName,
            storedPurpose: normalizedPurpose?.isEmpty == true ? nil : normalizedPurpose
        )
    }

    init(storedName: String, storedPurpose: String?) throws {
        let normalizedName = Self.normalize(storedName)
        let normalizedPurpose = storedPurpose.map(Self.normalize)

        guard normalizedName == storedName,
              !normalizedName.isEmpty,
              normalizedName.count <= Self.maximumNameLength,
              !Self.containsDisallowedScalars(normalizedName) else {
            throw PulseError.invalidHabitIdentity
        }

        if let storedPurpose {
            guard normalizedPurpose == storedPurpose,
                  !storedPurpose.isEmpty,
                  storedPurpose.count <= Self.maximumPurposeLength,
                  !Self.containsDisallowedScalars(storedPurpose) else {
                throw PulseError.invalidHabitIdentity
            }
        }

        name = normalizedName
        purpose = storedPurpose
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsDisallowedScalars(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            if scalar.properties.generalCategory == .control
                || CharacterSet.newlines.contains(scalar) {
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
