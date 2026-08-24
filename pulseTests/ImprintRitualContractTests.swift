import Foundation
import XCTest

@testable import pulse

@MainActor
final class ImprintRitualContractTests: XCTestCase {
    func testFiniteMotionDurationsStayWithinTwoSecondContract() {
        XCTAssertGreaterThan(PulseDesign.idleAuraBreathDuration, 0)
        XCTAssertLessThanOrEqual(PulseDesign.idleAuraBreathDuration, 2)
        XCTAssertGreaterThan(PulseDesign.imprintCompletionDuration, 0)
        XCTAssertLessThanOrEqual(PulseDesign.imprintCompletionDuration, 2)
        XCTAssertLessThanOrEqual(PulseDesign.imprintReducedMotionFadeDuration, 2)
    }

    func testAmbientFieldMotionHonorsVisibilityLifecycleAndReduceMotion() {
        XCTAssertTrue(
            PulseAmbientMotionPolicy.allowsMotion(
                requested: true,
                reduceMotion: false,
                sceneIsActive: true
            )
        )
        XCTAssertFalse(
            PulseAmbientMotionPolicy.allowsMotion(
                requested: false,
                reduceMotion: false,
                sceneIsActive: true
            )
        )
        XCTAssertFalse(
            PulseAmbientMotionPolicy.allowsMotion(
                requested: true,
                reduceMotion: true,
                sceneIsActive: true
            )
        )
        XCTAssertFalse(
            PulseAmbientMotionPolicy.allowsMotion(
                requested: true,
                reduceMotion: false,
                sceneIsActive: false
            )
        )
    }

    func testEraseAllDisclosureNamesEveryDeletedUserFact() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalog = try String(
            contentsOf: repositoryRoot.appending(path: "pulse/Localizable.xcstrings"),
            encoding: .utf8
        )

        XCTAssertTrue(
            catalog.contains(
                "All check-ins, daily notes, photos, preferences, and Pulse reminder plans will be removed."
            ))
        XCTAssertTrue(
            catalog.contains(
                "所有签到、每日记事、照片、偏好设置和一日一印创建的提醒计划都会被删除"
            ))
    }
}
