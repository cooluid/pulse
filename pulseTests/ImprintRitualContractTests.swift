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

    func testAmbientFieldMotionIsSlowAndLowAmplitude() {
        XCTAssertGreaterThanOrEqual(PulseDesign.ambientFieldCycleDuration, 12)
        XCTAssertLessThanOrEqual(PulseDesign.ambientFieldCycleDuration, 24)
        XCTAssertGreaterThanOrEqual(PulseDesign.ambientFieldMinimumInterval, 1.0 / 30.0)
        XCTAssertGreaterThan(PulseDesign.quietAmbientBackOpacity, 0)
        XCTAssertLessThanOrEqual(PulseDesign.quietAmbientBackOpacity, 0.4)
        XCTAssertGreaterThan(PulseDesign.quietAmbientFrontOpacity, 0)
        XCTAssertLessThanOrEqual(PulseDesign.quietAmbientFrontOpacity, 0.2)
        XCTAssertGreaterThan(PulseDesign.quietAmbientConfettiOpacity, 0)
        XCTAssertLessThanOrEqual(PulseDesign.quietAmbientConfettiOpacity, 0.6)
        XCTAssertGreaterThan(PulseDesign.quietAmbientObjectOpacity, 0)
        XCTAssertLessThanOrEqual(PulseDesign.quietAmbientObjectOpacity, 0.4)
        XCTAssertGreaterThan(PulseDesign.editorialAmbientRuleOpacity, 0)
        XCTAssertLessThanOrEqual(PulseDesign.editorialAmbientRuleOpacity, 0.2)
        XCTAssertGreaterThan(PulseDesign.editorialAmbientBookmarkOpacity, 0)
        XCTAssertLessThanOrEqual(PulseDesign.editorialAmbientBookmarkOpacity, 0.3)
        XCTAssertGreaterThan(PulseDesign.sunlitAmbientBandOpacity, 0)
        XCTAssertLessThanOrEqual(PulseDesign.sunlitAmbientBandOpacity, 0.7)
        XCTAssertGreaterThan(PulseDesign.sunlitAmbientRouteOpacity, 0)
        XCTAssertLessThanOrEqual(PulseDesign.sunlitAmbientRouteOpacity, 0.2)
        XCTAssertGreaterThan(PulseDesign.sunlitAmbientTravel, 0)
        XCTAssertLessThanOrEqual(PulseDesign.sunlitAmbientTravel, 8)
    }

    func testSunlitDayUsesSharedFieldAndAuthoritativeTodayCompletion() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let designSource = try String(
            contentsOf: repositoryRoot.appending(path: "pulse/Shared/PulseDesignSystem.swift"),
            encoding: .utf8
        )
        let todaySource = try String(
            contentsOf: repositoryRoot.appending(path: "pulse/Features/Today/TodayView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(designSource.contains("case .sunlitDay:\n            sunlitField"))
        XCTAssertTrue(designSource.contains("PulseSunlitFieldCanvas("))
        XCTAssertTrue(todaySource.contains("let isChecked = model.todayRecord != nil"))
        XCTAssertFalse(designSource.contains("routeNodes"))
        XCTAssertFalse(todaySource.contains("isCompleted: model.todayRecord != nil"))
    }

    func testAmbientFieldMotionHonorsLifecycleAndReduceMotion() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot.appending(path: "pulse/Shared/PulseDesignSystem.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("paused: !allowsAmbientMotion"))
        XCTAssertTrue(source.contains("!reduceMotion && scenePhase == .active"))
    }

    func testOnlyCommittedPresentationPhasesUseTheSolidGlyph() {
        XCTAssertFalse(ImprintRitualPhase.ready.usesSolidGlyph)
        XCTAssertFalse(ImprintRitualPhase.saving.usesSolidGlyph)
        XCTAssertFalse(ImprintRitualPhase.contracting.usesSolidGlyph)
        XCTAssertTrue(ImprintRitualPhase.imprinting.usesSolidGlyph)
        XCTAssertTrue(ImprintRitualPhase.imprinted.usesSolidGlyph)
    }

    func testProductionSourceContainsNoUnboundedRepeatForeverMotion() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = repositoryRoot.appending(path: "pulse", directoryHint: .isDirectory)
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(
                at: appSource,
                includingPropertiesForKeys: nil
            )
        )

        var offenders: [String] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            if source.contains(".repeatForever(") {
                offenders.append(fileURL.path.replacingOccurrences(
                    of: repositoryRoot.path + "/",
                    with: ""
                ))
            }
        }

        XCTAssertEqual(offenders, [], "Unbounded production motion found in: \(offenders)")
    }

    func testImprintCaptureHasNoPhotoLibraryFallback() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot.appending(
            path: "pulse/Features/Today/ImprintCameraView.swift"
        )
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertTrue(source.contains("controller.sourceType = .camera"))
        XCTAssertFalse(source.contains("controller.cameraDevice = .rear"))
        XCTAssertFalse(source.contains(".photoLibrary"))
        XCTAssertFalse(source.contains(".savedPhotosAlbum"))
    }
}
