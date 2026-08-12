import CommonCrypto
import CryptoKit
import Foundation
import Security

public final class PulseDecodedBackup: @unchecked Sendable {
    public let payload: PulseBackupPayload
    public let mediaDirectoryURL: URL

    init(payload: PulseBackupPayload, mediaDirectoryURL: URL) {
        self.payload = payload
        self.mediaDirectoryURL = mediaDirectoryURL
    }

    public func discard() {
        try? FileManager.default.removeItem(at: mediaDirectoryURL)
    }

    deinit { discard() }
}

public enum PulseEncryptedBackupCodec {
    private enum EntryKind: UInt8 {
        case manifest = 0
        case original = 1
        case thumbnail = 2
    }

    public static func write(
        _ payload: PulseBackupPayload,
        to destinationURL: URL,
        passphrase: String,
        fileProvider: (String, Int) throws -> Data
    ) throws {
        let validated = try PulseDataValidator.validate(payload)
        var passphraseData = try PulsePassphraseKeyDerivation.validatedPassphraseData(passphrase)
        defer { passphraseData.resetBytes(in: passphraseData.indices) }
        var manifestData = try PulseBackupPayloadCodec.encode(payload)
        defer { manifestData.resetBytes(in: manifestData.indices) }

        let salt = try secureRandomData(count: PulseBackupContract.saltByteCount)
        let entryCount = 1 + validated.media.count * 2
        guard entryCount <= 1 + PulseBackupContract.maximumMediaCount * 2 else {
            throw PulseCoreError.backupUnavailable
        }
        let fixedHeader = makeFixedHeader(entryCount: entryCount)
        var baseAuthenticatedData = fixedHeader
        baseAuthenticatedData.append(salt)
        let key = try PulsePassphraseKeyDerivation.deriveKey(
            passphraseData: passphraseData,
            salt: salt,
            iterations: PulseBackupContract.keyDerivationIterations
        )

        let fileManager = FileManager.default
        let directoryURL = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let temporaryURL = directoryURL.appendingPathComponent(
            ".\(destinationURL.lastPathComponent).\(UUID().uuidString).writing"
        )
        guard !fileManager.fileExists(atPath: destinationURL.path),
              !fileManager.fileExists(atPath: temporaryURL.path) else {
            throw PulseCoreError.backupUnavailable
        }
        fileManager.createFile(atPath: temporaryURL.path, contents: nil)

        do {
            let handle = try FileHandle(forWritingTo: temporaryURL)
            do {
                try handle.write(contentsOf: baseAuthenticatedData)
                try writeEntry(
                    kind: .manifest,
                    name: "manifest.json",
                    plaintext: manifestData,
                    baseAuthenticatedData: baseAuthenticatedData,
                    key: key,
                    handle: handle
                )

                for item in payload.media.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
                    var original = try fileProvider(
                        item.originalRelativePath,
                        PulseMediaFileStore.maximumOriginalBytes
                    )
                    defer { original.resetBytes(in: original.indices) }
                    guard original.count == item.byteCount,
                          SHA256.hash(data: original).hexString == item.sha256 else {
                        throw PulseCoreError.invalidMedia
                    }
                    try writeEntry(
                        kind: .original,
                        name: item.originalRelativePath,
                        plaintext: original,
                        baseAuthenticatedData: baseAuthenticatedData,
                        key: key,
                        handle: handle
                    )

                    var thumbnail = try fileProvider(
                        item.thumbnailRelativePath,
                        PulseMediaFileStore.maximumThumbnailBytes
                    )
                    defer { thumbnail.resetBytes(in: thumbnail.indices) }
                    guard thumbnail.count == item.thumbnailByteCount,
                          SHA256.hash(data: thumbnail).hexString == item.thumbnailSHA256 else {
                        throw PulseCoreError.invalidMedia
                    }
                    try writeEntry(
                        kind: .thumbnail,
                        name: item.thumbnailRelativePath,
                        plaintext: thumbnail,
                        baseAuthenticatedData: baseAuthenticatedData,
                        key: key,
                        handle: handle
                    )
                }
                try handle.synchronize()
                try handle.close()
            } catch {
                try? handle.close()
                throw error
            }
            let size = try temporaryURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
            guard let size, UInt64(size) <= PulseBackupContract.maximumBackupBytes else {
                throw PulseCoreError.backupUnavailable
            }
            try fileManager.setAttributes(
                [.protectionKey: PulseStoreProtection.fileProtectionType],
                ofItemAtPath: temporaryURL.path
            )
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    public static func read(
        from sourceURL: URL,
        stagingDirectoryURL: URL,
        passphrase: String
    ) throws -> PulseDecodedBackup {
        let fileSize = try sourceURL.resourceValues(forKeys: [
            .fileSizeKey,
            .isRegularFileKey,
            .isSymbolicLinkKey
        ])
        guard fileSize.isRegularFile == true,
              fileSize.isSymbolicLink != true,
              let byteCount = fileSize.fileSize,
              byteCount > PulseBackupContract.fixedHeaderByteCount,
              UInt64(byteCount) <= PulseBackupContract.maximumBackupBytes else {
            throw PulseCoreError.invalidBackup
        }

        var passphraseData = try PulsePassphraseKeyDerivation.validatedPassphraseData(passphrase)
        defer { passphraseData.resetBytes(in: passphraseData.indices) }
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: stagingDirectoryURL.path) else {
            throw PulseCoreError.invalidBackup
        }
        try fileManager.createDirectory(at: stagingDirectoryURL, withIntermediateDirectories: true)
        try fileManager.setAttributes(
            [.protectionKey: PulseStoreProtection.fileProtectionType],
            ofItemAtPath: stagingDirectoryURL.path
        )

        do {
            let handle = try FileHandle(forReadingFrom: sourceURL)
            defer { try? handle.close() }
            let fixedHeader = try readExactly(
                PulseBackupContract.fixedHeaderByteCount,
                from: handle
            )
            var cursor = PulseBackupCursor(data: fixedHeader)
            guard cursor.readData(count: PulseBackupContract.magic.count)
                    == PulseBackupContract.magic else {
                throw PulseCoreError.invalidBackup
            }
            let version: UInt16 = try cursor.readInteger()
            guard version == PulseBackupContract.containerVersion else {
                throw PulseCoreError.unsupportedBackupContainerVersion(version)
            }
            let kdf: UInt8 = try cursor.readInteger()
            let cipher: UInt8 = try cursor.readInteger()
            let iterations: UInt32 = try cursor.readInteger()
            let saltLength: UInt16 = try cursor.readInteger()
            let entryCount: UInt32 = try cursor.readInteger()
            let reserved: UInt16 = try cursor.readInteger()
            guard cursor.isAtEnd,
                  kdf == PulseBackupContract.keyDerivationIdentifier,
                  cipher == PulseBackupContract.cipherIdentifier,
                  iterations == PulseBackupContract.keyDerivationIterations,
                  Int(saltLength) == PulseBackupContract.saltByteCount,
                  entryCount >= 1,
                  entryCount <= UInt32(1 + PulseBackupContract.maximumMediaCount * 2),
                  reserved == 0 else {
                throw PulseCoreError.invalidBackup
            }
            let salt = try readExactly(Int(saltLength), from: handle)
            var baseAuthenticatedData = fixedHeader
            baseAuthenticatedData.append(salt)
            let key = try PulsePassphraseKeyDerivation.deriveKey(
                passphraseData: passphraseData,
                salt: salt,
                iterations: iterations
            )

            let manifestEntry = try readEntry(
                from: handle,
                baseAuthenticatedData: baseAuthenticatedData,
                key: key,
                maximumBytes: PulseBackupContract.maximumManifestBytes
            )
            guard manifestEntry.kind == .manifest,
                  manifestEntry.name == "manifest.json" else {
                throw PulseCoreError.invalidBackup
            }
            var manifestData = manifestEntry.plaintext
            defer { manifestData.resetBytes(in: manifestData.indices) }
            let payload = try PulseBackupPayloadCodec.decode(manifestData)
            guard entryCount == UInt32(1 + payload.media.count * 2) else {
                throw PulseCoreError.invalidBackup
            }

            var expected: [String: (EntryKind, PulseBackupPayload.MediaPayload)] = [:]
            for media in payload.media {
                guard expected.updateValue(
                    (.original, media),
                    forKey: media.originalRelativePath
                ) == nil,
                expected.updateValue(
                    (.thumbnail, media),
                    forKey: media.thumbnailRelativePath
                ) == nil else {
                    throw PulseCoreError.invalidBackup
                }
            }

            for _ in 1..<Int(entryCount) {
                let entry = try readEntry(
                    from: handle,
                    baseAuthenticatedData: baseAuthenticatedData,
                    key: key,
                    maximumBytes: PulseMediaFileStore.maximumOriginalBytes
                )
                guard let expectedEntry = expected.removeValue(forKey: entry.name),
                      entry.kind == expectedEntry.0 else {
                    throw PulseCoreError.invalidBackup
                }
                if entry.kind == .original {
                    guard entry.plaintext.count == expectedEntry.1.byteCount,
                          SHA256.hash(data: entry.plaintext).hexString == expectedEntry.1.sha256 else {
                        throw PulseCoreError.invalidBackup
                    }
                } else {
                    guard entry.plaintext.count == expectedEntry.1.thumbnailByteCount,
                          SHA256.hash(data: entry.plaintext).hexString
                            == expectedEntry.1.thumbnailSHA256 else {
                        throw PulseCoreError.invalidBackup
                    }
                }
                let destination = try secureDestination(
                    relativePath: entry.name,
                    rootURL: stagingDirectoryURL
                )
                try fileManager.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try entry.plaintext.write(to: destination, options: [.atomic])
                try fileManager.setAttributes(
                    [.protectionKey: PulseStoreProtection.fileProtectionType],
                    ofItemAtPath: destination.path
                )
            }
            guard expected.isEmpty,
                  try handle.offset() == UInt64(byteCount) else {
                throw PulseCoreError.invalidBackup
            }
            return PulseDecodedBackup(
                payload: payload,
                mediaDirectoryURL: stagingDirectoryURL
            )
        } catch {
            try? fileManager.removeItem(at: stagingDirectoryURL)
            throw error
        }
    }

