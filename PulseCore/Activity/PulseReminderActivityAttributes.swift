import ActivityKit
import Foundation

public enum PulseReminderActivityStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case dayRing
    case imprintPress
    case splitField

    public var id: String { rawValue }
}

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
    public let localeIdentifier: String
    public let style: PulseReminderActivityStyle

    public init(
        logicalDay: String,
        localeIdentifier: String,
        style: PulseReminderActivityStyle
    ) {
        self.logicalDay = logicalDay
        self.localeIdentifier = localeIdentifier
        self.style = style
    }
}

public enum PulseReminderActivityContract {
    public static let maximumScheduledActivities = 7
}
