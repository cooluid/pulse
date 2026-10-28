import SwiftUI

enum PulseWidgetMotionPresentation {
    /// Apple limits Widget and Live Activity animations to at most two seconds.
    /// Keep this as an explicit engineering gate instead of relying on the system
    /// to truncate an invalid design specification.
    static let systemMaximumAnimationDuration = 2.0

    /// The seal meeting the paper.
    static let stampDuration = 0.55
    /// Ink soaking up to a new level.
    static let riseDuration = 1.4

    static let galleryPendingStateHold: Duration = .milliseconds(700)
    static let galleryCompletionStateHold: Duration = .milliseconds(1_700)
    static let reducedMotionPendingStateHold: Duration = .milliseconds(650)
    static let reducedMotionCompletionStateHold: Duration = .milliseconds(350)

    static func stamp(allowsMotion: Bool) -> Animation? {
        guard allowsMotion else { return nil }
        precondition(stampDuration <= systemMaximumAnimationDuration)
        return .spring(duration: stampDuration, bounce: 0.22)
    }

    static func rise(allowsMotion: Bool) -> Animation? {
        guard allowsMotion else { return nil }
        precondition(riseDuration <= systemMaximumAnimationDuration)
        return .easeInOut(duration: riseDuration)
    }
}
