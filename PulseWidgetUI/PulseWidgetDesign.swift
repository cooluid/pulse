import SwiftUI

/// Widgets, the Live Activity and their previews always print in the free vermilion ink.
enum PulseWidgetDesign {
    static let paper = Color("PulseVermilionPaper")
    static let paperRaised = Color("PulseVermilionPaperRaised")
    static let ink = Color("PulseVermilionInk")
    static let muted = Color("PulseVermilionMuted")
    static let rule = Color("PulseVermilionRule")
    static let seal = Color("PulseVermilionSeal")
    static let onSeal = Color("PulseVermilionOnSeal")
    static let sealWash = Color("PulseVermilionSealWash")

    static let activityIslandSeal = Color("PulseActivityIslandSeal")
    static let activityLockScreenSeal = Color("PulseActivityLockScreenSeal")
    static let activityIslandBackground = Color.black
    static let activityIslandForeground = Color.white
    static let activityIslandSecondaryOpacity = 0.6

    static let sealCornerFraction: CGFloat = 0.12
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let homeContentInsets = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)

    static let activityCompletionAnimationDuration: TimeInterval = 0.6
    static let activityAppearanceAnimationDuration: TimeInterval = 0.5
    static let activityCopyTransitionDuration: TimeInterval = 0.32
    static let activityExpandedMarkSize: CGFloat = 40
    static let activityCompactMarkSize: CGFloat = 24
    static let activityMinimalMarkSize: CGFloat = 24
    static let activityLockScreenMarkSize: CGFloat = 54
    static let activityLockScreenInset: CGFloat = 14
    static let activityLockScreenItemSpacing: CGFloat = 12
    static let activityLockScreenCopySpacing: CGFloat = 2
    static let activityLockScreenStackSpacing: CGFloat = 10
    static let activityIslandCenterSpacing: CGFloat = 2
    static let activityActionHorizontalPadding: CGFloat = 16
    static let activityActionMinimumWidth: CGFloat = 72
    static let activityActionMinimumHeight: CGFloat = 44
    static let activityIslandActionVisibleHeight: CGFloat = 36
    static let activityPreviewItemSpacing: CGFloat = 12
    static let activityPreviewHorizontalInset: CGFloat = 14
    static let activityPreviewVerticalInset: CGFloat = 12
    static let activityPreviewCornerRadius: CGFloat = 32

    static let accessoryMarkSide: CGFloat = 17
    static let accessoryCircularInset: CGFloat = 9
    static let accessoryMarkSpacing: CGFloat = 3
}
