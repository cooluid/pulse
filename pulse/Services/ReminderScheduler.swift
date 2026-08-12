import ActivityKit
import Foundation
import PulseCore
import UserNotifications

enum NotificationPermissionState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}

struct ReminderScheduleSnapshot: Sendable {
    let enabled: Bool
    let deliveryMode: ReminderDeliveryMode
    let time: ReminderTime
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
                    triggerComponents: triggerComponents
                )
            )
        }

        return plan
    }
}

@MainActor
protocol ReminderScheduling: AnyObject {
    var deliveryCapabilities: ReminderDeliveryCapabilities { get }
    func permissionState() async -> NotificationPermissionState
    func requestPermission() async throws -> Bool
    func reconcile(_ snapshot: ReminderScheduleSnapshot) async throws
    func removeAllPulseNotifications() async
}

@MainActor
protocol ReminderLiveActivityScheduling: AnyObject {
    var capabilities: ReminderDeliveryCapabilities { get }
    func schedule(_ reminder: PlannedReminder, locale: Locale) async throws
    func removeAll() async
}

@MainActor
final class ActivityKitReminderLiveActivityScheduler: ReminderLiveActivityScheduling {
    var capabilities: ReminderDeliveryCapabilities {
        if #available(iOS 26.0, *) {
            return ReminderDeliveryCapabilities(
                supportsScheduledLiveActivities: true,
                liveActivitiesEnabled: ActivityAuthorizationInfo().areActivitiesEnabled
            )
        }
        return ReminderDeliveryCapabilities(
            supportsScheduledLiveActivities: false,
            liveActivitiesEnabled: false
        )
    }

    func schedule(_ reminder: PlannedReminder, locale: Locale) async throws {
        guard #available(iOS 26.0, *), capabilities.liveActivitiesEnabled else {
            throw PulseAppError.liveActivitiesUnavailable
        }

        let attributes = PulseReminderActivityAttributes(
            logicalDay: reminder.day.storageValue,
            localeIdentifier: locale.identifier
        )
        let content = ActivityContent(
            state: PulseReminderActivityAttributes.ContentState(),
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
            style: .transient,
            alertConfiguration: alert,
            start: reminder.deliveryDate
        )
    }

    func removeAll() async {
        for activity in Activity<PulseReminderActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

@MainActor
final class ReminderScheduler: ReminderScheduling {
    private let center: UNUserNotificationCenter
    private let liveActivityScheduler: any ReminderLiveActivityScheduling

    init(
        center: UNUserNotificationCenter = .current(),
        liveActivityScheduler: any ReminderLiveActivityScheduling = ActivityKitReminderLiveActivityScheduler()
    ) {
        self.center = center
        self.liveActivityScheduler = liveActivityScheduler
    }

    var deliveryCapabilities: ReminderDeliveryCapabilities {
        liveActivityScheduler.capabilities
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

    func reconcile(_ snapshot: ReminderScheduleSnapshot) async throws {
        await removePendingPulseNotifications()
        await removePulseLiveActivities()
        guard snapshot.enabled, snapshot.deliveryMode != .disabled else { return }

        let locale = Locale(identifier: snapshot.localeIdentifier)
        let plan = try ReminderSchedulePlanner.makePlan(for: snapshot)

        do {
            switch snapshot.deliveryMode {
            case .disabled:
                return
            case .localNotification:
                guard await permissionState() == .authorized else {
                    throw PulseAppError.notificationPermissionDenied
                }
                try await scheduleLocalNotifications(plan, locale: locale)
            case .scheduledLiveActivity:
                try await scheduleLiveActivities(plan, locale: locale)
            }
        } catch {
            await removePendingPulseNotifications()
            await removePulseLiveActivities()
            throw error
        }
    }

    func removeAllPulseNotifications() async {
        await removePendingPulseNotifications()
        await removePulseLiveActivities()
        let delivered = await center.deliveredNotifications()
        let identifiers = delivered
            .map(\.request.identifier)
            .filter { $0.hasPrefix(PulseRuntimeIdentity.reminderRequestPrefix) }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func removePendingPulseNotifications() async {
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(PulseRuntimeIdentity.reminderRequestPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func scheduleLocalNotifications(
        _ plan: [PlannedReminder],
        locale: Locale
    ) async throws {
        for reminder in plan {
            try Task.checkCancellation()

            let content = UNMutableNotificationContent()
            content.title = PulseLocalization.string("notification.title", locale: locale)
            content.body = PulseLocalization.string("notification.body", locale: locale)
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: PulseRuntimeIdentity.reminderRequestPrefix + reminder.day.storageValue,
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: reminder.triggerComponents,
                    repeats: false
                )
            )
            try await center.add(request)
        }
    }

    private func scheduleLiveActivities(
        _ plan: [PlannedReminder],
        locale: Locale
    ) async throws {
        guard liveActivityScheduler.capabilities.supportsScheduledLiveActivities,
              liveActivityScheduler.capabilities.liveActivitiesEnabled else {
            throw PulseAppError.liveActivitiesUnavailable
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
            throw PulseAppError.liveActivitySchedulingFailed
        }
    }

    private func removePulseLiveActivities() async {
        await liveActivityScheduler.removeAll()
    }
}
