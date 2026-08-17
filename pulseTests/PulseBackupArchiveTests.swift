import CryptoKit
import Foundation
import PulseCore
@testable import pulse
import UniformTypeIdentifiers
import XCTest

final class PulseBackupArchiveTests: XCTestCase {
    private let passphrase = "a sufficiently long backup passphrase"

    func testExportedContentTypeRemainsSinglePulseArchiveType() {
        XCTAssertEqual(UTType.pulseBackup.identifier, PulseBackupContract.contentTypeIdentifier)
        XCTAssertEqual(PulseBackupContract.containerVersion, 2)
        XCTAssertEqual(PulseBackupContract.payloadSchemaVersion, 3)
    }

    func testBackupExportCarriesANonemptySuggestedFilename() throws {
        let root = try makeTemporaryDirectory()
        let fileURL = root.appendingPathComponent("source.pulsebackup")
        try Data([0x01]).write(to: fileURL)
        let filename = PulseBackupContract.filename(day: "2026-08-15")
        let export = PulseBackupExport(fileURL: fileURL, suggestedFilename: filename)

        XCTAssertEqual(export.suggestedFilename, "pulse-2026-08-15.pulsebackup")
        XCTAssertFalse(export.suggestedFilename.isEmpty)
    }

    func testArchiveRoundTripIncludesAuthenticatedMediaEntries() throws {
        let fixture = try makeMediaFixture()
        let archiveURL = fixture.root.appendingPathComponent("roundtrip.pulsebackup")
        try PulseEncryptedBackupCodec.write(
            fixture.payload,
            to: archiveURL,
            passphrase: passphrase
        ) { path, _ in
            guard let data = fixture.files[path] else { throw PulseCoreError.invalidMedia }
            return data
        }

        let stagingURL = fixture.root.appendingPathComponent("restore", isDirectory: true)
        let decoded = try PulseEncryptedBackupCodec.read(
            from: archiveURL,
            stagingDirectoryURL: stagingURL,
            passphrase: passphrase
        )
        XCTAssertEqual(decoded.payload.schemaVersion, 3)
        XCTAssertEqual(decoded.payload.records.count, 1)
        XCTAssertEqual(decoded.payload.records.first?.journalNote, "Stayed focused")
        XCTAssertEqual(decoded.payload.records.first?.journalNoteModifiedAt, checkedNoteDate)
        XCTAssertEqual(decoded.payload.media.count, 1)
        let media = try XCTUnwrap(decoded.payload.media.first)
        XCTAssertEqual(
            try Data(contentsOf: stagingURL.appendingPathComponent(media.originalRelativePath)),
            fixture.files[media.originalRelativePath]
        )
        XCTAssertEqual(
            try Data(contentsOf: stagingURL.appendingPathComponent(media.thumbnailRelativePath)),
            fixture.files[media.thumbnailRelativePath]
        )
        decoded.discard()
        XCTAssertFalse(FileManager.default.fileExists(atPath: stagingURL.path))
    }

    func testFileStoreArchiveZeroizesDiskBackedMediaWithoutCrashing() async throws {
        let original = Data(repeating: 0x4f, count: 256 * 1_024)
        let thumbnail = Data(repeating: 0x54, count: 128 * 1_024)
        let fixture = try makeMediaFixture(original: original, thumbnail: thumbnail)
        let mediaRoot = fixture.root.appendingPathComponent("Media", isDirectory: true)
        let store = try PulseMediaFileStore(rootURL: mediaRoot)

        for (relativePath, data) in fixture.files {
            try data.write(to: mediaRoot.appendingPathComponent(relativePath), options: [.atomic])
        }

        let archiveURL = fixture.root.appendingPathComponent("disk-backed.pulsebackup")
        try await store.writeArchive(
            payload: fixture.payload,
            to: archiveURL,
            passphrase: passphrase
        )

        let decoded = try PulseEncryptedBackupCodec.read(
            from: archiveURL,
            stagingDirectoryURL: fixture.root.appendingPathComponent(
                "disk-backed-restore",
                isDirectory: true
            ),
            passphrase: passphrase
        )
        XCTAssertEqual(decoded.payload.media.count, 1)
        XCTAssertEqual(
            try Data(contentsOf: decoded.mediaDirectoryURL.appendingPathComponent(
                fixture.payload.media[0].originalRelativePath
            )),
            original
        )
        XCTAssertEqual(
            try Data(contentsOf: decoded.mediaDirectoryURL.appendingPathComponent(
                fixture.payload.media[0].thumbnailRelativePath
            )),
            thumbnail
        )
    }

