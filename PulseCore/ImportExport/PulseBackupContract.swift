import Foundation

public enum PulseBackupContract {
    public static let contentTypeIdentifier = "co.fanr.pulse.backup"
    public static let fileExtension = "pulsebackup"
    public static let payloadFormatIdentifier = "co.fanr.pulse.payload"
    public static let payloadSchemaVersion = 1
    public static let containerVersion: UInt16 = 1
    public static let keyDerivationIdentifier: UInt8 = 1
    public static let cipherIdentifier: UInt8 = 1
    public static let keyDerivationIterations: UInt32 = 600_000
    public static let saltByteCount = 16
    public static let nonceByteCount = 12
    public static let authenticationTagByteCount = 16
    public static let minimumPassphraseCharacterCount = 12
    public static let maximumPassphraseByteCount = 1_024
    public static let maximumRecordCount = 50_000
    public static let maximumBackupBytes = 32 * 1_024 * 1_024

    static let magic = Data("PULSEBKP".utf8)
    static let fixedHeaderByteCount = 28
    static let maximumPayloadBytes = maximumBackupBytes
        - fixedHeaderByteCount
        - saltByteCount
        - nonceByteCount
        - authenticationTagByteCount

    public static func filename(day: String?) -> String {
        "pulse-\(day ?? "backup").\(fileExtension)"
    }
}

public struct PulseBackupPayload: Codable, Sendable {
    public struct HabitPayload: Codable, Sendable {
        public let id: UUID
        public let name: String
        public let purpose: String?
        public let isIdentityConfirmed: Bool
        public let createdAt: Date
        public let startLogicalDay: String
        public let creationTimeZoneIdentifier: String
        public let timeZoneIdentifier: String

        public init(
            id: UUID,
            name: String,
            purpose: String?,
            isIdentityConfirmed: Bool,
            createdAt: Date,
            startLogicalDay: String,
            creationTimeZoneIdentifier: String,
            timeZoneIdentifier: String
        ) {
            self.id = id
            self.name = name
            self.purpose = purpose
            self.isIdentityConfirmed = isIdentityConfirmed
            self.createdAt = createdAt
            self.startLogicalDay = startLogicalDay
            self.creationTimeZoneIdentifier = creationTimeZoneIdentifier
            self.timeZoneIdentifier = timeZoneIdentifier
        }
    }

    public struct RecordPayload: Codable, Sendable {
        public let id: UUID
        public let logicalDay: String
        public let checkedAt: Date
        public let createdAt: Date
        public let timeZoneIdentifier: String

        public init(
            id: UUID,
            logicalDay: String,
            checkedAt: Date,
            createdAt: Date,
            timeZoneIdentifier: String
        ) {
            self.id = id
            self.logicalDay = logicalDay
            self.checkedAt = checkedAt
            self.createdAt = createdAt
            self.timeZoneIdentifier = timeZoneIdentifier
        }
    }

    public let format: String
    public let schemaVersion: Int
    public let exportedAt: Date
    public let habit: HabitPayload
    public let records: [RecordPayload]

    public init(
        format: String,
        schemaVersion: Int,
        exportedAt: Date,
        habit: HabitPayload,
        records: [RecordPayload]
    ) {
        self.format = format
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.habit = habit
        self.records = records
    }
}

public enum PulseBackupPayloadCodec {
    public static func encode(_ payload: PulseBackupPayload) throws -> Data {
        guard payload.format == PulseBackupContract.payloadFormatIdentifier,
              payload.schemaVersion == PulseBackupContract.payloadSchemaVersion else {
            throw PulseCoreError.backupUnavailable
        }
        _ = try PulseDataValidator.validate(payload)
        let data = try encoder.encode(payload)
        guard data.count <= PulseBackupContract.maximumPayloadBytes else {
            throw PulseCoreError.backupUnavailable
        }
        return data
    }

    public static func decode(_ data: Data) throws -> PulseBackupPayload {
        guard data.count <= PulseBackupContract.maximumPayloadBytes else {
            throw PulseCoreError.invalidBackup
        }
        let envelope: PulseBackupPayloadEnvelope
        do {
            envelope = try decoder.decode(PulseBackupPayloadEnvelope.self, from: data)
        } catch {
            throw PulseCoreError.invalidBackup
        }
        guard envelope.format == PulseBackupContract.payloadFormatIdentifier else {
            throw PulseCoreError.invalidBackup
        }
        guard envelope.schemaVersion == PulseBackupContract.payloadSchemaVersion else {
            throw PulseCoreError.unsupportedBackupPayloadVersion(envelope.schemaVersion)
        }
        do {
            let payload = try decoder.decode(PulseBackupPayload.self, from: data)
            _ = try PulseDataValidator.validate(payload)
            return payload
        } catch let error as PulseCoreError {
            throw error
        } catch {
            throw PulseCoreError.invalidBackup
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private struct PulseBackupPayloadEnvelope: Decodable {
    let format: String
    let schemaVersion: Int
}
