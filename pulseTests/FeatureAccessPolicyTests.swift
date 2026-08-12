import XCTest
@testable import pulse

final class FeatureAccessPolicyTests: XCTestCase {
    func testUnpurchasedUserNeverReceivesAReminderChannel() {
        let mode = FeatureAccessPolicy.reminderDeliveryMode(
            hasReminderEnhancement: false,
            capabilities: ReminderDeliveryCapabilities(
                supportsScheduledLiveActivities: true,
                liveActivitiesEnabled: true
            )
        )

        XCTAssertEqual(mode, .disabled)
    }

    func testPurchasedUserOnOlderSystemUsesLocalNotification() {
        let mode = FeatureAccessPolicy.reminderDeliveryMode(
            hasReminderEnhancement: true,
            capabilities: ReminderDeliveryCapabilities(
                supportsScheduledLiveActivities: false,
                liveActivitiesEnabled: false
            )
        )

        XCTAssertEqual(mode, .localNotification)
    }

    func testPurchasedUserOnIOS26UsesScheduledLiveActivity() {
        let mode = FeatureAccessPolicy.reminderDeliveryMode(
            hasReminderEnhancement: true,
            capabilities: ReminderDeliveryCapabilities(
                supportsScheduledLiveActivities: true,
                liveActivitiesEnabled: true
            )
        )

        XCTAssertEqual(mode, .scheduledLiveActivity)
    }

    func testPurchasedUserFallsBackWhenLiveActivitiesAreDisabled() {
        let mode = FeatureAccessPolicy.reminderDeliveryMode(
            hasReminderEnhancement: true,
            capabilities: ReminderDeliveryCapabilities(
                supportsScheduledLiveActivities: true,
                liveActivitiesEnabled: false
            )
        )

        XCTAssertEqual(mode, .localNotification)
    }
}
