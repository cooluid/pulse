import AppIntents
import PulseWatchShared
import SwiftUI
import WidgetKit

private struct PulseWatchEntry: TimelineEntry {
    let date: Date
    let projection: PulseWatchLocalProjection
}

@MainActor
private struct PulseWatchTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseWatchEntry {
        PulseWatchEntry(
            date: .now,
            projection: PulseWatchLocalProjection(
                snapshot: nil,
                pendingCommands: [],
                lastReceipt: nil
            )
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (PulseWatchEntry) -> Void
    ) {
        completion(entry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<PulseWatchEntry>) -> Void
    ) {
        let entry = entry()
        let retryDate = entry.date.addingTimeInterval(
            PulseWatchContract.missingSnapshotRetryInterval
        )
        let boundary = entry.projection.snapshot?.nextDayBoundary
        let reloadDate = boundary.flatMap { $0 > entry.date ? $0 : nil } ?? retryDate
        completion(Timeline(entries: [entry], policy: .after(reloadDate)))
    }

    private func entry() -> PulseWatchEntry {
        do {
            let store = try PulseWatchWidgetRuntime.localStore()
            return PulseWatchEntry(date: .now, projection: try store.projection())
        } catch {
            return PulseWatchEntry(
                date: .now,
                projection: .storageUnavailable
            )
        }
    }
}

private struct PulseWatchWidgetView: View {
    let entry: PulseWatchEntry
    let showsRhythm: Bool

    @Environment(\.widgetFamily) private var family
    @Environment(\.locale) private var locale
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Group {
            if canCheckIn {
                Button(intent: PulseWatchCheckInIntent()) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .containerBackground(Color.black, for: .widget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statusText)
    }

    @ViewBuilder
    private var content: some View {
        if showsRhythm,
           let days = entry.projection.snapshot?.sevenDayPulse {
            PulseWatchSevenDayPulse(
                days: days,
                displayState: displayState,
                usesWidgetAccent: usesWidgetAccent
            )
            .padding(.horizontal, PulseWatchDesign.widgetRhythmHorizontalPadding)
        } else if family == .accessoryInline {
            Label(statusText, systemImage: systemImage)
        } else {
            PulseWatchImprintMark(
                state: displayState,
                usesWidgetAccent: usesWidgetAccent
            )
                .padding(PulseWatchDesign.widgetMarkPadding)
        }
    }

    private var canCheckIn: Bool {
        if case .ready = displayState { return true }
        return false
    }

    private var statusText: String {
        PulseWatchLocalization.status(for: displayState, locale: locale)
    }

    private var systemImage: String {
        switch displayState {
        case .committed: "circle.inset.filled"
        case .pendingSync: "circle.dashed"
        case .failed: "exclamationmark.circle"
        case .needsSync: "iphone.and.arrow.forward"
        case .ready, .submitting: "circle"
        }
    }

    private var displayState: PulseWatchDisplayState {
        entry.projection.displayState(at: entry.date)
    }

    private var usesWidgetAccent: Bool {
        renderingMode == .accented
    }
}

private struct PulseWatchTodayImprintWidget: Widget {
    let kind = PulseWatchContract.circularKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseWatchTimelineProvider()) { entry in
            PulseWatchWidgetView(entry: entry, showsRhythm: false)
        }
        .configurationDisplayName("watch.widget.today.name")
        .description("watch.widget.today.description")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

private struct PulseWatchRhythmWidget: Widget {
    let kind = PulseWatchContract.rhythmKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseWatchTimelineProvider()) { entry in
            PulseWatchWidgetView(entry: entry, showsRhythm: true)
        }
        .configurationDisplayName("watch.widget.rhythm.name")
        .description("watch.widget.rhythm.description")
        .supportedFamilies([.accessoryRectangular])
    }
}

@main
@MainActor
struct PulseWatchWidgetBundle: WidgetBundle {
    init() {
        PulseWatchWidgetRuntime.start()
    }

    var body: some Widget {
        PulseWatchTodayImprintWidget()
        PulseWatchRhythmWidget()
    }
}
