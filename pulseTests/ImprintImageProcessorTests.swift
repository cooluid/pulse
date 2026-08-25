import PulseCore
import UIKit
import XCTest
@testable import pulse

@MainActor
final class ImprintImageProcessorTests: XCTestCase {
    func testProcessorProducesDecodableBoundedOriginalAndThumbnail() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: 5_000, height: 100),
            format: format
        ).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 5_000, height: 100))
        }

        let result = try ImprintImageProcessor.process(image)
        let original = try XCTUnwrap(UIImage(data: result.originalData))
        let thumbnail = try XCTUnwrap(UIImage(data: result.thumbnailData))

        XCTAssertEqual(max(result.pixelWidth, result.pixelHeight), 4_096)
        XCTAssertEqual(
            Int(original.size.width * original.scale),
            result.pixelWidth
        )
        XCTAssertEqual(
            Int(original.size.height * original.scale),
            result.pixelHeight
        )
        XCTAssertLessThanOrEqual(
            max(thumbnail.size.width * thumbnail.scale, thumbnail.size.height * thumbnail.scale),
            ImprintImageProcessor.thumbnailMaximumDimension
        )
    }

    func testProcessorRejectsAnEmptyImage() {
        XCTAssertThrowsError(try ImprintImageProcessor.process(UIImage())) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidMedia)
        }
    }
}
