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
    case ready(PulseWidgetSnapshot)
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
        PulseWidgetEntry(date: .now, state: .ready(.placeholder))
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
            guard let plan = try PulseWidgetSnapshotReader.readTimelinePlan(
                repository: repository,
                at: date
            ) else {
                throw RuntimeError.missingPrimaryHabit
            }
            return LoadResult(
                entry: PulseWidgetEntry(date: date, state: .ready(plan.snapshot)),
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
            migrator: PulseSharedStoreMigrator()
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
            case .ready(let snapshot):
                readyView(snapshot)
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
        .padding(contentInsets)
        .containerBackground(for: .widget) {
            PulseWidgetDesign.background
        }
    }

    @ViewBuilder
    private func readyView(_ snapshot: PulseWidgetSnapshot) -> some View {
        switch family {
        case .accessoryCircular:
            imprintControl(
                snapshot,
                diameter: PulseWidgetDesign.accessoryCircularImprintDiameter,
                usesAccessoryStyle: true
            )
        case .accessoryRectangular:
            accessoryRectangular(snapshot)
        case .systemMedium:
            systemMedium(snapshot)
        default:
            systemSmall(snapshot)
        }
    }

    private func systemSmall(_ snapshot: PulseWidgetSnapshot) -> some View {
        VStack(spacing: 0) {
            homeHeader(snapshot, usesMediumMetrics: false)

            weekRail(snapshot.recentDays)
                .padding(.top, PulseWidgetDesign.homeBandSpacing)

            homeCommitmentTitle(snapshot, usesMediumMetrics: false)

            homeStatusBand(snapshot, usesCompactFont: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func systemMedium(_ snapshot: PulseWidgetSnapshot) -> some View {
        VStack(spacing: 0) {
            homeHeader(snapshot, usesMediumMetrics: true)

            weekRail(snapshot.recentDays)
                .padding(.top, PulseWidgetDesign.homeBandSpacing)

            homeCommitmentTitle(snapshot, usesMediumMetrics: true)

            homeStatusBand(snapshot, usesCompactFont: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func homeHeader(
        _ snapshot: PulseWidgetSnapshot,
        usesMediumMetrics: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: PulseWidgetDesign.brandSpacing) {
                Image("PulseWidgetMark")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(brandAccent)
                    .frame(
                        width: usesMediumMetrics
                            ? PulseWidgetDesign.mediumBrandMarkSide
                            : PulseWidgetDesign.smallBrandMarkSide,
                        height: usesMediumMetrics
                            ? PulseWidgetDesign.mediumBrandMarkSide
                            : PulseWidgetDesign.smallBrandMarkSide
                    )
                    .widgetAccentable()
                    .accessibilityHidden(true)

                Text("widget.brand.imprint")
                    .font(.system(
                        size: usesMediumMetrics
                            ? PulseWidgetDesign.mediumBrandTextSize
                            : PulseWidgetDesign.smallBrandTextSize,
                        weight: .bold,
                        design: .default
                    ))
                    .foregroundStyle(primaryForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(PulseWidgetDesign.brandMinimumScale)
                    .allowsTightening(true)
            }
            .layoutPriority(1)

            Spacer(minLength: usesMediumMetrics
                ? PulseWidgetDesign.spacing8
                : PulseWidgetDesign.spacing4)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(snapshot.today.day, format: .number)
                    .font(.system(
                        size: usesMediumMetrics
                            ? PulseWidgetDesign.mediumDayNumberSize
                            : PulseWidgetDesign.smallDayNumberSize,
                        weight: .bold,
                        design: .default
                    ))
                Text("/")
                    .font(.system(
                        size: usesMediumMetrics
                            ? PulseWidgetDesign.mediumMonthNumberSize
                            : PulseWidgetDesign.smallMonthNumberSize,
                        weight: .semibold,
                        design: .default
                    ))
                Text(snapshot.today.month, format: .number)
                    .font(.system(
                        size: usesMediumMetrics
                            ? PulseWidgetDesign.mediumMonthNumberSize
                            : PulseWidgetDesign.smallMonthNumberSize,
                        weight: .semibold,
                        design: .default
                    ))
            }
            .foregroundStyle(primaryForeground)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(PulseWidgetDesign.dateMinimumScale)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(snapshot.today.day)/\(snapshot.today.month)"))
        }
        .frame(
            height: usesMediumMetrics
                ? PulseWidgetDesign.mediumHomeHeaderHeight
                : PulseWidgetDesign.smallHomeHeaderHeight,
            alignment: .top
        )
    }

    private func homeCommitmentTitle(
        _ snapshot: PulseWidgetSnapshot,
        usesMediumMetrics: Bool
    ) -> some View {
        Text(verbatim: snapshot.habitName)
            .font(.system(
                size: usesMediumMetrics
                    ? PulseWidgetDesign.mediumCommitmentTextSize
                    : PulseWidgetDesign.smallCommitmentTextSize,
                weight: .bold,
                design: .default
            ))
            .foregroundStyle(primaryForeground)
            .multilineTextAlignment(.center)
            .lineLimit(PulseWidgetDesign.commitmentLineLimit)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .accessibilityLabel(Text(verbatim: snapshot.habitName))
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
                weekRail(snapshot.recentDays, usesAccessoryStyle: true)
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
    private func homeStatusBand(
        _ snapshot: PulseWidgetSnapshot,
        usesCompactFont: Bool
    ) -> some View {
        if snapshot.isCheckedToday {
            homeStatusBandContent(snapshot, usesCompactFont: usesCompactFont)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("widget.accessibility.checked")
        } else {
            Button(intent: PulseCheckInIntent()) {
                homeStatusBandContent(snapshot, usesCompactFont: usesCompactFont)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("widget.action.check_in")
            .accessibilityHint("widget.action.check_in.hint")
        }
    }

    private func homeStatusBandContent(
        _ snapshot: PulseWidgetSnapshot,
        usesCompactFont: Bool
    ) -> some View {
        HStack(spacing: PulseWidgetDesign.spacing4) {
            Text(homeStatusKey(snapshot))
                .font(.system(
                    size: usesCompactFont
                        ? PulseWidgetDesign.smallStatusTextSize
                        : PulseWidgetDesign.mediumStatusTextSize,
                    weight: .bold,
                    design: .default
                ))
                .foregroundStyle(statusForeground(isChecked: snapshot.isCheckedToday))
                .lineLimit(1)
                .minimumScaleFactor(PulseWidgetDesign.statusMinimumScale)

            Spacer(minLength: 0)

            Text(verbatim: snapshot.isCheckedToday ? "☺︎" : "☹︎")
                .font(.system(
                    size: usesCompactFont
                        ? PulseWidgetDesign.smallStatusFaceSize
                        : PulseWidgetDesign.mediumStatusFaceSize,
                    weight: .semibold,
                    design: .default
                ))
                .foregroundStyle(statusForeground(isChecked: snapshot.isCheckedToday))
                .frame(
                    width: PulseWidgetDesign.statusFaceFrameSide,
                    height: PulseWidgetDesign.statusFaceFrameSide
                )
                .accessibilityHidden(true)
        }
        .padding(.horizontal, PulseWidgetDesign.statusHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: PulseWidgetDesign.homeStatusHeight)
        .background {
            RoundedRectangle(
                cornerRadius: PulseWidgetDesign.statusCornerRadius,
                style: .continuous
            )
            .fill(statusBackground(isChecked: snapshot.isCheckedToday))
        }
        .contentShape(Rectangle())
        .widgetAccentable(snapshot.isCheckedToday)
    }

    private func homeStatusKey(_ snapshot: PulseWidgetSnapshot) -> LocalizedStringKey {
        snapshot.isCheckedToday
            ? "widget.state.checked.short"
            : "widget.state.pending.short"
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
                isOnCompletedSurface: false
            )
            .frame(width: diameter, height: diameter)
            .accessibilityLabel("widget.accessibility.checked")
        } else {
            Button(intent: PulseCheckInIntent()) {
                PulseWidgetImprintMark(
                    isChecked: false,
                    usesAccessoryStyle: usesAccessoryStyle,
                    isOnCompletedSurface: false
                )
            }
            .buttonStyle(.plain)
            .frame(width: diameter, height: diameter)
            .accessibilityLabel("widget.action.check_in")
            .accessibilityHint("widget.action.check_in.hint")
        }
    }

    private func weekRail(
        _ days: [PulseWidgetDaySnapshot],
        usesAccessoryStyle: Bool = false
    ) -> some View {
        HStack(spacing: usesAccessoryStyle ? PulseWidgetDesign.spacing4 : 0) {
            ForEach(days) { item in
                weekRailMark(item, usesAccessoryStyle: usesAccessoryStyle)
                    .frame(maxWidth: usesAccessoryStyle ? nil : .infinity)
            }
        }
        .frame(
            maxWidth: usesAccessoryStyle ? nil : .infinity,
            minHeight: usesAccessoryStyle
                ? PulseWidgetDesign.accessoryRailHeight
                : PulseWidgetDesign.homeRailHeight
        )
    }

    private func weekRailMark(
        _ item: PulseWidgetDaySnapshot,
        usesAccessoryStyle: Bool
    ) -> some View {
        let side = railMarkSide(
            item.state,
            usesAccessoryStyle: usesAccessoryStyle
        )
        let railHeight = usesAccessoryStyle
            ? PulseWidgetDesign.accessoryRailHeight
            : PulseWidgetDesign.homeRailHeight
        let cornerRadius = usesAccessoryStyle
            ? PulseWidgetDesign.accessoryBlockCornerRadius
            : PulseWidgetDesign.homeBlockCornerRadius

        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(railMarkFill(item.state, usesAccessoryStyle: usesAccessoryStyle))
            .overlay {
                if let stroke = railMarkStroke(
                    item.state,
                    usesAccessoryStyle: usesAccessoryStyle
                ) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(stroke, lineWidth: PulseWidgetDesign.railStrokeWidth)
                }
            }
            .frame(width: side, height: side)
            .frame(
                width: PulseWidgetDesign.railMarkSlotWidth,
                height: railHeight,
                alignment: .center
            )
            .widgetAccentable(item.state == .checked || item.state == .todayPending)
            .accessibilityLabel(dayAccessibilityLabel(item))
    }

    private func railMarkSide(
        _ state: PulseWidgetDayState,
        usesAccessoryStyle: Bool
    ) -> CGFloat {
        let isPrimary = state == .checked || state == .todayPending
        if usesAccessoryStyle {
            return isPrimary
                ? PulseWidgetDesign.accessoryRailLargeSide
                : PulseWidgetDesign.accessoryRailSmallSide
        }
        return isPrimary
            ? PulseWidgetDesign.homeRailLargeSide
            : PulseWidgetDesign.homeRailSmallSide
    }

    private func railMarkFill(
        _ state: PulseWidgetDayState,
        usesAccessoryStyle: Bool
    ) -> Color {
        if usesAccessoryStyle {
            return switch state {
            case .checked:
                .primary
            case .missed:
                .primary.opacity(PulseWidgetDesign.accessoryMissedOpacity)
            case .beforeHabit, .todayPending:
                .clear
            }
        }
        return switch state {
        case .checked:
            usesFullColorPalette ? PulseWidgetDesign.grass : .primary
        case .missed:
            usesFullColorPalette
                ? PulseWidgetDesign.secondary.opacity(PulseWidgetDesign.homeMissedOpacity)
                : Color.primary.opacity(PulseWidgetDesign.adaptiveMissedOpacity)
        case .beforeHabit, .todayPending:
            .clear
        }
    }

    private func railMarkStroke(
        _ state: PulseWidgetDayState,
        usesAccessoryStyle: Bool
    ) -> Color? {
        switch state {
        case .beforeHabit:
            usesAccessoryStyle
                ? Color.primary.opacity(PulseWidgetDesign.accessoryBeforeHabitOpacity)
                : (usesFullColorPalette
                    ? PulseWidgetDesign.secondary.opacity(PulseWidgetDesign.homeBeforeHabitOpacity)
                    : Color.primary.opacity(PulseWidgetDesign.adaptiveBeforeHabitOpacity))
        case .todayPending:
            usesAccessoryStyle || !usesFullColorPalette
                ? Color.primary
                : PulseWidgetDesign.action
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

    private var brandAccent: Color {
        usesFullColorPalette ? PulseWidgetDesign.action : .primary
    }

    private func statusBackground(isChecked: Bool) -> Color {
        if usesFullColorPalette {
            return isChecked ? PulseWidgetDesign.grass : PulseWidgetDesign.surface
        }
        return Color.primary.opacity(isChecked
            ? PulseWidgetDesign.adaptiveCompletedSurfaceOpacity
            : PulseWidgetDesign.adaptivePendingSurfaceOpacity)
    }

    private func statusForeground(isChecked: Bool) -> Color {
        if usesFullColorPalette {
            return isChecked ? PulseWidgetDesign.grassForeground : PulseWidgetDesign.ink
        }
        return .primary
    }
}

private struct PulseWidgetImprintMark: View {
    let isChecked: Bool
    let usesAccessoryStyle: Bool
    let isOnCompletedSurface: Bool
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                Image("PulseWidgetMark")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(isChecked ? completedColor : pendingColor)
                    .padding(side * PulseWidgetDesign.imprintRingInsetRatio)

                if isChecked {
                    ZStack {
                        Circle()
                            .fill(completedColor)
                        Image(systemName: "checkmark")
                            .font(.system(
                                size: side * PulseWidgetDesign.imprintGlyphScale,
                                weight: .bold
                            ))
                            .foregroundStyle(.black)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                    .frame(
                        width: side * PulseWidgetDesign.imprintCoreScale,
                        height: side * PulseWidgetDesign.imprintCoreScale
                    )
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
}

private enum PulseWidgetDesign {
    static let background = Color("PulseBackground")
    static let surface = Color("PulseSurface")
    static let grass = Color("PulseGrass")
    static let grassForeground = Color("PulseGrassForeground")
    static let action = Color("PulseAction")
    static let ink = Color("PulseInk")
    static let secondary = Color("PulseSecondary")
    static let separator = Color("PulseSeparator")

    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8

    static let smallDayNumberSize: CGFloat = 26
    static let mediumDayNumberSize: CGFloat = 28
    static let smallMonthNumberSize: CGFloat = 13
    static let mediumMonthNumberSize: CGFloat = 14
    static let accessoryDayNumberSize: CGFloat = 28
    static let dateMinimumScale: CGFloat = 0.78

    static let accessoryCircularImprintDiameter: CGFloat = 50
    static let accessoryRectangularImprintDiameter: CGFloat = 44
    static let imprintRingInsetRatio: CGFloat = 0.08
    static let imprintCoreScale: CGFloat = 0.46
    static let imprintGlyphScale: CGFloat = 0.18
    static let statusMinimumScale: CGFloat = 0.78

    static let homeBandSpacing: CGFloat = 4
    static let homeContentInsets = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
    static let smallHomeHeaderHeight: CGFloat = 31
    static let mediumHomeHeaderHeight: CGFloat = 34
    static let smallBrandMarkSide: CGFloat = 24
    static let mediumBrandMarkSide: CGFloat = 28
    static let smallBrandTextSize: CGFloat = 16
    static let mediumBrandTextSize: CGFloat = 19
    static let brandSpacing: CGFloat = 4
    static let brandMinimumScale: CGFloat = 0.75
    static let smallCommitmentTextSize: CGFloat = 17
    static let mediumCommitmentTextSize: CGFloat = 20
    static let commitmentLineLimit = 2
    static let homeStatusHeight: CGFloat = 48
    static let smallStatusTextSize: CGFloat = 15
    static let mediumStatusTextSize: CGFloat = 17
    static let smallStatusFaceSize: CGFloat = 26
    static let mediumStatusFaceSize: CGFloat = 28
    static let statusFaceFrameSide: CGFloat = 28
    static let statusHorizontalPadding: CGFloat = 8
    static let statusCornerRadius: CGFloat = 8

    static let railMarkSlotWidth: CGFloat = 14
    static let homeRailHeight: CGFloat = 20
    static let homeRailLargeSide: CGFloat = 14
    static let homeRailSmallSide: CGFloat = 9
    static let accessoryRailHeight: CGFloat = 10
    static let accessoryRailLargeSide: CGFloat = 8
    static let accessoryRailSmallSide: CGFloat = 5
    static let homeBlockCornerRadius: CGFloat = 2.5
    static let accessoryBlockCornerRadius: CGFloat = 1.5
    static let railStrokeWidth: CGFloat = 1.5
    static let homeMissedOpacity = 0.38
    static let homeBeforeHabitOpacity = 0.58
    static let accessoryMissedOpacity = 0.42
    static let accessoryBeforeHabitOpacity = 0.56
    static let adaptiveMissedOpacity = 0.34
    static let adaptiveBeforeHabitOpacity = 0.52
    static let adaptiveCompletedSurfaceOpacity = 0.22
    static let adaptivePendingSurfaceOpacity = 0.10
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
