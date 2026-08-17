import Foundation

public enum PulseBackupContract {
    public static let contentTypeIdentifier = "co.fanr.pulse.backup"
    public static let fileExtension = "pulsebackup"
    public static let payloadFormatIdentifier = "co.fanr.pulse.payload"
    public static let payloadSchemaVersion = 3
    public static let containerVersion: UInt16 = 2
    public static let keyDerivationIdentifier: UInt8 = 1
    public static let cipherIdentifier: UInt8 = 1
    public static let keyDerivationIterations: UInt32 = 600_000
    public static let saltByteCount = 16
    public static let nonceByteCount = 12
    public static let authenticationTagByteCount = 16
    public static let minimumPassphraseCharacterCount = 4
    public static let maximumPassphraseByteCount = 1_024
    public static let maximumRecordCount = 50_000
    public static let maximumMediaCount = 20_000
    public static let maximumManifestBytes = 16 * 1_024 * 1_024
    public static let maximumBackupBytes: UInt64 = 512 * 1_024 * 1_024 * 1_024

    public static func accepts(passphrase: String) -> Bool {
        passphrase.count >= minimumPassphraseCharacterCount
            && passphrase.utf8.count <= maximumPassphraseByteCount
    }

    static let magic = Data("PULSEBKP".utf8)
    public static let fixedHeaderByteCount = 24
    static let entryFixedHeaderByteCount = 24

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
        public let journalNote: String?
        public let journalNoteModifiedAt: Date?

