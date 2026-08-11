import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum PulseDataContract {
    static let formatIdentifier = "co.fanr.pulse.export"
    static let fileExtension = "json"
    static let exportSchemaVersion = 2
    static let maximumRecordCount = 50_000
    static let maximumImportBytes = 32 * 1_024 * 1_024

    static func exportFilename(day: String?) -> String {
        "pulse-\(day ?? "export").\(fileExtension)"
    }
}

struct PulseExportPayload: Codable, Sendable {
    struct HabitPayload: Codable, Sendable {
        let id: UUID
        let name: String
        let purpose: String?
        let isIdentityConfirmed: Bool
        let createdAt: Date
        let startLogicalDay: String
        let creationTimeZoneIdentifier: String
        let timeZoneIdentifier: String
    }

    struct RecordPayload: Codable, Sendable {
        let id: UUID
        let logicalDay: String
        let checkedAt: Date
        let createdAt: Date
        let timeZoneIdentifier: String
    }

    let format: String
    let schemaVersion: Int
    let exportedAt: Date
    let habit: HabitPayload
    let records: [RecordPayload]
}

struct PulseExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let payload: PulseExportPayload

    init(payload: PulseExportPayload) {
        self.payload = payload
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw PulseError.exportUnavailable
        }
        payload = try Self.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try Self.encode(payload))
    }

    static func encode(_ payload: PulseExportPayload) throws -> Data {
        guard payload.format == PulseDataContract.formatIdentifier,
              payload.schemaVersion == PulseDataContract.exportSchemaVersion else {
            throw PulseError.exportUnavailable
        }
        return try encoder.encode(payload)
    }

    static func decode(_ data: Data) throws -> PulseExportPayload {
        let envelope = try decoder.decode(PulseExportEnvelope.self, from: data)
        guard envelope.format == PulseDataContract.formatIdentifier else {
            throw PulseError.invalidImport
        }

        switch envelope.schemaVersion {
        case 1:
            return try decoder.decode(PulseExportPayloadV1.self, from: data).upgradedToV2()
        case PulseDataContract.exportSchemaVersion:
            return try decoder.decode(PulseExportPayload.self, from: data)
        default:
            throw PulseError.unsupportedImportVersion(envelope.schemaVersion)
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

private struct PulseExportEnvelope: Decodable {
    let format: String
    let schemaVersion: Int
}

private struct PulseExportPayloadV1: Decodable {
    struct HabitPayload: Decodable {
        let id: UUID
        let name: String
        let createdAt: Date
        let startLogicalDay: String
        let creationTimeZoneIdentifier: String
        let timeZoneIdentifier: String
    }

    let format: String
    let schemaVersion: Int
    let exportedAt: Date
    let habit: HabitPayload
    let records: [PulseExportPayload.RecordPayload]

    func upgradedToV2() throws -> PulseExportPayload {
        guard format == PulseDataContract.formatIdentifier, schemaVersion == 1 else {
            throw PulseError.invalidImport
        }
        return PulseExportPayload(
            format: format,
            schemaVersion: PulseDataContract.exportSchemaVersion,
            exportedAt: exportedAt,
            habit: .init(
                id: habit.id,
                name: habit.name,
                purpose: nil,
                isIdentityConfirmed: false,
                createdAt: habit.createdAt,
                startLogicalDay: habit.startLogicalDay,
                creationTimeZoneIdentifier: habit.creationTimeZoneIdentifier,
                timeZoneIdentifier: habit.timeZoneIdentifier
            ),
            records: records
        )
    }
}
