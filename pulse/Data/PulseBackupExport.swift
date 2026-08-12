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
    }

    let id = UUID()
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    deinit {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
