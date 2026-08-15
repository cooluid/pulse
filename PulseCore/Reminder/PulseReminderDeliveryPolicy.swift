import Foundation

public enum PulseReminderDeliveryMode: Equatable, Sendable {
    case disabled
    case localNotification
    case scheduledLiveActivity
}

public struct PulseReminderDeliveryCapabilities: Equatable, Sendable {
    public let supportsScheduledLiveActivities: Bool
    public let liveActivitiesEnabled: Bool

    public init(supportsScheduledLiveActivities: Bool, liveActivitiesEnabled: Bool) {
        self.supportsScheduledLiveActivities = supportsScheduledLiveActivities
        self.liveActivitiesEnabled = liveActivitiesEnabled
    }
}

public enum PulseReminderDeliveryPolicy {
    public static func deliveryMode(
        reminderEnabled: Bool,
        hasEnhancementEntitlement: Bool,
        capabilities: PulseReminderDeliveryCapabilities
    ) -> PulseReminderDeliveryMode {
        guard reminderEnabled else { return .disabled }
        guard hasEnhancementEntitlement,
              capabilities.supportsScheduledLiveActivities,
              capabilities.liveActivitiesEnabled else {
            return .localNotification
        }
        return .scheduledLiveActivity
    }
}
