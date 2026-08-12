import CommonCrypto
import CryptoKit
import Foundation
import Security

public enum PulseEncryptedBackupCodec {
    public static func encrypt(
        _ payload: PulseBackupPayload,
        passphrase: String
    ) throws -> Data {
        var passphraseData = try PulsePassphraseKeyDerivation.validatedPassphraseData(
            passphrase
        )
        defer { passphraseData.resetBytes(in: passphraseData.indices) }
        var plaintext = try PulseBackupPayloadCodec.encode(payload)
        defer { plaintext.resetBytes(in: plaintext.indices) }
        let salt = try secureRandomData(count: PulseBackupContract.saltByteCount)
        let nonceData = try secureRandomData(count: PulseBackupContract.nonceByteCount)
        let key = try PulsePassphraseKeyDerivation.deriveKey(
            passphraseData: passphraseData,
            salt: salt,
            iterations: PulseBackupContract.keyDerivationIterations
        )
        let nonce: AES.GCM.Nonce
        do {
            nonce = try AES.GCM.Nonce(data: nonceData)
        } catch {
            throw PulseCoreError.backupUnavailable
        }

        var authenticatedHeader = makeFixedHeader(ciphertextLength: plaintext.count)
        authenticatedHeader.append(salt)
        authenticatedHeader.append(nonceData)

        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.seal(
                plaintext,
                using: key,
                nonce: nonce,
                authenticating: authenticatedHeader
            )
        } catch {
            throw PulseCoreError.backupUnavailable
        }

        var backup = authenticatedHeader
        backup.append(sealedBox.ciphertext)
        backup.append(sealedBox.tag)
        guard backup.count <= PulseBackupContract.maximumBackupBytes else {
            throw PulseCoreError.backupUnavailable
        }
        return backup
    }

    public static func decrypt(
        _ backup: Data,
        passphrase: String
    ) throws -> PulseBackupPayload {
        guard backup.count <= PulseBackupContract.maximumBackupBytes else {
            throw PulseCoreError.invalidBackup
        }
        var passphraseData = try PulsePassphraseKeyDerivation.validatedPassphraseData(
            passphrase
        )
        defer { passphraseData.resetBytes(in: passphraseData.indices) }
        var cursor = PulseBackupCursor(data: backup)
        guard cursor.readData(count: PulseBackupContract.magic.count) == PulseBackupContract.magic else {
            throw PulseCoreError.invalidBackup
        }

        let containerVersion: UInt16 = try cursor.readInteger()
        guard containerVersion == PulseBackupContract.containerVersion else {
            throw PulseCoreError.unsupportedBackupContainerVersion(containerVersion)
        }
        let keyDerivationIdentifier: UInt8 = try cursor.readInteger()
        let cipherIdentifier: UInt8 = try cursor.readInteger()
        let iterations: UInt32 = try cursor.readInteger()
        let saltLength: UInt16 = try cursor.readInteger()
        let nonceLength: UInt16 = try cursor.readInteger()
        let tagLength: UInt16 = try cursor.readInteger()
        let reserved: UInt16 = try cursor.readInteger()
        let ciphertextLength: UInt32 = try cursor.readInteger()

        guard keyDerivationIdentifier == PulseBackupContract.keyDerivationIdentifier,
              cipherIdentifier == PulseBackupContract.cipherIdentifier,
              iterations == PulseBackupContract.keyDerivationIterations,
              Int(saltLength) == PulseBackupContract.saltByteCount,
              Int(nonceLength) == PulseBackupContract.nonceByteCount,
              Int(tagLength) == PulseBackupContract.authenticationTagByteCount,
              reserved == 0,
              Int(ciphertextLength) <= PulseBackupContract.maximumPayloadBytes else {
            throw PulseCoreError.invalidBackup
        }

        let expectedByteCount = PulseBackupContract.fixedHeaderByteCount
            + Int(saltLength)
            + Int(nonceLength)
            + Int(ciphertextLength)
            + Int(tagLength)
        guard expectedByteCount == backup.count else {
            throw PulseCoreError.invalidBackup
        }

        let salt = try cursor.readRequiredData(count: Int(saltLength))
        let nonceData = try cursor.readRequiredData(count: Int(nonceLength))
        let authenticatedHeaderEnd = cursor.offset
        let ciphertext = try cursor.readRequiredData(count: Int(ciphertextLength))
        let tag = try cursor.readRequiredData(count: Int(tagLength))
        guard cursor.isAtEnd else {
            throw PulseCoreError.invalidBackup
        }

        let key = try PulsePassphraseKeyDerivation.deriveKey(
            passphraseData: passphraseData,
            salt: salt,
            iterations: iterations
        )
        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: nonceData),
                ciphertext: ciphertext,
                tag: tag
            )
        } catch {
            throw PulseCoreError.invalidBackup
        }

        var plaintext: Data
        do {
            plaintext = try AES.GCM.open(
                sealedBox,
                using: key,
                authenticating: backup.prefix(authenticatedHeaderEnd)
            )
        } catch {
            throw PulseCoreError.backupAuthenticationFailed
        }
        defer { plaintext.resetBytes(in: plaintext.indices) }
        return try PulseBackupPayloadCodec.decode(plaintext)
    }

    private static func makeFixedHeader(ciphertextLength: Int) -> Data {
        precondition(ciphertextLength <= PulseBackupContract.maximumPayloadBytes)
        var header = PulseBackupContract.magic
        header.appendBigEndian(PulseBackupContract.containerVersion)
        header.appendBigEndian(PulseBackupContract.keyDerivationIdentifier)
        header.appendBigEndian(PulseBackupContract.cipherIdentifier)
        header.appendBigEndian(PulseBackupContract.keyDerivationIterations)
        header.appendBigEndian(UInt16(PulseBackupContract.saltByteCount))
        header.appendBigEndian(UInt16(PulseBackupContract.nonceByteCount))
        header.appendBigEndian(UInt16(PulseBackupContract.authenticationTagByteCount))
        header.appendBigEndian(UInt16(0))
        header.appendBigEndian(UInt32(ciphertextLength))
        precondition(header.count == PulseBackupContract.fixedHeaderByteCount)
        return header
    }

    private static func secureRandomData(count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, count, bytes.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw PulseCoreError.backupUnavailable
        }
        return data
    }
}

enum PulsePassphraseKeyDerivation {
    static func validatedPassphraseData(_ passphrase: String) throws -> Data {
        guard passphrase.count >= PulseBackupContract.minimumPassphraseCharacterCount else {
            throw PulseCoreError.invalidBackupPassphrase
        }
        let byteCount = passphrase.utf8.count
        guard byteCount <= PulseBackupContract.maximumPassphraseByteCount else {
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
        guard status == kCCSuccess else {
            throw PulseCoreError.backupUnavailable
        }
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
        guard let value = readData(count: count) else {
            throw PulseCoreError.invalidBackup
        }
        return value
    }

    mutating func readInteger<T: FixedWidthInteger>() throws -> T {
        let bytes = try readRequiredData(count: MemoryLayout<T>.size)
        return bytes.reduce(T.zero) { partialResult, byte in
            (partialResult << 8) | T(byte)
        }
    }
}

private extension Data {
    mutating func appendBigEndian<T: FixedWidthInteger>(_ value: T) {
        var bigEndianValue = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndianValue) { bytes in
            append(contentsOf: bytes)
        }
    }
}
