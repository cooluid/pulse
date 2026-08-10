import Foundation
import Observation

enum WeekStart: Int, CaseIterable, Identifiable, Sendable {
    case sunday = 1
    case monday = 2

    var id: Int { rawValue }

    var localizedName: String {
        switch self {
        case .sunday: String(localized: "settings.week_start.sunday")
        case .monday: String(localized: "settings.week_start.monday")
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    enum StorageKey {
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let reminderEnabled = "settings.reminderEnabled"
        static let reminderTimeMinutes = "settings.reminderTimeMinutes"
        static let weekStart = "settings.weekStart"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isLoading = true

    var hapticsEnabled: Bool {
        didSet { persist(StorageKey.hapticsEnabled, value: hapticsEnabled) }
    }

    private(set) var reminderEnabled: Bool {
        didSet { persist(StorageKey.reminderEnabled, value: reminderEnabled) }
    }

    var reminderTime: ReminderTime {
        didSet { persist(StorageKey.reminderTimeMinutes, value: reminderTime.minutesFromMidnight) }
    }

    var weekStart: WeekStart {
        didSet { persist(StorageKey.weekStart, value: weekStart.rawValue) }
    }

    init(defaults: UserDefaults = .standard) throws {
        self.defaults = defaults
        defaults.register(defaults: [
            StorageKey.hapticsEnabled: true,
            StorageKey.reminderEnabled: false,
            StorageKey.reminderTimeMinutes: ReminderTime.standard.minutesFromMidnight,
            StorageKey.weekStart: WeekStart.monday.rawValue
        ])

        guard let loadedReminderTime = ReminderTime(
            minutesFromMidnight: defaults.integer(forKey: StorageKey.reminderTimeMinutes)
        ), let loadedWeekStart = WeekStart(rawValue: defaults.integer(forKey: StorageKey.weekStart)) else {
            throw PulseError.invalidSettings
        }

        hapticsEnabled = defaults.bool(forKey: StorageKey.hapticsEnabled)
        reminderEnabled = defaults.bool(forKey: StorageKey.reminderEnabled)
        reminderTime = loadedReminderTime
        weekStart = loadedWeekStart
        isLoading = false
    }

    func setReminderEnabled(_ enabled: Bool) {
        reminderEnabled = enabled
    }

    func reset() {
        isLoading = true
        [
            StorageKey.hapticsEnabled,
            StorageKey.reminderEnabled,
            StorageKey.reminderTimeMinutes,
            StorageKey.weekStart
        ].forEach(defaults.removeObject(forKey:))

        hapticsEnabled = true
        reminderEnabled = false
        reminderTime = .standard
        weekStart = .monday
        isLoading = false
    }

    private func persist(_ key: String, value: Any) {
        guard !isLoading else { return }
        defaults.set(value, forKey: key)
    }
}
