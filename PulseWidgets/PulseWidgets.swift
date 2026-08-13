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
        PulseReminderLiveActivity()
    }
}

struct PulseReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PulseReminderActivityAttributes.self) { context in
            PulseReminderLockScreenView(context: context)
                .environment(\.locale, Locale(identifier: context.attributes.localeIdentifier))
                .activityBackgroundTint(PulseWidgetDesign.background)
                .activitySystemActionForegroundColor(PulseWidgetDesign.action)
                .widgetURL(PulseReminderActivityContract.deepLink)
        } dynamicIsland: { context in
            let locale = Locale(identifier: context.attributes.localeIdentifier)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PulseReminderMark(size: 28)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(
                        LocalizedStringResource(
                            "activity.reminder.title",
                            locale: locale
                        )
                    )
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: PulseWidgetDesign.spacing8) {
                        Text(
                            LocalizedStringResource(
                                "activity.reminder.body",
                                locale: locale
                            )
                        )
                            .font(.subheadline)
                            .foregroundStyle(PulseWidgetDesign.secondary)
                            .lineLimit(2)
                        Spacer(minLength: PulseWidgetDesign.spacing8)
                        Link(destination: PulseReminderActivityContract.deepLink) {
                            Text(
                                LocalizedStringResource(
                                    "activity.reminder.action",
                                    locale: locale
                                )
                            )
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            } compactLeading: {
                PulseReminderMark(size: 18)
            } compactTrailing: {
                Text(
                    LocalizedStringResource(
                        "activity.reminder.compact",
                        locale: locale
                    )
                )
                    .font(.caption2.weight(.semibold))
            } minimal: {
                PulseReminderMark(size: 18)
            }
            .keylineTint(PulseWidgetDesign.grass)
            .widgetURL(PulseReminderActivityContract.deepLink)
        }
    }
}

private struct PulseReminderLockScreenView: View {
    let context: ActivityViewContext<PulseReminderActivityAttributes>

    var body: some View {
        HStack(spacing: PulseWidgetDesign.spacing8) {
            PulseReminderMark(size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("activity.reminder.title")
                    .font(.headline)
                Text("activity.reminder.body")
                    .font(.subheadline)
                    .foregroundStyle(PulseWidgetDesign.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: PulseWidgetDesign.spacing8)

            Link(destination: PulseReminderActivityContract.deepLink) {
                Image(systemName: "arrow.up.right")
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("activity.reminder.action")
        }
        .padding(PulseWidgetDesign.homeSafeInset)
    }
}

private struct PulseReminderMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(PulseWidgetDesign.grass, lineWidth: max(2, size * 0.1))
            Circle()
                .fill(PulseWidgetDesign.grass)
                .frame(width: size * 0.2, height: size * 0.2)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct PulseDailyImprintWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: PulseWidgetContract.kind,
            provider: PulseWidgetProvider()
        ) { entry in
            PulseWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.configuration.name")
        .description("widget.configuration.description")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular
        ])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}

private enum PulseWidgetEntryState {
    case ready(PulseWidgetSnapshot, PulseWidgetStyle)
    case needsOpenApp
    case unavailable
}

private struct PulseWidgetEntry: TimelineEntry {
    let date: Date
    let state: PulseWidgetEntryState
    let language: PulseInterfaceLanguage
}

@MainActor
private struct PulseWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseWidgetEntry {
        PulseWidgetEntry(
            date: .now,
            state: .ready(.placeholder, PulseSharedInterfacePreferences.defaultWidgetStyle),
            language: .system
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (PulseWidgetEntry) -> Void
    ) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task { @MainActor in
            let hasEnhancement = await PulseStoreKitEntitlementReader.hasCurrentEntitlement(
                for: PulseEnhancementContract.productIdentifier
            )
            completion(
                PulseWidgetRuntime.loadEntry(
                    at: .now,
                    hasEnhancementEntitlement: hasEnhancement
                ).entry
            )
        }
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<PulseWidgetEntry>) -> Void
    ) {
        Task { @MainActor in
            let hasEnhancement = await PulseStoreKitEntitlementReader.hasCurrentEntitlement(
                for: PulseEnhancementContract.productIdentifier
            )
            let result = PulseWidgetRuntime.loadEntry(
                at: .now,
                hasEnhancementEntitlement: hasEnhancement
            )
            completion(
                Timeline(
                    entries: [result.entry],
                    policy: .after(result.refreshAfter)
                )
            )
        }
    }
}

@MainActor
private enum PulseWidgetRuntime {
    struct LoadResult {
        let entry: PulseWidgetEntry
        let refreshAfter: Date
    }

    enum RuntimeError: Error {
        case missingAppGroupIdentifier
        case sharedStoreMissing
        case missingPrimaryHabit
    }

    static func loadEntry(
        at date: Date,
        hasEnhancementEntitlement: Bool
    ) -> LoadResult {
        let context: RuntimeContext
        let language: PulseInterfaceLanguage
        do {
            context = try makeLocationContext()
            language = try context.interfacePreferences.loadLanguage()
        } catch {
            return LoadResult(
                entry: PulseWidgetEntry(
                    date: date,
                    state: .unavailable,
                    language: .system
                ),
                refreshAfter: date.addingTimeInterval(15 * 60)
            )
        }

        do {
            try requireExistingStore(at: context.location)
            let repository = try makeRepository(
                at: context.location,
                clock: FixedPulseClock(now: date)
            )
            let preferredStyle = try context.interfacePreferences.loadWidgetStyle()
            let style = PulseWidgetStyleAccessPolicy.resolvedStyle(
                preferredStyle: preferredStyle,
                hasEnhancementEntitlement: hasEnhancementEntitlement
            )
            guard let plan = try PulseWidgetSnapshotReader.readTimelinePlan(
                repository: repository,
                at: date
            ) else {
                throw RuntimeError.missingPrimaryHabit
            }
            return LoadResult(
                entry: PulseWidgetEntry(
                    date: date,
                    state: .ready(plan.snapshot, style),
                    language: language
                ),
                refreshAfter: PulseWidgetStyleAccessPolicy.requiresEnhancement(style)
                    ? min(
                        plan.refreshAfter,
                        date.addingTimeInterval(
                            PulseEnhancementContract.entitlementRefreshInterval
                        )
                    )
                    : plan.refreshAfter
            )
        } catch RuntimeError.sharedStoreMissing, RuntimeError.missingPrimaryHabit {
            return LoadResult(
                entry: PulseWidgetEntry(
                    date: date,
                    state: .needsOpenApp,
                    language: language
                ),
                refreshAfter: date.addingTimeInterval(15 * 60)
            )
        } catch PulseWidgetProjectionError.identityNotConfirmed {
            return LoadResult(
                entry: PulseWidgetEntry(
                    date: date,
                    state: .needsOpenApp,
                    language: language
                ),
                refreshAfter: date.addingTimeInterval(15 * 60)
            )
        } catch {
            return LoadResult(
                entry: PulseWidgetEntry(
                    date: date,
                    state: .unavailable,
                    language: language
                ),
                refreshAfter: date.addingTimeInterval(15 * 60)
            )
        }
    }