    private static func writeEntry(
        kind: EntryKind,
        name: String,
        plaintext: Data,
        baseAuthenticatedData: Data,
        key: SymmetricKey,
        handle: FileHandle
    ) throws {
        guard let nameData = name.data(using: .utf8),
              !nameData.isEmpty,
              nameData.count <= Int(UInt16.max) else {
            throw PulseCoreError.backupUnavailable
        }
        let nonceData = try secureRandomData(count: PulseBackupContract.nonceByteCount)
        var entryHeader = Data()
        entryHeader.appendBigEndian(kind.rawValue)
        entryHeader.appendBigEndian(UInt8(0))
        entryHeader.appendBigEndian(UInt16(nameData.count))
        entryHeader.appendBigEndian(UInt64(plaintext.count))
        entryHeader.appendBigEndian(UInt64(plaintext.count))
        entryHeader.appendBigEndian(UInt8(PulseBackupContract.nonceByteCount))
        entryHeader.appendBigEndian(UInt8(PulseBackupContract.authenticationTagByteCount))
        entryHeader.appendBigEndian(UInt16(0))
        precondition(entryHeader.count == PulseBackupContract.entryFixedHeaderByteCount)
        var authenticatedData = baseAuthenticatedData
        authenticatedData.append(entryHeader)
        authenticatedData.append(nameData)
        let sealed = try AES.GCM.seal(
            plaintext,
            using: key,
            nonce: AES.GCM.Nonce(data: nonceData),
            authenticating: authenticatedData
        )
        try handle.write(contentsOf: entryHeader)
        try handle.write(contentsOf: nameData)
        try handle.write(contentsOf: nonceData)
        try handle.write(contentsOf: sealed.ciphertext)
        try handle.write(contentsOf: sealed.tag)
    }

