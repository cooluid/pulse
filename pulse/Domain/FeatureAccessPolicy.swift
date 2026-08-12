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

enum FeatureAccessPolicy {
    static func reminderDeliveryMode(
        hasReminderEnhancement: Bool,
        capabilities: ReminderDeliveryCapabilities
    ) -> ReminderDeliveryMode {
        guard hasReminderEnhancement else { return .disabled }
        guard capabilities.supportsScheduledLiveActivities,
              capabilities.liveActivitiesEnabled else {
            return .localNotification
        }
        return .scheduledLiveActivity
    }
}
