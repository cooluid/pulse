import Foundation

public enum PulseDataContract {
    public static let formatIdentifier = "co.fanr.pulse.export"
    public static let fileExtension = "json"
    public static let exportSchemaVersion = 1
    public static let maximumRecordCount = 50_000
    public static let maximumImportBytes = 32 * 1_024 * 1_024

    public static func exportFilename(day: String?) -> String {
        "pulse-\(day ?? "export").\(fileExtension)"
    }
}

public struct PulseExportPayload: Codable, Sendable {
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

public enum PulseExportCodec {
    public static func encode(_ payload: PulseExportPayload) throws -> Data {
        guard payload.format == PulseDataContract.formatIdentifier,
              payload.schemaVersion == PulseDataContract.exportSchemaVersion else {
            throw PulseCoreError.exportUnavailable
        }
        _ = try PulseDataValidator.validate(payload)
        return try encoder.encode(payload)
    }

    public static func decode(_ data: Data) throws -> PulseExportPayload {
        let envelope = try decoder.decode(PulseExportEnvelope.self, from: data)
        guard envelope.format == PulseDataContract.formatIdentifier else {
            throw PulseCoreError.invalidImport
        }

        guard envelope.schemaVersion == PulseDataContract.exportSchemaVersion else {
            throw PulseCoreError.unsupportedImportVersion(envelope.schemaVersion)
        }
        let payload = try decoder.decode(PulseExportPayload.self, from: data)
        _ = try PulseDataValidator.validate(payload)
        return payload
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

private struct PulseExportEnvelope: Decodable {
    let format: String
    let schemaVersion: Int
}
