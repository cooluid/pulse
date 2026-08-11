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
            imprintControl(snapshot, diameter: 50, usesAccessoryStyle: true)
        case .accessoryRectangular:
            accessoryRectangular(snapshot)
        case .systemMedium:
            systemMedium(snapshot)
        default:
            systemSmall(snapshot)
        }
    }

    private func systemSmall(_ snapshot: PulseWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: PulseWidgetDesign.spacing8) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.today.day, format: .number)
                    .font(.system(.title, design: .rounded, weight: .light))
                    .monospacedDigit()
                Spacer(minLength: PulseWidgetDesign.spacing8)
                Text(snapshot.isCheckedToday ? "widget.state.checked.short" : "widget.state.pending.short")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(snapshot.isCheckedToday
                        ? PulseWidgetDesign.grass
                        : PulseWidgetDesign.action)
            }

            Spacer(minLength: 0)
            imprintControl(snapshot, diameter: 72)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)

            if let name = snapshot.visibleHabitName {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(PulseWidgetDesign.ink)
                    .lineLimit(1)
            } else {
                Text("widget.privacy.private_commitment")
                    .font(.caption)
                    .foregroundStyle(PulseWidgetDesign.secondary)
                    .lineLimit(1)
            }
        }
        .padding(PulseWidgetDesign.spacing16)
    }

    private func systemMedium(_ snapshot: PulseWidgetSnapshot) -> some View {
        HStack(spacing: PulseWidgetDesign.spacing16) {
            VStack(alignment: .leading, spacing: PulseWidgetDesign.spacing8) {
                Text(snapshot.visibleHabitName ?? String(localized: "widget.privacy.private_commitment"))
                    .font(.headline)
                    .foregroundStyle(PulseWidgetDesign.ink)
                    .lineLimit(2)
                Text(snapshot.isCheckedToday ? "widget.state.checked" : "widget.state.pending")
                    .font(.subheadline)
                    .foregroundStyle(PulseWidgetDesign.secondary)
                Spacer(minLength: 0)
                weekRail(snapshot.recentDays)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            imprintControl(snapshot, diameter: 82)
        }
        .padding(PulseWidgetDesign.spacing16)
    }

    private func accessoryRectangular(_ snapshot: PulseWidgetSnapshot) -> some View {
        HStack(spacing: PulseWidgetDesign.spacing8) {
            imprintControl(snapshot, diameter: 42, usesAccessoryStyle: true)
            VStack(alignment: .leading, spacing: PulseWidgetDesign.spacing4) {
                Text(snapshot.isCheckedToday ? "widget.state.checked.short" : "widget.state.pending.short")
                    .font(.headline)
                weekRail(snapshot.recentDays, usesAccessoryStyle: true)
            }
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
        HStack(spacing: PulseWidgetDesign.spacing4) {
            ForEach(days) { item in
                Circle()
                    .fill(dayFill(item.state, usesAccessoryStyle: usesAccessoryStyle))
                    .overlay {
                        if item.state == .todayPending {
                            Circle()
                                .stroke(
                                    usesAccessoryStyle
                                        ? Color.primary
                                        : PulseWidgetDesign.action,
                                    lineWidth: 1.5
                                )
                        }
                    }
                    .frame(width: 9, height: 9)
                    .accessibilityLabel(dayAccessibilityLabel(item))
            }
        }
    }

    private func dayFill(
        _ state: PulseWidgetDayState,
        usesAccessoryStyle: Bool
    ) -> Color {
        if usesAccessoryStyle {
            return state == .checked ? .primary : .clear
        }
        return switch state {
        case .checked:
            PulseWidgetDesign.grass
        case .missed:
            PulseWidgetDesign.secondary.opacity(0.35)
        case .todayPending, .beforeHabit:
            .clear
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
        ZStack {
            if isChecked {
                Circle()
                    .fill(completedColor)
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(completedForeground)
            } else {
                Image("PulseWidgetMark")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(pendingColor)
                    .padding(6)
            }
        }
        .widgetAccentable(usesAccessoryStyle)
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
    static let grass = Color("PulseGrass")
    static let grassForeground = Color("PulseGrassForeground")
    static let action = Color("PulseAction")
    static let ink = Color("PulseInk")
    static let secondary = Color("PulseSecondary")

    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing16: CGFloat = 16
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
