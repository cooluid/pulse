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
        XCTAssertGreaterThan(PulseDesign.ambientFieldBreathAmplitude, 0)
        XCTAssertLessThanOrEqual(PulseDesign.ambientFieldBreathAmplitude, 0.012)
        XCTAssertGreaterThanOrEqual(PulseDesign.ambientFieldMinimumInterval, 1.0 / 30.0)
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
