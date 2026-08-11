import Foundation

public enum CheckInCommitDisposition: Equatable, Sendable {
    case created
    case alreadyPresent
}

public struct CheckInCommitReceipt: Equatable, Sendable {
    public let recordID: UUID
    public let logicalDay: LogicalDay
    public let checkedAt: Date
    public let disposition: CheckInCommitDisposition

    public init(
        recordID: UUID,
        logicalDay: LogicalDay,
        checkedAt: Date,
        disposition: CheckInCommitDisposition
    ) {
        self.recordID = recordID
        self.logicalDay = logicalDay
        self.checkedAt = checkedAt
        self.disposition = disposition
    }
}