    static func checkIn() throws {
        let clock = SystemPulseClock()
        let context = try makeLocationContext()
        try requireExistingStore(at: context.location)
        let repository = try makeRepository(at: context.location, clock: clock)
        guard let habit = try repository.existingPrimaryHabit(),
              habit.isIdentityConfirmed else {
            throw RuntimeError.missingPrimaryHabit
        }
        _ = try repository.checkIn(habitID: habit.id)
    }

    private static func makeLocationContext() throws -> RuntimeContext {
        guard let identifier = Bundle.main.object(
            forInfoDictionaryKey: "PulseAppGroupIdentifier"
        ) as? String,
        identifier.hasPrefix("group."),
        !identifier.contains("$(") else {
            throw RuntimeError.missingAppGroupIdentifier
        }
        let location = try PulseStoreLocator().appGroupLocation(identifier: identifier)
        return RuntimeContext(
            location: location,
            interfacePreferences: try PulseSharedInterfacePreferences(
                appGroupIdentifier: identifier
            )
        )
    }

    private static func requireExistingStore(at location: PulseStoreLocation) throws {
        guard FileManager.default.fileExists(atPath: location.storeURL.path) else {
            throw RuntimeError.sharedStoreMissing
        }
    }

    private static func makeRepository(
        at location: PulseStoreLocation,
        clock: any PulseClock
    ) throws -> SwiftDataPulseRepository {
        SwiftDataPulseRepository(
            container: try PersistenceController.makeContainer(
                storeName: PulseStoreContract.storeName,
                storeURL: location.storeURL
            ),
            clock: clock,
            primaryHabitProvisioning: .existingStoreOnly
        )
    }

    private struct RuntimeContext {
        let location: PulseStoreLocation
        let interfacePreferences: PulseSharedInterfacePreferences
    }
}

struct PulseCheckInIntent: AppIntent {
    static let title: LocalizedStringResource = "widget.intent.check_in.title"
    static let description = IntentDescription("widget.intent.check_in.description")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        try PulseWidgetRuntime.checkIn()
        WidgetCenter.shared.reloadTimelines(ofKind: PulseWidgetContract.kind)
        return .result()
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

