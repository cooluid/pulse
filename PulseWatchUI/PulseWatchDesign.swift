import CoreGraphics

enum PulseWatchDesign {
    static let pageSpacing: CGFloat = 10
    static let pageHorizontalPadding: CGFloat = 8
    static let pageBottomPadding: CGFloat = 8
    static let todayMarkSide: CGFloat = 94
    static let rhythmHeight: CGFloat = 34
    static let rhythmTopPadding: CGFloat = 4
    static let widgetMarkPadding: CGFloat = 3
    static let widgetRhythmHorizontalPadding: CGFloat = 4

    static let markMinimumLineWidth: CGFloat = 3
    static let markLineWidthRatio: CGFloat = 0.10
    static let markNeedsSyncMinimumLineWidth: CGFloat = 2
    static let markNeedsSyncLineWidthRatio: CGFloat = 0.085
    static let markDashRatio: CGFloat = 0.12
    static let markOpenStart: CGFloat = 0.08
    static let markOpenEnd: CGFloat = 0.92
    static let markPendingEnd: CGFloat = 0.78
    static let markRotationDegrees = -90.0
    static let fireflySideRatio: CGFloat = 0.16
    static let fireflyHorizontalOffsetRatio: CGFloat = 0.30
    static let fireflyVerticalOffsetRatio: CGFloat = -0.22
    static let committedCutoutSideRatio: CGFloat = 0.22
    static let committedCutoutHorizontalOffsetRatio: CGFloat = 0.18
    static let committedCutoutVerticalOffsetRatio: CGFloat = -0.18
    static let committedCutoutOpacity = 0.78
    static let failureSymbolRatio: CGFloat = 0.28

    static let rhythmSpacingRatio: CGFloat = 0.035
    static let rhythmTodayWidthRatio: CGFloat = 0.18
    static let rhythmHistoryHeightRatio: CGFloat = 0.44
    static let rhythmHistoryWidthRatio: CGFloat = 0.095
    static let historyNodeLineWidth: CGFloat = 1.5
    static let beforeHabitOpacity = 0.22
}
