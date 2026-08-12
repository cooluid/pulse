import ActivityKit
import Foundation

public struct PulseReminderActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public init() {}
    }

    public let logicalDay: String
    public let localeIdentifier: String

    public init(logicalDay: String, localeIdentifier: String) {
        self.logicalDay = logicalDay
        self.localeIdentifier = localeIdentifier
    }
}

public enum PulseReminderActivityContract {
    public static let maximumScheduledActivities = 7
    public static let deepLink = URL(string: "pulse://today")!
}
