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
        let style: PulseReminderActivityStyle
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
                style: activity.attributes.style,
                phase: activity.content.state.phase,
                lifecycle: lifecycle(for: activity.activityState)
            )
        }
        .sorted { $0.id < $1.id }
    }

    func startImmediately(
        logicalDay: LogicalDay,
        locale: Locale,
        style: PulseReminderActivityStyle
    ) async {
        await perform {
            let attributes = PulseReminderActivityAttributes(
                logicalDay: logicalDay.storageValue,
                localeIdentifier: locale.identifier,
                style: style
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
        style: PulseReminderActivityStyle,
        startDate: Date
    ) async {
        await perform {
            let attributes = PulseReminderActivityAttributes(
                logicalDay: logicalDay.storageValue,
                localeIdentifier: locale.identifier,
                style: style
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
    @State private var selectedStyle: PulseReminderActivityStyle = .dayRing

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
            Picker(copy(.style), selection: $selectedStyle) {
                ForEach(PulseReminderActivityStyle.allCases) { style in
                    Text(style.localizedName(locale: locale)).tag(style)
                }
            }
            LabeledContent(copy(.logicalDay), value: model.today?.storageValue ?? copy(.unavailable))
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
                guard let today = model.today else { return }
                Task {
                    await controller.startImmediately(
                        logicalDay: today,
                        locale: locale,
                        style: selectedStyle
                    )
                }
            } label: {
                Label(copy(.startNow), systemImage: "play.fill")
            }
            .disabled(!canStart)
            .accessibilityIdentifier("debug.activity.start-now")

            if #available(iOS 26.0, *) {
                Button {
                    guard let today = model.today else { return }
                    Task {
                        await controller.schedule(
                            logicalDay: today,
                            locale: locale,
                            style: selectedStyle,
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
                            Text(activity.style.localizedName(locale: locale))
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
        isIsolatedRuntimeIdentity && model.today != nil && controller.activitiesEnabled
    }

    private var isIsolatedRuntimeIdentity: Bool {
        PulseRuntimeIdentity.bundleIdentifier == "co.fanr.pulse.dev"
            && PulseRuntimeIdentity.appGroupIdentifier == "group.co.fanr.pulse.dev"
            && PulseRuntimeIdentity.urlScheme == "pulse-dev"
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
    enum Key {
        case title, isolationConfirmed, isolationFailed, appIdentifier, appGroup, urlScheme
        case identityHeader, identityFooter, configurationHeader, style, logicalDay, unavailable
        case activityEnabled, activityDisabled, startNow, startAfterThirtySeconds
        case scheduledStart, requiresIOS26, realActivityHeader, realActivityFooter
        case previewCompleted, restorePending, realCheckIn, endAll, stateHeader, stateFooter
        case alreadyCheckedIn, checkInFailed, checkInSucceeded
        case noActivities, lastRequest, refresh, diagnosticsHeader
        case phasePending, phaseCompleted
        case lifecyclePending, lifecycleActive, lifecycleStale
        case lifecycleEnded, lifecycleDismissed, lifecycleUnknown
    }

    static func string(_ key: Key, locale: Locale) -> String {
        let isChinese = locale.language.languageCode == .chinese
        let value: (zh: String, en: String)
        switch key {
        case .title: value = ("灵动岛测试台", "Dynamic Island Lab")
        case .isolationConfirmed: value = ("Debug 数据与正式版隔离", "Debug data is isolated from production")
        case .isolationFailed: value = ("身份异常，已禁用全部测试操作", "Identity mismatch; all test actions are disabled")
        case .appIdentifier: value = ("App 标识", "App identifier")
        case .appGroup: value = ("App Group", "App Group")
        case .urlScheme: value = ("URL Scheme", "URL scheme")
        case .identityHeader: value = ("运行身份", "Runtime identity")
        case .identityFooter: value = ("如果这里出现正式版标识，请停止测试；这表示构建配置发生回归。", "Stop testing if a production identifier appears here; the build configuration has regressed.")
        case .configurationHeader: value = ("测试参数", "Test configuration")
        case .style: value = ("样式", "Style")
        case .logicalDay: value = ("逻辑日期", "Logical day")
        case .unavailable: value = ("尚未加载", "Not loaded")
        case .activityEnabled: value = ("系统已允许实时活动", "Live Activities are enabled")
        case .activityDisabled: value = ("系统未允许实时活动", "Live Activities are disabled")
        case .startNow: value = ("立即启动真实活动", "Start real activity now")
        case .startAfterThirtySeconds: value = ("30 秒后由系统启动", "Ask the system to start in 30 seconds")
        case .scheduledStart: value = ("系统定时启动", "System-scheduled start")
        case .requiresIOS26: value = ("需要 iOS 26", "Requires iOS 26")
        case .realActivityHeader: value = ("真实 ActivityKit", "Real ActivityKit")
        case .realActivityFooter: value = ("立即启动验证真实系统表面；30 秒启动验证 iOS 26 的系统定时交付。系统决定灵动岛与锁屏的最终展示时机。", "Start now to verify real system surfaces. The 30-second option verifies iOS 26 system-scheduled delivery. The system decides when the Dynamic Island and Lock Screen are presented.")
        case .previewCompleted: value = ("仅切换为完成态", "Switch to completed appearance only")
        case .restorePending: value = ("恢复待签到态", "Restore pending appearance")
        case .realCheckIn: value = ("执行真实签到链路", "Run authoritative check-in")
        case .endAll: value = ("结束全部 Dev 活动", "End all Dev activities")
        case .stateHeader: value = ("状态与业务链路", "State and business flow")
        case .stateFooter: value = ("“完成态”只验证视觉；“真实签到”会写入 Dev 数据库、更新 Widget，并按正式规则结束当天活动。", "The completed state is visual-only. Authoritative check-in writes to the Dev database, updates widgets, and ends today's activity using production rules.")
        case .alreadyCheckedIn: value = ("今天已在 Dev 数据中签到；如需重测真实链路，请重置 Dev 数据。", "Today is already checked in within Dev data. Reset Dev data to test the real flow again.")
        case .checkInFailed: value = ("真实签到未完成，请检查 App 内错误提示。", "Authoritative check-in did not complete. Check the in-app error.")
        case .checkInSucceeded: value = ("真实签到完成；活动应先显示完成态，再按正式规则结束。", "Authoritative check-in completed. The activity should show completion briefly, then end under production rules.")
        case .noActivities: value = ("当前没有该 Dev App 创建的活动。", "No activities were created by this Dev app.")
        case .lastRequest: value = ("最近请求时间", "Last requested start")
        case .refresh: value = ("刷新活动状态", "Refresh activity state")
        case .diagnosticsHeader: value = ("诊断", "Diagnostics")
        case .phasePending: value = ("待签到", "Pending")
        case .phaseCompleted: value = ("已完成", "Completed")
        case .lifecyclePending: value = ("等待系统启动", "Waiting for system")
        case .lifecycleActive: value = ("活动中", "Active")
        case .lifecycleStale: value = ("已过期", "Stale")
        case .lifecycleEnded: value = ("已结束", "Ended")
        case .lifecycleDismissed: value = ("已移除", "Dismissed")
        case .lifecycleUnknown: value = ("未知", "Unknown")
        }
        return isChinese ? value.zh : value.en
    }
}
#endif
