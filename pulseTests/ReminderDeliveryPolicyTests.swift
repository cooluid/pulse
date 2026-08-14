import XCTest
@testable import PulseCore
@testable import pulse

final class ReminderDeliveryPolicyTests: XCTestCase {
    func testDisabledReminderNeverProducesADeliveryChannel() {
        let mode = ReminderDeliveryPolicy.deliveryMode(
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
        let mode = ReminderDeliveryPolicy.deliveryMode(
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
        let mode = ReminderDeliveryPolicy.deliveryMode(
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
        let mode = ReminderDeliveryPolicy.deliveryMode(
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
        let mode = ReminderDeliveryPolicy.deliveryMode(
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
            PulseWidgetStyle.allCases.filter {
                PulseWidgetStyleAccessPolicy.requiresEnhancement($0)
            }.count,
            7
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

    func testOfficialStyleContractContainsOnlyTheEightRitualObjects() {
        XCTAssertEqual(
            PulseWidgetStyle.allCases.map(\.rawValue),
            [
                "place",
                "orbit",
                "stack",
                "bleed",
                "letter",
                "field",
                "path",
                "tide",
            ]
        )
    }

    func testRetiredStyleIdentifiersFailClosed() {
        for rawValue in [
            "breathingOrbit",
            "starTrail",
            "seal",
            "numberSilhouette",
            "depthRhythm",
            "quietOrder",
            "rhythmBoard"
        ] {
            XCTAssertNil(PulseWidgetStyle(rawValue: rawValue))
        }
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
