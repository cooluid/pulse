import UIKit
import XCTest
@testable import pulse

@MainActor
final class ImprintCameraViewTests: XCTestCase {
    func testMissingCapturedImageReportsFailureInsteadOfCancellation() {
        var didCancel = false
        var didFail = false
        let coordinator = ImprintCameraView.Coordinator(
            onCapture: { _, _ in
                XCTFail("A missing image must not be reported as a capture.")
            },
            onCancel: { didCancel = true },
            onFailure: { didFail = true }
        )

        coordinator.imagePickerController(
            UIImagePickerController(),
            didFinishPickingMediaWithInfo: [:]
        )

        XCTAssertFalse(didCancel)
        XCTAssertTrue(didFail)
    }

    func testCapturedImageIsMaterializedBeforeLeavingThePickerCallback() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let base = UIGraphicsImageRenderer(
            size: CGSize(width: 80, height: 40),
            format: format
        ).image { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 40))
        }
        let oriented = UIImage(
            cgImage: try XCTUnwrap(base.cgImage),
            scale: 1,
            orientation: .right
        )
        var captured: UIImage?
        let coordinator = ImprintCameraView.Coordinator(
            onCapture: { image, _ in captured = image },
            onCancel: { XCTFail("A valid capture must not be cancelled.") },
            onFailure: { XCTFail("A valid capture must not fail.") },
            cameraPosition: { _ in .rear }
        )

        coordinator.imagePickerController(
            UIImagePickerController(),
            didFinishPickingMediaWithInfo: [.originalImage: oriented]
        )

        let materialized = try XCTUnwrap(captured)
        XCTAssertFalse(materialized === oriented)
        XCTAssertEqual(materialized.imageOrientation, .up)
        XCTAssertNotNil(materialized.cgImage)
        XCTAssertGreaterThan(materialized.size.width, 0)
        XCTAssertGreaterThan(materialized.size.height, 0)
    }
}
