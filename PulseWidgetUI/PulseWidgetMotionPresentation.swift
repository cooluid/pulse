import PulseCore
import SwiftUI

enum PulseWidgetMotionPresentation {
    static var entryTransition: Animation {
        .spring(duration: 0.85, bounce: 0.18)
    }

    static func variantTransition<V: Equatable>(value: V) -> Animation {
        entryTransition
    }
}

struct PulseWidgetPhaseAtmosphere {
    let variant: PulseWidgetVisualVariant

    var ambientOpacityScale: CGFloat {
        CGFloat(variant.ambientIntensity)
    }

    var ambientRotationOffset: Double {
        switch variant.phase {
        case .morning: -2.5
        case .midday: 0
        case .evening: 1.8
        case .night: -1.2
        }
    }
}
