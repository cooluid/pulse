import Foundation
import SwiftData

enum CheckInSource: String, Codable, Sendable {
    case manual
}

@Model
final class CheckInRecord {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var recordKey: String
    var habitID: UUID
    var logicalDayValue: String
    var checkedAt: Date
    var createdAt: Date
    var sourceRawValue: String

    init(
        id: UUID = UUID(),
        habitID: UUID,
        logicalDay: LogicalDay,
        checkedAt: Date,
        createdAt: Date,
        source: CheckInSource
    ) {
        self.id = id
        self.recordKey = Self.makeRecordKey(habitID: habitID, logicalDay: logicalDay)
        self.habitID = habitID
        self.logicalDayValue = logicalDay.storageValue
        self.checkedAt = checkedAt
        self.createdAt = createdAt
        self.sourceRawValue = source.rawValue
    }

    var logicalDay: LogicalDay? {
        LogicalDay(storageValue: logicalDayValue)
    }

    var source: CheckInSource? {
        CheckInSource(rawValue: sourceRawValue)
    }

    static func makeRecordKey(habitID: UUID, logicalDay: LogicalDay) -> String {
        "\(habitID.uuidString.lowercased()):\(logicalDay.storageValue)"
    }
}

