import Foundation
import PulseCore
import SwiftUI
import UniformTypeIdentifiers

struct PulseExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let payload: PulseExportPayload

    init(payload: PulseExportPayload) {
        self.payload = payload
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw PulseCoreError.exportUnavailable
        }
        payload = try Self.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try Self.encode(payload))
    }

    static func encode(_ payload: PulseExportPayload) throws -> Data {
        try PulseExportCodec.encode(payload)
    }

    static func decode(_ data: Data) throws -> PulseExportPayload {
        try PulseExportCodec.decode(data)
    }
}
