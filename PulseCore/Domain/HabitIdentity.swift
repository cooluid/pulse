import Foundation

public struct HabitIdentity: Equatable, Sendable {
    public static let minimumNameLength = 4
    public static let maximumNameLength = 12
    public static let maximumPurposeLength = 160

    public let name: String
    public let purpose: String?

    public init(userName: String, userPurpose: String?) throws {
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
              normalizedName.count >= Self.minimumNameLength,
              normalizedName.count <= Self.maximumNameLength,
              !Self.containsDisallowedScalars(normalizedName) else {
            throw PulseCoreError.invalidHabitIdentity
        }

        if let storedPurpose {
            guard normalizedPurpose == storedPurpose,
                  !storedPurpose.isEmpty,
                  storedPurpose.count <= Self.maximumPurposeLength,
                  !Self.containsDisallowedScalars(storedPurpose) else {
                throw PulseCoreError.invalidHabitIdentity
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
