import Foundation

enum PulseRuntimeIdentity {
    static let bundleIdentifier: String = {
        guard let identifier = Bundle.main.bundleIdentifier,
              !identifier.isEmpty else {
            preconditionFailure("Pulse requires a configured application bundle identifier.")
        }
        return identifier
    }()

    static let reminderRequestPrefix = "\(bundleIdentifier).daily-reminder."
}
