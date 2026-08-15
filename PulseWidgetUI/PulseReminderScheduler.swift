import ActivityKit
import Foundation
import PulseCore
import UserNotifications

enum NotificationPermissionState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}

enum PulseReminderSchedulingError: Error, Equatable, Sendable {
    case notificationPermissionDenied
    case liveActivitiesUnavailable
    case liveActivitySchedulingFailed
}

struct ReminderScheduleSnapshot: Sendable {
    let enabled: Bool
    let deliveryMode: PulseReminderDeliveryMode
    let time: PulseReminderTime
    let timeZoneIdentifier: String
    let localeIdentifier: String
    let checkedDays: Set<LogicalDay>
    let now: Date
}

enum ReminderSchedulePolicy {
    static let maximumPendingRequests = 64
    static let reservedPendingRequests = 4
    static let schedulingWindowDays = maximumPendingRequests - reservedPendingRequests
}

struct PlannedReminder: Equatable, Sendable {
    let day: LogicalDay
    let deliveryDate: Date
    let triggerComponents: DateComponents
    let timeZoneIdentifier: String
}

enum ReminderSchedulePlanner {
    static func makePlan(for snapshot: ReminderScheduleSnapshot) throws -> [PlannedReminder] {
        guard snapshot.enabled else { return [] }
        guard let timeZone = TimeZone(identifier: snapshot.timeZoneIdentifier) else {
            throw PulseCoreError.invalidTimeZone(snapshot.timeZoneIdentifier)
        }

        let today = LogicalDay.resolve(at: snapshot.now, timeZone: timeZone)
        let calendar = Calendar.pulseGregorian(timeZone: timeZone)
        var plan: [PlannedReminder] = []
        plan.reserveCapacity(ReminderSchedulePolicy.schedulingWindowDays)

        for offset in 0..<ReminderSchedulePolicy.schedulingWindowDays {
            let day = today.addingDays(offset, timeZone: timeZone)
            guard !snapshot.checkedDays.contains(day) else { continue }

            let dayStart = day.startDate(timeZone: timeZone)
            let requestedTime = DateComponents(
                hour: snapshot.time.hour,
                minute: snapshot.time.minute,
                second: 0
            )
            guard let deliveryDate = calendar.nextDate(
                after: dayStart.addingTimeInterval(-1),
                matching: requestedTime,
                matchingPolicy: .nextTimePreservingSmallerComponents,
                repeatedTimePolicy: .first,
                direction: .forward
            ),
            LogicalDay.resolve(at: deliveryDate, timeZone: timeZone) == day,
            deliveryDate > snapshot.now else {
                continue
            }

            var triggerComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: deliveryDate
            )
            triggerComponents.calendar = calendar
            triggerComponents.timeZone = timeZone
            plan.append(
                PlannedReminder(
                    day: day,
                    deliveryDate: deliveryDate,
                    triggerComponents: triggerComponents,
                    timeZoneIdentifier: snapshot.timeZoneIdentifier
                )
            )
        }

        return plan
    }
}

@MainActor
protocol ReminderScheduling: AnyObject {
    var deliveryCapabilities: PulseReminderDeliveryCapabilities { get }
    func permissionState() async -> NotificationPermissionState
    func requestPermission() async throws -> Bool
    func reconcile(_ snapshot: ReminderScheduleSnapshot) async throws -> PulseReminderDeliveryMode
    func completeLiveActivity(for logicalDay: LogicalDay) async
    func removeAllPulseNotifications() async
}

@MainActor
protocol ReminderLiveActivityScheduling: AnyObject {
    var capabilities: PulseReminderDeliveryCapabilities { get }
    func schedule(_ reminder: PlannedReminder, locale: Locale) async throws
    func complete(logicalDay: LogicalDay) async
    func removeAll(preservingActiveLogicalDay: LogicalDay?) async
}

@MainActor
protocol ReminderNotificationScheduling: AnyObject {
    func permissionState() async -> NotificationPermissionState
    func requestPermission() async throws -> Bool
    func pendingRequestIdentifiers() async -> [String]
    func deliveredRequestIdentifiers() async -> [String]
    func add(
        identifier: String,
        title: String,
        body: String,
        triggerComponents: DateComponents
    ) async throws
    func removePendingRequests(identifiers: [String])
    func removeDeliveredNotifications(identifiers: [String])
}

