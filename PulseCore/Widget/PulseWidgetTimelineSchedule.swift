import Foundation

public enum PulseWidgetAmbientPeriod: String, CaseIterable, Sendable {
    case morning
    case daylight
    case evening

    public static let morningStartHour = 6
    public static let daylightStartHour = 12
    public static let eveningStartHour = 18

    public static func resolve(at date: Date, timeZone: TimeZone) -> Self {
        let hour = Calendar.pulseGregorian(timeZone: timeZone).component(.hour, from: date)
        switch hour {
        case morningStartHour..<daylightStartHour:
            return .morning
        case daylightStartHour..<eveningStartHour:
            return .daylight
        default:
            return .evening
        }
    }

    static func boundaries(
        after date: Date,
        before nextDayBoundary: Date,
        timeZone: TimeZone
    ) -> [Date] {
        let calendar = Calendar.pulseGregorian(timeZone: timeZone)
        let dayStart = calendar.startOfDay(for: date)

        return [morningStartHour, daylightStartHour, eveningStartHour].compactMap { hour in
            guard let boundary = calendar.date(byAdding: .hour, value: hour, to: dayStart),
                  boundary > date,
                  boundary < nextDayBoundary else {
                return nil
            }
            return boundary
        }
    }
}

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
        let ambientBoundaries = PulseWidgetAmbientPeriod.boundaries(
            after: date,
            before: midnightDate,
            timeZone: snapshot.projectTimeZone
        )
        for boundary in ambientBoundaries {
            let ambientSnapshot = try PulseWidgetProjector.makeSnapshot(
                habit: habit,
                records: records,
                at: boundary
            )
            entries.append(
                PulseWidgetTimelineEntry(
                    date: boundary,
                    snapshot: ambientSnapshot
                )
            )
        }

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
