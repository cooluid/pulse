import Foundation

public enum PulseWidgetContract {
    public static let kind = "PulseDailyImprint"
    public static let showsHabitNamePreferenceKey = "widget.showsHabitName"
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
    public let today: LogicalDay
    public let checkedAt: Date?
    public let recentDays: [PulseWidgetDaySnapshot]
    public let visibleHabitName: String?
    public let generatedAt: Date
    public let nextDayBoundary: Date

    public var isCheckedToday: Bool { checkedAt != nil }

    public init(
        habitID: UUID,
        today: LogicalDay,
        checkedAt: Date?,
        recentDays: [PulseWidgetDaySnapshot],
        visibleHabitName: String?,
        generatedAt: Date,
        nextDayBoundary: Date
    ) {
        precondition(recentDays.count == 7, "Widget snapshot requires exactly seven days.")
        precondition(recentDays.last?.day == today, "Widget snapshot must end on today.")
        precondition(nextDayBoundary > generatedAt, "Widget refresh boundary must be in the future.")
        self.habitID = habitID
        self.today = today
        self.checkedAt = checkedAt
        self.recentDays = recentDays
        self.visibleHabitName = visibleHabitName
        self.generatedAt = generatedAt
        self.nextDayBoundary = nextDayBoundary
    }
}

public struct PulseWidgetTimelinePlan: Equatable, Sendable {
    public let snapshot: PulseWidgetSnapshot
    public let refreshAfter: Date

    public init(snapshot: PulseWidgetSnapshot) {
        self.snapshot = snapshot
        refreshAfter = snapshot.nextDayBoundary
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
        at date: Date,
        showsHabitName: Bool
    ) throws -> PulseWidgetTimelinePlan {
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

        let snapshot = PulseWidgetSnapshot(
            habitID: habit.id,
            today: today,
            checkedAt: recordsByDay[today]?.checkedAt,
            recentDays: recentDays,
            visibleHabitName: showsHabitName && habit.isIdentityConfirmed
                ? habit.name
                : nil,
            generatedAt: date,
            nextDayBoundary: nextDayBoundary
        )
        return PulseWidgetTimelinePlan(snapshot: snapshot)
    }
}

@MainActor
public enum PulseWidgetSnapshotReader {
    public static func readTimelinePlan(
        repository: any CheckInRepositoryProtocol,
        at date: Date,
        showsHabitName: Bool
    ) throws -> PulseWidgetTimelinePlan? {
        guard let habit = try repository.existingPrimaryHabit() else { return nil }
        let records = try repository.allRecords(habitID: habit.id)
        return try PulseWidgetProjector.makeTimelinePlan(
            habit: habit,
            records: records,
            at: date,
            showsHabitName: showsHabitName
        )
    }
}
