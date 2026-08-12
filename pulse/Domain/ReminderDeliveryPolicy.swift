import Foundation

enum ReminderDeliveryMode: Equatable, Sendable {
    case disabled
    case localNotification
    case scheduledLiveActivity
}

struct ReminderDeliveryCapabilities: Equatable, Sendable {
    let supportsScheduledLiveActivities: Bool
    let liveActivitiesEnabled: Bool
}

enum ReminderDeliveryPolicy {
    static func deliveryMode(
        reminderEnabled: Bool,
        hasEnhancementEntitlement: Bool,
        capabilities: ReminderDeliveryCapabilities
    ) -> ReminderDeliveryMode {
        guard reminderEnabled else { return .disabled }
        guard hasEnhancementEntitlement,
              capabilities.supportsScheduledLiveActivities,
              capabilities.liveActivitiesEnabled else {
            return .localNotification
        }
        return .scheduledLiveActivity
    }
}