    func testExactMinimumLengthPassphraseRoundTrips() throws {
        let fixture = try makeMediaFixture()
        let archiveURL = fixture.root.appendingPathComponent("four-characters.pulsebackup")
        let minimumPassphrase = "1234"
        XCTAssertEqual(
            minimumPassphrase.count,
            PulseBackupContract.minimumPassphraseCharacterCount
        )

        try PulseEncryptedBackupCodec.write(
            fixture.payload,
            to: archiveURL,
            passphrase: minimumPassphrase
        ) { path, _ in
            try XCTUnwrap(fixture.files[path])
        }

        let decoded = try PulseEncryptedBackupCodec.read(
            from: archiveURL,
            stagingDirectoryURL: fixture.root.appendingPathComponent("four-character-restore"),
            passphrase: minimumPassphrase
        )
        XCTAssertEqual(decoded.payload.records.count, 1)
        XCTAssertEqual(decoded.payload.media.count, 1)
        decoded.discard()
    }

    func testSamePayloadProducesDifferentCiphertext() throws {
        let fixture = try makeMediaFixture()
        let first = fixture.root.appendingPathComponent("first.pulsebackup")
        let second = fixture.root.appendingPathComponent("second.pulsebackup")
        for url in [first, second] {
            try PulseEncryptedBackupCodec.write(
                fixture.payload,
                to: url,
                passphrase: passphrase
            ) { path, _ in try XCTUnwrap(fixture.files[path]) }
        }
        XCTAssertNotEqual(try Data(contentsOf: first), try Data(contentsOf: second))
    }

