import Foundation
import UIKit

enum PulseFeedbackScreenshotError: Error, Equatable {
    case invalidImage
    case inputTooLarge
    case outputTooLarge
}

struct PulseFeedbackAttachment: Equatable, Sendable {
    let data: Data
    let mimeType: String
    let filename: String
    let pixelWidth: Int
    let pixelHeight: Int
}

enum PulseFeedbackScreenshotProcessor {
    static func process(_ sourceData: Data) throws -> PulseFeedbackAttachment {
        guard sourceData.count <= PulseSupportContract.maximumScreenshotInputByteCount else {
            throw PulseFeedbackScreenshotError.inputTooLarge
        }
        guard let sourceImage = UIImage(data: sourceData) else {
            throw PulseFeedbackScreenshotError.invalidImage
        }

        let sourceSize = sourceImage.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            throw PulseFeedbackScreenshotError.invalidImage
        }
        let scale = min(
            1,
            PulseSupportContract.maximumScreenshotPixelDimension
                / max(sourceSize.width, sourceSize.height)
        )
        let outputSize = CGSize(
            width: max(1, (sourceSize.width * scale).rounded()),
            height: max(1, (sourceSize.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let sanitizedImage = UIGraphicsImageRenderer(size: outputSize, format: format).image {
            context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: outputSize))
            sourceImage.draw(in: CGRect(origin: .zero, size: outputSize))
        }
        guard let outputData = sanitizedImage.jpegData(compressionQuality: 0.9) else {
            throw PulseFeedbackScreenshotError.invalidImage
        }
        guard outputData.count <= PulseSupportContract.maximumScreenshotOutputByteCount else {
            throw PulseFeedbackScreenshotError.outputTooLarge
        }

        return PulseFeedbackAttachment(
            data: outputData,
            mimeType: "image/jpeg",
            filename: "pulse-feedback-screenshot.jpg",
            pixelWidth: Int(outputSize.width),
            pixelHeight: Int(outputSize.height)
        )
    }
}
