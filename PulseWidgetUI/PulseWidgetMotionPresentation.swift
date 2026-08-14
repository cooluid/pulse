import SwiftUI

enum PulseWidgetMotionPresentation {
    static let previewPreparationDelay: Duration = .milliseconds(220)
    static let previewCompletionDelay: Duration = .milliseconds(1_250)
    static let reducedMotionPreviewCompletionDelay: Duration = .milliseconds(180)

    enum Material {
        case place
        case ink
        case paper
        case number
        case letter
        case echo
        case footprint
        case tide
    }

    static func animation(for material: Material, allowsMotion: Bool) -> Animation? {
        guard allowsMotion else { return nil }
        switch material {
        case .place:
            return Animation.easeInOut(duration: 0.90)
        case .ink:
            return Animation.easeOut(duration: 1.05)
        case .paper:
            return Animation.spring(duration: 1.10, bounce: 0.04)
        case .number:
            return Animation.easeOut(duration: 0.90)
        case .letter:
            return Animation.spring(duration: 1.08, bounce: 0.06)
        case .echo:
            return Animation.easeOut(duration: 1.20)
        case .footprint:
            return Animation.easeOut(duration: 0.95)
        case .tide:
            return Animation.easeInOut(duration: 1.25)
        }
    }
}
