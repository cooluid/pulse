#if DEBUG
import ActivityKit
import Observation
import PulseCore
import SwiftUI

@MainActor
@Observable
private final class ReminderActivityDebugController {
    struct ActivitySnapshot: Identifiable {
        let id: String
        let logicalDay: String
        let reminderDate: Date
        let timeZoneIdentifier: String
        let phase: PulseReminderActivityPhase
        let lifecycle: Lifecycle

        enum Lifecycle {
            case pending
            case active
            case stale
            case ended
            case dismissed
            case unknown
        }
    }

    private(set) var activities: [ActivitySnapshot] = []
    private(set) var isWorking = false
    private(set) var lastRequestedStartDate: Date?
    var message: String?

    var activitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func refresh() {
        activities = Activity<PulseReminderActivityAttributes>.activities.map { activity in
            ActivitySnapshot(
                id: activity.id,
                logicalDay: activity.attributes.logicalDay,
                reminderDate: activity.attributes.reminderDate,
                timeZoneIdentifier: activity.attributes.timeZoneIdentifier,
                phase: activity.content.state.phase,
                lifecycle: lifecycle(for: activity.activityState)
            )
        }
        .sorted { $0.id < $1.id }
    }

    func startImmediately(
        logicalDay: LogicalDay,
        locale: Locale,
        timeZoneIdentifier: String
    ) async {
        await perform {
            let attributes = PulseReminderActivityAttributes(
                logicalDay: logicalDay.storageValue,
                reminderDate: .now,
                timeZoneIdentifier: timeZoneIdentifier,
                localeIdentifier: locale.identifier
            )
            let content = ActivityContent(
                state: PulseReminderActivityAttributes.ContentState(phase: .pending),
                staleDate: nil
            )
            _ = try Activity<PulseReminderActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            lastRequestedStartDate = .now
        }
    }

    @available(iOS 26.0, *)
    func schedule(
        logicalDay: LogicalDay,
        locale: Locale,
        timeZoneIdentifier: String,
        startDate: Date
    ) async {
        await perform {
            let attributes = PulseReminderActivityAttributes(
                logicalDay: logicalDay.storageValue,
                reminderDate: startDate,
                timeZoneIdentifier: timeZoneIdentifier,
                localeIdentifier: locale.identifier
            )
            let content = ActivityContent(
                state: PulseReminderActivityAttributes.ContentState(phase: .pending),
                staleDate: nil
            )
            let alert = AlertConfiguration(
                title: LocalizedStringResource(
                    "activity.reminder.alert.title",
                    locale: locale
                ),
                body: LocalizedStringResource(
                    "activity.reminder.alert.body",
                    locale: locale
                ),
                sound: .default
            )
            _ = try Activity<PulseReminderActivityAttributes>.request(
                attributes: attributes,
                content: content,
                style: .standard,
                alertConfiguration: alert,
                start: startDate
            )
            lastRequestedStartDate = startDate
        }
    }

    func setVisualPhase(_ phase: PulseReminderActivityPhase) async {
        await perform {
            let content = ActivityContent(
                state: PulseReminderActivityAttributes.ContentState(phase: phase),
                staleDate: nil
            )
            for activity in Activity<PulseReminderActivityAttributes>.activities {
                await activity.update(content)
            }
        }
    }

    func endAll() async {
        await perform {
            for activity in Activity<PulseReminderActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func perform(_ operation: () async throws -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        message = nil
        defer {
            isWorking = false
            refresh()
        }
        do {
            try await operation()
        } catch {
            message = error.localizedDescription
        }
    }

    private func lifecycle(
        for state: ActivityState
    ) -> ActivitySnapshot.Lifecycle {
        if #available(iOS 26.0, *), state == .pending {
            return .pending
        }
        switch state {
        case .active:
            return .active
        case .stale:
            return .stale
        case .ended:
            return .ended
        case .dismissed:
            return .dismissed
        default:
            return .unknown
        }
    }
}

struct ReminderActivityDebugView: View {
    @Bindable var model: PulseAppModel
    @Environment(\.locale) private var locale
    @State private var controller = ReminderActivityDebugController()

