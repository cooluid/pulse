import Foundation
import UserNotifications

enum NotificationPermissionState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}

struct ReminderScheduleSnapshot: Sendable {
    let enabled: Bool
    let time: ReminderTime
    let timeZoneIdentifier: String
    let localeIdentifier: String
    let checkedDays: Set<LogicalDay>
    let now: Date
}

@MainActor
protocol ReminderScheduling: AnyObject {
    func permissionState() async -> NotificationPermissionState
    func requestPermission() async throws -> Bool
    func reconcile(_ snapshot: ReminderScheduleSnapshot) async throws
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

    func reconcile(_ snapshot: ReminderScheduleSnapshot) async throws {
        await removePendingPulseNotifications()
        guard snapshot.enabled else { return }
        guard await permissionState() == .authorized else {
            throw PulseError.notificationPermissionDenied
        }

        guard let timeZone = TimeZone(identifier: snapshot.timeZoneIdentifier) else {
            throw PulseError.invalidTimeZone(snapshot.timeZoneIdentifier)
        }
        let today = LogicalDay.resolve(at: snapshot.now, timeZone: timeZone)
        let calendar = Calendar.pulseGregorian(timeZone: timeZone)
        let locale = Locale(identifier: snapshot.localeIdentifier)

        do {
            for offset in 0..<Configuration.schedulingWindowDays {
                try Task.checkCancellation()
                let day = today.addingDays(offset, timeZone: timeZone)
                guard !snapshot.checkedDays.contains(day) else { continue }

                var components = DateComponents()
                components.calendar = calendar
                components.timeZone = timeZone
                components.year = day.year
                components.month = day.month
                components.day = day.day
                components.hour = snapshot.time.hour
                components.minute = snapshot.time.minute

                guard let deliveryDate = calendar.date(from: components),
                      deliveryDate > snapshot.now else {
                    continue
                }

                let content = UNMutableNotificationContent()
                content.title = PulseLocalization.string("notification.title", locale: locale)
                content.body = PulseLocalization.string("notification.body", locale: locale)
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: PulseRuntimeIdentity.reminderRequestPrefix + day.storageValue,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                )
                try await center.add(request)
            }
        } catch {
            await removePendingPulseNotifications()
            throw error
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
