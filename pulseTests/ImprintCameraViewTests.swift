import UIKit
import XCTest
@testable import pulse

@MainActor
final class ImprintCameraViewTests: XCTestCase {
    func testFrontCameraIsPreferredWhenAvailable() {
        XCTAssertEqual(
            ImprintCameraView.preferredCameraDevice(frontCameraAvailable: true),
            .front
        )
    }

    func testRearCameraIsUsedWhenFrontCameraIsUnavailable() {
        XCTAssertEqual(
            ImprintCameraView.preferredCameraDevice(frontCameraAvailable: false),
            .rear
        )
    }
}
