import CryptoKit
import XCTest
import UniformTypeIdentifiers
@testable import PulseCore
@testable import pulse

final class PulseBackupDocumentTests: XCTestCase {
    private let passphrase = "correct horse battery staple"

    func testBackupFilenameAndDocumentTypeUseOneEncryptedAuthority() {
        XCTAssertEqual(
            PulseBackupContract.filename(day: "2026-08-11"),
            "pulse-2026-08-11.pulsebackup"
        )
        XCTAssertEqual(
            PulseBackupContract.filename(day: nil),
            "pulse-backup.pulsebackup"
        )
        XCTAssertEqual(PulseBackupDocument.readableContentTypes, [.pulseBackup])
        XCTAssertEqual(PulseBackupDocument.writableContentTypes, [.pulseBackup])
        XCTAssertEqual(UTType.pulseBackup.identifier, PulseBackupContract.contentTypeIdentifier)
    }

    func testPBKDF2HMACSHA256MatchesKnownVector() throws {
        let key = try PulsePassphraseKeyDerivation.deriveKey(
            passphraseData: Data("password".utf8),
            salt: Data("salt".utf8),
            iterations: 1
        )
        let bytes = key.withUnsafeBytes { Data($0) }
        XCTAssertEqual(
            bytes.map { String(format: "%02x", $0) }.joined(),
            "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"
        )
    }

    func testEncryptedRoundTripPreservesCompletePayload() throws {
        let payload = makePayload()

        let data = try PulseEncryptedBackupCodec.encrypt(payload, passphrase: passphrase)
        let decoded = try PulseBackupDocument.decode(data, passphrase: passphrase)

        XCTAssertFalse(data.contains(Data("Keep learning".utf8)))
        XCTAssertEqual(decoded.format, PulseBackupContract.payloadFormatIdentifier)
        XCTAssertEqual(decoded.schemaVersion, PulseBackupContract.payloadSchemaVersion)
        XCTAssertEqual(decoded.habit.id, payload.habit.id)
        XCTAssertEqual(decoded.habit.purpose, "Keep learning")
        XCTAssertTrue(decoded.habit.isIdentityConfirmed)
        XCTAssertEqual(decoded.habit.startLogicalDay, "2026-08-10")
        XCTAssertEqual(decoded.habit.creationTimeZoneIdentifier, "Asia/Shanghai")
        XCTAssertEqual(decoded.records.map(\.id), payload.records.map(\.id))
        XCTAssertEqual(decoded.records.map(\.logicalDay), ["2026-08-10"])
    }

    func testSamePayloadAndPassphraseProduceDifferentBackups() throws {
        let payload = makePayload()

        let first = try PulseEncryptedBackupCodec.encrypt(payload, passphrase: passphrase)
        let second = try PulseEncryptedBackupCodec.encrypt(payload, passphrase: passphrase)

        XCTAssertNotEqual(first, second)
    }

