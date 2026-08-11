import Foundation

enum PulseRuntimeIdentity {
    static let bundleIdentifier: String = {
        guard let identifier = Bundle.main.bundleIdentifier,
              !identifier.isEmpty else {
            preconditionFailure("Pulse requires a configured application bundle identifier.")
        }
        return identifier
    }()

    static let appGroupIdentifier: String = {
        guard let identifier = Bundle.main.object(
            forInfoDictionaryKey: "PulseAppGroupIdentifier"
        ) as? String,
        identifier.hasPrefix("group."),
        !identifier.contains("$(") else {
            preconditionFailure("Pulse requires a configured App Group identifier.")
        }
        return identifier
    }()

    static let reminderRequestPrefix = "\(bundleIdentifier).daily-reminder."
}
