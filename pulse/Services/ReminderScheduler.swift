import Foundation
import UserNotifications

enum NotificationPermissionState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}

@MainActor
protocol ReminderScheduling: AnyObject {
    func permissionState() async -> NotificationPermissionState
    func requestPermission() async throws -> Bool
    func reconcile(
        enabled: Bool,
        time: ReminderTime,
        habit: Habit,
        checkedDays: Set<LogicalDay>,
        now: Date
    ) async throws
    func removeAllPulseNotifications() async
}

@MainActor
final class ReminderScheduler: ReminderScheduling {
    private enum Configuration {
        static let schedulingWindowDays = 30
    }

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

    func reconcile(
        enabled: Bool,
        time: ReminderTime,
        habit: Habit,
        checkedDays: Set<LogicalDay>,
        now: Date
    ) async throws {
        await removePendingPulseNotifications()
        guard enabled else { return }
        guard await permissionState() == .authorized else {
            throw PulseError.notificationPermissionDenied
        }

        let timeZone = try habit.resolvedTimeZone()
        let today = try habit.logicalDay(at: now)
        let calendar = Calendar.pulseGregorian(timeZone: timeZone)

        for offset in 0..<Configuration.schedulingWindowDays {
            let day = today.addingDays(offset, timeZone: timeZone)
            guard !checkedDays.contains(day) else { continue }

            var components = DateComponents()
            components.calendar = calendar
            components.timeZone = timeZone
            components.year = day.year
            components.month = day.month
            components.day = day.day
            components.hour = time.hour
            components.minute = time.minute

            guard let deliveryDate = calendar.date(from: components), deliveryDate > now else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "notification.title")
            content.body = String(localized: "notification.body")
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: PulseRuntimeIdentity.reminderRequestPrefix + day.storageValue,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try await center.add(request)
        }
    }

    func removeAllPulseNotifications() async {
        await removePendingPulseNotifications()
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
}
