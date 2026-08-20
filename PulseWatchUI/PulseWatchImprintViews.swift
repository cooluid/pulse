import PulseWatchShared
import SwiftUI
import WidgetKit

struct PulseWatchImprintMark: View {
    let state: PulseWatchDisplayState
    var usesWidgetAccent = false

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                switch state {
                case .needsSync:
                    Circle()
                        .stroke(
                            Color("PulseWatchSecondary"),
                            style: StrokeStyle(
                                lineWidth: max(
                                    PulseWatchDesign.markNeedsSyncMinimumLineWidth,
                                    side * PulseWatchDesign.markNeedsSyncLineWidthRatio
                                ),
                                lineCap: .round,
                                dash: [
                                    side * PulseWatchDesign.markDashRatio,
                                    side * PulseWatchDesign.markDashRatio,
                                ]
                            )
                        )
                case .ready, .submitting:
                    Circle()
                        .trim(
                            from: PulseWatchDesign.markOpenStart,
                            to: PulseWatchDesign.markOpenEnd
                        )
                        .stroke(
                            Color("PulseWatchField"),
                            style: StrokeStyle(
                                lineWidth: max(
                                    PulseWatchDesign.markMinimumLineWidth,
                                    side * PulseWatchDesign.markLineWidthRatio
                                ),
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(PulseWatchDesign.markRotationDegrees))
                    if case .submitting = state {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color("PulseWatchInk"))
                    }
                case .pendingSync:
                    Circle()
                        .trim(
                            from: PulseWatchDesign.markOpenStart,
                            to: PulseWatchDesign.markPendingEnd
                        )
                        .stroke(
                            Color("PulseWatchField"),
                            style: StrokeStyle(
                                lineWidth: max(
                                    PulseWatchDesign.markMinimumLineWidth,
                                    side * PulseWatchDesign.markLineWidthRatio
                                ),
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(PulseWatchDesign.markRotationDegrees))
                    Circle()
                        .fill(Color("PulseWatchPending"))
                        .frame(
                            width: side * PulseWatchDesign.fireflySideRatio,
                            height: side * PulseWatchDesign.fireflySideRatio
                        )
                        .offset(
                            x: side * PulseWatchDesign.fireflyHorizontalOffsetRatio,
                            y: side * PulseWatchDesign.fireflyVerticalOffsetRatio
                        )
                        .widgetAccentable(usesWidgetAccent)
                case .committed:
                    Circle()
                        .fill(Color("PulseWatchCommitted"))
                        .widgetAccentable(usesWidgetAccent)
                case .failed:
                    Circle()
                        .trim(
                            from: PulseWatchDesign.markOpenStart,
                            to: PulseWatchDesign.markOpenEnd
                        )
                        .stroke(
                            Color("PulseWatchField"),
                            style: StrokeStyle(
                                lineWidth: max(
                                    PulseWatchDesign.markMinimumLineWidth,
                                    side * PulseWatchDesign.markLineWidthRatio
                                ),
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(PulseWatchDesign.markRotationDegrees))
                    Image(systemName: "exclamationmark")
                        .font(.system(
                            size: side * PulseWatchDesign.failureSymbolRatio,
                            weight: .bold
                        ))
                        .foregroundStyle(Color("PulseWatchInk"))
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct PulseWatchHistoryNode: View {
    let state: PulseWatchDayState
    var usesWidgetAccent = false

    var body: some View {
        switch state {
        case .checked:
            Circle()
                .fill(Color("PulseWatchCommitted"))
                .widgetAccentable(usesWidgetAccent)
        case .missed:
            Circle().stroke(
                Color("PulseWatchSecondary"),
                lineWidth: PulseWatchDesign.historyNodeLineWidth
            )
        case .beforeHabit:
            Circle().fill(
                Color("PulseWatchSecondary").opacity(PulseWatchDesign.beforeHabitOpacity)
            )
        case .todayPending:
            Circle().stroke(
                Color("PulseWatchField"),
                lineWidth: PulseWatchDesign.historyNodeLineWidth
            )
        }
    }
}

struct PulseWatchWeekOrbit: View {
    let days: [PulseWatchDaySnapshot]
    let radius: CGFloat
    let nodeSide: CGFloat

    var body: some View {
        let history = Array(days.dropLast())
        ZStack {
            Circle()
                .trim(
                    from: PulseWatchDesign.orbitStartDegrees / 360,
                    to: PulseWatchDesign.orbitEndDegrees / 360
                )
                .stroke(
                    Color("PulseWatchSecondary")
                        .opacity(PulseWatchDesign.orbitTrackOpacity),
                    style: StrokeStyle(
                        lineWidth: PulseWatchDesign.orbitTrackLineWidth,
                        lineCap: .round
                    )
                )
                .frame(width: radius * 2, height: radius * 2)

            ForEach(Array(history.enumerated()), id: \.element.id) { index, day in
                PulseWatchHistoryNode(state: day.state)
                    .frame(width: nodeSide, height: nodeSide)
                    .offset(orbitOffset(index: index, count: history.count))
            }
        }
        .frame(
            width: radius * 2 + nodeSide,
            height: radius * 2 + nodeSide
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func orbitOffset(index: Int, count: Int) -> CGSize {
        guard count > 0 else { return .zero }
        let step = count > 1
            ? (PulseWatchDesign.orbitEndDegrees - PulseWatchDesign.orbitStartDegrees)
                / CGFloat(count - 1)
            : 0
        let degrees = PulseWatchDesign.orbitStartDegrees + step * CGFloat(index)
        let radians = degrees * .pi / 180
        return CGSize(
            width: radius * cos(radians),
            height: radius * sin(radians)
        )
    }
}

struct PulseWatchSevenDayPulse: View {
    let days: [PulseWatchDaySnapshot]
    let displayState: PulseWatchDisplayState
    var usesWidgetAccent = false
    var showsTodayImprint = true

    var body: some View {
        GeometryReader { proxy in
            let history = Array(days.dropLast())
            let historySide = historyNodeSide(in: proxy.size)
            let todaySide = todayImprintSide(in: proxy.size)
            let todayCenter = CGPoint(
                x: proxy.size.width - todaySide / 2,
                y: proxy.size.height / 2
            )
            ZStack {
                Path { path in
                    let points = history.indices.map {
                        historyPoint(
                            index: $0,
                            count: history.count,
                            size: proxy.size
                        )
                    }
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    if showsTodayImprint {
                        path.addLine(to: todayCenter)
                    }
                }
                .stroke(
                    Color("PulseWatchSecondary")
                        .opacity(PulseWatchDesign.rectangularTrackOpacity),
                    style: StrokeStyle(
                        lineWidth: PulseWatchDesign.rectangularTrackLineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                ForEach(Array(history.enumerated()), id: \.element.id) { index, day in
                    PulseWatchHistoryNode(
                        state: day.state,
                        usesWidgetAccent: usesWidgetAccent
                    )
                    .frame(width: historySide, height: historySide)
                    .position(historyPoint(
                        index: index,
                        count: history.count,
                        size: proxy.size
                    ))
                }
                if showsTodayImprint {
                    PulseWatchImprintMark(
                        state: displayState,
                        usesWidgetAccent: usesWidgetAccent
                    )
                    .frame(width: todaySide, height: todaySide)
                    .position(todayCenter)
                }
            }
        }
    }

    private func historyPoint(
        index: Int,
        count: Int,
        size: CGSize
    ) -> CGPoint {
        let progress = count > 1 ? CGFloat(index) / CGFloat(count - 1) : 0
        let horizontalInset = size.width
            * PulseWatchDesign.rectangularHorizontalInsetRatio
        let historyEnd = showsTodayImprint
            ? size.width * PulseWatchDesign.rectangularHistoryEndRatio
            : size.width - horizontalInset
        let x = horizontalInset + (historyEnd - horizontalInset) * progress
        let y = size.height / 2
            + sin(progress * .pi) * size.height
                * PulseWatchDesign.rectangularArcAmplitudeRatio
        return CGPoint(x: x, y: y)
    }

    private func historyNodeSide(in size: CGSize) -> CGFloat {
        if showsTodayImprint {
            return min(
                size.height * PulseWatchDesign.rhythmHistoryHeightRatio,
                size.width * PulseWatchDesign.rhythmHistoryWidthRatio
            )
        }
        return min(
            size.height * PulseWatchDesign.rhythmHistoryOnlyHeightRatio,
            size.width * PulseWatchDesign.rhythmHistoryOnlyWidthRatio
        )
    }

    private func todayImprintSide(in size: CGSize) -> CGFloat {
        min(
            size.height,
            size.width * PulseWatchDesign.rhythmTodayWidthRatio
        )
    }
}
