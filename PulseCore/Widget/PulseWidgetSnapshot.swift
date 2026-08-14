import Foundation

public enum PulseWidgetContract {
    public static let homeKind = "PulseDailyImprint"
    public static let accessoryKind = "PulseAccessoryRhythm"
    public static let allKinds = [homeKind, accessoryKind]
}

public enum PulseWidgetDayState: String, Codable, Equatable, Sendable {
    case beforeHabit
    case checked
    case missed
    case todayPending
}

public struct PulseWidgetDaySnapshot: Codable, Equatable, Identifiable, Sendable {
    public let day: LogicalDay
    public let state: PulseWidgetDayState

    public var id: LogicalDay { day }

    public init(day: LogicalDay, state: PulseWidgetDayState) {
        self.day = day
        self.state = state
    }
}

public struct PulseWidgetSnapshot: Codable, Equatable, Sendable {
    public let habitID: UUID
    public let habitName: String
    public let today: LogicalDay
    public let checkedAt: Date?
    public let recentDays: [PulseWidgetDaySnapshot]
    public let generatedAt: Date
    public let nextDayBoundary: Date
    public let projectTimeZoneIdentifier: String

    public var projectTimeZone: TimeZone {
        TimeZone(identifier: projectTimeZoneIdentifier) ?? .current
    }

    public var isCheckedToday: Bool { checkedAt != nil }
    public var recentCheckedCount: Int {
        recentDays.filter { $0.state == .checked }.count
    }
    public var previousSixCheckedCount: Int {
        recentDays.dropLast().filter { $0.state == .checked }.count
    }

    public init(
        habitID: UUID,
        habitName: String,
        today: LogicalDay,
        checkedAt: Date?,
        recentDays: [PulseWidgetDaySnapshot],
        generatedAt: Date,
        nextDayBoundary: Date,
        projectTimeZoneIdentifier: String
    ) {
        precondition(recentDays.count == 7, "Widget snapshot requires exactly seven days.")
        precondition(recentDays.last?.day == today, "Widget snapshot must end on today.")
        precondition(nextDayBoundary > generatedAt, "Widget refresh boundary must be in the future.")
        precondition(
            TimeZone(identifier: projectTimeZoneIdentifier) != nil,
            "Widget snapshot requires a valid project time zone identifier."
        )
        self.habitID = habitID
        self.habitName = habitName
        self.today = today
        self.checkedAt = checkedAt
        self.recentDays = recentDays
        self.generatedAt = generatedAt
        self.nextDayBoundary = nextDayBoundary
        self.projectTimeZoneIdentifier = projectTimeZoneIdentifier
    }
}

public struct PulseWidgetTimelinePlan: Equatable, Sendable {
    public let entries: [PulseWidgetTimelineEntry]

    public var snapshot: PulseWidgetSnapshot {
        guard let first = entries.first else {
            preconditionFailure("Widget timeline plan requires at least one entry.")
        }
        return first.snapshot
    }

    public var reloadAfter: Date {
        guard let last = entries.last else {
            preconditionFailure("Widget timeline plan requires at least one entry.")
        }
        return last.date
    }

    public init(entries: [PulseWidgetTimelineEntry]) {
        precondition(!entries.isEmpty, "Widget timeline plan requires at least one entry.")
        let sorted = entries.sorted { $0.date < $1.date }
        precondition(
            sorted.map(\.date) == entries.map(\.date),
            "Widget timeline entries must be strictly chronological."
        )
        self.entries = entries
    }
}

public enum PulseWidgetProjectionError: Error, Equatable, Sendable {
    case identityNotConfirmed
    case recordBelongsToAnotherHabit
    case duplicateLogicalDay
    case invalidNextDayBoundary
}

public enum PulseWidgetProjector {
    public static func makeTimelinePlan(
        habit: HabitSnapshot,
        records: [CheckInRecordSnapshot],
        at date: Date
    ) throws -> PulseWidgetTimelinePlan {
        let snapshot = try makeSnapshot(habit: habit, records: records, at: date)
        let entries = try PulseWidgetTimelineSchedule.buildEntries(
            habit: habit,
            records: records,
            snapshot: snapshot,
            at: date
        )
        return PulseWidgetTimelinePlan(entries: entries)
    }

    public static func makeSnapshot(
        habit: HabitSnapshot,
        records: [CheckInRecordSnapshot],
        at date: Date
    ) throws -> PulseWidgetSnapshot {
        guard habit.isIdentityConfirmed else {
            throw PulseWidgetProjectionError.identityNotConfirmed
        }
        var recordsByDay: [LogicalDay: CheckInRecordSnapshot] = [:]
        for record in records {
            guard record.habitID == habit.id else {
                throw PulseWidgetProjectionError.recordBelongsToAnotherHabit
            }
            guard recordsByDay.updateValue(record, forKey: record.logicalDay) == nil else {
                throw PulseWidgetProjectionError.duplicateLogicalDay
            }
        }

        let today = habit.logicalDay(at: date)
        let recentDays = (-6...0).map { offset in
            let day = today.addingDays(offset, timeZone: habit.timeZone)
            let state: PulseWidgetDayState
            if day < habit.startLogicalDay {
                state = .beforeHabit
            } else if recordsByDay[day] != nil {
                state = .checked
            } else if day == today {
                state = .todayPending
            } else {
                state = .missed
            }
            return PulseWidgetDaySnapshot(day: day, state: state)
        }

        let nextDayBoundary = today
            .addingDays(1, timeZone: habit.timeZone)
            .startDate(timeZone: habit.timeZone)
        guard nextDayBoundary > date else {
            throw PulseWidgetProjectionError.invalidNextDayBoundary
        }

        return PulseWidgetSnapshot(
            habitID: habit.id,
            habitName: habit.name,
            today: today,
            checkedAt: recordsByDay[today]?.checkedAt,
            recentDays: recentDays,
            generatedAt: date,
            nextDayBoundary: nextDayBoundary,
            projectTimeZoneIdentifier: habit.timeZoneIdentifier
        )
    }
}

@MainActor
public enum PulseWidgetSnapshotReader {
    public static func readTimelinePlan(
        repository: any PulseRepositoryProtocol,
        at date: Date
    ) throws -> PulseWidgetTimelinePlan? {
        guard let habit = try repository.existingPrimaryHabit() else { return nil }
        let records = try repository.allRecords(habitID: habit.id)
        return try PulseWidgetProjector.makeTimelinePlan(
            habit: habit,
            records: records,
            at: date
        )
    }
}
