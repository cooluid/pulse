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
    let sealSide: CGFloat
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
            sealSide: min(
                PulseWatchDesign.sealWidth.resolve(for: width),
                height * PulseWatchDesign.sealMaximumHeightRatio
            ),
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
        ratio: 0.03,
        minimum: 4,
        maximum: 7
    )
    fileprivate static let sealWidth = PulseWatchScaledMetric(
        ratio: 0.46,
        minimum: 64,
        maximum: 104
    )
    fileprivate static let sealMaximumHeightRatio: CGFloat = 0.42
    fileprivate static let primaryFontSize = PulseWatchScaledMetric(
        ratio: 0.12,
        minimum: 19,
        maximum: 25
    )

    static let sealCornerFraction: CGFloat = 0.12
    static let recoveryButtonHorizontalPadding: CGFloat = 16
    static let recoveryButtonMinimumHeight: CGFloat = 44
    static let waveFrameInterval = 1.0 / 12.0
    static let waveBackPeriod = 17.0
    static let waveMiddlePeriod = 13.0
    static let waveFrontPeriod = 10.0
    static let waveHorizontalTravelRatio: CGFloat = 0.065
    static let waveVerticalTravelRatio: CGFloat = 0.012

    static let widgetMarkPadding: CGFloat = 4
    static let widgetRhythmHorizontalPadding: CGFloat = 2

    static let failureSymbolRatio: CGFloat = 0.32
    static let beforeHabitOpacity = 0.4

    static let rhythmTodayWidthRatio: CGFloat = 0.27
    static let rhythmTodayGap: CGFloat = 4
    static let rhythmHistoryHeightRatio: CGFloat = 0.5
    static let rhythmHistorySpacing: CGFloat = 2
}
