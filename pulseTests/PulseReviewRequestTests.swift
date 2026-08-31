import XCTest
@testable import PulseCore
@testable import pulse

@MainActor
final class PulseReviewRequestTests: XCTestCase {
    func testPolicyUsesMeaningfulUsageMilestonesWithoutCatchUpBursts() {
        XCTAssertNil(
            PulseReviewRequestPolicy.nextMilestone(
                totalCheckInCount: 6,
                attemptedMilestones: []
            )
        )
        XCTAssertEqual(
            PulseReviewRequestPolicy.nextMilestone(
                totalCheckInCount: 7,
                attemptedMilestones: []
            ),
            7
        )
        XCTAssertEqual(
            PulseReviewRequestPolicy.nextMilestone(
                totalCheckInCount: 100,
                attemptedMilestones: []
            ),
            100
        )
        XCTAssertEqual(
            PulseReviewRequestPolicy.consumedMilestones(through: 100),
            [7, 30, 100]
        )
    }

    func testSettingsPersistsReviewAttemptsAndResetClearsThem() throws {
        let suiteName = "PulseReviewRequestTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let sharedSettings = PulseSharedSettings(defaults: defaults)
        let settings = try AppSettings(
            sharedSettings: sharedSettings,
            defaults: defaults
        )

        XCTAssertNil(settings.reserveReviewRequestMilestone(totalCheckInCount: 6))
        XCTAssertEqual(settings.reserveReviewRequestMilestone(totalCheckInCount: 7), 7)
        XCTAssertNil(settings.reserveReviewRequestMilestone(totalCheckInCount: 29))

        let reloaded = try AppSettings(
            sharedSettings: sharedSettings,
            defaults: defaults
        )
        XCTAssertNil(reloaded.reserveReviewRequestMilestone(totalCheckInCount: 7))
        XCTAssertEqual(reloaded.reserveReviewRequestMilestone(totalCheckInCount: 30), 30)

        reloaded.reset()
        XCTAssertEqual(reloaded.reserveReviewRequestMilestone(totalCheckInCount: 100), 100)
        XCTAssertNil(reloaded.reserveReviewRequestMilestone(totalCheckInCount: 101))
    }

    func testCorruptReviewAttemptHistoryFailsSettingsInitialization() throws {
        let suiteName = "PulseReviewRequestTests.Invalid.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["7"], forKey: AppSettings.StorageKey.reviewRequestMilestones)

        XCTAssertThrowsError(
            try AppSettings(
                sharedSettings: PulseSharedSettings(defaults: defaults),
                defaults: defaults
            )
        )
    }

    func testWriteReviewURLUsesThePublishedAppID() {
        XCTAssertEqual(PulseAppStoreContract.appID, "6800603164")
        XCTAssertEqual(
            PulseAppStoreContract.writeReviewURL.absoluteString,
            "https://apps.apple.com/app/id6800603164?action=write-review"
        )
    }
}
