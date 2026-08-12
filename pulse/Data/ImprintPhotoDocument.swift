import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ImprintPhotoDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.jpeg] }

    private let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard configuration.contentType.conforms(to: .jpeg),
              let data = configuration.file.regularFileContents,
              !data.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
