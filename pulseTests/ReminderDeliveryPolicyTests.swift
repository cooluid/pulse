import XCTest
@testable import PulseCore
@testable import pulse

final class ReminderDeliveryPolicyTests: XCTestCase {
    func testDisabledReminderNeverProducesADeliveryChannel() {
        let mode = PulseReminderDeliveryPolicy.deliveryMode(
            reminderEnabled: false,
            hasEnhancementEntitlement: true,
            capabilities: .init(
                supportsScheduledLiveActivities: true,
                liveActivitiesEnabled: true
            )
        )

        XCTAssertEqual(mode, .disabled)
    }

    func testUnpurchasedUserReceivesFreeLocalNotification() {
        let mode = PulseReminderDeliveryPolicy.deliveryMode(
            reminderEnabled: true,
            hasEnhancementEntitlement: false,
            capabilities: .init(
                supportsScheduledLiveActivities: true,
                liveActivitiesEnabled: true
            )
        )

        XCTAssertEqual(mode, .localNotification)
    }

    func testPurchasedUserOnOlderSystemUsesLocalNotification() {
        let mode = PulseReminderDeliveryPolicy.deliveryMode(
            reminderEnabled: true,
            hasEnhancementEntitlement: true,
            capabilities: .init(
                supportsScheduledLiveActivities: false,
                liveActivitiesEnabled: false
            )
        )

        XCTAssertEqual(mode, .localNotification)
    }

    func testPurchasedUserOnIOS26UsesScheduledLiveActivity() {
        let mode = PulseReminderDeliveryPolicy.deliveryMode(
            reminderEnabled: true,
            hasEnhancementEntitlement: true,
            capabilities: .init(
                supportsScheduledLiveActivities: true,
                liveActivitiesEnabled: true
            )
        )

        XCTAssertEqual(mode, .scheduledLiveActivity)
    }

    func testPurchasedUserUsesLocalNotificationWhenLiveActivitiesAreDisabled() {
        let mode = PulseReminderDeliveryPolicy.deliveryMode(
            reminderEnabled: true,
            hasEnhancementEntitlement: true,
            capabilities: .init(
                supportsScheduledLiveActivities: true,
                liveActivitiesEnabled: false
            )
        )

        XCTAssertEqual(mode, .localNotification)
    }
}

final class PulseWidgetStyleAccessPolicyTests: XCTestCase {
    func testAwaitingPlaceIsTheOnlyIncludedStyle() {
        XCTAssertEqual(PulseWidgetStyleAccessPolicy.freeStyle, .place)
        XCTAssertFalse(PulseWidgetStyleAccessPolicy.requiresEnhancement(.place))
        XCTAssertTrue(PulseWidgetStyleAccessPolicy.requiresEnhancement(.orbit))
        XCTAssertEqual(
            PulseWidgetStyleAccessPolicy.enhancementStyles.count,
            7
        )
        XCTAssertEqual(
            PulseWidgetStyleAccessPolicy.enhancementStyles,
            PulseWidgetStyle.allCases.filter {
                PulseWidgetStyleAccessPolicy.requiresEnhancement($0)
            }
        )
        XCTAssertFalse(
            PulseWidgetStyleAccessPolicy.enhancementStyles.contains(.place)
        )
    }

    func testUnavailablePremiumStyleIsRejectedInsteadOfSilentlySubstituted() {
        XCTAssertFalse(
            PulseWidgetStyleAccessPolicy.isAvailable(
                .stack,
                hasEnhancementEntitlement: false
            )
        )
    }



    func testEntitlementMakesEveryOfficialStyleAvailable() {
        for style in PulseWidgetStyle.allCases {
            XCTAssertTrue(
                PulseWidgetStyleAccessPolicy.isAvailable(
                    style,
                    hasEnhancementEntitlement: true
                )
            )
        }
    }
}
