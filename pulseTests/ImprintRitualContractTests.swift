import Foundation
import XCTest
@testable import pulse

@MainActor
final class ImprintRitualContractTests: XCTestCase {
    func testCheckInStateMotionStaysWithinTwoSecondContract() {
        XCTAssertGreaterThan(PulseDesign.checkInStateDuration, 0)
        XCTAssertLessThanOrEqual(PulseDesign.checkInStateDuration, 2)
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
