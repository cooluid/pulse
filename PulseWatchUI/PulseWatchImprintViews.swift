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

struct PulseWatchSevenDayPulse: View {
    let days: [PulseWatchDaySnapshot]
    let displayState: PulseWatchDisplayState
    var usesWidgetAccent = false
    var showsTodayImprint = true

    var body: some View {
        GeometryReader { proxy in
            let spacing = proxy.size.width * PulseWatchDesign.rhythmSpacingRatio
            let historySide = historyNodeSide(in: proxy.size)
            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(days.dropLast())) { day in
                    dayNode(day.state)
                        .frame(width: historySide, height: historySide)
                }
                if showsTodayImprint {
                    Spacer(minLength: spacing)
                    PulseWatchImprintMark(
                        state: displayState,
                        usesWidgetAccent: usesWidgetAccent
                    )
                    .frame(
                        width: todayImprintSide(in: proxy.size),
                        height: todayImprintSide(in: proxy.size)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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

    @ViewBuilder
    private func dayNode(_ state: PulseWatchDayState) -> some View {
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
