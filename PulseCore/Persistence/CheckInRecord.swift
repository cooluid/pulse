import Foundation
import SwiftData

typealias CheckInRecord = PulseSchema.CheckInRecord

extension PulseSchema {
    @Model
    final class CheckInRecord {
        @Attribute(.unique) var id: UUID
        @Attribute(.unique) var recordKey: String
        var habitID: UUID
        var logicalDayValue: String
        var checkedAt: Date
        var createdAt: Date
        var timeZoneIdentifier: String
        var journalNote: String?
        var journalNoteModifiedAt: Date?

        init(
            id: UUID = UUID(),
            habitID: UUID,
            logicalDay: LogicalDay,
            checkedAt: Date,
            createdAt: Date,
            timeZoneIdentifier: String,
            journalNote: String? = nil,
            journalNoteModifiedAt: Date? = nil
        ) {
            self.id = id
            self.recordKey = CheckInRecordKey.make(habitID: habitID, logicalDay: logicalDay)
            self.habitID = habitID
            self.logicalDayValue = logicalDay.storageValue
            self.checkedAt = checkedAt
            self.createdAt = createdAt
            self.timeZoneIdentifier = timeZoneIdentifier
            self.journalNote = journalNote
            self.journalNoteModifiedAt = journalNoteModifiedAt
        }

        var logicalDay: LogicalDay? {
            LogicalDay(storageValue: logicalDayValue)
        }

        var timeZone: TimeZone? {
            TimeZone(identifier: timeZoneIdentifier)
        }
    }
}
