import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum PulseDataContract {
    static let exportSchemaVersion = 1
}

struct PulseExportPayload: Codable, Sendable {
    struct HabitPayload: Codable, Sendable {
        let id: UUID
        let name: String
        let createdAt: Date
        let timeZoneIdentifier: String
        let dayStartMinutes: Int
    }

    struct RecordPayload: Codable, Sendable {
        let id: UUID
        let logicalDay: String
        let checkedAt: Date
        let createdAt: Date
        let source: String
    }

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
        try encoder.encode(payload)
    }

    static func decode(_ data: Data) throws -> PulseExportPayload {
        try decoder.decode(PulseExportPayload.self, from: data)
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
