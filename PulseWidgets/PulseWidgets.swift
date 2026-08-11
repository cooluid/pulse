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
                at: date,
                showsHabitName: context.defaults.bool(
                    forKey: PulseWidgetContract.showsHabitNamePreferenceKey
                )
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
        guard let defaults = UserDefaults(suiteName: identifier) else {
            throw RuntimeError.missingAppGroupIdentifier
        }
        return RuntimeContext(
            location: location,
            defaults: defaults,
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
        let defaults: UserDefaults
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
        VStack(spacing: PulseWidgetDesign.homeBandSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: PulseWidgetDesign.spacing8) {
                Text(snapshot.visibleHabitName ?? String(localized: "widget.brand.name"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseWidgetDesign.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(PulseWidgetDesign.identityMinimumScale)

                Spacer(minLength: PulseWidgetDesign.spacing4)

                Text(snapshot.today.day, format: .number)
                    .font(.system(
                        size: PulseWidgetDesign.smallDayNumberSize,
                        weight: .bold,
                        design: .default
                    ))
                    .foregroundStyle(PulseWidgetDesign.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(PulseWidgetDesign.dayNumberMinimumScale)
            }
            .frame(height: PulseWidgetDesign.smallHeaderHeight, alignment: .top)

            weekRail(snapshot.recentDays)

            homeStatusBand(snapshot, usesCompactCopy: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func systemMedium(_ snapshot: PulseWidgetSnapshot) -> some View {
        VStack(spacing: PulseWidgetDesign.homeBandSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: PulseWidgetDesign.spacing16) {
                Text(snapshot.visibleHabitName ?? String(localized: "widget.brand.name"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseWidgetDesign.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(PulseWidgetDesign.identityMinimumScale)

                Spacer(minLength: PulseWidgetDesign.spacing8)

                Text(snapshot.today.day, format: .number)
                    .font(.system(
                        size: PulseWidgetDesign.mediumDayNumberSize,
                        weight: .bold,
                        design: .default
                    ))
                    .foregroundStyle(PulseWidgetDesign.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(PulseWidgetDesign.dayNumberMinimumScale)
            }
            .frame(height: PulseWidgetDesign.mediumHeaderHeight, alignment: .top)

            weekRail(snapshot.recentDays)

            homeStatusBand(snapshot, usesCompactCopy: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        usesCompactCopy: Bool
    ) -> some View {
        if snapshot.isCheckedToday {
            homeStatusBandContent(snapshot, usesCompactCopy: usesCompactCopy)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("widget.accessibility.checked")
        } else {
            Button(intent: PulseCheckInIntent()) {
                homeStatusBandContent(snapshot, usesCompactCopy: usesCompactCopy)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("widget.action.check_in")
            .accessibilityHint("widget.action.check_in.hint")
        }
    }

    private func homeStatusBandContent(
        _ snapshot: PulseWidgetSnapshot,
        usesCompactCopy: Bool
    ) -> some View {
        HStack(spacing: PulseWidgetDesign.spacing8) {
            Text(homeStatusKey(snapshot, usesCompactCopy: usesCompactCopy))
                .font((usesCompactCopy ? Font.caption : Font.subheadline).weight(.semibold))
                .foregroundStyle(PulseWidgetDesign.ink)
                .lineLimit(1)
                .minimumScaleFactor(PulseWidgetDesign.statusMinimumScale)

            Spacer(minLength: PulseWidgetDesign.spacing4)

            PulseWidgetImprintMark(
                isChecked: snapshot.isCheckedToday,
                usesAccessoryStyle: false
            )
            .frame(
                width: PulseWidgetDesign.homeStatusImprintDiameter,
                height: PulseWidgetDesign.homeStatusImprintDiameter
            )
        }
        .padding(.horizontal, PulseWidgetDesign.statusHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: PulseWidgetDesign.homeStatusHeight)
        .background {
            RoundedRectangle(
                cornerRadius: PulseWidgetDesign.statusCornerRadius,
                style: .continuous
            )
            .fill(PulseWidgetDesign.surface)
        }
        .contentShape(Rectangle())
    }

    private func homeStatusKey(
        _ snapshot: PulseWidgetSnapshot,
        usesCompactCopy: Bool
    ) -> LocalizedStringKey {
        if snapshot.isCheckedToday {
            return usesCompactCopy
                ? "widget.state.checked.short"
                : "widget.state.checked"
        }
        return "widget.action.check_in"
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
                usesAccessoryStyle: usesAccessoryStyle
            )
            .frame(width: diameter, height: diameter)
            .accessibilityLabel("widget.accessibility.checked")
        } else {
            Button(intent: PulseCheckInIntent()) {
                PulseWidgetImprintMark(
                    isChecked: false,
                    usesAccessoryStyle: usesAccessoryStyle
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
        .background(alignment: .bottom) {
            Capsule()
                .fill(usesAccessoryStyle
                    ? Color.primary.opacity(PulseWidgetDesign.accessoryRailBaselineOpacity)
                    : PulseWidgetDesign.separator)
                .frame(height: PulseWidgetDesign.thinLineWidth)
                .accessibilityHidden(true)
        }
    }

    private func weekRailMark(
        _ item: PulseWidgetDaySnapshot,
        usesAccessoryStyle: Bool
    ) -> some View {
        let height = railMarkHeight(
            item.state,
            usesAccessoryStyle: usesAccessoryStyle
        )
        let railHeight = usesAccessoryStyle
            ? PulseWidgetDesign.accessoryRailHeight
            : PulseWidgetDesign.homeRailHeight
        let markWidth = usesAccessoryStyle
            ? PulseWidgetDesign.accessoryRailMarkWidth
            : PulseWidgetDesign.homeRailMarkWidth

        return Capsule()
            .fill(railMarkFill(item.state, usesAccessoryStyle: usesAccessoryStyle))
            .overlay {
                if let stroke = railMarkStroke(
                    item.state,
                    usesAccessoryStyle: usesAccessoryStyle
                ) {
                    Capsule()
                        .stroke(stroke, lineWidth: PulseWidgetDesign.railStrokeWidth)
                }
            }
            .frame(width: markWidth, height: height)
            .frame(
                width: PulseWidgetDesign.railMarkSlotWidth,
                height: railHeight,
                alignment: .bottom
            )
            .accessibilityLabel(dayAccessibilityLabel(item))
    }

    private func railMarkHeight(
        _ state: PulseWidgetDayState,
        usesAccessoryStyle: Bool
    ) -> CGFloat {
        let isTall = state == .checked || state == .todayPending
        if usesAccessoryStyle {
            return isTall
                ? PulseWidgetDesign.accessoryRailTallHeight
                : PulseWidgetDesign.accessoryRailShortHeight
        }
        return isTall
            ? PulseWidgetDesign.homeRailTallHeight
            : PulseWidgetDesign.homeRailShortHeight
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
            PulseWidgetDesign.grass
        case .missed:
            PulseWidgetDesign.secondary.opacity(PulseWidgetDesign.homeMissedOpacity)
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
                : PulseWidgetDesign.secondary.opacity(PulseWidgetDesign.homeBeforeHabitOpacity)
        case .todayPending:
            usesAccessoryStyle ? Color.primary : PulseWidgetDesign.action
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
                    .foregroundStyle(PulseWidgetDesign.secondary)
            }
        }
        .foregroundStyle(family == .accessoryCircular
            ? Color.primary
            : PulseWidgetDesign.ink)
        .padding(family == .accessoryCircular ? 0 : PulseWidgetDesign.spacing16)
    }
}

private struct PulseWidgetImprintMark: View {
    let isChecked: Bool
    let usesAccessoryStyle: Bool

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
                    Circle()
                        .fill(completedColor)
                        .frame(
                            width: side * PulseWidgetDesign.imprintCoreScale,
                            height: side * PulseWidgetDesign.imprintCoreScale
                        )
                    Image(systemName: "checkmark")
                        .font(.system(
                            size: side * PulseWidgetDesign.imprintGlyphScale,
                            weight: .bold
                        ))
                        .foregroundStyle(completedForeground)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .widgetAccentable(usesAccessoryStyle)
        .accessibilityHidden(true)
    }

    private var completedColor: Color {
        usesAccessoryStyle ? .primary : PulseWidgetDesign.grass
    }

    private var completedForeground: Color {
        usesAccessoryStyle ? .black : PulseWidgetDesign.grassForeground
    }

    private var pendingColor: Color {
        usesAccessoryStyle ? .primary : PulseWidgetDesign.action
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
    static let spacing16: CGFloat = 16

    static let smallDayNumberSize: CGFloat = 34
    static let mediumDayNumberSize: CGFloat = 38
    static let accessoryDayNumberSize: CGFloat = 28
    static let dayNumberMinimumScale: CGFloat = 0.88
    static let identityMinimumScale: CGFloat = 0.72

    static let accessoryCircularImprintDiameter: CGFloat = 50
    static let accessoryRectangularImprintDiameter: CGFloat = 44
    static let imprintRingInsetRatio: CGFloat = 0.08
    static let imprintCoreScale: CGFloat = 0.46
    static let imprintGlyphScale: CGFloat = 0.18
    static let statusMinimumScale: CGFloat = 0.78

    static let homeBandSpacing: CGFloat = 4
    static let smallHeaderHeight: CGFloat = 36
    static let mediumHeaderHeight: CGFloat = 40
    static let homeStatusHeight: CGFloat = 44
    static let homeStatusImprintDiameter: CGFloat = 30
    static let statusHorizontalPadding: CGFloat = 10
    static let statusCornerRadius: CGFloat = 11

    static let homeRailMarkWidth: CGFloat = 8
    static let accessoryRailMarkWidth: CGFloat = 5
    static let railMarkSlotWidth: CGFloat = 5
    static let homeRailHeight: CGFloat = 34
    static let homeRailTallHeight: CGFloat = 32
    static let homeRailShortHeight: CGFloat = 13
    static let accessoryRailHeight: CGFloat = 11
    static let accessoryRailTallHeight: CGFloat = 11
    static let accessoryRailShortHeight: CGFloat = 5
    static let railStrokeWidth: CGFloat = 1.25
    static let thinLineWidth: CGFloat = 1
    static let homeMissedOpacity = 0.38
    static let homeBeforeHabitOpacity = 0.58
    static let accessoryMissedOpacity = 0.42
    static let accessoryBeforeHabitOpacity = 0.56
    static let accessoryRailBaselineOpacity = 0.3
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
            today: today,
            checkedAt: nil,
            recentDays: days,
            visibleHabitName: nil,
            generatedAt: Date(timeIntervalSince1970: 1_754_860_800),
            nextDayBoundary: Date(timeIntervalSince1970: 1_754_947_200)
        )
    }
}