    private static func readEntry(
        from handle: FileHandle,
        baseAuthenticatedData: Data,
        key: SymmetricKey,
        maximumBytes: Int
    ) throws -> (kind: EntryKind, name: String, plaintext: Data) {
        let header = try readExactly(PulseBackupContract.entryFixedHeaderByteCount, from: handle)
        var cursor = PulseBackupCursor(data: header)
        let rawKind: UInt8 = try cursor.readInteger()
        let reservedByte: UInt8 = try cursor.readInteger()
        let nameLength: UInt16 = try cursor.readInteger()
        let plaintextLength: UInt64 = try cursor.readInteger()
        let ciphertextLength: UInt64 = try cursor.readInteger()
        let nonceLength: UInt8 = try cursor.readInteger()
        let tagLength: UInt8 = try cursor.readInteger()
        let reserved: UInt16 = try cursor.readInteger()
        guard cursor.isAtEnd,
              let kind = EntryKind(rawValue: rawKind),
              reservedByte == 0,
              reserved == 0,
              nameLength > 0,
              plaintextLength == ciphertextLength,
              plaintextLength > 0,
              plaintextLength <= UInt64(maximumBytes),
              Int(nonceLength) == PulseBackupContract.nonceByteCount,
              Int(tagLength) == PulseBackupContract.authenticationTagByteCount else {
            throw PulseCoreError.invalidBackup
        }
        let nameData = try readExactly(Int(nameLength), from: handle)
        guard let name = String(data: nameData, encoding: .utf8) else {
            throw PulseCoreError.invalidBackup
        }
        let nonce = try readExactly(Int(nonceLength), from: handle)
        let ciphertext = try readExactly(Int(ciphertextLength), from: handle)
        let tag = try readExactly(Int(tagLength), from: handle)
        var authenticatedData = baseAuthenticatedData
        authenticatedData.append(header)
        authenticatedData.append(nameData)
        do {
            let sealed = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: nonce),
                ciphertext: ciphertext,
                tag: tag
            )
            let plaintext = try AES.GCM.open(
                sealed,
                using: key,
                authenticating: authenticatedData
            )
            guard plaintext.count == Int(plaintextLength) else {
                throw PulseCoreError.invalidBackup
            }
            return (kind, name, plaintext)
        } catch let error as PulseCoreError {
            throw error
        } catch {
            throw PulseCoreError.backupAuthenticationFailed
        }
    }

    private static func makeFixedHeader(entryCount: Int) -> Data {
        var header = PulseBackupContract.magic
        header.appendBigEndian(PulseBackupContract.containerVersion)
        header.appendBigEndian(PulseBackupContract.keyDerivationIdentifier)
        header.appendBigEndian(PulseBackupContract.cipherIdentifier)
        header.appendBigEndian(PulseBackupContract.keyDerivationIterations)
        header.appendBigEndian(UInt16(PulseBackupContract.saltByteCount))
        header.appendBigEndian(UInt32(entryCount))
        header.appendBigEndian(UInt16(0))
        precondition(header.count == PulseBackupContract.fixedHeaderByteCount)
        return header
    }

    private static func secureDestination(relativePath: String, rootURL: URL) throws -> URL {
        guard !relativePath.hasPrefix("/"),
              !relativePath.contains(".."),
              !relativePath.contains("\\"),
              relativePath.split(separator: "/").count == 2 else {
            throw PulseCoreError.invalidBackup
        }
        let destination = rootURL.appendingPathComponent(relativePath).standardizedFileURL
        let prefix = rootURL.standardizedFileURL.path + "/"
        guard destination.path.hasPrefix(prefix) else {
            throw PulseCoreError.invalidBackup
        }
        return destination
    }

    private static func readExactly(_ count: Int, from handle: FileHandle) throws -> Data {
        guard count >= 0, let data = try handle.read(upToCount: count), data.count == count else {
            throw PulseCoreError.invalidBackup
        }
        return data
    }

    private static func secureRandomData(count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, count, bytes.baseAddress!)
        }
        guard status == errSecSuccess else { throw PulseCoreError.backupUnavailable }
        return data
    }
}

