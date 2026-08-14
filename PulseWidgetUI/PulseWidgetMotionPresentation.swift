import PulseCore
import SwiftUI

enum PulseWidgetMotionPresentation {
    /// Apple limits Widget and Live Activity animations to at most two seconds.
    /// Keep this as an explicit engineering gate instead of relying on the system
    /// to truncate an invalid design specification.
    static let systemMaximumAnimationDuration = 2.0

    static let galleryInitialStateHold: Duration = .milliseconds(550)
    static let galleryAmbientStateHold: Duration = .milliseconds(1_100)
    static let galleryCompletionStateHold: Duration = .milliseconds(2_050)
    static let reducedMotionPendingStateHold: Duration = .milliseconds(650)
    static let reducedMotionCompletionStateHold: Duration = .milliseconds(350)

    enum Material: CaseIterable {
        case place
        case ink
        case paper
        case number
        case letter
        case echo
        case footprint
        case tide
    }

    struct AmbientPose: Hashable {
        let horizontalPoints: CGFloat
        let verticalPoints: CGFloat
        let rotationDegrees: Double
    }

    static func completionDuration(for material: Material) -> TimeInterval {
        switch material {
        case .place: 1.45
        case .ink: 1.70
        case .paper: 1.80
        case .number: 1.45
        case .letter: 1.75
        case .echo: 1.85
        case .footprint: 1.65
        case .tide: 1.90
        }
    }

    static func ambientDuration(for material: Material) -> TimeInterval {
        switch material {
        case .place: 0.82
        case .ink: 0.92
        case .paper: 0.88
        case .number: 0.76
        case .letter: 0.86
        case .echo: 0.94
        case .footprint: 0.84
        case .tide: 0.96
        }
    }

    static func completionAnimation(
        for material: Material,
        allowsMotion: Bool
    ) -> Animation? {
        guard allowsMotion else { return nil }
        let duration = completionDuration(for: material)
        precondition(duration <= systemMaximumAnimationDuration)

        switch material {
        case .place:
            return .easeInOut(duration: duration)
        case .ink:
            return .easeOut(duration: duration)
        case .paper:
            return .spring(duration: duration, bounce: 0.035)
        case .number:
            return .easeOut(duration: duration)
        case .letter:
            return .spring(duration: duration, bounce: 0.045)
        case .echo:
            return .easeOut(duration: duration)
        case .footprint:
            return .easeOut(duration: duration)
        case .tide:
            return .easeInOut(duration: duration)
        }
    }

    static func ambientAnimation(
        for material: Material,
        allowsMotion: Bool
    ) -> Animation? {
        guard allowsMotion else { return nil }
        let duration = ambientDuration(for: material)
        precondition(duration <= systemMaximumAnimationDuration)

        switch material {
        case .paper, .letter:
            return .smooth(duration: duration)
        default:
            return .easeInOut(duration: duration)
        }
    }

    static func ambientPose(
        for material: Material,
        period: PulseWidgetAmbientPeriod
    ) -> AmbientPose {
        let phase: CGFloat
        switch period {
        case .morning: phase = -1
        case .daylight: phase = 0
        case .evening: phase = 1
        }

        let amplitude: AmbientPose
        switch material {
        case .place:
            amplitude = AmbientPose(horizontalPoints: 4.0, verticalPoints: 0.4, rotationDegrees: 1.0)
        case .ink:
            amplitude = AmbientPose(horizontalPoints: 1.2, verticalPoints: -0.3, rotationDegrees: 3.1)
        case .paper:
            amplitude = AmbientPose(horizontalPoints: 1.8, verticalPoints: 0.7, rotationDegrees: -0.8)
        case .number:
            amplitude = AmbientPose(horizontalPoints: -2.6, verticalPoints: -2.1, rotationDegrees: 0)
        case .letter:
            amplitude = AmbientPose(horizontalPoints: 2.1, verticalPoints: 0.9, rotationDegrees: 0.6)
        case .echo:
            amplitude = AmbientPose(horizontalPoints: -1.4, verticalPoints: -1.3, rotationDegrees: 0)
        case .footprint:
            amplitude = AmbientPose(horizontalPoints: 3.2, verticalPoints: -0.7, rotationDegrees: 0.9)
        case .tide:
            amplitude = AmbientPose(horizontalPoints: -3.6, verticalPoints: 2.8, rotationDegrees: 0)
        }

        return AmbientPose(
            horizontalPoints: amplitude.horizontalPoints * phase,
            verticalPoints: amplitude.verticalPoints * phase,
            rotationDegrees: amplitude.rotationDegrees * Double(phase)
        )
    }
}
