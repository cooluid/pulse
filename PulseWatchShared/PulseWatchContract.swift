import CryptoKit
import Foundation

public enum PulseWatchContract {
    public static let protocolVersion = 2
    public static let localStateVersion = 2
    public static let localDirectoryName = "PulseWatch"
    public static let localStateFilename = "pulse-watch-state.json"
    public static let snapshotContextKey = "pulse.watch.snapshot"
    public static let commandUserInfoKey = "pulse.watch.command"
    public static let receiptUserInfoKey = "pulse.watch.receipt"
    public static let snapshotRequestKey = "pulse.watch.snapshot.request"
    public static let circularKind = "PulseWatchTodayImprint"
    public static let rhythmKind = "PulseWatchSevenDayRhythm"
    public static let allWidgetKinds = [circularKind, rhythmKind]
    public static let missingSnapshotRetryInterval: TimeInterval = 15 * 60
}

public enum PulseWatchDayState: String, Codable, Equatable, Sendable {
    case beforeHabit
    case checked
    case missed
    case todayPending
}

public struct PulseWatchDaySnapshot: Codable, Equatable, Identifiable, Sendable {
    public let logicalDay: String
    public let state: PulseWatchDayState

    public var id: String { logicalDay }

    public init(logicalDay: String, state: PulseWatchDayState) {
        self.logicalDay = logicalDay
        self.state = state
    }
}

public struct PulseWatchProjectSnapshot: Codable, Equatable, Sendable {
    public let protocolVersion: Int
    public let projectID: UUID
    public let projectRevision: String
    public let projectTimeZoneIdentifier: String
    public let todayLogicalDay: String
    public let isCheckedToday: Bool
    public let checkedAt: Date?
    public let waveMotionEnabled: Bool
    public let sevenDayPulse: [PulseWatchDaySnapshot]
    public let generatedAt: Date
    public let nextDayBoundary: Date

    public init(
        projectID: UUID,
        projectRevision: String,
        projectTimeZoneIdentifier: String,
        todayLogicalDay: String,
        isCheckedToday: Bool,
        checkedAt: Date?,
        waveMotionEnabled: Bool,
        sevenDayPulse: [PulseWatchDaySnapshot],
        generatedAt: Date,
        nextDayBoundary: Date
    ) {
        precondition(sevenDayPulse.count == 7, "Watch snapshot requires seven days.")
        precondition(
            sevenDayPulse.last?.logicalDay == todayLogicalDay,
            "Watch snapshot must end on today."
        )
        precondition(nextDayBoundary > generatedAt, "Watch boundary must be in the future.")
        self.protocolVersion = PulseWatchContract.protocolVersion
        self.projectID = projectID
        self.projectRevision = projectRevision
        self.projectTimeZoneIdentifier = projectTimeZoneIdentifier
        self.todayLogicalDay = todayLogicalDay
        self.isCheckedToday = isCheckedToday
        self.checkedAt = checkedAt
        self.waveMotionEnabled = waveMotionEnabled
        self.sevenDayPulse = sevenDayPulse
        self.generatedAt = generatedAt
        self.nextDayBoundary = nextDayBoundary
    }

    private enum CodingKeys: String, CodingKey {
        case protocolVersion
        case projectID
        case projectRevision
        case projectTimeZoneIdentifier
        case todayLogicalDay
        case isCheckedToday
        case checkedAt
        case waveMotionEnabled
        case sevenDayPulse
        case generatedAt
        case nextDayBoundary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        protocolVersion = try container.decode(Int.self, forKey: .protocolVersion)
        projectID = try container.decode(UUID.self, forKey: .projectID)
        projectRevision = try container.decode(String.self, forKey: .projectRevision)
        projectTimeZoneIdentifier = try container.decode(
            String.self,
            forKey: .projectTimeZoneIdentifier
        )
        todayLogicalDay = try container.decode(String.self, forKey: .todayLogicalDay)
        isCheckedToday = try container.decode(Bool.self, forKey: .isCheckedToday)
        checkedAt = try container.decodeIfPresent(Date.self, forKey: .checkedAt)
        waveMotionEnabled = try container.decode(Bool.self, forKey: .waveMotionEnabled)
        sevenDayPulse = try container.decode(
            [PulseWatchDaySnapshot].self,
            forKey: .sevenDayPulse
        )
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        nextDayBoundary = try container.decode(Date.self, forKey: .nextDayBoundary)
    }
}

