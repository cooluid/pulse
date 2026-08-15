import ActivityKit
import Foundation

public enum PulseReminderActivityPhase: String, Codable, Hashable, Sendable {
    case pending
    case completed
}

public struct PulseReminderActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public let phase: PulseReminderActivityPhase

        public init(phase: PulseReminderActivityPhase) {
            self.phase = phase
        }
    }

    public let logicalDay: String
    public let reminderDate: Date
    public let timeZoneIdentifier: String
    public let localeIdentifier: String

    public init(
        logicalDay: String,
        reminderDate: Date,
        timeZoneIdentifier: String,
        localeIdentifier: String
    ) {
        self.logicalDay = logicalDay
        self.reminderDate = reminderDate
        self.timeZoneIdentifier = timeZoneIdentifier
        self.localeIdentifier = localeIdentifier
    }
}

public enum PulseReminderActivityContract {
    public static let maximumScheduledActivities = 7
    public static let completionEchoDuration: Duration = .milliseconds(1_700)
}
