import ActivityKit
import AppIntents
import Foundation
import PulseCore
import SwiftUI
import WidgetKit

@main
struct PulseWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PulseDailyImprintWidget()
        PulseAccessoryRhythmWidget()
        PulseReminderLiveActivity()
    }
}

struct PulseReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PulseReminderActivityAttributes.self) { context in
            let locale = Locale(identifier: context.attributes.localeIdentifier)
            PulseReminderLockScreenView(
                phase: context.state.phase,
                reminderDate: context.attributes.reminderDate,
                timeZoneIdentifier: context.attributes.timeZoneIdentifier,
                locale: locale,
                animatesAppearance: true
            )
                .activityBackgroundTint(PulseWidgetDesign.paper)
                .activitySystemActionForegroundColor(PulseWidgetDesign.ink)
                .widgetURL(PulseRuntimeIdentity.todayDeepLink)
        } dynamicIsland: { context in
            let locale = Locale(identifier: context.attributes.localeIdentifier)
            let day = PulseReminderActivityDay.number(
                reminderDate: context.attributes.reminderDate,
                timeZoneIdentifier: context.attributes.timeZoneIdentifier
            )
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PulseReminderActivityMark(
                        phase: context.state.phase,
                        layout: .islandExpanded,
                        day: day,
                        animatesAppearance: true
                    )
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.phase == .pending {
                        PulseReminderActivityActionButton(
                            locale: locale,
                            surface: .island
                        )
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    PulseReminderActivityStatusCopy(
                        phase: context.state.phase,
                        reminderDate: context.attributes.reminderDate,
                        timeZoneIdentifier: context.attributes.timeZoneIdentifier,
                        locale: locale,
                        surface: .island
                    )
                }
            } compactLeading: {
                PulseReminderActivityMark(
                    phase: context.state.phase,
                    layout: .islandCompact,
                    day: day,
                    locale: locale,
                    animatesAppearance: true
                )
            } compactTrailing: {
                EmptyView()
            } minimal: {
                PulseReminderActivityMark(
                    phase: context.state.phase,
                    layout: .islandMinimal,
                    day: day,
                    locale: locale,
                    animatesAppearance: true
                )
            }
            .keylineTint(PulseWidgetDesign.activityIslandSeal)
            .widgetURL(PulseRuntimeIdentity.todayDeepLink)
        }
    }
}

struct PulseDailyImprintWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: PulseWidgetContract.homeKind,
            intent: PulseWidgetConfigurationIntent.self,
            provider: PulseWidgetProvider()
        ) { entry in
            PulseWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.configuration.name")
        .description("widget.configuration.description")
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}

struct PulseAccessoryRhythmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: PulseWidgetContract.accessoryKind,
            provider: PulseAccessoryProvider()
        ) { entry in
            PulseWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.accessory.configuration.name")
        .description("widget.accessory.configuration.description")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular
        ])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}

@MainActor
private struct PulseWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PulseWidgetEntry {
        PulseWidgetEntry(
            date: .now,
            state: .placeholder,
            language: .system
        )
    }

    func snapshot(
        for configuration: PulseWidgetConfigurationIntent,
        in context: Context
    ) async -> PulseWidgetEntry {
        if context.isPreview {
            return PulseWidgetEntry(
                date: .now,
                state: .ready(.placeholder, configuration.style),
                language: .system
            )
        }
        let hasEnhancement = await PulseStoreKitEntitlementReader.hasCurrentEntitlement(
            for: PulseEnhancementContract.productIdentifier
        )
        return PulseWidgetTimelineLoader.loadTimeline(
            at: .now,
            requestedStyle: configuration.style,
            hasEnhancementEntitlement: hasEnhancement
        ).entries[0]
    }

    func timeline(
        for configuration: PulseWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<PulseWidgetEntry> {
        let hasEnhancement = await PulseStoreKitEntitlementReader.hasCurrentEntitlement(
            for: PulseEnhancementContract.productIdentifier
        )
        return PulseWidgetTimelineLoader.loadTimeline(
            at: .now,
            requestedStyle: configuration.style,
            hasEnhancementEntitlement: hasEnhancement
        )
    }
}

