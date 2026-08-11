import Foundation

struct HabitSnapshot: Equatable, Identifiable, Sendable {
    let id: UUID
    let slotKey: String
    let name: String
    let purpose: String?
    let isIdentityConfirmed: Bool
    let createdAt: Date
    let startLogicalDayValue: String
    let creationTimeZoneIdentifier: String
    let timeZoneIdentifier: String

    init(model: Habit) {
        id = model.id
        slotKey = model.slotKey
        name = model.name
        purpose = model.purpose
        isIdentityConfirmed = model.isIdentityConfirmed
        createdAt = model.createdAt
        startLogicalDayValue = model.startLogicalDayValue
        creationTimeZoneIdentifier = model.creationTimeZoneIdentifier
        timeZoneIdentifier = model.timeZoneIdentifier
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
