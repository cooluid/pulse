import Foundation
import SwiftData

@Model
final class Habit {
    static let primarySlotKey = "primary"

    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var slotKey: String
    var name: String
    var createdAt: Date
    var startLogicalDayValue: String
    var creationTimeZoneIdentifier: String
    var timeZoneIdentifier: String

    init(
        id: UUID = UUID(),
        slotKey: String = Habit.primarySlotKey,
        name: String,
        createdAt: Date,
        startLogicalDay: LogicalDay,
        creationTimeZoneIdentifier: String,
        timeZoneIdentifier: String
    ) {
        self.id = id
        self.slotKey = slotKey
        self.name = name
        self.createdAt = createdAt
        self.startLogicalDayValue = startLogicalDay.storageValue
        self.creationTimeZoneIdentifier = creationTimeZoneIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    var startLogicalDay: LogicalDay? {
        LogicalDay(storageValue: startLogicalDayValue)
    }

    func resolvedTimeZone() throws -> TimeZone {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw PulseError.invalidTimeZone(timeZoneIdentifier)
        }
        return timeZone
    }

    func logicalDay(at date: Date) throws -> LogicalDay {
        LogicalDay.resolve(at: date, timeZone: try resolvedTimeZone())
    }
}