    func testWrongPassphraseAndTamperingFailAuthentication() throws {
        let fixture = try makeMediaFixture()
        let archiveURL = fixture.root.appendingPathComponent("secure.pulsebackup")
        try PulseEncryptedBackupCodec.write(
            fixture.payload,
            to: archiveURL,
            passphrase: passphrase
        ) { path, _ in try XCTUnwrap(fixture.files[path]) }

        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.read(
                from: archiveURL,
                stagingDirectoryURL: fixture.root.appendingPathComponent("wrong"),
                passphrase: "another long but incorrect passphrase"
            )
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .backupAuthenticationFailed)
        }

        var bytes = try Data(contentsOf: archiveURL)
        bytes[bytes.count - 1] ^= 0x01
        let tamperedURL = fixture.root.appendingPathComponent("tampered.pulsebackup")
        try bytes.write(to: tamperedURL)
        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.read(
                from: tamperedURL,
                stagingDirectoryURL: fixture.root.appendingPathComponent("tampered-restore"),
                passphrase: passphrase
            )
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .backupAuthenticationFailed)
        }
    }

    func testVersionOneArchiveIsExplicitlyUnsupported() throws {
        let root = try makeTemporaryDirectory()
        var data = Data("PULSEBKP".utf8)
        data.append(contentsOf: [0, 1])
        data.append(Data(repeating: 0, count: PulseBackupContract.fixedHeaderByteCount - 10))
        data.append(0)
        let url = root.appendingPathComponent("old.pulsebackup")
        try data.write(to: url)
        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.read(
                from: url,
                stagingDirectoryURL: root.appendingPathComponent("restore"),
                passphrase: passphrase
            )
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .unsupportedBackupContainerVersion(1))
        }
    }

    func testPayloadThreeRequiresExplicitJournalFieldsAndRejectsPayloadTwo() throws {
        let fixture = try makeMediaFixture()
        let encoded = try PulseBackupPayloadCodec.encode(fixture.payload)
        var object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var records = try XCTUnwrap(object["records"] as? [[String: Any]])
        XCTAssertEqual(records.count, 1)
        XCTAssertTrue(records[0].keys.contains("journalNote"))
        XCTAssertTrue(records[0].keys.contains("journalNoteModifiedAt"))
        XCTAssertEqual(records[0]["journalNote"] as? String, "Stayed focused")
        XCTAssertNotNil(records[0]["journalNoteModifiedAt"] as? String)

        var unknownFieldObject = object
        var unknownFieldRecords = records
        unknownFieldRecords[0]["legacyNote"] = "must fail closed"
        unknownFieldObject["records"] = unknownFieldRecords
        XCTAssertThrowsError(
            try PulseBackupPayloadCodec.decode(
                try JSONSerialization.data(withJSONObject: unknownFieldObject)
            )
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidBackup)
        }

        records[0].removeValue(forKey: "journalNote")
        object["records"] = records
        let missingField = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try PulseBackupPayloadCodec.decode(missingField)) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidBackup)
        }

        object["schemaVersion"] = 2
        let payloadTwo = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try PulseBackupPayloadCodec.decode(payloadTwo)) { error in
            XCTAssertEqual(error as? PulseCoreError, .unsupportedBackupPayloadVersion(2))
        }
    }

    func testShortPassphraseAndMissingMediaFailClosed() throws {
        let fixture = try makeMediaFixture()
        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.write(
                fixture.payload,
                to: fixture.root.appendingPathComponent("short.pulsebackup"),
                passphrase: "abc"
            ) { path, _ in try XCTUnwrap(fixture.files[path]) }
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidBackupPassphrase)
        }

        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.write(
                fixture.payload,
                to: fixture.root.appendingPathComponent("missing.pulsebackup"),
                passphrase: passphrase
            ) { _, _ in throw PulseCoreError.mediaFileUnavailable }
        )
    }

    func testThumbnailIdentityMismatchCannotBeArchived() throws {
        let fixture = try makeMediaFixture()
        let thumbnailPath = try XCTUnwrap(fixture.payload.media.first?.thumbnailRelativePath)
        XCTAssertThrowsError(
            try PulseEncryptedBackupCodec.write(
                fixture.payload,
                to: fixture.root.appendingPathComponent("thumbnail-mismatch.pulsebackup"),
                passphrase: passphrase
            ) { path, _ in
                if path == thumbnailPath {
                    return Data([0xff, 0xd8, 0, 0xff, 0xd9])
                }
                return try XCTUnwrap(fixture.files[path])
            }
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidMedia)
        }
    }

    private func makeMediaFixture(
        original: Data = Data([0xff, 0xd8, 0x50, 0x55, 0x4c, 0x53, 0x45, 0xff, 0xd9]),
        thumbnail: Data = Data([0xff, 0xd8, 0x54, 0x48, 0x4d, 0xff, 0xd9])
    ) throws -> (
        root: URL,
        payload: PulseBackupPayload,
        files: [String: Data]
    ) {
        let root = try makeTemporaryDirectory()
        let habitID = UUID()
        let recordID = UUID()
        let mediaID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_704_067_200)
        let checkedAt = createdAt.addingTimeInterval(3_600)
        let capturedAt = checkedAt.addingTimeInterval(60)
        let exportedAt = capturedAt.addingTimeInterval(60)
        let originalPath = "originals/\(mediaID.uuidString.lowercased()).jpg"
        let thumbnailPath = "thumbnails/\(mediaID.uuidString.lowercased()).jpg"
        let hash = SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined()
        let payload = PulseBackupPayload(
            format: PulseBackupContract.payloadFormatIdentifier,
            schemaVersion: PulseBackupContract.payloadSchemaVersion,
            exportedAt: exportedAt,
            habit: .init(
                id: habitID,
                name: "Read",
                purpose: "Stay attentive",
                isIdentityConfirmed: true,
                createdAt: createdAt,
                startLogicalDay: "2024-01-01",
                creationTimeZoneIdentifier: "UTC",
                timeZoneIdentifier: "UTC"
            ),
            records: [
                .init(
                    id: recordID,
                    logicalDay: "2024-01-01",
                    checkedAt: checkedAt,
                    createdAt: checkedAt,
                    timeZoneIdentifier: "UTC",
                    journalNote: "Stayed focused",
                    journalNoteModifiedAt: checkedAt
                )
            ],
            media: [
                .init(
                    id: mediaID,
                    recordID: recordID,
                    logicalDay: "2024-01-01",
                    capturedAt: capturedAt,
                    createdAt: capturedAt,
                    modifiedAt: capturedAt,
                    originalRelativePath: originalPath,
                    thumbnailRelativePath: thumbnailPath,
                    byteCount: Int64(original.count),
                    thumbnailByteCount: Int64(thumbnail.count),
                    pixelWidth: 1_200,
                    pixelHeight: 1_600,
                    sha256: hash,
                    thumbnailSHA256: SHA256.hash(data: thumbnail)
                        .map { String(format: "%02x", $0) }
                        .joined(),
                    cameraPosition: ImprintCameraPosition.rear.rawValue
                )
            ]
        )
        return (root, payload, [originalPath: original, thumbnailPath: thumbnail])
    }

    private var checkedNoteDate: Date {
        Date(timeIntervalSince1970: 1_704_067_200).addingTimeInterval(3_600)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseBackupArchiveTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
