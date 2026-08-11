import Foundation

enum CheckInCommitDisposition: Equatable, Sendable {
    case created
    case alreadyPresent
}

struct CheckInCommitReceipt: Equatable, Sendable {
    let recordID: UUID
    let logicalDay: LogicalDay
    let checkedAt: Date
    let disposition: CheckInCommitDisposition
}
