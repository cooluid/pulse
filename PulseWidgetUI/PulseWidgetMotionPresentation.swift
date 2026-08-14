import SwiftUI

enum PulseWidgetMotionPresentation {
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
            return Animation.easeInOut(duration: 0.52)
        case .ink:
            return Animation.easeOut(duration: 0.62)
        case .paper:
            return Animation.spring(duration: 0.68, bounce: 0.04)
        case .number:
            return Animation.easeOut(duration: 0.48)
        case .letter:
            return Animation.spring(duration: 0.64, bounce: 0.06)
        case .echo:
            return Animation.easeOut(duration: 0.72)
        case .footprint:
            return Animation.easeOut(duration: 0.46)
        case .tide:
            return Animation.easeInOut(duration: 0.78)
        }
    }
}
