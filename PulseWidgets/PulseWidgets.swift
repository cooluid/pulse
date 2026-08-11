import AppIntents
import PulseCore
import SwiftUI
import WidgetKit

@main
struct PulseWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PulseDailyImprintWidget()
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
}

@MainActor
private struct PulseWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseWidgetEntry {
        PulseWidgetEntry(
            date: .now,
            state: .ready(.placeholder, PulseWidgetStylePreferences.defaultStyle)
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
        completion(PulseWidgetRuntime.loadEntry(at: .now).entry)
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<PulseWidgetEntry>) -> Void
    ) {
        let result = PulseWidgetRuntime.loadEntry(at: .now)
        completion(
            Timeline(
                entries: [result.entry],
                policy: .after(result.refreshAfter)
            )
        )
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
        case sharedStoreNotReady
        case missingPrimaryHabit
    }

    static func loadEntry(at date: Date) -> LoadResult {
        do {
            let context = try makeLocationContext()
            guard try context.migrator.currentPhase(target: context.location) == .ready else {
                throw RuntimeError.sharedStoreNotReady
            }
            let repository = try makeRepository(
                at: context.location,
                clock: FixedPulseClock(now: date)
            )
            let style = try context.stylePreferences.load()
            guard let plan = try PulseWidgetSnapshotReader.readTimelinePlan(
                repository: repository,
                at: date
            ) else {
                throw RuntimeError.missingPrimaryHabit
            }
            return LoadResult(
                entry: PulseWidgetEntry(date: date, state: .ready(plan.snapshot, style)),
                refreshAfter: plan.refreshAfter
            )
        } catch RuntimeError.sharedStoreNotReady {
            return LoadResult(
                entry: PulseWidgetEntry(date: date, state: .needsOpenApp),
                refreshAfter: date.addingTimeInterval(15 * 60)
            )
        } catch PulseWidgetProjectionError.identityNotConfirmed {
            return LoadResult(
                entry: PulseWidgetEntry(date: date, state: .needsOpenApp),
                refreshAfter: date.addingTimeInterval(15 * 60)
            )
        } catch {
            return LoadResult(
                entry: PulseWidgetEntry(date: date, state: .unavailable),
                refreshAfter: date.addingTimeInterval(15 * 60)
            )
        }
    }

    static func checkIn() throws {
        let clock = SystemPulseClock()
        let context = try makeLocationContext()
        guard try context.migrator.currentPhase(target: context.location) == .ready else {
            throw RuntimeError.sharedStoreNotReady
        }
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
            migrator: PulseSharedStoreMigrator(),
            stylePreferences: try PulseWidgetStylePreferences(
                appGroupIdentifier: identifier
            )
        )
    }

    private static func makeRepository(
        at location: PulseStoreLocation,
        clock: any PulseClock
    ) throws -> SwiftDataCheckInRepository {
        SwiftDataCheckInRepository(
            container: try PersistenceController.makeContainer(
                storeName: PulseStoreContract.storeName,
                storeURL: location.storeURL
            ),
            clock: clock,
            initialIdentity: try HabitIdentity(userName: "Pulse", userPurpose: nil)
        )
    }

    private struct RuntimeContext {
        let location: PulseStoreLocation
        let migrator: PulseSharedStoreMigrator
        let stylePreferences: PulseWidgetStylePreferences
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
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.widgetContentMargins) private var widgetContentMargins

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
            imprintControl(
                snapshot,
                diameter: PulseWidgetDesign.accessoryCircularImprintDiameter,
                usesAccessoryStyle: true
            )
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

    private func accessoryRectangular(_ snapshot: PulseWidgetSnapshot) -> some View {
        HStack(spacing: PulseWidgetDesign.spacing4) {
            Text(snapshot.today.day, format: .number)
                .font(.system(
                    size: PulseWidgetDesign.accessoryDayNumberSize,
                    weight: .light,
                    design: .default
                ))
                .monospacedDigit()
                .lineLimit(1)

            VStack(alignment: .leading, spacing: PulseWidgetDesign.spacing4) {
                Text(snapshot.isCheckedToday
                    ? "widget.state.checked.short"
                    : "widget.state.pending.short")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                accessoryWeekRail(snapshot.recentDays)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            imprintControl(
                snapshot,
                diameter: PulseWidgetDesign.accessoryRectangularImprintDiameter,
                usesAccessoryStyle: true
            )
        }
    }

    @ViewBuilder
    private func imprintControl(
        _ snapshot: PulseWidgetSnapshot,
        diameter: CGFloat,
        usesAccessoryStyle: Bool = false
    ) -> some View {
        if snapshot.isCheckedToday {
            PulseWidgetImprintMark(
                isChecked: true,
                usesAccessoryStyle: usesAccessoryStyle,
                isOnCompletedSurface: false,
                coreScale: PulseWidgetDesign.imprintCoreScale,
                ringInsetRatio: PulseWidgetDesign.imprintRingInsetRatio,
                showsPendingCore: false,
                pendingLabelScale: 0,
                glyphScale: PulseWidgetDesign.imprintGlyphScale,
                ringRotationDegrees: 0,
                coreRotationDegrees: 0
            )
            .frame(width: diameter, height: diameter)
            .accessibilityLabel("widget.accessibility.checked")
        } else {
            Button(intent: PulseCheckInIntent()) {
                PulseWidgetImprintMark(
                    isChecked: false,
                    usesAccessoryStyle: usesAccessoryStyle,
                    isOnCompletedSurface: false,
                    coreScale: PulseWidgetDesign.imprintCoreScale,
                    ringInsetRatio: PulseWidgetDesign.imprintRingInsetRatio,
                    showsPendingCore: false,
                    pendingLabelScale: 0,
                    glyphScale: PulseWidgetDesign.imprintGlyphScale,
                    ringRotationDegrees: 0,
                    coreRotationDegrees: 0
                )
            }
            .buttonStyle(.plain)
            .frame(width: diameter, height: diameter)
            .accessibilityLabel("widget.action.check_in")
            .accessibilityHint("widget.action.check_in.hint")
        }
    }

    private func accessoryWeekRail(_ days: [PulseWidgetDaySnapshot]) -> some View {
        HStack(spacing: PulseWidgetDesign.spacing4) {
            ForEach(days) { item in
                accessoryWeekRailMark(item)
            }
        }
        .frame(minHeight: PulseWidgetDesign.accessoryRailHeight)
    }

    private func accessoryWeekRailMark(_ item: PulseWidgetDaySnapshot) -> some View {
        let isPrimary = item.state == .checked || item.state == .todayPending
        let side = isPrimary
            ? PulseWidgetDesign.accessoryRailLargeSide
            : PulseWidgetDesign.accessoryRailSmallSide

        return RoundedRectangle(
            cornerRadius: PulseWidgetDesign.accessoryBlockCornerRadius,
            style: .continuous
        )
        .fill(accessoryRailMarkFill(item.state))
        .overlay {
            if let stroke = accessoryRailMarkStroke(item.state) {
                RoundedRectangle(
                    cornerRadius: PulseWidgetDesign.accessoryBlockCornerRadius,
                    style: .continuous
                )
                .stroke(stroke, lineWidth: PulseWidgetDesign.railStrokeWidth)
            }
        }
        .frame(width: side, height: side)
        .frame(
            width: PulseWidgetDesign.railMarkSlotWidth,
            height: PulseWidgetDesign.accessoryRailHeight,
            alignment: .center
        )
        .widgetAccentable(item.state == .checked || item.state == .todayPending)
        .accessibilityLabel(dayAccessibilityLabel(item))
    }

    private func accessoryRailMarkFill(_ state: PulseWidgetDayState) -> Color {
        switch state {
        case .checked:
            .primary
        case .missed:
            .primary.opacity(PulseWidgetDesign.accessoryMissedOpacity)
        case .beforeHabit, .todayPending:
            .clear
        }
    }

    private func accessoryRailMarkStroke(_ state: PulseWidgetDayState) -> Color? {
        switch state {
        case .beforeHabit:
            Color.primary.opacity(PulseWidgetDesign.accessoryBeforeHabitOpacity)
        case .todayPending:
            Color.primary
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
        return Text("\(item.day.storageValue), \(String(localized: String.LocalizationValue(stateKey)))")
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
    private enum RailShape {
        case circle
        case square
    }

    let snapshot: PulseWidgetSnapshot
    let style: PulseWidgetStyle
    let usesMediumMetrics: Bool
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.locale) private var locale

    var body: some View {
        GeometryReader { proxy in
            Group {
                switch style {
                case .faultField:
                    faultField(size: proxy.size)
                case .oversizedRing:
                    oversizedRing(size: proxy.size)
                case .commitmentManifesto:
                    commitmentManifesto(size: proxy.size)
                case .tearOffCalendar:
                    tearOffCalendar(size: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityElement(children: .contain)
    }

    private func faultField(size: CGSize) -> some View {
        let actionDiameter = size.width * (usesMediumMetrics ? 0.25 : 0.30)
        let actionLeft = size.width * (usesMediumMetrics ? 0.39 : 0.43)
        let actionTop = size.height * (usesMediumMetrics ? 0.25 : 0.40)
        let commitmentWidth = size.width * (usesMediumMetrics ? 0.33 : 0.30)

        return ZStack {
            baseBackground

            PulseFaultFieldShape(
                isChecked: snapshot.isCheckedToday,
                usesMediumMetrics: usesMediumMetrics
            )
                .fill(stateFieldColor)

            brandText(foreground: actionForeground, size: css(17, in: size))
                .padding(.leading, size.width * 0.08)
                .padding(.top, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            faultDate(size: size)
                .padding(.leading, size.width * (usesMediumMetrics ? 0.06 : 0.07))
                .padding(.top, size.height * (usesMediumMetrics ? 0.21 : 0.22))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(verbatim: snapshot.habitName)
                .font(.system(
                    size: css(usesMediumMetrics ? 38 : 25, in: size),
                    weight: .medium,
                    design: .default
                ))
                .foregroundStyle(stateFieldForeground)
                .multilineTextAlignment(usesMediumMetrics ? .leading : .trailing)
                .lineLimit(usesMediumMetrics ? 2 : 3)
                .minimumScaleFactor(0.64)
                .allowsTightening(true)
                .frame(
                    width: commitmentWidth,
                    alignment: usesMediumMetrics ? .leading : .trailing
                )
                .padding(.trailing, size.width * (usesMediumMetrics ? 0.06 : 0.07))
                .padding(.top, size.height * (usesMediumMetrics ? 0.19 : 0.16))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            homeWeekRail(
                snapshot.recentDays,
                shape: .circle,
                gapCSS: 7,
                usesFaultPalette: true,
                size: size
            )
            .padding(.leading, size.width * (usesMediumMetrics ? 0.06 : 0.08))
            .padding(.bottom, size.height * (usesMediumMetrics ? 0.09 : 0.08))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            editorialStatus(foreground: stateFieldForeground, size: css(14, in: size))
                .padding(.trailing, size.width * 0.07)
                .padding(.bottom, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            homeImprintControl(
                diameter: actionDiameter,
                hasHalo: true,
                coreScale: 0.38,
                ringInsetRatio: 0.10,
                pendingLabelScale: 0.13,
                glyphScale: 0.235,
                ringRotationDegrees: 180
            )
            .position(
                x: actionLeft + actionDiameter / 2,
                y: actionTop + actionDiameter / 2
            )
        }
    }

    private func oversizedRing(size: CGSize) -> some View {
        let ringDiameter = size.width * (usesMediumMetrics ? 0.50 : 0.66)
        let ringLeft = size.width * (usesMediumMetrics ? -0.03 : -0.08)
        let ringTop = size.height * (usesMediumMetrics ? -0.12 : 0.17)
        let commitmentWidth = size.width * (usesMediumMetrics ? 0.47 : 0.42)

        return ZStack {
            baseBackground

            homeImprintControl(
                diameter: ringDiameter,
                hasHalo: false,
                coreScale: 0.36,
                ringInsetRatio: 0,
                pendingLabelScale: 0.08,
                glyphScale: 0.134
            )
            .position(x: ringLeft + ringDiameter / 2, y: ringTop + ringDiameter / 2)

            brandText(foreground: actionForeground, size: css(19, in: size))
                .tracking(css(19 * 0.08, in: size))
                .padding(.leading, size.width * (usesMediumMetrics ? 0.05 : 0.08))
                .padding(.top, size.height * 0.07)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            giantDate(size: size)
                .padding(.trailing, size.width * (usesMediumMetrics ? 0.05 : 0.07))
                .padding(.top, size.height * (usesMediumMetrics ? 0.08 : 0.06))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Text(verbatim: snapshot.habitName)
                .font(.system(
                    size: css(usesMediumMetrics ? 38 : 28, in: size),
                    weight: .medium,
                    design: .default
                ))
                .foregroundStyle(primaryForeground)
                .multilineTextAlignment(usesMediumMetrics ? .leading : .trailing)
                .lineLimit(usesMediumMetrics ? 2 : 3)
                .minimumScaleFactor(0.68)
                .allowsTightening(true)
                .frame(
                    width: commitmentWidth,
                    alignment: usesMediumMetrics ? .leading : .trailing
                )
                .padding(.trailing, size.width * (usesMediumMetrics ? 0.05 : 0.07))
                .padding(.top, size.height * (usesMediumMetrics ? 0.33 : 0.38))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            homeWeekRail(
                snapshot.recentDays,
                shape: .square,
                gapCSS: 8,
                usesFaultPalette: false,
                size: size
            )
            .padding(.trailing, size.width * (usesMediumMetrics ? 0.05 : 0.07))
            .padding(.bottom, size.height * (usesMediumMetrics ? 0.11 : 0.10))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    private func commitmentManifesto(size: CGSize) -> some View {
        let actionDiameter = size.width * (usesMediumMetrics ? 0.25 : 0.24)
        let actionRight = size.width * (usesMediumMetrics ? 0.05 : 0.08)
        let actionBottom = size.height * (usesMediumMetrics ? 0.11 : 0.08)

        return ZStack {
            baseBackground

            editorialStatus(foreground: secondaryForeground, size: css(14, in: size))
                .tracking(css(14 * 0.14, in: size))
                .padding(.leading, size.width * 0.08)
                .padding(.top, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(verbatim: editorialDate)
                .font(.system(size: css(17, in: size), weight: .medium))
                .foregroundStyle(actionForeground)
                .monospacedDigit()
                .padding(.trailing, size.width * 0.08)
                .padding(.top, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Text(verbatim: snapshot.habitName)
                .font(.system(
                    size: css(usesMediumMetrics ? 56 : 43, in: size),
                    weight: .medium,
                    design: .default
                ))
                .foregroundStyle(primaryForeground)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.60)
                .allowsTightening(true)
                .lineSpacing(-css(2, in: size))
                .frame(
                    width: size.width * (usesMediumMetrics ? 0.67 : 0.76),
                    alignment: .leading
                )
                .padding(.leading, size.width * 0.08)
                .padding(.top, size.height * (usesMediumMetrics ? 0.25 : 0.22))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            homeWeekRail(
                snapshot.recentDays,
                shape: .square,
                gapCSS: 6,
                usesFaultPalette: false,
                size: size
            )
            .padding(.leading, size.width * 0.08)
            .padding(.bottom, size.height * (usesMediumMetrics ? 0.09 : 0.11))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            homeImprintControl(
                diameter: actionDiameter,
                hasHalo: false,
                coreScale: 0.39,
                ringInsetRatio: 0,
                pendingLabelScale: 0.16,
                glyphScale: 0.293
            )
            .position(
                x: size.width - actionRight - actionDiameter / 2,
                y: size.height - actionBottom - actionDiameter / 2
            )
        }
    }

    private func tearOffCalendar(size: CGSize) -> some View {
        let actionDiameter = size.width * (usesMediumMetrics ? 0.21 : 0.34)
        let actionRight = size.width * (usesMediumMetrics ? 0.04 : -0.04)
        let actionBottom = size.height * (usesMediumMetrics ? 0.03 : 0.10)

        return ZStack {
            baseBackground

            VStack(spacing: 0) {
                stateFieldColor
                    .frame(height: size.height * 0.18)
                Spacer(minLength: 0)
            }

            Text("widget.brand.daily_imprint")
                .font(.system(size: css(16, in: size), weight: .medium))
                .foregroundStyle(stateFieldForeground)
                .padding(.leading, size.width * 0.08)
                .padding(.top, size.height * 0.05)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(snapshot.today.day, format: .number)
                .font(.system(
                    size: css(usesMediumMetrics ? 176 : 148, in: size),
                    weight: .medium,
                    design: .default
                ))
                .foregroundStyle(primaryForeground)
                .monospacedDigit()
                .tracking(-css(usesMediumMetrics ? 15.8 : 13.3, in: size))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.leading, size.width * (usesMediumMetrics ? 0.05 : 0.04))
                .padding(.top, size.height * (usesMediumMetrics ? 0.14 : 0.15))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityLabel(Text(verbatim: "\(snapshot.today.day)"))

            calendarMonthLabel(size: size)

            calendarCommitment(size: size)

            homeWeekRail(
                snapshot.recentDays,
                shape: .circle,
                gapCSS: 10,
                usesFaultPalette: false,
                size: size
            )
            .padding(.leading, size.width * (usesMediumMetrics ? 0.46 : 0.08))
            .padding(.bottom, size.height * (usesMediumMetrics ? 0.10 : 0.07))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            homeImprintControl(
                diameter: actionDiameter,
                hasHalo: false,
                coreScale: 0.38,
                ringInsetRatio: 0,
                pendingLabelScale: 0.112,
                glyphScale: 0.207,
                coreRotationDegrees: 13
            )
            .rotationEffect(.degrees(-13))
            .position(
                x: size.width - actionRight - actionDiameter / 2,
                y: size.height - actionBottom - actionDiameter / 2
            )
        }
    }

    private func brandText(foreground: Color, size: CGFloat) -> some View {
        Text("widget.brand.imprint")
            .font(.system(size: size, weight: .medium, design: .default))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func giantDate(size: CGSize) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(snapshot.today.day, format: .number)
                .font(.system(
                    size: css(usesMediumMetrics ? 62 : 54, in: size),
                    weight: .medium,
                    design: .default
                ))
            Text(verbatim: "/")
            Text(snapshot.today.month, format: .number)
        }
        .font(.system(size: css(20, in: size), weight: .medium))
        .foregroundStyle(primaryForeground)
        .monospacedDigit()
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(snapshot.today.day)/\(snapshot.today.month)"))
    }

    private func faultDate(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: css(5, in: size)) {
            Text(snapshot.today.day, format: .number)
                .font(.system(
                    size: css(usesMediumMetrics ? 112 : 92, in: size),
                    weight: .medium,
                    design: .default
                ))
                .tracking(-css(usesMediumMetrics ? 9 : 7.4, in: size))
                .monospacedDigit()
            Text(verbatim: localizedMonthName)
                .font(.system(size: css(17, in: size), weight: .medium))
                .foregroundStyle(secondaryForeground)
                .tracking(css(17 * 0.08, in: size))
        }
        .foregroundStyle(primaryForeground)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(snapshot.today.day)/\(snapshot.today.month)"))
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
    private func calendarMonthLabel(size: CGSize) -> some View {
        let fontSize = css(22, in: size)
        let label = Group {
            if usesVerticalMonthText {
                Text(verbatim: localizedMonthName.map(String.init).joined(separator: "\n"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(-css(3, in: size))
            } else {
                Text(verbatim: localizedMonthName)
                    .rotationEffect(.degrees(90))
                    .fixedSize()
            }
        }
        .font(.system(size: fontSize, weight: .medium))
        .foregroundStyle(actionForeground)
        .tracking(css(22 * 0.12, in: size))
        .accessibilityLabel(Text(verbatim: localizedMonthName))

        if usesMediumMetrics {
            label
                .padding(.leading, size.width * 0.32)
                .padding(.top, size.height * 0.27)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            label
                .padding(.trailing, size.width * 0.07)
                .padding(.top, size.height * 0.26)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }

    @ViewBuilder
    private func calendarCommitment(size: CGSize) -> some View {
        let label = Text(verbatim: snapshot.habitName)
            .font(.system(
                size: css(usesMediumMetrics ? 38 : 21, in: size),
                weight: .medium,
                design: .default
            ))
            .foregroundStyle(primaryForeground)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .minimumScaleFactor(0.68)
            .allowsTightening(true)

        if usesMediumMetrics {
            label
                .frame(width: size.width * 0.46, alignment: .leading)
                .padding(.leading, size.width * 0.46)
                .padding(.top, size.height * 0.29)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            label
                .frame(width: size.width * 0.64, alignment: .leading)
                .padding(.leading, size.width * 0.08)
                .padding(.bottom, size.height * 0.18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
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
                usesAccessoryStyle: false,
                isOnCompletedSurface: false,
                coreScale: coreScale,
                ringInsetRatio: ringInsetRatio,
                showsPendingCore: true,
                pendingLabelScale: pendingLabelScale,
                glyphScale: glyphScale,
                ringRotationDegrees: ringRotationDegrees,
                coreRotationDegrees: coreRotationDegrees
            )
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
    }

    private func homeWeekRail(
        _ days: [PulseWidgetDaySnapshot],
        shape: RailShape,
        gapCSS: CGFloat,
        usesFaultPalette: Bool,
        size: CGSize
    ) -> some View {
        let connectorWidth = css(gapCSS + 2, in: size)
        let connectorOverlap = css(1, in: size)

        return HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, item in
                homeWeekRailMark(
                    item,
                    shape: shape,
                    usesFaultPalette: usesFaultPalette,
                    size: size
                )
                .zIndex(1)

                if index < days.count - 1 {
                    Rectangle()
                        .fill(homeWeekRailConnector(usesFaultPalette: usesFaultPalette))
                        .frame(
                            width: connectorWidth,
                            height: css(2, in: size)
                        )
                        .padding(.horizontal, -connectorOverlap)
                        .zIndex(0)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(height: css(15, in: size))
        .fixedSize()
    }

    private func homeWeekRailConnector(usesFaultPalette: Bool) -> Color {
        guard usesFullColorPalette else {
            return Color.primary.opacity(0.28)
        }
        return usesFaultPalette
            ? PulseWidgetDesign.ink.opacity(0.28)
            : PulseWidgetDesign.secondary.opacity(0.32)
    }

    @ViewBuilder
    private func homeWeekRailMark(
        _ item: PulseWidgetDaySnapshot,
        shape: RailShape,
        usesFaultPalette: Bool,
        size: CGSize
    ) -> some View {
        let side = item.state == .checked || item.state == .todayPending
            ? css(15, in: size)
            : css(11, in: size)
        let fill = homeRailMarkFill(item.state, usesFaultPalette: usesFaultPalette)
        let stroke = homeRailMarkStroke(item.state, usesFaultPalette: usesFaultPalette)
        let cornerRadius = shape == .circle ? side / 2 : css(3, in: size)

        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay {
                if let stroke {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(stroke, lineWidth: css(2, in: size))
                }
            }
        .frame(width: side, height: side)
        .widgetAccentable(item.state == .checked || item.state == .todayPending)
        .accessibilityLabel(dayAccessibilityLabel(item))
    }

    private func homeRailMarkFill(
        _ state: PulseWidgetDayState,
        usesFaultPalette: Bool
    ) -> Color {
        guard usesFullColorPalette else {
            return switch state {
            case .checked: .primary
            case .missed: .primary.opacity(PulseWidgetDesign.homeMissedOpacity)
            case .beforeHabit, .todayPending: .clear
            }
        }

        let primary = usesFaultPalette ? PulseWidgetDesign.ink : PulseWidgetDesign.grass
        let missed = usesFaultPalette ? PulseWidgetDesign.ink : PulseWidgetDesign.secondary
        return switch state {
        case .checked:
            primary
        case .missed:
            missed.opacity(usesFaultPalette ? 0.34 : 0.44)
        case .beforeHabit, .todayPending:
            .clear
        }
    }

    private func homeRailMarkStroke(
        _ state: PulseWidgetDayState,
        usesFaultPalette: Bool
    ) -> Color? {
        guard usesFullColorPalette else {
            return switch state {
            case .beforeHabit: Color.primary.opacity(PulseWidgetDesign.homeBeforeHabitOpacity)
            case .todayPending: Color.primary
            case .checked, .missed: nil
            }
        }

        let foreground = usesFaultPalette ? PulseWidgetDesign.ink : PulseWidgetDesign.secondary
        return switch state {
        case .beforeHabit:
            foreground.opacity(usesFaultPalette ? 0.62 : 0.55)
        case .todayPending:
            usesFaultPalette ? PulseWidgetDesign.ink : PulseWidgetDesign.action
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
        return Text("\(item.day.storageValue), \(String(localized: String.LocalizationValue(stateKey)))")
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

    private var stateFieldColor: Color {
        if usesFullColorPalette {
            return snapshot.isCheckedToday
                ? PulseWidgetDesign.grass
                : PulseWidgetDesign.action
        }
        return .primary.opacity(snapshot.isCheckedToday ? 0.28 : 0.18)
    }

    private var stateFieldForeground: Color {
        if usesFullColorPalette {
            return snapshot.isCheckedToday
                ? PulseWidgetDesign.grassForeground
                : PulseWidgetDesign.actionForeground
        }
        return .primary
    }

    private var editorialDate: String {
        String(format: "%02d / %02d", snapshot.today.month, snapshot.today.day)
    }

    private var localizedMonthName: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = .gmt
        components.year = snapshot.today.year
        components.month = snapshot.today.month
        components.day = 1
        guard let date = components.date else { return "\(snapshot.today.month)" }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: date)
    }

    private var usesVerticalMonthText: Bool {
        let identifier = locale.identifier.lowercased()
        return identifier.hasPrefix("zh")
            || identifier.hasPrefix("ja")
            || identifier.hasPrefix("ko")
    }

    private func css(_ value: CGFloat, in size: CGSize) -> CGFloat {
        let prototypeHeight: CGFloat = usesMediumMetrics ? (680 / 2.05) : 340
        return value * size.height / prototypeHeight
    }
}

private struct PulseFaultFieldShape: Shape {
    let isChecked: Bool
    let usesMediumMetrics: Bool

    func path(in rect: CGRect) -> Path {
        let topRatio: CGFloat
        let bottomRatio: CGFloat
        if usesMediumMetrics {
            topRatio = isChecked ? 0.38 : 0.58
            bottomRatio = isChecked ? 0.28 : 0.44
        } else {
            topRatio = isChecked ? 0.41 : 0.65
            bottomRatio = isChecked ? 0.19 : 0.38
        }

        var path = Path()
        path.move(to: CGPoint(x: rect.width * topRatio, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width * bottomRatio, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct PulseWidgetImprintMark: View {
    let isChecked: Bool
    let usesAccessoryStyle: Bool
    let isOnCompletedSurface: Bool
    let coreScale: CGFloat
    let ringInsetRatio: CGFloat
    let showsPendingCore: Bool
    let pendingLabelScale: CGFloat
    let glyphScale: CGFloat
    let ringRotationDegrees: Double
    let coreRotationDegrees: Double
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                if usesAccessoryStyle {
                    Image("PulseWidgetMark")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(isChecked ? completedColor : pendingColor)
                        .padding(side * ringInsetRatio)
                } else {
                    PulsePrototypeRing(color: isChecked ? completedColor : pendingColor)
                        .padding(side * ringInsetRatio)
                        .rotationEffect(.degrees(ringRotationDegrees))
                }

                if isChecked {
                    ZStack {
                        Circle()
                            .fill(completedColor)
                        Image(systemName: "checkmark")
                            .font(.system(
                                size: side * glyphScale,
                                weight: .medium
                            ))
                            .foregroundStyle(completedCoreForeground)
                    }
                    .frame(
                        width: side * coreScale,
                        height: side * coreScale
                    )
                    .rotationEffect(.degrees(coreRotationDegrees))
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
        guard renderingMode == .fullColor, !usesAccessoryStyle else { return .primary }
        return isOnCompletedSurface
            ? PulseWidgetDesign.grassForeground
            : PulseWidgetDesign.grass
    }

    private var pendingColor: Color {
        renderingMode == .fullColor && !usesAccessoryStyle
            ? PulseWidgetDesign.action
            : .primary
    }

    private var completedCoreForeground: Color {
        renderingMode == .fullColor && !usesAccessoryStyle
            ? PulseWidgetDesign.grassForeground
            : .white
    }

    private var pendingCoreForeground: Color {
        renderingMode == .fullColor && !usesAccessoryStyle
            ? PulseWidgetDesign.actionForeground
            : .white
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
                        lineWidth: side * 0.14,
                        lineCap: .butt,
                        lineJoin: .round
                    )
                )
                .rotationEffect(.degrees(-114))
                .padding(side * 0.07)
                .frame(width: side, height: side)
        }
        .accessibilityHidden(true)
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

    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let homeSafeInset: CGFloat = 12

    static let accessoryDayNumberSize: CGFloat = 28

    static let accessoryCircularImprintDiameter: CGFloat = 50
    static let accessoryRectangularImprintDiameter: CGFloat = 44
    static let imprintRingInsetRatio: CGFloat = 0.08
    static let imprintCoreScale: CGFloat = 0.46
    static let imprintGlyphScale: CGFloat = 0.18
    static let homeContentInsets = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)

    static let railMarkSlotWidth: CGFloat = 14
    static let accessoryRailHeight: CGFloat = 10
    static let accessoryRailLargeSide: CGFloat = 8
    static let accessoryRailSmallSide: CGFloat = 5
    static let accessoryBlockCornerRadius: CGFloat = 1.5
    static let railStrokeWidth: CGFloat = 1.5
    static let homeMissedOpacity = 0.38
    static let homeBeforeHabitOpacity = 0.58
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