@MainActor
final class UserNotificationReminderScheduler: ReminderNotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func permissionState() async -> NotificationPermissionState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    func requestPermission() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func pendingRequestIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func deliveredRequestIdentifiers() async -> [String] {
        await center.deliveredNotifications().map(\.request.identifier)
    }

    func add(
        identifier: String,
        title: String,
        body: String,
        triggerComponents: DateComponents
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        try await center.add(
            UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: triggerComponents,
                    repeats: false
                )
            )
        )
    }

    func removePendingRequests(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDeliveredNotifications(identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

@MainActor
final class ActivityKitReminderLiveActivityScheduler: ReminderLiveActivityScheduling {
    var capabilities: PulseReminderDeliveryCapabilities {
        if #available(iOS 26.0, *) {
            return PulseReminderDeliveryCapabilities(
                supportsScheduledLiveActivities: true,
                liveActivitiesEnabled: ActivityAuthorizationInfo().areActivitiesEnabled
            )
        }
        return PulseReminderDeliveryCapabilities(
            supportsScheduledLiveActivities: false,
            liveActivitiesEnabled: false
        )
    }

    func schedule(_ reminder: PlannedReminder, locale: Locale) async throws {
        guard #available(iOS 26.0, *), capabilities.liveActivitiesEnabled else {
            throw PulseReminderSchedulingError.liveActivitiesUnavailable
        }

        let attributes = PulseReminderActivityAttributes(
            logicalDay: reminder.day.storageValue,
            reminderDate: reminder.deliveryDate,
            timeZoneIdentifier: reminder.timeZoneIdentifier,
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
            start: reminder.deliveryDate
        )
    }

    func complete(logicalDay: LogicalDay) async {
        let hasMatchingActivity = Activity<PulseReminderActivityAttributes>.activities.contains {
            $0.attributes.logicalDay == logicalDay.storageValue
        }
        guard hasMatchingActivity else { return }

        let completedContent = ActivityContent(
            state: PulseReminderActivityAttributes.ContentState(phase: .completed),
            staleDate: nil
        )
        for activity in Activity<PulseReminderActivityAttributes>.activities where
            activity.attributes.logicalDay == logicalDay.storageValue {
            await activity.update(completedContent)
        }
        try? await Task.sleep(for: PulseReminderActivityContract.completionEchoDuration)
        for activity in Activity<PulseReminderActivityAttributes>.activities where
            activity.attributes.logicalDay == logicalDay.storageValue {
            await activity.end(completedContent, dismissalPolicy: .immediate)
        }
    }

    func removeAll(preservingActiveLogicalDay: LogicalDay?) async {
        for activity in Activity<PulseReminderActivityAttributes>.activities {
            if activity.activityState == .active,
               activity.attributes.logicalDay == preservingActiveLogicalDay?.storageValue {
                continue
            }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

@MainActor
final class ReminderScheduler: ReminderScheduling {
    private let notificationScheduler: any ReminderNotificationScheduling
    private let liveActivityScheduler: any ReminderLiveActivityScheduling

    init(
        notificationScheduler: any ReminderNotificationScheduling = UserNotificationReminderScheduler(),
        liveActivityScheduler: any ReminderLiveActivityScheduling = ActivityKitReminderLiveActivityScheduler()
    ) {
        self.notificationScheduler = notificationScheduler
        self.liveActivityScheduler = liveActivityScheduler
    }

    var deliveryCapabilities: PulseReminderDeliveryCapabilities {
        liveActivityScheduler.capabilities
    }

    func permissionState() async -> NotificationPermissionState {
        await notificationScheduler.permissionState()
    }

    func requestPermission() async throws -> Bool {
        try await notificationScheduler.requestPermission()
    }

    func completeLiveActivity(for logicalDay: LogicalDay) async {
        await liveActivityScheduler.complete(logicalDay: logicalDay)
    }

    func reconcile(_ snapshot: ReminderScheduleSnapshot) async throws -> PulseReminderDeliveryMode {
        let activeLogicalDayToPreserve = activeLogicalDayToPreserve(for: snapshot)
        await removePendingPulseNotifications()
        await removePulseLiveActivities(
            preservingActiveLogicalDay: activeLogicalDayToPreserve
        )
        guard snapshot.enabled, snapshot.deliveryMode != .disabled else { return .disabled }

        let locale = Locale(identifier: snapshot.localeIdentifier)
        let plan = try ReminderSchedulePlanner.makePlan(for: snapshot)

        do {
            switch snapshot.deliveryMode {
            case .disabled:
                return .disabled
            case .localNotification:
                guard await permissionState() == .authorized else {
                    throw PulseReminderSchedulingError.notificationPermissionDenied
                }
                try await scheduleLocalNotifications(plan, locale: locale)
                return .localNotification
            case .scheduledLiveActivity:
                do {
                    let scheduledActivityCount = try await scheduleLiveActivities(
                        plan,
                        locale: locale
                    )
                    let notificationPlan = Array(plan.dropFirst(scheduledActivityCount))
                    if !notificationPlan.isEmpty {
                        guard await permissionState() == .authorized else {
                            throw PulseReminderSchedulingError.notificationPermissionDenied
                        }
                        try await scheduleLocalNotifications(notificationPlan, locale: locale)
                    }
                    return .scheduledLiveActivity
                } catch {
                    await removePulseLiveActivities(
                        preservingActiveLogicalDay: activeLogicalDayToPreserve
                    )
                    guard await permissionState() == .authorized else {
                        throw PulseReminderSchedulingError.liveActivitySchedulingFailed
                    }
                    try await scheduleLocalNotifications(plan, locale: locale)
                    return .localNotification
                }
            }
        } catch {
            await removePendingPulseNotifications()
            await removePulseLiveActivities(
                preservingActiveLogicalDay: activeLogicalDayToPreserve
            )
            throw error
        }
    }

    func removeAllPulseNotifications() async {
        await removePendingPulseNotifications()
        await removePulseLiveActivities(preservingActiveLogicalDay: nil)
        let identifiers = await notificationScheduler.deliveredRequestIdentifiers()
            .filter { $0.hasPrefix(PulseRuntimeIdentity.reminderRequestPrefix) }
        notificationScheduler.removeDeliveredNotifications(identifiers: identifiers)
    }

    private func removePendingPulseNotifications() async {
        let identifiers = await notificationScheduler.pendingRequestIdentifiers()
            .filter { $0.hasPrefix(PulseRuntimeIdentity.reminderRequestPrefix) }
        notificationScheduler.removePendingRequests(identifiers: identifiers)
    }

    private func scheduleLocalNotifications(
        _ plan: [PlannedReminder],
        locale: Locale
    ) async throws {
        for reminder in plan {
            try Task.checkCancellation()

            try await notificationScheduler.add(
                identifier: PulseRuntimeIdentity.reminderRequestPrefix + reminder.day.storageValue,
                title: PulseLocalization.string("notification.title", locale: locale),
                body: PulseLocalization.string("notification.body", locale: locale),
                triggerComponents: reminder.triggerComponents
            )
        }
    }

    private func scheduleLiveActivities(
        _ plan: [PlannedReminder],
        locale: Locale
    ) async throws -> Int {
        guard liveActivityScheduler.capabilities.supportsScheduledLiveActivities,
              liveActivityScheduler.capabilities.liveActivitiesEnabled else {
            throw PulseReminderSchedulingError.liveActivitiesUnavailable
        }

        var scheduledCount = 0
        for reminder in plan.prefix(PulseReminderActivityContract.maximumScheduledActivities) {
            try Task.checkCancellation()
            do {
                try await liveActivityScheduler.schedule(reminder, locale: locale)
                scheduledCount += 1
            } catch where scheduledCount > 0 {
                // ActivityKit applies a device-dependent pending activity budget.
                // Keeping the accepted prefix is more useful than deleting every valid reminder.
                break
            }
        }

        guard scheduledCount > 0 || plan.isEmpty else {
            throw PulseReminderSchedulingError.liveActivitySchedulingFailed
        }
        return scheduledCount
    }

    private func activeLogicalDayToPreserve(
        for snapshot: ReminderScheduleSnapshot
    ) -> LogicalDay? {
        guard snapshot.enabled,
              snapshot.deliveryMode == .scheduledLiveActivity,
              let timeZone = TimeZone(identifier: snapshot.timeZoneIdentifier) else {
            return nil
        }
        let today = LogicalDay.resolve(at: snapshot.now, timeZone: timeZone)
        return snapshot.checkedDays.contains(today) ? nil : today
    }

    private func removePulseLiveActivities(
        preservingActiveLogicalDay: LogicalDay?
    ) async {
        await liveActivityScheduler.removeAll(
            preservingActiveLogicalDay: preservingActiveLogicalDay
        )
    }
}
