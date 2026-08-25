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
}
