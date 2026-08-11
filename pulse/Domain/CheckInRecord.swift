import Foundation
import SwiftData

typealias CheckInRecord = PulseSchemaV2.CheckInRecord

extension PulseSchemaV2 {
    @Model
    final class CheckInRecord {
        @Attribute(.unique) var id: UUID
        @Attribute(.unique) var recordKey: String
        var habitID: UUID
        var logicalDayValue: String
        var checkedAt: Date
        var createdAt: Date
        var timeZoneIdentifier: String

        init(
            id: UUID = UUID(),
            habitID: UUID,
            logicalDay: LogicalDay,
            checkedAt: Date,
            createdAt: Date,
            timeZoneIdentifier: String
        ) {
            self.id = id
            self.recordKey = Self.makeRecordKey(habitID: habitID, logicalDay: logicalDay)
            self.habitID = habitID
            self.logicalDayValue = logicalDay.storageValue
            self.checkedAt = checkedAt
            self.createdAt = createdAt
            self.timeZoneIdentifier = timeZoneIdentifier
        }

        var logicalDay: LogicalDay? {
            LogicalDay(storageValue: logicalDayValue)
        }

        var timeZone: TimeZone? {
            TimeZone(identifier: timeZoneIdentifier)
        }

        static func makeRecordKey(habitID: UUID, logicalDay: LogicalDay) -> String {
            "\(habitID.uuidString.lowercased()):\(logicalDay.storageValue)"
        }
    }
}
