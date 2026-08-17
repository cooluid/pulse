import Foundation

enum CheckInRecordKey {
    static func make(habitID: UUID, logicalDay: LogicalDay) -> String {
        "\(habitID.uuidString.lowercased()):\(logicalDay.storageValue)"
    }
}

public struct CheckInRecordSnapshot: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let habitID: UUID
    public let logicalDay: LogicalDay
    public let checkedAt: Date
    public let createdAt: Date
    public let timeZoneIdentifier: String
    public let timeZone: TimeZone
    public let journalNote: String?
    public let journalNoteModifiedAt: Date?

    init(model: CheckInRecord, logicalDay: LogicalDay, timeZone: TimeZone) {
        id = model.id
        habitID = model.habitID
        self.logicalDay = logicalDay
        checkedAt = model.checkedAt
        createdAt = model.createdAt
        timeZoneIdentifier = model.timeZoneIdentifier
        self.timeZone = timeZone
        journalNote = model.journalNote
        journalNoteModifiedAt = model.journalNoteModifiedAt
    }
}
