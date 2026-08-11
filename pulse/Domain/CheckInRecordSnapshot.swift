import Foundation

enum CheckInRecordKey {
    static func make(habitID: UUID, logicalDay: LogicalDay) -> String {
        "\(habitID.uuidString.lowercased()):\(logicalDay.storageValue)"
    }
}

struct CheckInRecordSnapshot: Equatable, Identifiable, Sendable {
    let id: UUID
    let recordKey: String
    let habitID: UUID
    let logicalDayValue: String
    let checkedAt: Date
    let createdAt: Date
    let timeZoneIdentifier: String

    init(model: CheckInRecord) {
        id = model.id
        recordKey = model.recordKey
        habitID = model.habitID
        logicalDayValue = model.logicalDayValue
        checkedAt = model.checkedAt
        createdAt = model.createdAt
        timeZoneIdentifier = model.timeZoneIdentifier
    }

    var logicalDay: LogicalDay? {
        LogicalDay(storageValue: logicalDayValue)
    }

    var timeZone: TimeZone? {
        TimeZone(identifier: timeZoneIdentifier)
    }
}