    var body: some View {
        Form {
            identitySection
            configurationSection
            realActivitySection
            stateSection
            diagnosticsSection
        }
        .scrollContentBackground(.hidden)
        .background(PulseDesign.background)
        .foregroundStyle(PulseDesign.ink)
        .tint(PulseDesign.tint)
        .navigationTitle(copy(.title))
        .navigationBarTitleDisplayMode(.inline)
        .pulseSecondaryNavigation()
        .disabled(controller.isWorking)
        .overlay {
            if controller.isWorking {
                ProgressView()
                    .controlSize(.large)
                    .padding(PulseDesign.spacing20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
        }
        .task { controller.refresh() }
    }

    private var identitySection: some View {
        Section {
            Label(
                copy(isIsolatedRuntimeIdentity ? .isolationConfirmed : .isolationFailed),
                systemImage: isIsolatedRuntimeIdentity
                    ? "checkmark.shield.fill"
                    : "exclamationmark.shield.fill"
            )
            .foregroundStyle(isIsolatedRuntimeIdentity ? PulseDesign.grass : PulseDesign.action)
            LabeledContent(copy(.appIdentifier), value: PulseRuntimeIdentity.bundleIdentifier)
                .accessibilityIdentifier("debug.identity.app")
            LabeledContent(copy(.appGroup), value: PulseRuntimeIdentity.appGroupIdentifier)
                .accessibilityIdentifier("debug.identity.app-group")
            LabeledContent(copy(.urlScheme), value: PulseRuntimeIdentity.urlScheme)
                .accessibilityIdentifier("debug.identity.url-scheme")
        } header: {
            Text(copy(.identityHeader))
        } footer: {
            Text(copy(.identityFooter))
        }
    }

    private var configurationSection: some View {
        Section {
            LabeledContent(copy(.logicalDay), value: model.today?.storageValue ?? copy(.unavailable))
            LabeledContent(copy(.timeZone), value: model.habit?.timeZoneIdentifier ?? copy(.unavailable))
        } header: {
            Text(copy(.configurationHeader))
        }
    }

    private var realActivitySection: some View {
        Section {
            Label(
                controller.activitiesEnabled ? copy(.activityEnabled) : copy(.activityDisabled),
                systemImage: controller.activitiesEnabled
                    ? "waveform.path.ecg.rectangle.fill"
                    : "exclamationmark.triangle.fill"
            )
            .foregroundStyle(
                controller.activitiesEnabled ? PulseDesign.grass : PulseDesign.action
            )

            Button {
                guard let today = model.today,
                      let timeZoneIdentifier = model.habit?.timeZoneIdentifier else { return }
                Task {
                    await controller.startImmediately(
                        logicalDay: today,
                        locale: locale,
                        timeZoneIdentifier: timeZoneIdentifier
                    )
                }
            } label: {
                Label(copy(.startNow), systemImage: "play.fill")
            }
            .disabled(!canStart)
            .accessibilityIdentifier("debug.activity.start-now")

            if #available(iOS 26.0, *) {
                Button {
                    guard let today = model.today,
                          let timeZoneIdentifier = model.habit?.timeZoneIdentifier else { return }
                    Task {
                        await controller.schedule(
                            logicalDay: today,
                            locale: locale,
                            timeZoneIdentifier: timeZoneIdentifier,
                            startDate: .now.addingTimeInterval(30)
                        )
                    }
                } label: {
                    Label(copy(.startAfterThirtySeconds), systemImage: "timer")
                }
                .disabled(!canStart)
                .accessibilityIdentifier("debug.activity.schedule-30-seconds")
            } else {
                LabeledContent(copy(.scheduledStart), value: copy(.requiresIOS26))
                    .foregroundStyle(PulseDesign.secondary)
            }
        } header: {
            Text(copy(.realActivityHeader))
        } footer: {
            Text(copy(.realActivityFooter))
        }
        .disabled(!isIsolatedRuntimeIdentity)
    }

    private var stateSection: some View {
        Section {
            Button {
                Task { await controller.setVisualPhase(.completed) }
            } label: {
                Label(copy(.previewCompleted), systemImage: "checkmark.circle")
            }
            .disabled(controller.activities.isEmpty)
            .accessibilityIdentifier("debug.activity.preview-completed")

            Button {
                Task { await controller.setVisualPhase(.pending) }
            } label: {
                Label(copy(.restorePending), systemImage: "arrow.counterclockwise")
            }
            .disabled(controller.activities.isEmpty)
            .accessibilityIdentifier("debug.activity.restore-pending")

            Button {
                Task {
                    guard model.todayRecord == nil else {
                        controller.message = copy(.alreadyCheckedIn)
                        return
                    }
                    guard await model.checkIn() != nil else {
                        controller.message = copy(.checkInFailed)
                        return
                    }
                    controller.message = copy(.checkInSucceeded)
                    controller.refresh()
                }
            } label: {
                Label(copy(.realCheckIn), systemImage: "checkmark.seal.fill")
            }
            .disabled(model.today == nil || model.todayRecord != nil)
            .accessibilityIdentifier("debug.activity.real-check-in")

            Button(role: .destructive) {
                Task { await controller.endAll() }
            } label: {
                Label(copy(.endAll), systemImage: "xmark.octagon")
            }
            .disabled(controller.activities.isEmpty)
            .accessibilityIdentifier("debug.activity.end-all")
        } header: {
            Text(copy(.stateHeader))
        } footer: {
            Text(copy(.stateFooter))
        }
        .disabled(!isIsolatedRuntimeIdentity)
    }

    private var diagnosticsSection: some View {
        Section {
            if controller.activities.isEmpty {
                Text(copy(.noActivities))
                    .foregroundStyle(PulseDesign.secondary)
            } else {
                ForEach(controller.activities) { activity in
                    VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                        HStack {
                            Text(formattedReminderTime(activity))
                                .font(.headline)
                            Spacer()
                            Text(lifecycleName(activity.lifecycle))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseDesign.secondary)
                        }
                        Text("\(phaseName(activity.phase)) · \(activity.logicalDay)")
                            .font(.footnote)
                            .foregroundStyle(PulseDesign.secondary)
                        Text(activity.id)
                            .font(.caption2.monospaced())
                            .foregroundStyle(PulseDesign.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, PulseDesign.spacing4)
                }
            }

            if let date = controller.lastRequestedStartDate {
                LabeledContent(copy(.lastRequest), value: date.formatted(date: .omitted, time: .standard))
            }

            if let message = controller.message {
                Label(message, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(PulseDesign.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(copy(.refresh)) {
                controller.refresh()
            }
            .accessibilityIdentifier("debug.activity.refresh")
        } header: {
            Text(copy(.diagnosticsHeader))
        }
    }

    private var canStart: Bool {
        isIsolatedRuntimeIdentity
            && model.today != nil
            && model.habit != nil
            && controller.activitiesEnabled
    }

    private var isIsolatedRuntimeIdentity: Bool {
        PulseRuntimeIdentity.bundleIdentifier == "co.fanr.pulse.dev"
            && PulseRuntimeIdentity.appGroupIdentifier == "group.co.fanr.pulse.dev"
            && PulseRuntimeIdentity.urlScheme == "pulse-dev"
    }

    private func formattedReminderTime(
        _ activity: ReminderActivityDebugController.ActivitySnapshot
    ) -> String {
        guard let timeZone = TimeZone(identifier: activity.timeZoneIdentifier) else {
            return copy(.invalidTimeZone)
        }
        return activity.reminderDate.formatted(Date.FormatStyle(
            date: .omitted,
            time: .standard,
            locale: locale,
            timeZone: timeZone
        ))
    }

    private func phaseName(_ phase: PulseReminderActivityPhase) -> String {
        switch phase {
        case .pending: copy(.phasePending)
        case .completed: copy(.phaseCompleted)
        }
    }

    private func lifecycleName(
        _ lifecycle: ReminderActivityDebugController.ActivitySnapshot.Lifecycle
    ) -> String {
        switch lifecycle {
        case .pending: copy(.lifecyclePending)
        case .active: copy(.lifecycleActive)
        case .stale: copy(.lifecycleStale)
        case .ended: copy(.lifecycleEnded)
        case .dismissed: copy(.lifecycleDismissed)
        case .unknown: copy(.lifecycleUnknown)
        }
    }

    private func copy(_ key: ReminderActivityDebugCopy.Key) -> String {
        ReminderActivityDebugCopy.string(key, locale: locale)
    }
}

private enum ReminderActivityDebugCopy {
    enum Key: String {
        case title = "debug.activity_lab.title"
        case isolationConfirmed = "debug.activity_lab.isolation_confirmed"
        case isolationFailed = "debug.activity_lab.isolation_failed"
        case appIdentifier = "debug.activity_lab.app_identifier"
        case appGroup = "debug.activity_lab.app_group"
        case urlScheme = "debug.activity_lab.url_scheme"
        case identityHeader = "debug.activity_lab.identity_header"
        case identityFooter = "debug.activity_lab.identity_footer"
        case configurationHeader = "debug.activity_lab.configuration_header"
        case logicalDay = "debug.activity_lab.logical_day"
        case timeZone = "debug.activity_lab.time_zone"
        case unavailable = "debug.activity_lab.unavailable"
        case invalidTimeZone = "debug.activity_lab.invalid_time_zone"
        case activityEnabled = "debug.activity_lab.activity_enabled"
        case activityDisabled = "debug.activity_lab.activity_disabled"
        case startNow = "debug.activity_lab.start_now"
        case startAfterThirtySeconds = "debug.activity_lab.start_after_thirty_seconds"
        case scheduledStart = "debug.activity_lab.scheduled_start"
        case requiresIOS26 = "debug.activity_lab.requires_ios_26"
        case realActivityHeader = "debug.activity_lab.real_activity_header"
        case realActivityFooter = "debug.activity_lab.real_activity_footer"
        case previewCompleted = "debug.activity_lab.preview_completed"
        case restorePending = "debug.activity_lab.restore_pending"
        case realCheckIn = "debug.activity_lab.real_check_in"
        case endAll = "debug.activity_lab.end_all"
        case stateHeader = "debug.activity_lab.state_header"
        case stateFooter = "debug.activity_lab.state_footer"
        case alreadyCheckedIn = "debug.activity_lab.already_checked_in"
        case checkInFailed = "debug.activity_lab.check_in_failed"
        case checkInSucceeded = "debug.activity_lab.check_in_succeeded"
        case noActivities = "debug.activity_lab.no_activities"
        case lastRequest = "debug.activity_lab.last_request"
        case refresh = "debug.activity_lab.refresh"
        case diagnosticsHeader = "debug.activity_lab.diagnostics_header"
        case phasePending = "debug.activity_lab.phase_pending"
        case phaseCompleted = "debug.activity_lab.phase_completed"
        case lifecyclePending = "debug.activity_lab.lifecycle_pending"
        case lifecycleActive = "debug.activity_lab.lifecycle_active"
        case lifecycleStale = "debug.activity_lab.lifecycle_stale"
        case lifecycleEnded = "debug.activity_lab.lifecycle_ended"
        case lifecycleDismissed = "debug.activity_lab.lifecycle_dismissed"
        case lifecycleUnknown = "debug.activity_lab.lifecycle_unknown"
    }

    static func string(_ key: Key, locale: Locale) -> String {
        PulseLocalization.string(
            key.rawValue,
            table: "PulseDebug",
            locale: locale
        )
    }
}
#endif
