import Foundation
import PulseCore
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let pulseBackup = UTType(
        exportedAs: PulseBackupContract.contentTypeIdentifier,
        conformingTo: .data
    )
}

struct PulseBackupDocument: FileDocument, Sendable {
    static var readableContentTypes: [UTType] { [.pulseBackup] }
    static var writableContentTypes: [UTType] { [.pulseBackup] }

    let encryptedData: Data

    init(payload: PulseBackupPayload, passphrase: String) throws {
        encryptedData = try PulseEncryptedBackupCodec.encrypt(
            payload,
            passphrase: passphrase
        )
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              data.count <= PulseBackupContract.maximumBackupBytes else {
            throw PulseCoreError.invalidBackup
        }
        encryptedData = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: encryptedData)
    }

    static func decode(_ data: Data, passphrase: String) throws -> PulseBackupPayload {
        try PulseEncryptedBackupCodec.decrypt(data, passphrase: passphrase)
    }

    static func readEncryptedData(from url: URL) throws -> Data {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }

        var data = Data()
        while data.count <= PulseBackupContract.maximumBackupBytes {
            let remainingCapacity = PulseBackupContract.maximumBackupBytes + 1 - data.count
            let readCount = min(64 * 1_024, remainingCapacity)
            guard let chunk = try fileHandle.read(upToCount: readCount),
                  !chunk.isEmpty else {
                return data
            }
            data.append(chunk)
        }
        throw PulseCoreError.invalidBackup
    }
}
