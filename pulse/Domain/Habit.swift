import Foundation
import SwiftData

@Model
final class Habit {
    static let primarySlotKey = "primary"

    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var slotKey: String
    var name: String
    var createdAt: Date
    var timeZoneIdentifier: String
    var dayStartMinutes: Int
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        slotKey: String = Habit.primarySlotKey,
        name: String,
        createdAt: Date,
        timeZoneIdentifier: String,
        dayStartMinutes: Int = 0,
        isArchived: Bool = false
    ) {
        self.id = id
        self.slotKey = slotKey
        self.name = name
        self.createdAt = createdAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.dayStartMinutes = dayStartMinutes
        self.isArchived = isArchived
    }

    func resolvedTimeZone() throws -> TimeZone {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw PulseError.invalidTimeZone(timeZoneIdentifier)
        }
        return timeZone
    }

    func logicalDay(at date: Date) throws -> LogicalDay {
        LogicalDay.resolve(
            at: date,
            timeZone: try resolvedTimeZone(),
            dayStartMinutes: dayStartMinutes
        )
    }
}
