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
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let contentGap: CGFloat
    let axisWidth: CGFloat
    let primaryFontSize: CGFloat

    static func resolve(containerSize: CGSize) -> PulseWatchLayoutMetrics {
        let width = max(containerSize.width, PulseWatchDesign.layoutDimensionFloor)
        let height = max(containerSize.height, PulseWatchDesign.layoutDimensionFloor)
        return PulseWatchLayoutMetrics(
            horizontalPadding: PulseWatchDesign.pageHorizontalPadding.resolve(
                for: width
            ),
            topPadding: PulseWatchDesign.pageTopPadding.resolve(for: height),
            bottomPadding: PulseWatchDesign.pageBottomPadding.resolve(for: height),
            contentGap: PulseWatchDesign.pageContentGap.resolve(for: width),
            axisWidth: PulseWatchDesign.statusAxisWidth.resolve(for: width),
            primaryFontSize: PulseWatchDesign.primaryFontSize.resolve(for: width)
        )
    }
}

enum PulseWatchDesign {
    fileprivate static let layoutDimensionFloor: CGFloat = 1
    fileprivate static let pageHorizontalPadding = PulseWatchScaledMetric(
        ratio: 0.065,
        minimum: 10,
        maximum: 14
    )
    fileprivate static let pageTopPadding = PulseWatchScaledMetric(
        ratio: 0.035,
        minimum: 6,
        maximum: 9
    )
    fileprivate static let pageBottomPadding = PulseWatchScaledMetric(
        ratio: 0.045,
        minimum: 8,
        maximum: 12
    )
    fileprivate static let pageContentGap = PulseWatchScaledMetric(
        ratio: 0.025,
        minimum: 4,
        maximum: 6
    )
    fileprivate static let statusAxisWidth = PulseWatchScaledMetric(
        ratio: 0.23,
        minimum: 40,
        maximum: 52
    )
    fileprivate static let primaryFontSize = PulseWatchScaledMetric(
        ratio: 0.20,
        minimum: 30,
        maximum: 41
    )

    static let recoveryButtonHorizontalPadding: CGFloat = 16
    static let recoveryButtonMinimumHeight: CGFloat = 44
    static let statusAxisLineWidth: CGFloat = 1.5
    static let statusAxisNodeSide: CGFloat = 16
    static let statusAxisNodeStrokeWidth: CGFloat = 3
    static let statusAxisNodeShadowRadius: CGFloat = 6
    static let waveFrameInterval = 1.0 / 12.0
    static let waveBackPeriod = 17.0
    static let waveMiddlePeriod = 13.0
    static let waveFrontPeriod = 10.0
    static let waveHorizontalTravelRatio: CGFloat = 0.065
    static let waveVerticalTravelRatio: CGFloat = 0.012

    static let widgetMarkPadding: CGFloat = 3
    static let widgetRhythmHorizontalPadding: CGFloat = 4

    static let markMinimumLineWidth: CGFloat = 3.5
    static let markLineWidthRatio: CGFloat = 0.09
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
}
