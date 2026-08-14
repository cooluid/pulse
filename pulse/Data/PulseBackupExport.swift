import CoreTransferable
import Foundation
import PulseCore
import UniformTypeIdentifiers

extension UTType {
    static let pulseBackup = UTType(
        exportedAs: PulseBackupContract.contentTypeIdentifier,
        conformingTo: .data
    )
}

final class PulseBackupExport: Transferable, Identifiable, @unchecked Sendable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pulseBackup) { export in
            SentTransferredFile(export.fileURL)
        }
        .suggestedFileName { export in
            export.suggestedFilename
        }
    }

    let id = UUID()
    let fileURL: URL
    let suggestedFilename: String

    init(fileURL: URL, suggestedFilename: String) {
        precondition(!suggestedFilename.isEmpty)
        self.fileURL = fileURL
        self.suggestedFilename = suggestedFilename
    }

    deinit {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
