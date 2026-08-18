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
                locale: locale
            )
                .activityBackgroundTint(nil)
                .activitySystemActionForegroundColor(nil)
                .widgetURL(PulseRuntimeIdentity.todayDeepLink)
        } dynamicIsland: { context in
            let locale = Locale(identifier: context.attributes.localeIdentifier)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PulseReminderActivityMark(
                        phase: context.state.phase,
                        layout: .islandExpanded
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
                    locale: locale
                )
            } compactTrailing: {
                EmptyView()
            } minimal: {
                PulseReminderActivityMark(
                    phase: context.state.phase,
                    layout: .islandMinimal,
                    locale: locale
                )
            }
            .keylineTint(PulseWidgetDesign.activityIslandFirefly)
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

private enum PulseWidgetEntryState {
    case ready(PulseWidgetSnapshot, PulseWidgetStyle)
    case enhancementRequired
    case needsOpenApp
    case unavailable
}

private struct PulseWidgetEntry: TimelineEntry {
    let date: Date
    let state: PulseWidgetEntryState
    let language: PulseInterfaceLanguage
}

@MainActor
private struct PulseWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PulseWidgetEntry {
        PulseWidgetEntry(
            date: .now,
            state: .ready(.placeholder, PulseWidgetStyleAccessPolicy.freeStyle),
            language: .system
        )
    }

    func snapshot(
        for configuration: PulseWidgetConfigurationIntent,
        in context: Context
    ) async -> PulseWidgetEntry {
        if context.isPreview {
            return placeholder(in: context)
        }
        let hasEnhancement = await PulseStoreKitEntitlementReader.hasCurrentEntitlement(
            for: PulseEnhancementContract.productIdentifier
        )
        return PulseWidgetRuntime.loadTimeline(
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
        return PulseWidgetRuntime.loadTimeline(
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
            PulseWidgetRuntime.loadTimeline(
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
            PulseWidgetRuntime.loadTimeline(
                at: .now,
                requestedStyle: PulseWidgetStyleAccessPolicy.freeStyle,
                hasEnhancementEntitlement: false
            )
        )
    }
}

@MainActor
private enum PulseWidgetRuntime {
    struct TimelineResult {
        let entries: [PulseWidgetEntry]
        let policy: TimelineReloadPolicy

        var timeline: Timeline<PulseWidgetEntry> {
            Timeline(entries: entries, policy: policy)
        }
    }

    static func loadTimeline(
        at date: Date,
        requestedStyle: PulseWidgetStyle,
        hasEnhancementEntitlement: Bool
    ) -> Timeline<PulseWidgetEntry> {
        let context: PulseWidgetSharedRuntime.Context
        let language: PulseInterfaceLanguage
        do {
            context = try PulseWidgetSharedRuntime.makeContext()
            language = try context.sharedSettings.load().language
        } catch {
            return failureTimeline(
                at: date,
                state: .unavailable,
                language: .system,
                retryAfter: 15 * 60
            ).timeline
        }

        do {
            try PulseWidgetSharedRuntime.requireExistingStore(at: context.location)
            let repository = try PulseWidgetSharedRuntime.makeRepository(
                at: context.location,
                clock: FixedPulseClock(now: date)
            )
            guard PulseWidgetStyleAccessPolicy.isAvailable(
                requestedStyle,
                hasEnhancementEntitlement: hasEnhancementEntitlement
            ) else {
                return failureTimeline(
                    at: date,
                    state: .enhancementRequired,
                    language: language,
                    retryAfter: PulseEnhancementContract.entitlementRefreshInterval
                ).timeline
            }
            guard let plan = try PulseWidgetSnapshotReader.readTimelinePlan(
                repository: repository,
                at: date
            ) else {
                throw PulseWidgetSharedRuntime.RuntimeError.missingPrimaryHabit
            }
            let entries = plan.entries.map { timelineEntry in
                PulseWidgetEntry(
                    date: timelineEntry.date,
                    state: .ready(timelineEntry.snapshot, requestedStyle),
                    language: language
                )
            }
            return TimelineResult(entries: entries, policy: .atEnd).timeline
        } catch PulseWidgetSharedRuntime.RuntimeError.sharedStoreMissing,
                PulseWidgetSharedRuntime.RuntimeError.missingPrimaryHabit {
            return failureTimeline(
                at: date,
                state: .needsOpenApp,
                language: language,
                retryAfter: 15 * 60
            ).timeline
        } catch PulseWidgetProjectionError.identityNotConfirmed {
            return failureTimeline(
                at: date,
                state: .needsOpenApp,
                language: language,
                retryAfter: 15 * 60
            ).timeline
        } catch {
            return failureTimeline(
                at: date,
                state: .unavailable,
                language: language,
                retryAfter: 15 * 60
            ).timeline
        }
    }

    private static func failureTimeline(
        at date: Date,
        state: PulseWidgetEntryState,
        language: PulseInterfaceLanguage,
        retryAfter: TimeInterval
    ) -> TimelineResult {
        return TimelineResult(
            entries: [
                PulseWidgetEntry(
                    date: date,
                    state: state,
                    language: language
                ),
            ],
            policy: .after(date.addingTimeInterval(retryAfter))
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
            PulseWidgetDesign.background
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
                    ? "widget.state.checked.editorial"
                    : "widget.state.pending.short",
                locale: locale
            ),
            pathSummaryFormat: String(
                localized: "widget.path.summary.format",
                locale: locale
            ),
            emptyPlaceText: String(
                localized: "widget.place.empty",
                locale: locale
            ),
            placeStatusText: String(
                localized: snapshot.isCheckedToday
                    ? "widget.place.checked"
                    : "widget.place.pending",
                locale: locale
            )
        )

        ZStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .invalidatableContent()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            if snapshot.isCheckedToday {
                Color.clear
                    .accessibilityElement()
                    .accessibilityLabel("widget.accessibility.checked")
            } else {
                PulseWidgetCheckInHitTarget()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func accessoryCircular(_ snapshot: PulseWidgetSnapshot) -> some View {
        if snapshot.isCheckedToday {
            accessoryCircularContent(snapshot)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("widget.accessibility.checked")
        } else {
            ZStack {
                accessoryCircularContent(snapshot)
                    .invalidatableContent()
                    .allowsHitTesting(false)

                PulseWidgetCheckInHitTarget()
            }
        }
    }

    private func accessoryCircularContent(_ snapshot: PulseWidgetSnapshot) -> some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            accessoryImprintMark(
                snapshot,
                dayNumber: accessoryDayNumber(for: snapshot.today)
            )
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func accessoryRectangular(_ snapshot: PulseWidgetSnapshot) -> some View {
        if snapshot.isCheckedToday {
            accessoryRectangularContent(snapshot)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: accessorySummary(snapshot)))
        } else {
            ZStack {
                accessoryRectangularContent(snapshot)
                    .invalidatableContent()
                    .allowsHitTesting(false)

                PulseWidgetCheckInHitTarget(
                    label: Text(verbatim: accessorySummary(snapshot))
                )
            }
        }
    }

    private func accessoryRectangularContent(
        _ snapshot: PulseWidgetSnapshot
    ) -> some View {
        GeometryReader { proxy in
            let metrics = PulseAccessoryRhythmMetrics(size: proxy.size)
            let history = Array(snapshot.recentDays.dropLast())
            let dayNumbers = accessoryDayNumbers(for: snapshot.recentDays)

            ZStack(alignment: .topLeading) {
                Text(snapshot.isCheckedToday
                    ? "widget.accessory.state.checked"
                    : "widget.accessory.state.pending")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(width: metrics.statusWidth, alignment: .leading)

                accessoryConnectorPath(days: history, metrics: metrics)
                    .stroke(
                        Color.primary.opacity(PulseWidgetDesign.accessoryConnectorOpacity),
                        style: StrokeStyle(
                            lineWidth: PulseWidgetDesign.accessoryConnectorWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .accessibilityHidden(true)

                ForEach(Array(history.enumerated()), id: \.element.id) { index, item in
                    let side = accessoryHistoryMarkSide(item.state)
                    accessoryHistoryDayLabel(dayNumbers[index])
                        .position(
                            x: metrics.historyCenters[index],
                            y: metrics.historyDateY
                        )

                    accessoryHistoryMark(item)
                        .frame(width: side, height: side)
                        .position(
                            x: metrics.historyCenters[index],
                            y: metrics.railY
                        )
                }

                accessoryImprintMark(
                    snapshot,
                    dayNumber: dayNumbers.last
                        ?? accessoryDayNumber(for: snapshot.today)
                )
                .frame(width: metrics.imprintSide, height: metrics.imprintSide)
                .position(metrics.imprintCenter)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private func accessoryDayNumbers(
        for days: [PulseWidgetDaySnapshot]
    ) -> [String] {
        days.map { item in
            PulseLocalizedDateFormatting.dayNumber(item.day, locale: locale)
        }
    }

    private func accessoryDayNumber(for day: LogicalDay) -> String {
        PulseLocalizedDateFormatting.dayNumber(day, locale: locale)
    }

    private func accessoryHistoryDayLabel(_ dayNumber: String) -> some View {
        Text(verbatim: dayNumber)
            .font(.system(
                size: PulseWidgetDesign.accessoryDateFontSize,
                weight: .semibold
            ))
            .monospacedDigit()
            .foregroundStyle(Color.primary.opacity(PulseWidgetDesign.accessoryDateOpacity))
            .lineLimit(1)
            .frame(
                width: PulseWidgetDesign.accessoryDateLabelWidth,
                height: PulseWidgetDesign.accessoryDateLabelHeight
            )
            .accessibilityHidden(true)
    }

    private func accessoryConnectorPath(
        days: [PulseWidgetDaySnapshot],
        metrics: PulseAccessoryRhythmMetrics
    ) -> Path {
        var path = Path()
        guard days.count == metrics.historyCenters.count,
              let lastDay = days.last,
              let lastCenter = metrics.historyCenters.last else {
            return path
        }

        for index in 0..<(days.count - 1) {
            let startX = metrics.historyCenters[index]
                + accessoryHistoryMarkSide(days[index].state) / 2
            let endX = metrics.historyCenters[index + 1]
                - accessoryHistoryMarkSide(days[index + 1].state) / 2
            path.move(to: CGPoint(x: startX, y: metrics.railY))
            path.addLine(to: CGPoint(x: endX, y: metrics.railY))
        }

        let start = CGPoint(
            x: lastCenter + accessoryHistoryMarkSide(lastDay.state) / 2,
            y: metrics.railY
        )
        let end = metrics.imprintLeadingAnchor
        let controlX = start.x + (end.x - start.x) * 0.58
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(x: controlX, y: start.y),
            control2: CGPoint(x: controlX, y: end.y)
        )
        return path
    }

    private func accessoryHistoryMark(_ item: PulseWidgetDaySnapshot) -> some View {
        RoundedRectangle(
            cornerRadius: PulseWidgetDesign.accessoryBlockCornerRadius,
            style: .continuous
        )
        .fill(accessoryHistoryMarkFill(item.state))
        .overlay {
            if let stroke = accessoryHistoryMarkStroke(item.state) {
                RoundedRectangle(
                    cornerRadius: PulseWidgetDesign.accessoryBlockCornerRadius,
                    style: .continuous
                )
                .stroke(stroke, lineWidth: PulseWidgetDesign.accessoryRailStrokeWidth)
            }
        }
        .widgetAccentable(item.state == .checked)
        .accessibilityHidden(true)
    }

    private func accessoryHistoryMarkSide(_ state: PulseWidgetDayState) -> CGFloat {
        state == .checked
            ? PulseWidgetDesign.accessoryRailLargeSide
            : PulseWidgetDesign.accessoryRailSmallSide
    }

    private func accessoryHistoryMarkFill(_ state: PulseWidgetDayState) -> Color {
        switch state {
        case .checked:
            .primary
        case .missed:
            .primary.opacity(PulseWidgetDesign.accessoryMissedOpacity)
        case .beforeHabit, .todayPending:
            .clear
        }
    }

    private func accessoryHistoryMarkStroke(_ state: PulseWidgetDayState) -> Color? {
        switch state {
        case .beforeHabit:
            Color.primary.opacity(PulseWidgetDesign.accessoryBeforeHabitOpacity)
        case .todayPending:
            Color.primary
        case .checked, .missed:
            nil
        }
    }

    private func accessoryImprintMark(
        _ snapshot: PulseWidgetSnapshot,
        dayNumber: String
    ) -> some View {
        PulseWidgetImprintMark(
            isChecked: snapshot.isCheckedToday,
            usesFullColorPalette: usesFullColorPalette,
            usesSystemPalette: true,
            isOnCompletedSurface: false,
            coreScale: PulseWidgetDesign.imprintCoreScale,
            ringInsetRatio: PulseWidgetDesign.imprintRingInsetRatio,
            showsPendingCore: false,
            pendingLabel: nil,
            pendingLabelScale: 0,
            glyphScale: PulseWidgetDesign.imprintGlyphScale,
            centerLabel: dayNumber,
            centerLabelScale: PulseWidgetDesign.accessoryTodayDateScale,
            ringRotationDegrees: 0,
            coreRotationDegrees: 0
        )
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
        usesFullColorPalette ? PulseWidgetDesign.secondary : .secondary
    }
}

private struct PulseWidgetCheckInHitTarget: View {
    let label: Text

    init(label: Text = Text("widget.action.check_in")) {
        self.label = label
    }

    var body: some View {
        Button(intent: PulseCheckInIntent()) {
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityHint("widget.action.check_in.hint")
    }
}

private struct PulseAccessoryRhythmMetrics {
    let imprintSide: CGFloat
    let imprintCenter: CGPoint
    let imprintLeadingAnchor: CGPoint
    let historyCenters: [CGFloat]
    let historyDateY: CGFloat
    let railY: CGFloat
    let statusWidth: CGFloat

    init(size: CGSize) {
        let imprintSide = min(
            size.height * PulseWidgetDesign.accessoryImprintHeightRatio,
            size.width * PulseWidgetDesign.accessoryImprintWidthRatio
        )
        let imprintCenter = CGPoint(
            x: size.width - imprintSide / 2,
            y: size.height / 2
        )
        let visibleRingInset = imprintSide * (
            PulseWidgetDesign.imprintRingInsetRatio
                + (1 - 2 * PulseWidgetDesign.imprintRingInsetRatio)
                * PulseWidgetDesign.prototypeRingInsetRatio
        )
        let imprintLeadingAnchor = CGPoint(
            x: size.width - imprintSide + visibleRingInset,
            y: imprintCenter.y
        )
        let firstCenter = max(
            PulseWidgetDesign.accessoryRailLargeSide / 2,
            PulseWidgetDesign.accessoryDateLabelWidth / 2
        )
        let lastCenter = max(
            firstCenter,
            imprintLeadingAnchor.x - PulseWidgetDesign.accessoryRailTerminalGap
        )
        let step = (lastCenter - firstCenter) / 5
        let railY = min(
            size.height - PulseWidgetDesign.accessoryRailLargeSide / 2,
            size.height * PulseWidgetDesign.accessoryRailYRatio
        )

        self.imprintSide = imprintSide
        self.imprintCenter = imprintCenter
        self.imprintLeadingAnchor = imprintLeadingAnchor
        historyCenters = (0..<6).map { firstCenter + CGFloat($0) * step }
        historyDateY = max(
            PulseWidgetDesign.accessoryDateLabelHeight / 2,
            railY
                - PulseWidgetDesign.accessoryRailLargeSide / 2
                - PulseWidgetDesign.accessoryDateRailGap
                - PulseWidgetDesign.accessoryDateLabelHeight / 2
        )
        self.railY = railY
        statusWidth = max(
            0,
            size.width - imprintSide - PulseWidgetDesign.spacing8
        )
    }
}

private extension PulseWidgetSnapshot {
    static var placeholder: PulseWidgetSnapshot {
        let generatedAt = Date.now
        let timeZone = TimeZone.current
        let today = LogicalDay.resolve(at: generatedAt, timeZone: timeZone)
        let days = (-6...0).map { offset in
            PulseWidgetDaySnapshot(
                day: today.addingDays(offset, timeZone: timeZone),
                state: offset == 0 ? .todayPending : (offset.isMultiple(of: 2) ? .checked : .missed)
            )
        }
        return PulseWidgetSnapshot(
            habitID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            habitName: String(localized: "widget.placeholder.commitment"),
            today: today,
            checkedAt: nil,
            recentDays: days,
            generatedAt: generatedAt,
            nextDayBoundary: today.addingDays(1, timeZone: timeZone).startDate(
                timeZone: timeZone
            ),
            projectTimeZoneIdentifier: timeZone.identifier
        )
    }
}