public struct PulseWatchSnapshotEnvelope: Codable, Equatable, Sendable {
    public let protocolVersion: Int
    public let snapshot: PulseWatchProjectSnapshot?
    public let generatedAt: Date

    public init(snapshot: PulseWatchProjectSnapshot?, generatedAt: Date) {
        self.protocolVersion = PulseWatchContract.protocolVersion
        self.snapshot = snapshot
        self.generatedAt = generatedAt
    }
}

public struct PulseWatchCheckInCommand: Codable, Equatable, Identifiable, Sendable {
    public let protocolVersion: Int
    public let operationID: UUID
    public let projectID: UUID
    public let projectRevision: String
    public let occurredAt: Date
    public let projectTimeZoneIdentifierSnapshot: String

    public var id: UUID { operationID }

    public init(
        operationID: UUID = UUID(),
        projectID: UUID,
        projectRevision: String,
        occurredAt: Date,
        projectTimeZoneIdentifierSnapshot: String
    ) {
        self.protocolVersion = PulseWatchContract.protocolVersion
        self.operationID = operationID
        self.projectID = projectID
        self.projectRevision = projectRevision
        self.occurredAt = occurredAt
        self.projectTimeZoneIdentifierSnapshot = projectTimeZoneIdentifierSnapshot
    }
}

public enum PulseWatchCommitDisposition: String, Codable, Equatable, Sendable {
    case created
    case alreadyPresent
}

public enum PulseWatchRejectionReason: String, Codable, Equatable, Error, Sendable {
    case incompatibleProtocol
    case projectChanged
    case timeZoneChanged
    case occurrenceInFuture
    case occurrenceBeforeProjectStart
    case invalidCommand
    case temporarilyUnavailable
    case persistenceFailure
}

public enum PulseWatchReceiptOutcome: Codable, Equatable, Sendable {
    case committed(
        logicalDay: String,
        checkedAt: Date,
        disposition: PulseWatchCommitDisposition
    )
    case rejected(reason: PulseWatchRejectionReason)
}

public struct PulseWatchCheckInReceipt: Codable, Equatable, Identifiable, Sendable {
    public let protocolVersion: Int
    public let operationID: UUID
    public let projectID: UUID
    public let projectRevision: String
    public let outcome: PulseWatchReceiptOutcome
    public let acknowledgedAt: Date

    public var id: UUID { operationID }

    public init(
        operationID: UUID,
        projectID: UUID,
        projectRevision: String,
        outcome: PulseWatchReceiptOutcome,
        acknowledgedAt: Date
    ) {
        self.protocolVersion = PulseWatchContract.protocolVersion
        self.operationID = operationID
        self.projectID = projectID
        self.projectRevision = projectRevision
        self.outcome = outcome
        self.acknowledgedAt = acknowledgedAt
    }
}

public enum PulseWatchDisplayState: Equatable, Sendable {
    case needsSync
    case ready
    case submitting
    case pendingSync
    case committed(checkedAt: Date?)
    case failed(PulseWatchRejectionReason)
}

public struct PulseWatchLocalProjection: Equatable, Sendable {
    public let snapshot: PulseWatchProjectSnapshot?
    public let pendingCommands: [PulseWatchCheckInCommand]
    public let lastReceipt: PulseWatchCheckInReceipt?
    public let storageFailure: Bool

    public init(
        snapshot: PulseWatchProjectSnapshot?,
        pendingCommands: [PulseWatchCheckInCommand],
        lastReceipt: PulseWatchCheckInReceipt?,
        storageFailure: Bool = false
    ) {
        self.snapshot = snapshot
        self.pendingCommands = pendingCommands
        self.lastReceipt = lastReceipt
        self.storageFailure = storageFailure
    }