    var body: some View {
        Group {
            switch entry.state {
            case .ready(let snapshot, let style):
                readyView(snapshot, style: style)
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
            PulseWidgetHomeView(
                snapshot: snapshot,
                style: style,
                usesMediumMetrics: true
            )
        default:
            PulseWidgetHomeView(
                snapshot: snapshot,
                style: style,
                usesMediumMetrics: false
            )
        }
    }

    @ViewBuilder
    private func accessoryCircular(_ snapshot: PulseWidgetSnapshot) -> some View {
        if snapshot.isCheckedToday {
            accessoryCircularContent(snapshot)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("widget.accessibility.checked")
        } else {
            Button(intent: PulseCheckInIntent()) {
                accessoryCircularContent(snapshot)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("widget.action.check_in")
            .accessibilityHint("widget.action.check_in.hint")
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
            Button(intent: PulseCheckInIntent()) {
                accessoryRectangularContent(snapshot)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: accessorySummary(snapshot)))
            .accessibilityHint("widget.action.check_in.hint")
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
        return days.map { item in
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
            .foregroundStyle(
                Color.primary.opacity(PulseWidgetDesign.accessoryDateOpacity)
            )
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
            usesSystemPalette: true,
            isOnCompletedSurface: false,
            coreScale: PulseWidgetDesign.imprintCoreScale,
            ringInsetRatio: PulseWidgetDesign.imprintRingInsetRatio,
            showsPendingCore: false,
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

private struct PulseWidgetHomeView: View {
    let snapshot: PulseWidgetSnapshot
    let style: PulseWidgetStyle
    let usesMediumMetrics: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.locale) private var locale

    var body: some View {
        GeometryReader { proxy in
            let content = Group {
                switch style {
                case .breathingOrbit:
                    breathingOrbit(size: proxy.size)
                case .morningDew:
                    morningDew(size: proxy.size)
                case .diagonalLight:
                    diagonalLight(size: proxy.size)
                case .tidalFill:
                    tidalFill(size: proxy.size)
                case .cornerTint:
                    cornerTint(size: proxy.size)
                case .quietOrder:
                    quietOrder(size: proxy.size)
                case .signalPoster:
                    signalPoster(size: proxy.size)
                case .rhythmBoard:
                    rhythmBoard(size: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()

            if usesDesignedStateTransition {
                content.animation(
                    reduceMotion
                        ? nil
                        : .easeOut(duration: PulseWidgetDesign.stateTransitionDuration),
                    value: snapshot.isCheckedToday
                )
            } else {
                content
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var usesDesignedStateTransition: Bool {
        style == .signalPoster || style == .rhythmBoard
    }

    private func breathingOrbit(size: CGSize) -> some View {
        let actionDiameter = size.width * (usesMediumMetrics ? 0.19 : 0.25)
        let inset = size.width * (usesMediumMetrics ? 0.055 : 0.075)

        return ZStack {
            baseBackground

            organicContours(
                size: size,
                anchor: CGPoint(x: 0.78, y: 0.58),
                widthRatio: usesMediumMetrics ? 0.56 : 0.90,
                heightRatio: 1.04
            )

            editorialStatus(foreground: secondaryForeground, size: css(14, in: size))
                .padding(.leading, inset)
                .padding(.top, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(verbatim: editorialDate)
                .font(.system(size: css(17, in: size), weight: .medium, design: .rounded))
                .foregroundStyle(actionForeground)
                .monospacedDigit()
                .padding(.trailing, inset)
                .padding(.top, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Text(verbatim: snapshot.habitName)
                .font(.system(
                    size: css(usesMediumMetrics ? 47 : 39, in: size),
                    weight: .semibold,
                    design: .rounded
                ))
                .foregroundStyle(primaryForeground)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .allowsTightening(true)
                .frame(
                    width: size.width * (usesMediumMetrics ? 0.60 : 0.70),
                    alignment: .leading
                )
                .padding(.leading, inset)
                .padding(.top, size.height * 0.28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            homeWeekRail(snapshot.recentDays, gapCSS: 7, size: size)
                .padding(.leading, inset)
                .padding(.bottom, size.height * 0.10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            homeImprintControl(
                diameter: actionDiameter,
                hasHalo: true,
                coreScale: 0.40,
                ringInsetRatio: 0.10,
                pendingLabelScale: 0.13,
                glyphScale: 0.24
            )
            .padding(.trailing, inset)
            .padding(.bottom, size.height * 0.065)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    private func diagonalLight(size: CGSize) -> some View {
        let actionDiameter = size.width * (usesMediumMetrics ? 0.18 : 0.24)
        let inset = size.width * (usesMediumMetrics ? 0.055 : 0.075)

        return ZStack {
            baseBackground

            PulseWidgetDiagonalField()
                .fill(diagonalFieldColor)
            PulseWidgetDiagonalField(boundaryOffset: -0.045)
                .fill(diagonalHighlightColor)

            Text(verbatim: editorialDate)
                .font(.system(size: css(17, in: size), weight: .medium, design: .rounded))
                .foregroundStyle(actionForeground)
                .monospacedDigit()
                .padding(.leading, inset)
                .padding(.top, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            editorialStatus(foreground: secondaryForeground, size: css(14, in: size))
                .padding(.trailing, inset)
                .padding(.top, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Text(verbatim: snapshot.habitName)
                .font(.system(
                    size: css(usesMediumMetrics ? 45 : 36, in: size),
                    weight: .semibold,
                    design: .rounded
                ))
                .foregroundStyle(primaryForeground)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.64)
                .frame(
                    width: size.width * (usesMediumMetrics ? 0.58 : 0.64),
                    alignment: .leading
                )
                .padding(.leading, inset)
                .padding(.top, size.height * 0.30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            homeWeekRail(snapshot.recentDays, gapCSS: 7, size: size)
                .padding(.leading, inset)
                .padding(.bottom, size.height * 0.10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            homeImprintControl(
                diameter: actionDiameter,
                hasHalo: false,
                coreScale: 0.42,
                ringInsetRatio: 0.08,
                pendingLabelScale: 0.14,
                glyphScale: 0.25
            )
            .padding(.trailing, inset)
            .padding(.bottom, size.height * 0.065)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    private func tidalFill(size: CGSize) -> some View {
        let actionDiameter = size.width * (usesMediumMetrics ? 0.18 : 0.24)
        let inset = size.width * (usesMediumMetrics ? 0.055 : 0.075)

        return ZStack {
            baseBackground

            PulseWidgetTidalField(level: 0.46, lift: 0.025)
                .fill(tidalFieldColor(opacity: 0.09))
            PulseWidgetTidalField(level: 0.60, lift: -0.020)
                .fill(tidalFieldColor(opacity: 0.13))
            PulseWidgetTidalField(level: 0.75, lift: 0.018)
                .fill(tidalAccentColor)

            editorialStatus(foreground: secondaryForeground, size: css(14, in: size))
                .padding(.leading, inset)
                .padding(.top, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(verbatim: editorialDate)
                .font(.system(size: css(17, in: size), weight: .medium, design: .rounded))
                .foregroundStyle(actionForeground)
                .monospacedDigit()
                .padding(.trailing, inset)
                .padding(.top, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Text(verbatim: snapshot.habitName)
                .font(.system(
                    size: css(usesMediumMetrics ? 43 : 34, in: size),
                    weight: .semibold,
                    design: .rounded
                ))
                .foregroundStyle(primaryForeground)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.64)
                .frame(
                    width: size.width * (usesMediumMetrics ? 0.60 : 0.64),
                    alignment: .leading
                )
                .padding(.leading, inset)
                .padding(.top, size.height * 0.30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            homeImprintControl(
                diameter: actionDiameter,
                hasHalo: false,
                coreScale: 0.42,
                ringInsetRatio: 0.08,
                pendingLabelScale: 0.14,
                glyphScale: 0.25
            )
            .padding(.trailing, inset)
            .padding(.bottom, size.height * 0.065)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            homeWeekRail(snapshot.recentDays, gapCSS: 7, size: size)
                .padding(.leading, inset)
                .padding(.bottom, size.height * 0.10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }

    private func morningDew(size: CGSize) -> some View {
        let actionDiameter = size.width * (usesMediumMetrics ? 0.18 : 0.24)
        let inset = size.width * (usesMediumMetrics ? 0.055 : 0.075)

        return ZStack {
            baseBackground

            Circle()
                .fill(dewFill.opacity(0.16))
                .frame(width: size.height * 0.88, height: size.height * 0.88)
                .offset(x: size.width * (usesMediumMetrics ? 0.31 : 0.27), y: -size.height * 0.17)

            Circle()
                .fill(dewFill.opacity(0.10))
                .frame(width: size.height * 0.36, height: size.height * 0.36)
                .offset(x: size.width * (usesMediumMetrics ? 0.10 : 0.04), y: size.height * 0.31)

            editorialStatus(foreground: secondaryForeground, size: css(14, in: size))
                .padding(.leading, inset)
                .padding(.top, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            VStack(alignment: .trailing, spacing: 0) {
                Text(snapshot.today.day, format: .number)
                    .font(.system(
                        size: css(usesMediumMetrics ? 76 : 68, in: size),
                        weight: .semibold,
                        design: .rounded
                    ))
                    .foregroundStyle(primaryForeground)
                    .monospacedDigit()
                    .lineLimit(1)
                Text(verbatim: localizedMonthName)
                    .font(.system(size: css(14, in: size), weight: .medium))
                    .foregroundStyle(secondaryForeground)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: localizedAccessibilityDate))
            .padding(.trailing, inset)
            .padding(.top, size.height * 0.06)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Text(verbatim: snapshot.habitName)
                .font(.system(
                    size: css(usesMediumMetrics ? 44 : 36, in: size),
                    weight: .semibold,
                    design: .rounded
                ))
                .foregroundStyle(primaryForeground)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.64)
                .frame(
                    width: size.width * (usesMediumMetrics ? 0.60 : 0.66),
                    alignment: .leading
                )
                .padding(.leading, inset)
                .padding(.top, size.height * 0.33)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            homeWeekRail(snapshot.recentDays, gapCSS: 7, size: size)
                .padding(.leading, inset)
                .padding(.bottom, size.height * 0.10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            homeImprintControl(
                diameter: actionDiameter,
                hasHalo: false,
                coreScale: 0.42,
                ringInsetRatio: 0.08,
                pendingLabelScale: 0.14,
                glyphScale: 0.25
            )
            .padding(.trailing, inset)
            .padding(.bottom, size.height * 0.065)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    private func cornerTint(size: CGSize) -> some View {
        let actionDiameter = size.width * (usesMediumMetrics ? 0.18 : 0.24)
        let inset = size.width * (usesMediumMetrics ? 0.055 : 0.075)

        return ZStack {
            baseBackground

            Circle()
                .fill(cornerLeadingColor)
                .frame(width: size.height * 0.96, height: size.height * 0.96)
                .offset(x: -size.width * 0.40, y: -size.height * 0.38)

            Circle()
                .fill(cornerTrailingColor)
                .frame(width: size.height * 0.74, height: size.height * 0.74)
                .offset(x: size.width * 0.45, y: size.height * 0.39)

            editorialStatus(foreground: secondaryForeground, size: css(14, in: size))
                .padding(.leading, inset)
                .padding(.top, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(verbatim: editorialDate)
                .font(.system(size: css(17, in: size), weight: .medium, design: .rounded))
                .foregroundStyle(actionForeground)
                .monospacedDigit()
                .padding(.trailing, inset)
                .padding(.top, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Text(verbatim: snapshot.habitName)
                .font(.system(
                    size: css(usesMediumMetrics ? 44 : 36, in: size),
                    weight: .semibold,
                    design: .rounded
                ))
                .foregroundStyle(primaryForeground)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.64)
                .frame(
                    width: size.width * (usesMediumMetrics ? 0.58 : 0.64),
                    alignment: .leading
                )
                .padding(.leading, inset)
                .padding(.top, size.height * 0.30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            homeWeekRail(snapshot.recentDays, gapCSS: 7, size: size)
                .padding(.leading, inset)
                .padding(.bottom, size.height * 0.10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            homeImprintControl(
                diameter: actionDiameter,
                hasHalo: false,
                coreScale: 0.42,
                ringInsetRatio: 0.08,
                pendingLabelScale: 0.14,
                glyphScale: 0.25
            )
            .padding(.trailing, inset)
            .padding(.bottom, size.height * 0.065)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    private func quietOrder(size: CGSize) -> some View {
        let actionDiameter = size.width * (usesMediumMetrics ? 0.16 : 0.22)
        let inset = size.width * (usesMediumMetrics ? 0.055 : 0.075)

        return ZStack {
            baseBackground

            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    editorialStatus(
                        foreground: secondaryForeground,
                        size: css(14, in: size)
                    )
                    Spacer()
                    Text(verbatim: editorialDate)
                        .font(.system(
                            size: css(17, in: size),
                            weight: .medium,
                            design: .rounded
                        ))
                        .foregroundStyle(actionForeground)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                Text(verbatim: snapshot.habitName)
                    .font(.system(
                        size: css(usesMediumMetrics ? 46 : 37, in: size),
                        weight: .semibold,
                        design: .rounded
                    ))
                    .foregroundStyle(primaryForeground)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)
                    .frame(maxWidth: size.width * (usesMediumMetrics ? 0.70 : 0.78))

                Spacer(minLength: 0)

                HStack(spacing: css(12, in: size)) {
                    homeWeekRail(snapshot.recentDays, gapCSS: 7, size: size)
                    Spacer(minLength: css(8, in: size))
                    homeImprintControl(
                        diameter: actionDiameter,
                        hasHalo: false,
                        coreScale: 0.42,
                        ringInsetRatio: 0.08,
                        pendingLabelScale: 0.14,
                        glyphScale: 0.25
                    )
                }
                .padding(.leading, css(14, in: size))
                .padding(.trailing, css(7, in: size))
                .padding(.vertical, css(7, in: size))
                .background(orderShelfColor, in: Capsule())
            }
            .padding(.horizontal, inset)
            .padding(.top, size.height * 0.08)
            .padding(.bottom, size.height * 0.065)
        }
    }

    @ViewBuilder
    private func signalPoster(size: CGSize) -> some View {
        let inset = size.width * (usesMediumMetrics ? 0.055 : 0.075)

        if usesMediumMetrics {
            let panelWidth = size.width * 0.26
            let actionDiameter = size.height * 0.48

            ZStack {
                baseBackground

                Rectangle()
                    .fill(signalPosterFieldColor)
                    .frame(width: panelWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .widgetAccentable()

                signalPosterDate(size: size, numberSizeCSS: 76)
                    .frame(width: panelWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: css(10, in: size)) {
                    Text(verbatim: snapshot.habitName)
                        .font(.system(
                            size: css(40, in: size),
                            weight: .semibold,
                            design: .rounded
                        ))
                        .foregroundStyle(primaryForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.66)

                    HStack(spacing: css(10, in: size)) {
                        editorialStatus(foreground: secondaryForeground, size: css(14, in: size))
                            .contentTransition(.interpolate)
                        Text(verbatim: recentSummary)
                            .font(.system(size: css(11, in: size), weight: .medium))
                            .foregroundStyle(secondaryForeground)
                            .lineLimit(1)
                    }

                    HStack(alignment: .center, spacing: css(10, in: size)) {
                        homeWeekRail(snapshot.recentDays, gapCSS: 7, size: size)
                        Spacer(minLength: css(8, in: size))
                        designedHomeImprintControl(
                            diameter: actionDiameter,
                            hasHalo: false,
                            coreScale: 0.42,
                            ringInsetRatio: 0.08,
                            pendingLabelScale: 0.14,
                            glyphScale: 0.25
                        )
                    }
                }
                .padding(.leading, panelWidth + inset)
                .padding(.trailing, inset)
                .padding(.vertical, size.height * 0.075)
                .frame(maxHeight: .infinity, alignment: .center)
            }
        } else {
            let actionDiameter = size.width * 0.22

            ZStack {
                baseBackground

                Rectangle()
                    .fill(signalPosterFieldColor)
                    .frame(height: size.height * 0.34)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .widgetAccentable()

                HStack(alignment: .center, spacing: css(8, in: size)) {
                    signalPosterDate(size: size, numberSizeCSS: 50)
                    Spacer(minLength: css(4, in: size))
                    editorialStatus(foreground: secondaryForeground, size: css(12, in: size))
                        .contentTransition(.interpolate)
                }
                .padding(.horizontal, inset)
                .frame(height: size.height * 0.34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                VStack(alignment: .leading, spacing: css(6, in: size)) {
                    Text(verbatim: snapshot.habitName)
                        .font(.system(
                            size: css(34, in: size),
                            weight: .semibold,
                            design: .rounded
                        ))
                        .foregroundStyle(primaryForeground)
                        .lineLimit(2)
                        .minimumScaleFactor(0.64)

                    Text(verbatim: recentSummary)
                        .font(.system(size: css(11, in: size), weight: .medium))
                        .foregroundStyle(secondaryForeground)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    HStack(spacing: css(7, in: size)) {
                        homeWeekRail(snapshot.recentDays, gapCSS: 4, size: size)
                        Spacer(minLength: 0)
                        designedHomeImprintControl(
                            diameter: actionDiameter,
                            hasHalo: false,
                            coreScale: 0.42,
                            ringInsetRatio: 0.08,
                            pendingLabelScale: 0.14,
                            glyphScale: 0.25
                        )
                    }
                }
                .padding(.horizontal, inset)
                .padding(.top, size.height * 0.39)
                .padding(.bottom, size.height * 0.065)
            }
        }
    }

    private func rhythmBoard(size: CGSize) -> some View {
        let inset = size.width * (usesMediumMetrics ? 0.055 : 0.075)

        return ZStack {
            baseBackground

            VStack(alignment: .leading, spacing: css(8, in: size)) {
                HStack(alignment: .firstTextBaseline, spacing: css(8, in: size)) {
                    Text(verbatim: snapshot.habitName)
                        .font(.system(
                            size: css(usesMediumMetrics ? 38 : 31, in: size),
                            weight: .semibold,
                            design: .rounded
                        ))
                        .foregroundStyle(primaryForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.66)
                    Spacer(minLength: css(8, in: size))
                    Text(verbatim: editorialDate)
                        .font(.system(
                            size: css(usesMediumMetrics ? 17 : 15, in: size),
                            weight: .medium,
                            design: .rounded
                        ))
                        .foregroundStyle(secondaryForeground)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                HStack(spacing: css(8, in: size)) {
                    editorialStatus(
                        foreground: secondaryForeground,
                        size: css(usesMediumMetrics ? 14 : 12, in: size)
                    )
                    .contentTransition(.interpolate)
                    Spacer(minLength: 0)
                    Text(verbatim: recentSummary)
                        .font(.system(size: css(11, in: size), weight: .medium))
                        .foregroundStyle(secondaryForeground)
                        .lineLimit(1)
                }

                homeWeekDateDots(snapshot.recentDays, size: size)
            }
            .padding(.horizontal, inset)
            .padding(.top, size.height * 0.07)
            .padding(.bottom, size.height * 0.065)
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private func organicContours(
        size: CGSize,
        anchor: CGPoint,
        widthRatio: CGFloat,
        heightRatio: CGFloat
    ) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Ellipse()
                    .stroke(
                        contourColor.opacity(0.30 - Double(index) * 0.05),
                        lineWidth: css(index == 0 ? 2.2 : 1.4, in: size)
                    )
                    .frame(
                        width: size.width * max(0.18, widthRatio - CGFloat(index) * 0.11),
                        height: size.height * max(0.22, heightRatio - CGFloat(index) * 0.13)
                    )
            }
        }
        .position(x: size.width * anchor.x, y: size.height * anchor.y)
        .accessibilityHidden(true)
    }

    private func editorialStatus(foreground: Color, size: CGFloat) -> some View {
        Text(snapshot.isCheckedToday
            ? "widget.state.checked.editorial"
            : "widget.state.pending.short")
            .font(.system(size: size, weight: .medium, design: .default))
            .foregroundStyle(foreground)
            .lineLimit(1)
    }

    @ViewBuilder
    private func homeImprintControl(
        diameter: CGFloat,
        hasHalo: Bool,
        coreScale: CGFloat,
        ringInsetRatio: CGFloat,
        pendingLabelScale: CGFloat,
        glyphScale: CGFloat,
        ringRotationDegrees: Double = 0,
        coreRotationDegrees: Double = 0
    ) -> some View {
        if snapshot.isCheckedToday {
            homeImprintMark(
                diameter: diameter,
                hasHalo: hasHalo,
                coreScale: coreScale,
                ringInsetRatio: ringInsetRatio,
                pendingLabelScale: pendingLabelScale,
                glyphScale: glyphScale,
                ringRotationDegrees: ringRotationDegrees,
                coreRotationDegrees: coreRotationDegrees
            )
                .accessibilityLabel("widget.accessibility.checked")
        } else {
            Button(intent: PulseCheckInIntent()) {
                homeImprintMark(
                    diameter: diameter,
                    hasHalo: hasHalo,
                    coreScale: coreScale,
                    ringInsetRatio: ringInsetRatio,
                    pendingLabelScale: pendingLabelScale,
                    glyphScale: glyphScale,
                    ringRotationDegrees: ringRotationDegrees,
                    coreRotationDegrees: coreRotationDegrees
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("widget.action.check_in")
            .accessibilityHint("widget.action.check_in.hint")
        }
    }

    private func homeImprintMark(
        diameter: CGFloat,
        hasHalo: Bool,
        coreScale: CGFloat,
        ringInsetRatio: CGFloat,
        pendingLabelScale: CGFloat,
        glyphScale: CGFloat,
        ringRotationDegrees: Double,
        coreRotationDegrees: Double
    ) -> some View {
        ZStack {
            if hasHalo {
                Circle()
                    .fill(usesFullColorPalette
                        ? PulseWidgetDesign.surface
                        : Color.primary.opacity(0.12))
            }
            PulseWidgetImprintMark(
                isChecked: snapshot.isCheckedToday,
                usesSystemPalette: false,
                isOnCompletedSurface: false,
                coreScale: coreScale,
                ringInsetRatio: ringInsetRatio,
                showsPendingCore: true,
                pendingLabelScale: pendingLabelScale,
                glyphScale: glyphScale,
                centerLabel: nil,
                centerLabelScale: 0,
                ringRotationDegrees: ringRotationDegrees,
                coreRotationDegrees: coreRotationDegrees
            )
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
    }

    @ViewBuilder
    private func designedHomeImprintControl(
        diameter: CGFloat,
        hasHalo: Bool,
        coreScale: CGFloat,
        ringInsetRatio: CGFloat,
        pendingLabelScale: CGFloat,
        glyphScale: CGFloat
    ) -> some View {
        if snapshot.isCheckedToday {
            designedHomeImprintMark(
                diameter: diameter,
                hasHalo: hasHalo,
                coreScale: coreScale,
                ringInsetRatio: ringInsetRatio,
                pendingLabelScale: pendingLabelScale,
                glyphScale: glyphScale
            )
            .accessibilityLabel("widget.accessibility.checked")
        } else {
            Button(intent: PulseCheckInIntent()) {
                designedHomeImprintMark(
                    diameter: diameter,
                    hasHalo: hasHalo,
                    coreScale: coreScale,
                    ringInsetRatio: ringInsetRatio,
                    pendingLabelScale: pendingLabelScale,
                    glyphScale: glyphScale
                )
                .invalidatableContent()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("widget.action.check_in")
            .accessibilityHint("widget.action.check_in.hint")
        }
    }

    private func designedHomeImprintMark(
        diameter: CGFloat,
        hasHalo: Bool,
        coreScale: CGFloat,
        ringInsetRatio: CGFloat,
        pendingLabelScale: CGFloat,
        glyphScale: CGFloat
    ) -> some View {
        homeImprintMark(
            diameter: diameter,
            hasHalo: hasHalo,
            coreScale: coreScale,
            ringInsetRatio: ringInsetRatio,
            pendingLabelScale: pendingLabelScale,
            glyphScale: glyphScale,
            ringRotationDegrees: 0,
            coreRotationDegrees: 0
        )
        .id(snapshot.isCheckedToday)
        .transition(
            reduceMotion
                ? .opacity
                : .scale(scale: 0.88).combined(with: .opacity)
        )
    }

    private func homeWeekRail(
        _ days: [PulseWidgetDaySnapshot],
        gapCSS: CGFloat,
        size: CGSize
    ) -> some View {
        HStack(spacing: css(gapCSS, in: size)) {
            ForEach(days) { item in
                homeWeekRailMark(item, size: size)
            }
        }
        .frame(height: css(15, in: size))
        .fixedSize()
    }

    private func signalPosterDate(
        size: CGSize,
        numberSizeCSS: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            Text(snapshot.today.day, format: .number)
                .font(.system(
                    size: css(numberSizeCSS, in: size),
                    weight: .semibold,
                    design: .rounded
                ))
                .foregroundStyle(primaryForeground)
                .monospacedDigit()
                .lineLimit(1)
            Text(verbatim: localizedMonthName)
                .font(.system(size: css(12, in: size), weight: .medium))
                .foregroundStyle(secondaryForeground)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: localizedAccessibilityDate))
    }

    private func homeWeekDateDots(
        _ days: [PulseWidgetDaySnapshot],
        size: CGSize
    ) -> some View {
        HStack(spacing: css(usesMediumMetrics ? 8 : 2, in: size)) {
            ForEach(days) { item in
                homeWeekDateDotControl(item, size: size)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func homeWeekDateDotControl(
        _ item: PulseWidgetDaySnapshot,
        size: CGSize
    ) -> some View {
        if item.state == .todayPending {
            Button(intent: PulseCheckInIntent()) {
                homeWeekDateDot(item, size: size)
                    .invalidatableContent()
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("widget.action.check_in")
            .accessibilityHint("widget.action.check_in.hint")
        } else {
            homeWeekDateDot(item, size: size)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(dayAccessibilityLabel(item))
        }
    }

    private func homeWeekDateDot(
        _ item: PulseWidgetDaySnapshot,
        size: CGSize
    ) -> some View {
        let slotSide = css(usesMediumMetrics ? 40 : 28, in: size)
        let isEmphasized = item.state == .checked || item.state == .todayPending
        let visualSide = isEmphasized ? slotSide : slotSide * 0.64

        return VStack(spacing: css(4, in: size)) {
            Text(verbatim: PulseLocalizedDateFormatting.dayNumber(
                item.day,
                locale: locale
            ))
            .font(.system(
                size: css(usesMediumMetrics ? 14 : 11, in: size),
                weight: .medium,
                design: .rounded
            ))
            .foregroundStyle(secondaryForeground)
            .monospacedDigit()
            .lineLimit(1)

            ZStack {
                Circle()
                    .fill(homeRailMarkFill(item.state))
                    .overlay {
                        if let stroke = homeRailMarkStroke(item.state) {
                            Circle()
                                .stroke(stroke, lineWidth: css(1.4, in: size))
                        }
                    }

                if item.state == .checked {
                    Image(systemName: "checkmark")
                        .font(.system(
                            size: css(usesMediumMetrics ? 12 : 9, in: size),
                            weight: .bold
                        ))
                        .foregroundStyle(checkedDotForeground)
                }
            }
            .frame(width: visualSide, height: visualSide)
            .frame(width: slotSide, height: slotSide)
            .widgetAccentable(isEmphasized)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func homeWeekRailMark(
        _ item: PulseWidgetDaySnapshot,
        size: CGSize
    ) -> some View {
        let side = item.state == .checked || item.state == .todayPending
            ? css(14, in: size)
            : css(9, in: size)
        let fill = homeRailMarkFill(item.state)
        let stroke = homeRailMarkStroke(item.state)

        Circle()
            .fill(fill)
            .overlay {
                if let stroke {
                    Circle()
                        .stroke(stroke, lineWidth: css(1.4, in: size))
                }
            }
        .frame(width: side, height: side)
        .widgetAccentable(item.state == .checked || item.state == .todayPending)
        .accessibilityLabel(dayAccessibilityLabel(item))
    }

    private func homeRailMarkFill(_ state: PulseWidgetDayState) -> Color {
        guard usesFullColorPalette else {
            return switch state {
            case .checked: .primary
            case .missed: .primary.opacity(PulseWidgetDesign.homeMissedOpacity)
            case .beforeHabit, .todayPending: .clear
            }
        }

        return switch state {
        case .checked:
            PulseWidgetDesign.grass
        case .missed:
            PulseWidgetDesign.secondary.opacity(0.34)
        case .beforeHabit, .todayPending:
            .clear
        }
    }

    private func homeRailMarkStroke(_ state: PulseWidgetDayState) -> Color? {
        guard usesFullColorPalette else {
            return switch state {
            case .beforeHabit: Color.primary.opacity(PulseWidgetDesign.homeBeforeHabitOpacity)
            case .todayPending: Color.primary
            case .checked, .missed: nil
            }
        }

        return switch state {
        case .beforeHabit:
            PulseWidgetDesign.secondary.opacity(0.50)
        case .todayPending:
            PulseWidgetDesign.action
        case .checked, .missed:
            nil
        }
    }

    private func dayAccessibilityLabel(_ item: PulseWidgetDaySnapshot) -> Text {
        let stateKey = switch item.state {
        case .beforeHabit: "widget.day.before_habit"
        case .checked: "widget.day.checked"
        case .missed: "widget.day.missed"
        case .todayPending: "widget.day.today_pending"
        }
        let date = PulseLocalizedDateFormatting.accessibilityDate(
            item.day,
            locale: locale
        )
        let state = String(
            localized: String.LocalizationValue(stateKey),
            locale: locale
        )
        return Text(verbatim: "\(date), \(state)")
    }

    private var usesFullColorPalette: Bool {
        renderingMode == .fullColor
    }

    private var baseBackground: Color {
        usesFullColorPalette ? PulseWidgetDesign.background : .clear
    }

    private var primaryForeground: Color {
        usesFullColorPalette ? PulseWidgetDesign.ink : .primary
    }

    private var secondaryForeground: Color {
        usesFullColorPalette ? PulseWidgetDesign.secondary : .secondary
    }

    private var actionForeground: Color {
        usesFullColorPalette ? PulseWidgetDesign.action : .primary
    }

    private var contourColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.grass : .primary
    }

    private var dewFill: Color {
        usesFullColorPalette ? PulseWidgetDesign.grass : .primary
    }

    private var diagonalFieldColor: Color {
        usesFullColorPalette
            ? PulseWidgetDesign.field.opacity(0.19)
            : Color.primary.opacity(0.10)
    }

    private var diagonalHighlightColor: Color {
        usesFullColorPalette
            ? PulseWidgetDesign.grass.opacity(0.055)
            : Color.primary.opacity(0.035)
    }

    private func tidalFieldColor(opacity: Double) -> Color {
        usesFullColorPalette
            ? PulseWidgetDesign.field.opacity(opacity)
            : Color.primary.opacity(opacity * 0.72)
    }

    private var tidalAccentColor: Color {
        usesFullColorPalette
            ? PulseWidgetDesign.grass.opacity(0.10)
            : Color.primary.opacity(0.07)
    }

    private var cornerLeadingColor: Color {
        usesFullColorPalette
            ? PulseWidgetDesign.field.opacity(0.18)
            : Color.primary.opacity(0.09)
    }

    private var cornerTrailingColor: Color {
        usesFullColorPalette
            ? PulseWidgetDesign.grass.opacity(0.10)
            : Color.primary.opacity(0.06)
    }

    private var signalPosterFieldColor: Color {
        usesFullColorPalette
            ? PulseWidgetDesign.field.opacity(0.16)
            : Color.primary.opacity(0.08)
    }

    private var checkedDotForeground: Color {
        usesFullColorPalette ? PulseWidgetDesign.grassForeground : .white
    }

    private var orderShelfColor: Color {
        usesFullColorPalette
            ? PulseWidgetDesign.field.opacity(0.10)
            : Color.primary.opacity(0.07)
    }

    private var editorialDate: String {
        PulseLocalizedDateFormatting.monthAndDay(snapshot.today, locale: locale)
    }

    private var localizedMonthName: String {
        PulseLocalizedDateFormatting.monthName(snapshot.today, locale: locale)
    }

    private var localizedAccessibilityDate: String {
        PulseLocalizedDateFormatting.accessibilityDate(
            snapshot.today,
            locale: locale
        )
    }

    private var recentSummary: String {
        let format = String(
            localized: "widget.rhythm.summary.format",
            locale: locale
        )
        return String(
            format: format,
            locale: locale,
            Int64(snapshot.recentCheckedCount)
        )
    }

    private func css(_ value: CGFloat, in size: CGSize) -> CGFloat {
        let prototypeHeight: CGFloat = usesMediumMetrics ? (680 / 2.05) : 340
        return value * size.height / prototypeHeight
    }
}

private struct PulseWidgetDiagonalField: Shape {
    var boundaryOffset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(
            x: rect.width * (0.46 + boundaryOffset),
            y: rect.minY
        ))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(
            x: rect.width * (0.24 + boundaryOffset),
            y: rect.maxY
        ))
        path.closeSubpath()
        return path
    }
}

private struct PulseWidgetTidalField: Shape {
    let level: CGFloat
    let lift: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let startY = rect.height * level
        path.move(to: CGPoint(x: rect.minX, y: startY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * (level + lift)),
            control1: CGPoint(x: rect.width * 0.28, y: rect.height * (level - 0.10)),
            control2: CGPoint(x: rect.width * 0.70, y: rect.height * (level + 0.10))
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct PulseWidgetImprintMark: View {
    let isChecked: Bool
    let usesSystemPalette: Bool
    let isOnCompletedSurface: Bool
    let coreScale: CGFloat
    let ringInsetRatio: CGFloat
    let showsPendingCore: Bool
    let pendingLabelScale: CGFloat
    let glyphScale: CGFloat
    let centerLabel: String?
    let centerLabelScale: CGFloat
    let ringRotationDegrees: Double
    let coreRotationDegrees: Double
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                PulsePrototypeRing(color: isChecked ? completedColor : pendingColor)
                    .padding(side * ringInsetRatio)
                    .rotationEffect(.degrees(ringRotationDegrees))

                if isChecked {
                    ZStack {
                        Circle()
                            .fill(completedColor)
                        if let centerLabel {
                            Text(verbatim: centerLabel)
                                .font(.system(
                                    size: side * centerLabelScale,
                                    weight: .bold
                                ))
                                .monospacedDigit()
                                .foregroundStyle(
                                    usesCutoutGlyph
                                        ? Color.black
                                        : completedCoreForeground
                                )
                                .blendMode(
                                    usesCutoutGlyph ? .destinationOut : .normal
                                )
                                .minimumScaleFactor(0.72)
                                .lineLimit(1)
                        } else if usesCutoutGlyph {
                            Image(systemName: "checkmark")
                                .font(.system(
                                    size: side * glyphScale,
                                    weight: .medium
                                ))
                                .foregroundStyle(.black)
                                .blendMode(.destinationOut)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(
                                    size: side * glyphScale,
                                    weight: .medium
                                ))
                                .foregroundStyle(completedCoreForeground)
                        }
                    }
                    .compositingGroup()
                    .frame(
                        width: side * coreScale,
                        height: side * coreScale
                    )
                    .rotationEffect(.degrees(coreRotationDegrees))
                } else if let centerLabel {
                    Text(verbatim: centerLabel)
                        .font(.system(
                            size: side * centerLabelScale,
                            weight: .bold
                        ))
                        .monospacedDigit()
                        .foregroundStyle(pendingColor)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                        .frame(
                            width: side * coreScale,
                            height: side * coreScale
                        )
                } else if showsPendingCore {
                    ZStack {
                        Circle()
                            .fill(pendingColor)
                        Text("widget.action.check_in.short")
                            .font(.system(
                                size: side * pendingLabelScale,
                                weight: .medium,
                                design: .default
                            ))
                            .foregroundStyle(pendingCoreForeground)
                            .minimumScaleFactor(0.58)
                            .lineLimit(1)
                    }
                    .frame(
                        width: side * coreScale,
                        height: side * coreScale
                    )
                    .rotationEffect(.degrees(coreRotationDegrees))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .widgetAccentable()
        .accessibilityHidden(true)
    }

    private var completedColor: Color {
        guard renderingMode == .fullColor, !usesSystemPalette else { return .primary }
        return isOnCompletedSurface
            ? PulseWidgetDesign.grassForeground
            : PulseWidgetDesign.grass
    }

    private var pendingColor: Color {
        renderingMode == .fullColor && !usesSystemPalette
            ? PulseWidgetDesign.action
            : .primary
    }

    private var completedCoreForeground: Color {
        PulseWidgetDesign.grassForeground
    }

    private var pendingCoreForeground: Color {
        renderingMode == .fullColor && !usesSystemPalette
            ? PulseWidgetDesign.actionForeground
            : .white
    }

    private var usesCutoutGlyph: Bool {
        usesSystemPalette || renderingMode != .fullColor
    }
}

private struct PulsePrototypeRing: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            Circle()
                .trim(from: 0, to: 312 / 360)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: side * 0.09,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .rotationEffect(.degrees(-114))
                .padding(side * PulseWidgetDesign.prototypeRingInsetRatio)
                .frame(width: side, height: side)
        }
        .accessibilityHidden(true)
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

private enum PulseWidgetDesign {
    static let background = Color("PulseBackground")
    static let surface = Color("PulseSurface")
    static let grass = Color("PulseGrass")
    static let grassForeground = Color("PulseGrassForeground")
    static let action = Color("PulseAction")
    static let actionForeground = Color("PulseActionForeground")
    static let ink = Color("PulseInk")
    static let secondary = Color("PulseSecondary")
    static let field = Color("PulseField")

    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let homeSafeInset: CGFloat = 12

    static let imprintRingInsetRatio: CGFloat = 0.08
    static let prototypeRingInsetRatio: CGFloat = 0.07
    static let imprintCoreScale: CGFloat = 0.46
    static let imprintGlyphScale: CGFloat = 0.18
    static let homeContentInsets = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)

    static let accessoryRailLargeSide: CGFloat = 8
    static let accessoryRailSmallSide: CGFloat = 5
    static let accessoryBlockCornerRadius: CGFloat = 1.5
    static let accessoryRailStrokeWidth: CGFloat = 1.5
    static let accessoryConnectorWidth: CGFloat = 1
    static let accessoryConnectorOpacity = 0.28
    static let accessoryDateFontSize: CGFloat = 8
    static let accessoryDateLabelWidth: CGFloat = 14
    static let accessoryDateLabelHeight: CGFloat = 10
    static let accessoryDateRailGap: CGFloat = 2
    static let accessoryDateOpacity = 0.62
    static let accessoryTodayDateScale: CGFloat = 0.24
    static let accessoryImprintHeightRatio: CGFloat = 0.82
    static let accessoryImprintWidthRatio: CGFloat = 0.26
    static let accessoryRailYRatio: CGFloat = 0.73
    static let accessoryRailTerminalGap: CGFloat = 14
    static let homeMissedOpacity = 0.38
    static let homeBeforeHabitOpacity = 0.58
    static let stateTransitionDuration = 0.48
    static let accessoryMissedOpacity = 0.42
    static let accessoryBeforeHabitOpacity = 0.56
}

private extension PulseWidgetSnapshot {
    static var placeholder: PulseWidgetSnapshot {
        let today = LogicalDay(year: 2026, month: 8, day: 11)
        let days = (-6...0).map { offset in
            PulseWidgetDaySnapshot(
                day: today.addingDays(offset, timeZone: .gmt),
                state: offset == 0 ? .todayPending : (offset.isMultiple(of: 2) ? .checked : .missed)
            )
        }
        return PulseWidgetSnapshot(
            habitID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            habitName: String(localized: "widget.placeholder.commitment"),
            today: today,
            checkedAt: nil,
            recentDays: days,
            generatedAt: Date(timeIntervalSince1970: 1_754_860_800),
            nextDayBoundary: Date(timeIntervalSince1970: 1_754_947_200)
        )
    }
}
