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
    let horizontalPadding: CGFloat
    let bottomPadding: CGFloat
    let bloomSide: CGFloat
    let todayMarkSide: CGFloat

    static func resolve(
        containerSize: CGSize,
        showsRecoveryAction: Bool,
        showsDateCaption: Bool,
        showsTransientStatus: Bool
    ) -> PulseWatchLayoutMetrics {
        let width = max(containerSize.width, PulseWatchDesign.layoutDimensionFloor)
        let height = max(containerSize.height, PulseWatchDesign.layoutDimensionFloor)
        let horizontalPadding = PulseWatchDesign.pageHorizontalPadding.resolve(
            for: width
        )
        let bottomPadding = PulseWatchDesign.pageBottomPadding.resolve(for: height)
        let innerWidth = max(
            width - horizontalPadding * 2,
            PulseWatchDesign.layoutDimensionFloor
        )
        let statusLane = showsTransientStatus
            ? PulseWatchDesign.statusLaneHeight
            : 0
        let recoveryLane = showsRecoveryAction
            ? PulseWatchDesign.recoveryButtonMinimumHeight
                + PulseWatchDesign.recoveryGap
            : 0
        let dateLane = showsDateCaption
            ? PulseWatchDesign.dateCaptionHeight
                + PulseWatchDesign.dateCaptionGap
            : 0
        let availableHeight = max(
            height - statusLane - recoveryLane - dateLane - bottomPadding,
            PulseWatchDesign.layoutDimensionFloor
        )
        let availableSide = min(innerWidth, availableHeight)
        let minimumMarkSide = showsRecoveryAction
            ? PulseWatchDesign.recoveryMarkMinimumSide
            : PulseWatchDesign.standardMarkMinimumSide
        let bloomSide = availableSide * PulseWatchDesign.bloomFillRatio
        let todayMarkSide = clamp(
            bloomSide / PulseWatchDesign.ambientBloomRatio,
            minimum: minimumMarkSide,
            maximum: PulseWatchDesign.todayMarkMaximumSide
        )
        return PulseWatchLayoutMetrics(
            horizontalPadding: horizontalPadding,
            bottomPadding: bottomPadding,
            bloomSide: min(
                todayMarkSide * PulseWatchDesign.ambientBloomRatio,
                availableSide
            ),
            todayMarkSide: todayMarkSide
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
    fileprivate static let pageBottomPadding = PulseWatchScaledMetric(
        ratio: 0.02,
        minimum: 4,
        maximum: 8
    )
    fileprivate static let statusLaneHeight: CGFloat = 16
    fileprivate static let recoveryGap: CGFloat = 4
    fileprivate static let bloomFillRatio: CGFloat = 0.92
    fileprivate static let recoveryMarkMinimumSide: CGFloat = 48
    fileprivate static let standardMarkMinimumSide: CGFloat = 88
    fileprivate static let todayMarkMaximumSide: CGFloat = 136

    static let dateCaptionHeight: CGFloat = 16
    static let dateCaptionGap: CGFloat = 6
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
    static let historyNodeLineWidth: CGFloat = 1.75
    static let beforeHabitOpacity = 0.34
    static let rectangularTrackLineWidth: CGFloat = 1
    static let rectangularTrackOpacity = 0.34
    static let rectangularHistoryEndRatio: CGFloat = 0.66
    static let rectangularHorizontalInsetRatio: CGFloat = 0.045
    static let rectangularArcAmplitudeRatio: CGFloat = 0.13

    static let ambientFrameInterval = 1.0 / 10.0
    static let ambientPrimaryPeriod = 18.0
    static let ambientSecondaryPeriod = 24.0
    static let ambientBloomRatio: CGFloat = 1.28
    static let ambientPrimaryWidthRatio: CGFloat = 1.04
    static let ambientPrimaryHeightRatio: CGFloat = 0.92
    static let ambientSecondaryWidthRatio: CGFloat = 0.86
    static let ambientSecondaryHeightRatio: CGFloat = 0.78
    static let ambientPrimaryCenterXRatio: CGFloat = 0.50
    static let ambientPrimaryCenterYRatio: CGFloat = 0.53
    static let ambientSecondaryCenterXRatio: CGFloat = 0.52
    static let ambientSecondaryCenterYRatio: CGFloat = 0.50
    static let ambientPrimaryMotionX: CGFloat = 6
    static let ambientPrimaryMotionY: CGFloat = 4
    static let ambientSecondaryMotionX: CGFloat = 5
    static let ambientSecondaryMotionY: CGFloat = 5
    static let ambientPrimaryScaleAmplitude: CGFloat = 0.05
    static let ambientSecondaryScaleAmplitude: CGFloat = 0.06
    static let ambientRotationAmplitude = 6.0
    static let ambientReadyPrimaryOpacity = 0.46
    static let ambientReadySecondaryOpacity = 0.28
    static let ambientCommittedPrimaryOpacity = 0.40
    static let ambientCommittedSecondaryOpacity = 0.30
    static let ambientGradientMidpointOpacityRatio = 0.58
    static let ambientGradientStartRadiusRatio: CGFloat = 0.58
}
