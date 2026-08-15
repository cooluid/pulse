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

    static let urlScheme: String = {
        guard let scheme = Bundle.main.object(
            forInfoDictionaryKey: "PulseURLScheme"
        ) as? String,
        !scheme.isEmpty,
        !scheme.contains("$(") else {
            preconditionFailure("Pulse requires a configured URL scheme.")
        }
        return scheme
    }()

    static var todayDeepLink: URL {
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = "today"
        guard let url = components.url else {
            preconditionFailure("Pulse requires a valid Today deep link.")
        }
        return url
    }

    static let reminderRequestPrefix = "\(bundleIdentifier).daily-reminder."
}
