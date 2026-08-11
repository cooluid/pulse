import Foundation

public struct HabitSnapshot: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let slotKey: String
    public let name: String
    public let purpose: String?
    public let isIdentityConfirmed: Bool
    public let createdAt: Date
    public let startLogicalDay: LogicalDay
    public let creationTimeZoneIdentifier: String
    public let timeZoneIdentifier: String
    public let creationTimeZone: TimeZone
    public let timeZone: TimeZone

    init(
        model: Habit,
        startLogicalDay: LogicalDay,
        creationTimeZone: TimeZone,
        timeZone: TimeZone
    ) {
        id = model.id
        slotKey = model.slotKey
        name = model.name
        purpose = model.purpose
        isIdentityConfirmed = model.isIdentityConfirmed
        createdAt = model.createdAt
        self.startLogicalDay = startLogicalDay
        creationTimeZoneIdentifier = model.creationTimeZoneIdentifier
        timeZoneIdentifier = model.timeZoneIdentifier
        self.creationTimeZone = creationTimeZone
        self.timeZone = timeZone
    }

    public func logicalDay(at date: Date) -> LogicalDay {
        LogicalDay.resolve(at: date, timeZone: timeZone)
    }
}
