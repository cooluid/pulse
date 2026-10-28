import PulseWatchShared
import SwiftUI
import WidgetKit

/// Today's seal on the watch: a dashed place until the iPhone confirms the day, then the impression.
struct PulseWatchImprintMark: View {
    let state: PulseWatchDisplayState
    let todayLogicalDay: String?
    var usesWidgetAccent = false

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                switch state {
                case .committed:
                    PulseWatchSealImpression(text: dayText ?? "印", ink: Color("PulseWatchSeal"), seed: seed)
                        .widgetAccentable(usesWidgetAccent)
                case .ready:
                    PulseWatchSealSlot(text: dayText, tint: Color("PulseWatchSeal"))
                        .widgetAccentable(usesWidgetAccent)
                case .submitting:
                    PulseWatchSealSlot(text: nil, tint: Color("PulseWatchSeal"))
                        .widgetAccentable(usesWidgetAccent)
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color("PulseWatchInk"))
                case .pendingSync:
                    // Sent, not yet kept: the place stays dashed until the iPhone answers.
                    PulseWatchSealSlot(text: dayText, tint: Color("PulseWatchSeal"), ghostOpacity: 0.55)
                        .widgetAccentable(usesWidgetAccent)
                case .needsSync:
                    PulseWatchSealSlot(text: "印", tint: Color("PulseWatchMuted"), ghostOpacity: 0.4)
                case .failed:
                    PulseWatchSealSlot(text: nil, tint: Color("PulseWatchMuted"))
                    Image(systemName: "exclamationmark")
                        .font(.system(size: side * PulseWatchDesign.failureSymbolRatio, weight: .bold))
                        .foregroundStyle(Color("PulseWatchInk"))
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var dayText: String? {
        PulseWatchDayNumber.from(todayLogicalDay).map(String.init)
    }

    private var seed: UInt64 {
        PulseWatchSealRandom.seed(for: todayLogicalDay ?? "")
    }
}

/// One earlier day in the row: a small impression if it was kept, a dash if it was missed.
struct PulseWatchHistoryNode: View {
    let day: PulseWatchDaySnapshot
    var usesWidgetAccent = false

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                switch day.state {
                case .checked:
                    PulseWatchSealImpression(
                        text: PulseWatchDayNumber.from(day.logicalDay).map(String.init) ?? "",
                        ink: Color("PulseWatchSeal"),
                        seed: PulseWatchSealRandom.seed(for: day.logicalDay),
                        texture: 0.5
                    )
                    .widgetAccentable(usesWidgetAccent)
                case .missed:
                    Capsule()
                        .fill(Color("PulseWatchMuted"))
                        .frame(width: side * 0.42, height: max(1.5, side * 0.1))
                case .beforeHabit:
                    Circle()
                        .fill(Color("PulseWatchMuted").opacity(PulseWatchDesign.beforeHabitOpacity))
                        .frame(width: side * 0.18, height: side * 0.18)
                case .todayPending:
                    PulseWatchSealSlot(text: nil, tint: Color("PulseWatchSeal"))
                        .widgetAccentable(usesWidgetAccent)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Six earlier days, then today's seal at the end of the row.
struct PulseWatchSevenDayPulse: View {
    let days: [PulseWatchDaySnapshot]
    let displayState: PulseWatchDisplayState
    var usesWidgetAccent = false
    var showsTodayImprint = true

    var body: some View {
        GeometryReader { proxy in
            let history = Array(days.dropLast())
            let todaySide = showsTodayImprint ? min(proxy.size.height, proxy.size.width * PulseWatchDesign.rhythmTodayWidthRatio) : 0
            let historyWidth = proxy.size.width - todaySide - (showsTodayImprint ? PulseWatchDesign.rhythmTodayGap : 0)
            let nodeSide = min(
                proxy.size.height * PulseWatchDesign.rhythmHistoryHeightRatio,
                historyWidth / CGFloat(max(history.count, 1)) - PulseWatchDesign.rhythmHistorySpacing
            )
            HStack(spacing: PulseWatchDesign.rhythmTodayGap) {
                HStack(spacing: 0) {
                    ForEach(history) { day in
                        PulseWatchHistoryNode(day: day, usesWidgetAccent: usesWidgetAccent)
                            .frame(width: nodeSide, height: nodeSide)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: historyWidth)

                if showsTodayImprint {
                    PulseWatchImprintMark(
                        state: displayState,
                        todayLogicalDay: days.last?.logicalDay,
                        usesWidgetAccent: usesWidgetAccent
                    )
                    .frame(width: todaySide, height: todaySide)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
