import CoreGraphics

fileprivate struct PulseWatchScaledMetric {
    let ratio: CGFloat
    let minimum: CGFloat
    let maximum: CGFloat

    func resolve(for dimension: CGFloat) -> CGFloat {
        min(max(dimension * ratio, minimum), maximum)
    }
}

struct PulseWatchLayoutMetrics: Equatable {
    let topReserve: CGFloat
    let contentHeight: CGFloat
    let horizontalPadding: CGFloat
    let bottomPadding: CGFloat
    let spacing: CGFloat
    let todayMarkSide: CGFloat
    let rhythmHeight: CGFloat

    static func resolve(
        containerSize: CGSize,
        safeAreaTop: CGFloat,
        safeAreaBottom: CGFloat,
        showsDate: Bool,
        showsRecoveryAction: Bool,
        showsRhythm: Bool
    ) -> PulseWatchLayoutMetrics {
        let width = max(containerSize.width, PulseWatchDesign.layoutDimensionFloor)
        let height = max(containerSize.height, PulseWatchDesign.layoutDimensionFloor)
        let horizontalPadding = PulseWatchDesign.pageHorizontalPadding.resolve(
            for: width
        )
        let topReserve = max(
            safeAreaTop,
            PulseWatchDesign.pageTopReserve.resolve(for: height)
        )
        let bottomPadding = max(
            safeAreaBottom,
            PulseWatchDesign.pageBottomPadding.resolve(for: height)
        )
        let contentHeight = max(
            height - topReserve - bottomPadding,
            PulseWatchDesign.layoutDimensionFloor
        )
        let spacing = PulseWatchDesign.pageSpacing.resolve(for: height)
        let rhythmHeight = showsRhythm
            ? PulseWatchDesign.pageRhythmHeight.resolve(for: height)
            : 0
        let visibleSectionCount = PulseWatchDesign.baseVisibleSectionCount
            + (showsDate ? 1 : 0)
            + (showsRecoveryAction ? 1 : 0)
            + (showsRhythm ? 1 : 0)
        let gapHeight = CGFloat(max(visibleSectionCount - 1, 0)) * spacing
        let fixedHeight = (showsDate ? PulseWatchDesign.dateRowReservation : 0)
            + PulseWatchDesign.statusRowReservation
            + (showsRecoveryAction ? PulseWatchDesign.recoveryButtonMinimumHeight : 0)
            + rhythmHeight
            + gapHeight
        let widthBound = width * PulseWatchDesign.todayMarkWidthRatio
        let remainingHeight = contentHeight - fixedHeight
        let minimumMarkSide = showsRecoveryAction
            ? PulseWatchDesign.recoveryMarkMinimumSide
            : PulseWatchDesign.standardMarkMinimumSide
        let todayMarkSide = clamp(
            min(widthBound, remainingHeight),
            minimum: minimumMarkSide,
            maximum: PulseWatchDesign.todayMarkMaximumSide
        )
        return PulseWatchLayoutMetrics(
            topReserve: topReserve,
            contentHeight: contentHeight,
            horizontalPadding: horizontalPadding,
            bottomPadding: bottomPadding,
            spacing: spacing,
            todayMarkSide: todayMarkSide,
            rhythmHeight: rhythmHeight
        )
    }

    private static func clamp(
        _ value: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        min(max(value, minimum), maximum)
    }
}

enum PulseWatchDesign {
    fileprivate static let layoutDimensionFloor: CGFloat = 1
    fileprivate static let pageHorizontalPadding = PulseWatchScaledMetric(
        ratio: 0.045,
        minimum: 6,
        maximum: 10
    )
    fileprivate static let pageTopReserve = PulseWatchScaledMetric(
        ratio: 0.10,
        minimum: 20,
        maximum: 28
    )
    fileprivate static let pageBottomPadding = PulseWatchScaledMetric(
        ratio: 0.02,
        minimum: 4,
        maximum: 8
    )
    fileprivate static let pageSpacing = PulseWatchScaledMetric(
        ratio: 0.026,
        minimum: 5,
        maximum: 8
    )
    fileprivate static let pageRhythmHeight = PulseWatchScaledMetric(
        ratio: 0.12,
        minimum: 22,
        maximum: 30
    )
    fileprivate static let baseVisibleSectionCount = 2
    fileprivate static let dateRowReservation: CGFloat = 16
    fileprivate static let statusRowReservation: CGFloat = 20
    fileprivate static let todayMarkWidthRatio: CGFloat = 0.50
    fileprivate static let recoveryMarkMinimumSide: CGFloat = 48
    fileprivate static let standardMarkMinimumSide: CGFloat = 60
    fileprivate static let todayMarkMaximumSide: CGFloat = 96

    static let recoveryButtonHorizontalPadding: CGFloat = 16
    static let recoveryButtonMinimumHeight: CGFloat = 44
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
    static let failureSymbolRatio: CGFloat = 0.28

    static let rhythmSpacingRatio: CGFloat = 0.035
    static let rhythmTodayWidthRatio: CGFloat = 0.18
    static let rhythmHistoryHeightRatio: CGFloat = 0.44
    static let rhythmHistoryWidthRatio: CGFloat = 0.095
    static let rhythmHistoryOnlyHeightRatio: CGFloat = 0.52
    static let rhythmHistoryOnlyWidthRatio: CGFloat = 0.11
    static let historyNodeLineWidth: CGFloat = 1.5
    static let beforeHabitOpacity = 0.34
}