        public init(
            id: UUID,
            logicalDay: String,
            checkedAt: Date,
            createdAt: Date,
            timeZoneIdentifier: String,
            journalNote: String? = nil,
            journalNoteModifiedAt: Date? = nil
        ) {
            self.id = id
            self.logicalDay = logicalDay
            self.checkedAt = checkedAt
            self.createdAt = createdAt
            self.timeZoneIdentifier = timeZoneIdentifier
            self.journalNote = journalNote
            self.journalNoteModifiedAt = journalNoteModifiedAt
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case logicalDay
            case checkedAt
            case createdAt
            case timeZoneIdentifier
            case journalNote
            case journalNoteModifiedAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            guard container.contains(.journalNote),
                  container.contains(.journalNoteModifiedAt) else {
                throw DecodingError.keyNotFound(
                    container.contains(.journalNote)
                        ? CodingKeys.journalNoteModifiedAt
                        : CodingKeys.journalNote,
                    .init(
                        codingPath: container.codingPath,
                        debugDescription: "Pulse backup record is missing required journal fields."
                    )
                )
            }
            id = try container.decode(UUID.self, forKey: .id)
            logicalDay = try container.decode(String.self, forKey: .logicalDay)
            checkedAt = try container.decode(Date.self, forKey: .checkedAt)
            createdAt = try container.decode(Date.self, forKey: .createdAt)
            timeZoneIdentifier = try container.decode(String.self, forKey: .timeZoneIdentifier)
            journalNote = try container.decodeIfPresent(String.self, forKey: .journalNote)
            journalNoteModifiedAt = try container.decodeIfPresent(
                Date.self,
                forKey: .journalNoteModifiedAt
            )
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(logicalDay, forKey: .logicalDay)
            try container.encode(checkedAt, forKey: .checkedAt)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(timeZoneIdentifier, forKey: .timeZoneIdentifier)
            try container.encode(journalNote, forKey: .journalNote)
            try container.encode(journalNoteModifiedAt, forKey: .journalNoteModifiedAt)
        }
    }

    public struct MediaPayload: Codable, Sendable {
        public let id: UUID
        public let recordID: UUID?
        public let logicalDay: String
        public let capturedAt: Date
        public let createdAt: Date
        public let modifiedAt: Date
        public let originalRelativePath: String
        public let thumbnailRelativePath: String
        public let byteCount: Int64
        public let thumbnailByteCount: Int64
        public let pixelWidth: Int
        public let pixelHeight: Int
        public let sha256: String
        public let thumbnailSHA256: String
        public let cameraPosition: String

        public init(snapshot: ImprintMediaSnapshot) {
            id = snapshot.id
            recordID = snapshot.recordID
            logicalDay = snapshot.logicalDay.storageValue
            capturedAt = snapshot.capturedAt
            createdAt = snapshot.createdAt
            modifiedAt = snapshot.modifiedAt
            originalRelativePath = snapshot.originalRelativePath
            thumbnailRelativePath = snapshot.thumbnailRelativePath
            byteCount = snapshot.byteCount
            thumbnailByteCount = snapshot.thumbnailByteCount
            pixelWidth = snapshot.pixelWidth
            pixelHeight = snapshot.pixelHeight
            sha256 = snapshot.sha256
            thumbnailSHA256 = snapshot.thumbnailSHA256
            cameraPosition = snapshot.cameraPosition.rawValue
        }

        public init(
            id: UUID,
            recordID: UUID?,
            logicalDay: String,
            capturedAt: Date,
            createdAt: Date,
            modifiedAt: Date,
            originalRelativePath: String,
            thumbnailRelativePath: String,
            byteCount: Int64,
            thumbnailByteCount: Int64,
            pixelWidth: Int,
            pixelHeight: Int,
            sha256: String,
            thumbnailSHA256: String,
            cameraPosition: String
        ) {
            self.id = id
            self.recordID = recordID
            self.logicalDay = logicalDay
            self.capturedAt = capturedAt
            self.createdAt = createdAt
            self.modifiedAt = modifiedAt
            self.originalRelativePath = originalRelativePath
            self.thumbnailRelativePath = thumbnailRelativePath
            self.byteCount = byteCount
            self.thumbnailByteCount = thumbnailByteCount
            self.pixelWidth = pixelWidth
            self.pixelHeight = pixelHeight
            self.sha256 = sha256
            self.thumbnailSHA256 = thumbnailSHA256
            self.cameraPosition = cameraPosition
        }
    }

    public let format: String
    public let schemaVersion: Int
    public let exportedAt: Date
    public let habit: HabitPayload
    public let records: [RecordPayload]
    public let media: [MediaPayload]

    public init(
        format: String,
        schemaVersion: Int,
        exportedAt: Date,
        habit: HabitPayload,
        records: [RecordPayload],
        media: [MediaPayload]
    ) {
        self.format = format
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.habit = habit
        self.records = records
        self.media = media
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
        guard data.count <= PulseBackupContract.maximumManifestBytes else {
            throw PulseCoreError.backupUnavailable
        }
        return data
    }

    public static func decode(_ data: Data) throws -> PulseBackupPayload {
        guard data.count <= PulseBackupContract.maximumManifestBytes else {
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
            try validateManifestShape(data)
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

    private static func validateManifestShape(_ data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PulseCoreError.invalidBackup
        }
        try requireKeys(
            in: root,
            required: ["format", "schemaVersion", "exportedAt", "habit", "records", "media"],
            allowed: ["format", "schemaVersion", "exportedAt", "habit", "records", "media"]
        )

        guard let habit = root["habit"] as? [String: Any],
              let records = root["records"] as? [[String: Any]],
              let media = root["media"] as? [[String: Any]] else {
            throw PulseCoreError.invalidBackup
        }
        try requireKeys(
            in: habit,
            required: [
                "id", "name", "isIdentityConfirmed", "createdAt", "startLogicalDay",
                "creationTimeZoneIdentifier", "timeZoneIdentifier",
            ],
            allowed: [
                "id", "name", "purpose", "isIdentityConfirmed", "createdAt",
                "startLogicalDay", "creationTimeZoneIdentifier", "timeZoneIdentifier",
            ]
        )
        for record in records {
            try requireKeys(
                in: record,
                required: [
                    "id", "logicalDay", "checkedAt", "createdAt", "timeZoneIdentifier",
                    "journalNote", "journalNoteModifiedAt",
                ],
                allowed: [
                    "id", "logicalDay", "checkedAt", "createdAt", "timeZoneIdentifier",
                    "journalNote", "journalNoteModifiedAt",
                ]
            )
        }
        for item in media {
            try requireKeys(
                in: item,
                required: [
                    "id", "logicalDay", "capturedAt", "createdAt", "modifiedAt",
                    "originalRelativePath", "thumbnailRelativePath", "byteCount",
                    "thumbnailByteCount", "pixelWidth", "pixelHeight", "sha256",
                    "thumbnailSHA256", "cameraPosition",
                ],
                allowed: [
                    "id", "recordID", "logicalDay", "capturedAt", "createdAt", "modifiedAt",
                    "originalRelativePath", "thumbnailRelativePath", "byteCount",
                    "thumbnailByteCount", "pixelWidth", "pixelHeight", "sha256",
                    "thumbnailSHA256", "cameraPosition",
                ]
            )
        }
    }

    private static func requireKeys(
        in object: [String: Any],
        required: Set<String>,
        allowed: Set<String>
    ) throws {
        let actual = Set(object.keys)
        guard required.isSubset(of: actual), actual.isSubset(of: allowed) else {
            throw PulseCoreError.invalidBackup
        }
    }
}

private struct PulseBackupPayloadEnvelope: Decodable {
    let format: String
    let schemaVersion: Int
}