@MainActor
private struct PulseAccessoryProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseWidgetEntry {
        PulseWidgetEntry(
            date: .now,
            state: .ready(.placeholder, PulseWidgetStyleAccessPolicy.freeStyle),
            language: .system
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (PulseWidgetEntry) -> Void
    ) {
        guard !context.isPreview else {
            completion(placeholder(in: context))
            return
        }
        completion(
            PulseWidgetTimelineLoader.loadTimeline(
                at: .now,
                requestedStyle: PulseWidgetStyleAccessPolicy.freeStyle,
                hasEnhancementEntitlement: false
            ).entries[0]
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<PulseWidgetEntry>) -> Void
    ) {
        completion(
            PulseWidgetTimelineLoader.loadTimeline(
                at: .now,
                requestedStyle: PulseWidgetStyleAccessPolicy.freeStyle,
                hasEnhancementEntitlement: false
            )
        )
    }
}

private struct PulseWidgetView: View {
    let entry: PulseWidgetEntry

    var body: some View {
        PulseLocalizedWidgetView(entry: entry)
            .environment(\.locale, entry.language.locale)
    }
}

private struct PulseLocalizedWidgetView: View {
    let entry: PulseWidgetEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.widgetContentMargins) private var widgetContentMargins
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        Group {
            switch entry.state {
            case .placeholder:
                Color.clear
                    .accessibilityHidden(true)
            case .ready(let snapshot, let style):
                readyView(snapshot, style: style)
            case .enhancementRequired:
                unavailableView(
                    title: "widget.state.enhancement_required.title",
                    message: "widget.state.enhancement_required.message",
                    systemImage: "lock"
                )
            case .needsOpenApp:
                unavailableView(
                    title: "widget.state.open_app.title",
                    message: "widget.state.open_app.message",
                    systemImage: "arrow.up.forward.app"
                )
            case .unavailable:
                unavailableView(
                    title: "widget.state.unavailable.title",
                    message: "widget.state.unavailable.message",
                    systemImage: "exclamationmark.circle"
                )
            }
        }
        .containerBackground(for: .widget) {
            PulseWidgetDesign.paper
        }
    }

    @ViewBuilder
    private func readyView(
        _ snapshot: PulseWidgetSnapshot,
        style: PulseWidgetStyle
    ) -> some View {
        switch family {
        case .accessoryCircular:
            accessoryCircular(snapshot)
                .padding(widgetContentMargins)
        case .accessoryRectangular:
            accessoryRectangular(snapshot)
                .padding(widgetContentMargins)
        case .systemMedium:
            homeWidget(snapshot, style: style, usesMediumMetrics: true)
        default:
            homeWidget(snapshot, style: style, usesMediumMetrics: false)
        }
    }

    @ViewBuilder
    private func homeWidget(
        _ snapshot: PulseWidgetSnapshot,
        style: PulseWidgetStyle,
        usesMediumMetrics: Bool
    ) -> some View {
        let content = PulseWidgetHomeRenderer(
            snapshot: snapshot,
            style: style,
            usesMediumMetrics: usesMediumMetrics,
            usesFullColorPalette: usesFullColorPalette,
            allowsMotion: !reduceMotion && !isLuminanceReduced,
            statusText: String(
                localized: snapshot.isCheckedToday
                    ? "widget.state.checked"
                    : "widget.state.pending",
                locale: locale
            ),
            pathSummaryFormat: String(
                localized: "widget.path.summary.format",
                locale: locale
            )
        )

        ZStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            Color.clear
                .accessibilityElement()
                .accessibilityLabel("widget.accessibility.checked")
                .accessibilityHidden(!snapshot.isCheckedToday)

            PulseWidgetCheckInHitTarget(
                isEnabled: !snapshot.isCheckedToday
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func accessoryCircular(_ snapshot: PulseWidgetSnapshot) -> some View {
        ZStack {
            accessoryCircularContent(snapshot)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            Color.clear
                .accessibilityElement()
                .accessibilityLabel("widget.accessibility.checked")
                .accessibilityHidden(!snapshot.isCheckedToday)

            PulseWidgetCheckInHitTarget(
                isEnabled: !snapshot.isCheckedToday
            )
        }
    }

    private func accessoryCircularContent(_ snapshot: PulseWidgetSnapshot) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            PulseDayMark(
                day: snapshot.today.day,
                state: snapshot.isCheckedToday ? .kept : .awaiting,
                seed: PulseSealSeed.value(for: snapshot.today),
                seal: .primary,
                ink: .primary,
                muted: .secondary,
                emphasized: true
            )
            .padding(PulseWidgetDesign.accessoryCircularInset)
            .widgetAccentable()
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func accessoryRectangular(_ snapshot: PulseWidgetSnapshot) -> some View {
        ZStack {
            accessoryRectangularContent(snapshot)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            Color.clear
                .accessibilityElement()
                .accessibilityLabel(Text(verbatim: accessorySummary(snapshot)))
                .accessibilityHidden(!snapshot.isCheckedToday)

            PulseWidgetCheckInHitTarget(
                label: Text(verbatim: accessorySummary(snapshot)),
                isEnabled: !snapshot.isCheckedToday
            )
        }
    }

    /// The status, then the week as a row of date seals ending on today.
    private func accessoryRectangularContent(
        _ snapshot: PulseWidgetSnapshot
    ) -> some View {
        VStack(alignment: .leading, spacing: PulseWidgetDesign.spacing4) {
            Text(snapshot.isCheckedToday
                ? "widget.accessory.state.checked"
                : "widget.accessory.state.pending")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: PulseWidgetDesign.accessoryMarkSpacing) {
                ForEach(snapshot.recentDays) { item in
                    PulseDayMark(
                        day: item.day.day,
                        state: PulseDayMarkState(item.state),
                        seed: PulseSealSeed.value(for: item.day),
                        seal: .primary,
                        ink: .primary,
                        muted: .secondary,
                        emphasized: item.day == snapshot.today,
                        isCompact: true
                    )
                    .frame(
                        width: PulseWidgetDesign.accessoryMarkSide,
                        height: PulseWidgetDesign.accessoryMarkSide
                    )
                    .widgetAccentable(item.state == .checked || item.state == .todayPending)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func accessorySummary(_ snapshot: PulseWidgetSnapshot) -> String {
        let key = snapshot.isCheckedToday
            ? "widget.accessibility.accessory.checked.summary"
            : "widget.accessibility.accessory.pending.summary"
        let format = String(
            localized: String.LocalizationValue(key),
            locale: locale
        )
        return String(
            format: format,
            locale: locale,
            Int64(snapshot.previousSixCheckedCount)
        )
    }

    private func unavailableView(
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: PulseWidgetDesign.spacing8) {
            Image(systemName: systemImage)
                .font(.title2)
            Text(title)
                .font(.headline)
            if family != .accessoryCircular {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(secondaryForeground)
            }
        }
        .foregroundStyle(family == .accessoryCircular
            ? Color.primary
            : primaryForeground)
        .padding(contentInsets)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: family == .accessoryCircular ? .center : .leading
        )
    }

    private var usesFullColorPalette: Bool {
        renderingMode == .fullColor
    }

    private var contentInsets: EdgeInsets {
        switch family {
        case .systemSmall, .systemMedium:
            PulseWidgetDesign.homeContentInsets
        default:
            widgetContentMargins
        }
    }

    private var primaryForeground: Color {
        usesFullColorPalette ? PulseWidgetDesign.ink : .primary
    }

    private var secondaryForeground: Color {
        usesFullColorPalette ? PulseWidgetDesign.muted : .secondary
    }
}

private struct PulseWidgetCheckInHitTarget: View {
    let label: Text
    let isEnabled: Bool

    init(
        label: Text = Text("widget.action.check_in"),
        isEnabled: Bool
    ) {
        self.label = label
        self.isEnabled = isEnabled
    }

    var body: some View {
        Button(intent: PulseWidgetCheckInIntent()) {
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityHint("widget.action.check_in.hint")
        .accessibilityHidden(!isEnabled)
    }
}
