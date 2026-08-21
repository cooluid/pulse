import Foundation
import PulseWatchShared

public enum PulseWatchSnapshotProjector {
    public static func makeSnapshot(
        habit: HabitSnapshot,
        records: [CheckInRecordSnapshot],
        waveMotionEnabled: Bool,
        at date: Date
    ) throws -> PulseWatchProjectSnapshot {
        let widgetSnapshot = try PulseWidgetProjector.makeSnapshot(
            habit: habit,
            records: records,
            at: date
        )
        let revision = PulseWatchProjectRevision.make(
            projectID: habit.id,
            startLogicalDay: habit.startLogicalDay.storageValue,
            timeZoneIdentifier: habit.timeZoneIdentifier
        )
        return PulseWatchProjectSnapshot(
            projectID: habit.id,
            projectRevision: revision,
            projectTimeZoneIdentifier: habit.timeZoneIdentifier,
            todayLogicalDay: widgetSnapshot.today.storageValue,
            isCheckedToday: widgetSnapshot.isCheckedToday,
            checkedAt: widgetSnapshot.checkedAt,
            waveMotionEnabled: waveMotionEnabled,
            sevenDayPulse: widgetSnapshot.recentDays.map { day in
                PulseWatchDaySnapshot(
                    logicalDay: day.day.storageValue,
                    state: watchState(day.state)
                )
            },
            generatedAt: widgetSnapshot.generatedAt,
            nextDayBoundary: widgetSnapshot.nextDayBoundary
        )
    }

    private static func watchState(
        _ state: PulseWidgetDayState
    ) -> PulseWatchDayState {
        switch state {
        case .beforeHabit: .beforeHabit
        case .checked: .checked
        case .missed: .missed
        case .todayPending: .todayPending
        }
    }
}