    func testWrongPassphraseAndAuthenticatedByteTamperingFailClosed() throws {
        let data = try PulseEncryptedBackupCodec.encrypt(makePayload(), passphrase: passphrase)

        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.decrypt(
                data,
                passphrase: "a different long passphrase"
            )
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .backupAuthenticationFailed)
        }

        for index in [8, 28, 44, data.count - 1] {
            var tampered = data
            tampered[index] ^= 0x01
            XCTAssertThrowsError(
                try PulseEncryptedBackupCodec.decrypt(tampered, passphrase: passphrase),
                "Expected byte \(index) to be authenticated or rejected"
            )
        }
    }

    func testTruncationTrailingBytesAndPlaintextJSONAreRejected() throws {
        let encrypted = try PulseEncryptedBackupCodec.encrypt(makePayload(), passphrase: passphrase)
        var withTrailingByte = encrypted
        withTrailingByte.append(0)
        let plaintext = try PulseBackupPayloadCodec.encode(makePayload())

        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.decrypt(encrypted.dropLast(), passphrase: passphrase)
        )
        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.decrypt(withTrailingByte, passphrase: passphrase)
        )
        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.decrypt(plaintext, passphrase: passphrase)
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidBackup)
        }
    }

    func testUnknownContainerVersionAndNonContractParametersAreRejected() throws {
        let encrypted = try PulseEncryptedBackupCodec.encrypt(makePayload(), passphrase: passphrase)
        var unknownVersion = encrypted
        unknownVersion[8] = 0
        unknownVersion[9] = 2
        var unknownKDF = encrypted
        unknownKDF[10] = 2
        var nonzeroReserved = encrypted
        nonzeroReserved[23] = 1
        var hostileCiphertextLength = encrypted
        hostileCiphertextLength.replaceSubrange(24...27, with: [0xFF, 0xFF, 0xFF, 0xFF])

        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.decrypt(unknownVersion, passphrase: passphrase)
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .unsupportedBackupContainerVersion(2))
        }
        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.decrypt(unknownKDF, passphrase: passphrase)
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidBackup)
        }
        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.decrypt(nonzeroReserved, passphrase: passphrase)
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidBackup)
        }
        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.decrypt(hostileCiphertextLength, passphrase: passphrase)
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidBackup)
        }
    }

    func testPassphraseContractIsExactAndBounded() throws {
        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.encrypt(makePayload(), passphrase: "too short")
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidBackupPassphrase)
        }

        let unicodePassphrase = "密钥-Exact-Case-🔐"
        let data = try PulseEncryptedBackupCodec.encrypt(
            makePayload(),
            passphrase: unicodePassphrase
        )
        XCTAssertNoThrow(
            try PulseEncryptedBackupCodec.decrypt(data, passphrase: unicodePassphrase)
        )
        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.decrypt(
                data,
                passphrase: unicodePassphrase.lowercased()
            )
        )
        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.encrypt(
                makePayload(),
                passphrase: String(repeating: "🔐", count: 300)
            )
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidBackupPassphrase)
        }
    }

    func testUnknownPayloadVersionIsRejectedWithoutCompatibilityDecoder() {
        let data = Data(
            #"{"format":"co.fanr.pulse.payload","schemaVersion":99}"#.utf8
        )

        XCTAssertThrowsError(try PulseBackupPayloadCodec.decode(data)) { error in
            XCTAssertEqual(error as? PulseCoreError, .unsupportedBackupPayloadVersion(99))
        }
    }

    func testOversizedBackupIsRejectedBeforeParsingOrKeyDerivation() {
        let oversized = Data(count: PulseBackupContract.maximumBackupBytes + 1)

        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.decrypt(oversized, passphrase: passphrase)
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidBackup)
        }
    }

    func testDocumentReaderRejectsBackupThatGrowsBeyondTheLimit() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("oversized-\(UUID().uuidString).pulsebackup")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(count: PulseBackupContract.maximumBackupBytes + 1).write(to: url)

        XCTAssertThrowsError(try PulseBackupDocument.readEncryptedData(from: url)) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidBackup)
        }
    }

    func testInvalidPayloadFactsAreRejectedBeforeEncryption() throws {
        let valid = makePayload()
        let invalid = PulseBackupPayload(
            format: valid.format,
            schemaVersion: valid.schemaVersion,
            exportedAt: valid.exportedAt,
            habit: .init(
                id: valid.habit.id,
                name: valid.habit.name,
                purpose: valid.habit.purpose,
                isIdentityConfirmed: valid.habit.isIdentityConfirmed,
                createdAt: valid.habit.createdAt,
                startLogicalDay: valid.habit.startLogicalDay,
                creationTimeZoneIdentifier: valid.habit.creationTimeZoneIdentifier,
                timeZoneIdentifier: "America/Los_Angeles"
            ),
            records: valid.records
        )

        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.encrypt(invalid, passphrase: passphrase)
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidBackup)
        }
    }

    private func makePayload() -> PulseBackupPayload {
        let date = Date(timeIntervalSince1970: 1_786_320_000)
        return PulseBackupPayload(
            format: PulseBackupContract.payloadFormatIdentifier,
            schemaVersion: PulseBackupContract.payloadSchemaVersion,
            exportedAt: date,
            habit: .init(
                id: UUID(),
                name: "Daily",
                purpose: "Keep learning",
                isIdentityConfirmed: true,
                createdAt: date,
                startLogicalDay: "2026-08-10",
                creationTimeZoneIdentifier: "Asia/Shanghai",
                timeZoneIdentifier: "Asia/Shanghai"
            ),
            records: [
                .init(
                    id: UUID(),
                    logicalDay: "2026-08-10",
                    checkedAt: date,
                    createdAt: date,
                    timeZoneIdentifier: "Asia/Shanghai"
                )
            ]
        )
    }
}
