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
            throw PulseError.invalidTimeZone(snapshot.timeZoneIdentifier)
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
    func permissionState() async -> NotificationPermissionState
    func requestPermission() async throws -> Bool
    func reconcile(_ snapshot: ReminderScheduleSnapshot) async throws
    func removeAllPulseNotifications() async
}

@MainActor
final class ReminderScheduler: ReminderScheduling {
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

        let locale = Locale(identifier: snapshot.localeIdentifier)

        do {
            for reminder in try ReminderSchedulePlanner.makePlan(for: snapshot) {
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
