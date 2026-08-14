import Foundation

public struct PulseWidgetTimelineEntry: Equatable, Sendable {
    public let date: Date
    public let snapshot: PulseWidgetSnapshot
    public let variant: PulseWidgetVisualVariant

    public init(
        date: Date,
        snapshot: PulseWidgetSnapshot,
        variant: PulseWidgetVisualVariant
    ) {
        self.date = date
        self.snapshot = snapshot
        self.variant = variant
    }
}

public enum PulseWidgetTimelineSchedule {
    public static func buildEntries(
        habit: HabitSnapshot,
        records: [CheckInRecordSnapshot],
        snapshot: PulseWidgetSnapshot,
        at date: Date,
        includePhaseKeyframes: Bool
    ) throws -> [PulseWidgetTimelineEntry] {
        let timeZone = habit.timeZone
        var entries: [PulseWidgetTimelineEntry] = [
            PulseWidgetTimelineEntry(
                date: date,
                snapshot: snapshot,
                variant: PulseWidgetVisualVariant.make(
                    for: snapshot.today,
                    at: date,
                    timeZone: timeZone
                )
            ),
        ]

        if includePhaseKeyframes {
            let phaseBoundaries = PulseWidgetDayPhase.upcomingPhaseBoundaries(
                after: date,
                before: snapshot.nextDayBoundary,
                timeZone: timeZone
            )
            for boundary in phaseBoundaries {
                entries.append(
                    PulseWidgetTimelineEntry(
                        date: boundary,
                        snapshot: snapshot,
                        variant: PulseWidgetVisualVariant.make(
                            for: snapshot.today,
                            at: boundary,
                            timeZone: timeZone
                        )
                    )
                )
            }
        }

        let midnightDate = snapshot.nextDayBoundary
        if entries.last?.date != midnightDate {
            let midnightSnapshot = try PulseWidgetProjector.makeSnapshot(
                habit: habit,
                records: records,
                at: midnightDate
            )
            entries.append(
                PulseWidgetTimelineEntry(
                    date: midnightDate,
                    snapshot: midnightSnapshot,
                    variant: PulseWidgetVisualVariant.make(
                        for: midnightSnapshot.today,
                        at: midnightDate,
                        timeZone: timeZone
                    )
                )
            )
        }

        return deduplicatedSortedEntries(entries)
    }

    private static func deduplicatedSortedEntries(
        _ entries: [PulseWidgetTimelineEntry]
    ) -> [PulseWidgetTimelineEntry] {
        let sorted = entries.sorted { $0.date < $1.date }
        var result: [PulseWidgetTimelineEntry] = []
        result.reserveCapacity(sorted.count)

        for entry in sorted {
            if result.last?.date == entry.date {
                result[result.count - 1] = entry
            } else {
                result.append(entry)
            }
        }
        return result
    }
}