    public static let storageUnavailable = PulseWatchLocalProjection(
        snapshot: nil,
        pendingCommands: [],
        lastReceipt: nil,
        storageFailure: true
    )

    public func displayState(at date: Date) -> PulseWatchDisplayState {
        if storageFailure {
            return .failed(.persistenceFailure)
        }
        if let pending = pendingCommands.last {
            guard let snapshot else {
                return .pendingSync
            }
            guard pending.projectID == snapshot.projectID,
                  pending.projectRevision == snapshot.projectRevision else {
                return .failed(.projectChanged)
            }
            guard pending.projectTimeZoneIdentifierSnapshot
                    == snapshot.projectTimeZoneIdentifier else {
                return .failed(.timeZoneChanged)
            }
            return .pendingSync
        }
        guard let snapshot else { return .needsSync }
        guard date < snapshot.nextDayBoundary else { return .needsSync }
        if let lastReceipt,
           case .committed(let logicalDay, let checkedAt, _) = lastReceipt.outcome,
           lastReceipt.projectID == snapshot.projectID,
           lastReceipt.projectRevision == snapshot.projectRevision,
           logicalDay == snapshot.todayLogicalDay {
            return .committed(checkedAt: checkedAt)
        }
        if let lastReceipt,
           case .rejected(let reason) = lastReceipt.outcome,
           lastReceipt.acknowledgedAt >= snapshot.generatedAt {
            return .failed(reason)
        }
        return snapshot.isCheckedToday
            ? .committed(checkedAt: snapshot.checkedAt)
            : .ready
    }
}

public struct PulseWatchCommandIdentity: Codable, Equatable, Sendable {
    public let protocolVersion: Int
    public let operationID: UUID
    public let projectID: UUID
    public let projectRevision: String
}

