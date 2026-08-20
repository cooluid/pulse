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
    let dateLane: CGFloat
    let bottomChrome: CGFloat
    let todayMarkSide: CGFloat
    let orbitRadius: CGFloat
    let orbitNodeSide: CGFloat
    let requiresScroll: Bool

    static func resolve(
        containerSize: CGSize,
        safeAreaTop: CGFloat,
        safeAreaBottom: CGFloat,
        showsDate: Bool,
        showsRecoveryAction: Bool,
        showsRhythm: Bool,
        showsTransientStatus: Bool
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
        let innerWidth = max(
            width - horizontalPadding * 2,
            PulseWatchDesign.layoutDimensionFloor
        )
        let dateLane = showsDate ? PulseWatchDesign.dateLaneHeight : 0
        let statusLane = showsTransientStatus
            ? PulseWatchDesign.statusLaneHeight
            : 0
        let recoveryLane = showsRecoveryAction
            ? PulseWatchDesign.recoveryButtonMinimumHeight
                + PulseWatchDesign.recoveryGap
            : 0
        let bottomChrome = statusLane + recoveryLane
        let faceHeight = max(
            contentHeight - dateLane - bottomChrome,
            PulseWatchDesign.layoutDimensionFloor
        )
        let faceSide = min(innerWidth, faceHeight) * PulseWatchDesign.faceInsetRatio
        let orbitNodeSide = showsRhythm
            ? PulseWatchDesign.orbitNodeSide.resolve(for: faceSide)
            : 0
        let orbitGap = showsRhythm
            ? PulseWatchDesign.orbitGap.resolve(for: faceSide)
            : 0
        let orbitChrome = showsRhythm ? (orbitGap + orbitNodeSide) * 2 : 0
        let minimumMarkSide = showsRecoveryAction
            ? PulseWatchDesign.recoveryMarkMinimumSide
            : PulseWatchDesign.standardMarkMinimumSide
        let fittedMark = faceSide - orbitChrome
        let requiresScroll = fittedMark < minimumMarkSide
        let todayMarkSide = clamp(
            fittedMark,
            minimum: minimumMarkSide,
            maximum: PulseWatchDesign.todayMarkMaximumSide
        )
        let orbitRadius = showsRhythm
            ? todayMarkSide / 2 + orbitGap + orbitNodeSide / 2
            : 0
        return PulseWatchLayoutMetrics(
            topReserve: topReserve,
            contentHeight: contentHeight,
            horizontalPadding: horizontalPadding,
            bottomPadding: bottomPadding,
            dateLane: dateLane,
            bottomChrome: bottomChrome,
            todayMarkSide: todayMarkSide,
            orbitRadius: orbitRadius,
            orbitNodeSide: orbitNodeSide,
            requiresScroll: requiresScroll
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
    fileprivate static let dateLaneHeight: CGFloat = 16
    fileprivate static let statusLaneHeight: CGFloat = 16
    fileprivate static let recoveryGap: CGFloat = 4
    fileprivate static let faceInsetRatio: CGFloat = 0.94
    fileprivate static let recoveryMarkMinimumSide: CGFloat = 48
    fileprivate static let standardMarkMinimumSide: CGFloat = 72
    fileprivate static let todayMarkMaximumSide: CGFloat = 128
    fileprivate static let orbitNodeSide = PulseWatchScaledMetric(
        ratio: 0.055,
        minimum: 6,
        maximum: 9
    )
    fileprivate static let orbitGap = PulseWatchScaledMetric(
        ratio: 0.045,
        minimum: 5,
        maximum: 8
    )

    static let recoveryButtonHorizontalPadding: CGFloat = 16
    static let recoveryButtonMinimumHeight: CGFloat = 44
    static let widgetMarkPadding: CGFloat = 3
    static let widgetRhythmHorizontalPadding: CGFloat = 4
    static let accessibilityRhythmHeight: CGFloat = 24

    static let markMinimumLineWidth: CGFloat = 3
    static let markLineWidthRatio: CGFloat = 0.075
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
    static let orbitStartDegrees: CGFloat = 240
}
