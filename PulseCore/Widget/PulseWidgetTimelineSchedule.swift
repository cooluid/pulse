import Foundation

public struct PulseWidgetTimelineEntry: Equatable, Sendable {
    public let date: Date
    public let snapshot: PulseWidgetSnapshot

    public init(
        date: Date,
        snapshot: PulseWidgetSnapshot
    ) {
        self.date = date
        self.snapshot = snapshot
    }
}

public enum PulseWidgetTimelineSchedule {
    public static func buildEntries(
        habit: HabitSnapshot,
        records: [CheckInRecordSnapshot],
        snapshot: PulseWidgetSnapshot,
        at date: Date
    ) throws -> [PulseWidgetTimelineEntry] {
        var entries: [PulseWidgetTimelineEntry] = [
            PulseWidgetTimelineEntry(
                date: date,
                snapshot: snapshot
            ),
        ]

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
                    snapshot: midnightSnapshot
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