enum PulsePassphraseKeyDerivation {
    static func validatedPassphraseData(_ passphrase: String) throws -> Data {
        guard passphrase.count >= PulseBackupContract.minimumPassphraseCharacterCount,
              passphrase.utf8.count <= PulseBackupContract.maximumPassphraseByteCount else {
            throw PulseCoreError.invalidBackupPassphrase
        }
        return Data(passphrase.utf8)
    }

    static func deriveKey(
        passphraseData: Data,
        salt: Data,
        iterations: UInt32,
        keyByteCount: Int = 32
    ) throws -> SymmetricKey {
        var derivedKey = Data(count: keyByteCount)
        defer { derivedKey.resetBytes(in: derivedKey.indices) }
        let status = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            passphraseData.withUnsafeBytes { passphraseBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        UInt32(kCCPBKDF2),
                        passphraseBytes.bindMemory(to: Int8.self).baseAddress,
                        passphraseData.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        UInt32(kCCPRFHmacAlgSHA256),
                        iterations,
                        derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress,
                        keyByteCount
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw PulseCoreError.backupUnavailable }
        return SymmetricKey(data: derivedKey)
    }
}

private struct PulseBackupCursor {
    let data: Data
    private(set) var offset = 0
    var isAtEnd: Bool { offset == data.count }

    mutating func readData(count: Int) -> Data? {
        guard count >= 0, count <= data.count - offset else { return nil }
        defer { offset += count }
        return data.subdata(in: offset..<(offset + count))
    }

    mutating func readRequiredData(count: Int) throws -> Data {
        guard let value = readData(count: count) else { throw PulseCoreError.invalidBackup }
        return value
    }

    mutating func readInteger<T: FixedWidthInteger>() throws -> T {
        let bytes = try readRequiredData(count: MemoryLayout<T>.size)
        return bytes.reduce(T.zero) { ($0 << 8) | T($1) }
    }
}

private extension Data {
    mutating func appendBigEndian<T: FixedWidthInteger>(_ value: T) {
        var bigEndianValue = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndianValue) { append(contentsOf: $0) }
    }
}

private extension SHA256Digest {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