public enum PulseWatchProjectRevision {
    public static func make(
        projectID: UUID,
        startLogicalDay: String,
        timeZoneIdentifier: String
    ) -> String {
        let value = [
            projectID.uuidString.lowercased(),
            startLogicalDay,
            timeZoneIdentifier,
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

public enum PulseWatchCodecError: Error, Equatable, Sendable {
    case incompatibleProtocol
    case invalidPayload
}

public enum PulseWatchCodec {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    public static func decodeSnapshotEnvelope(
        from data: Data
    ) throws -> PulseWatchSnapshotEnvelope {
        let value = try JSONDecoder().decode(PulseWatchSnapshotEnvelope.self, from: data)
        guard value.protocolVersion == PulseWatchContract.protocolVersion else {
            throw PulseWatchCodecError.incompatibleProtocol
        }
        try validate(value)
        return value
    }

    public static func decodeCommand(from data: Data) throws -> PulseWatchCheckInCommand {
        let value = try JSONDecoder().decode(PulseWatchCheckInCommand.self, from: data)
        guard value.protocolVersion == PulseWatchContract.protocolVersion else {
            throw PulseWatchCodecError.incompatibleProtocol
        }
        try validate(value)
        return value
    }

    public static func decodeCommandIdentity(from data: Data) throws -> PulseWatchCommandIdentity {
        let value = try JSONDecoder().decode(PulseWatchCommandIdentity.self, from: data)
        guard isValidRevision(value.projectRevision) else {
            throw PulseWatchCodecError.invalidPayload
        }
        return value
    }

    public static func decodeReceipt(from data: Data) throws -> PulseWatchCheckInReceipt {
        let value = try JSONDecoder().decode(PulseWatchCheckInReceipt.self, from: data)
        guard value.protocolVersion == PulseWatchContract.protocolVersion else {
            throw PulseWatchCodecError.incompatibleProtocol
        }
        try validate(value)
        return value
    }

    public static func validate(_ envelope: PulseWatchSnapshotEnvelope) throws {
        guard envelope.protocolVersion == PulseWatchContract.protocolVersion,
              envelope.generatedAt.timeIntervalSinceReferenceDate.isFinite else {
            throw PulseWatchCodecError.invalidPayload
        }
        if let snapshot = envelope.snapshot {
            try validate(snapshot)
        }
    }

    public static func validate(_ snapshot: PulseWatchProjectSnapshot) throws {
        guard snapshot.protocolVersion == PulseWatchContract.protocolVersion,
              isValidRevision(snapshot.projectRevision),
              let timeZone = TimeZone(identifier: snapshot.projectTimeZoneIdentifier),
              snapshot.generatedAt.timeIntervalSinceReferenceDate.isFinite,
              snapshot.nextDayBoundary.timeIntervalSinceReferenceDate.isFinite,
              snapshot.nextDayBoundary > snapshot.generatedAt,
              snapshot.sevenDayPulse.count == 7,
              snapshot.sevenDayPulse.last?.logicalDay == snapshot.todayLogicalDay,
              Set(snapshot.sevenDayPulse.map(\.logicalDay)).count == 7,
              snapshot.isCheckedToday == (snapshot.checkedAt != nil),
              snapshot.sevenDayPulse.last?.state
                == (snapshot.isCheckedToday ? .checked : .todayPending) else {
            throw PulseWatchCodecError.invalidPayload
        }
        if let checkedAt = snapshot.checkedAt {
            guard checkedAt.timeIntervalSinceReferenceDate.isFinite,
                  logicalDay(at: checkedAt, timeZone: timeZone)
                    == snapshot.todayLogicalDay else {
                throw PulseWatchCodecError.invalidPayload
            }
        }
        let logicalDates = try snapshot.sevenDayPulse.map { day -> Date in
            guard day.state != .todayPending || day.logicalDay == snapshot.todayLogicalDay,
                  let date = logicalDayDate(day.logicalDay, timeZone: timeZone) else {
                throw PulseWatchCodecError.invalidPayload
            }
            return date
        }
        let calendar = gregorianCalendar(timeZone: timeZone)
        for index in logicalDates.indices.dropFirst() {
            guard calendar.date(byAdding: .day, value: 1, to: logicalDates[index - 1])
                    == logicalDates[index] else {
                throw PulseWatchCodecError.invalidPayload
            }
        }
    }

    public static func validate(_ command: PulseWatchCheckInCommand) throws {
        guard command.protocolVersion == PulseWatchContract.protocolVersion,
              isValidRevision(command.projectRevision),
              TimeZone(identifier: command.projectTimeZoneIdentifierSnapshot) != nil,
              command.occurredAt.timeIntervalSinceReferenceDate.isFinite else {
            throw PulseWatchCodecError.invalidPayload
        }
    }

    public static func validate(_ receipt: PulseWatchCheckInReceipt) throws {
        guard receipt.protocolVersion == PulseWatchContract.protocolVersion,
              isValidRevision(receipt.projectRevision),
              receipt.acknowledgedAt.timeIntervalSinceReferenceDate.isFinite else {
            throw PulseWatchCodecError.invalidPayload
        }
        if case .committed(let logicalDay, let checkedAt, _) = receipt.outcome {
            guard logicalDayDate(logicalDay, timeZone: .gmt) != nil,
                  checkedAt.timeIntervalSinceReferenceDate.isFinite,
                  checkedAt <= receipt.acknowledgedAt else {
                throw PulseWatchCodecError.invalidPayload
            }
        }
    }

    private static func isValidRevision(_ value: String) -> Bool {
        value.count == 64
            && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private static func logicalDay(
        at date: Date,
        timeZone: TimeZone
    ) -> String {
        let components = gregorianCalendar(timeZone: timeZone)
            .dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return ""
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func logicalDayDate(
        _ value: String,
        timeZone: TimeZone
    ) -> Date? {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }
        let calendar = gregorianCalendar(timeZone: timeZone)
        guard let date = calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day
        )) else {
            return nil
        }
        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        return resolved.year == year && resolved.month == month && resolved.day == day
            ? date
            : nil
    }

    private static func gregorianCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }
}
