import CryptoKit
import Foundation
@testable import PulseCore
import XCTest

@MainActor
final class ImprintMediaRepositoryTests: XCTestCase {
    func testMediaIsIndependentFromCheckInAndReattachesWhenDayIsCheckedAgain() throws {
        let clock = MutableMediaClock(now: date(hour: 9))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: .gmt)
        let receipt = try repository.checkIn(habitID: habit.id, journalNote: nil)
        let media = try repository.upsertMedia(
            draft(
                habitID: habit.id,
                recordID: receipt.recordID,
                day: receipt.logicalDay,
                createdAt: clock.now
            )
        )
        XCTAssertEqual(media.recordID, receipt.recordID)

        try repository.delete(recordID: receipt.recordID)
        XCTAssertTrue(try repository.allRecords(habitID: habit.id).isEmpty)
        XCTAssertNil(try XCTUnwrap(repository.allMedia(habitID: habit.id).first).recordID)

        clock.now = date(hour: 10)
        let secondReceipt = try repository.checkIn(habitID: habit.id, journalNote: nil)
        XCTAssertNotEqual(secondReceipt.recordID, receipt.recordID)
        XCTAssertEqual(
            try XCTUnwrap(repository.allMedia(habitID: habit.id).first).recordID,
            secondReceipt.recordID
        )
    }

    func testMediaRequiresMatchingCheckInAndReplacementPreservesOneFactPerDay() throws {
        let clock = MutableMediaClock(now: date(hour: 9))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: .gmt)
        let day = LogicalDay.resolve(at: clock.now, timeZone: .gmt)
        XCTAssertThrowsError(
            try repository.upsertMedia(
                draft(habitID: habit.id, recordID: UUID(), day: day, createdAt: clock.now)
            )
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidMedia)
        }

        let receipt = try repository.checkIn(habitID: habit.id, journalNote: nil)
        let first = try repository.upsertMedia(
            draft(
                habitID: habit.id,
                recordID: receipt.recordID,
                day: day,
                createdAt: clock.now
            )
        )
        clock.now = date(hour: 11)
        let replacement = try repository.upsertMedia(
            draft(
                habitID: habit.id,
                recordID: receipt.recordID,
                day: day,
                createdAt: clock.now
            )
        )
        XCTAssertNotEqual(first.id, replacement.id)
        XCTAssertEqual(try repository.allMedia(habitID: habit.id).count, 1)
    }

    func testFileStoreInstallsValidatesAndAuditsImmutableFiles() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseMediaFileStoreTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try PulseMediaFileStore(rootURL: root)
        let original = Data([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9])
        let thumbnail = Data([0xff, 0xd8, 4, 0xff, 0xd9])
        let keptFiles = try await store.installVerified(
            originalData: original,
            thumbnailData: thumbnail
        )
        let orphanFiles = try await store.installVerified(
            originalData: original,
            thumbnailData: thumbnail
        )
        let now = date(hour: 9)
        let kept = snapshot(files: keptFiles, original: original, now: now)
        let storedOriginal = try await store.readCommittedOriginal(for: kept)
        let storedThumbnail = try await store.readCommittedThumbnail(for: kept)
        XCTAssertEqual(storedOriginal, original)
        XCTAssertEqual(storedThumbnail, thumbnail)

        try await store.audit(referencedMedia: [kept])
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent(orphanFiles.originalRelativePath).path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent(keptFiles.originalRelativePath).path
            )
        )
    }

    func testInstallVerificationRetriesTransientIdentityMismatchBeforeCommit() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseMediaTransientInstallTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let readCounter = MediaReadCounter()
        let store = try PulseMediaFileStore(
            rootURL: root,
            readTransform: { context, relativePath, attempt, data in
                guard case .precommitVerification = context,
                      relativePath.hasPrefix("originals/") else {
                    return data
                }
                readCounter.record()
                return attempt < 2 ? Data(data.dropLast()) : data
            },
            retrySleeper: { _ in }
        )
        let original = Data([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9])
        let thumbnail = Data([0xff, 0xd8, 4, 0xff, 0xd9])
        let files = try await store.installVerified(
            originalData: original,
            thumbnailData: thumbnail
        )
        let item = snapshot(files: files, original: original, now: date(hour: 9))
        let storedOriginal = try await store.readCommittedOriginal(for: item)
        let storedThumbnail = try await store.readCommittedThumbnail(for: item)

        XCTAssertEqual(readCounter.value, 3)
        XCTAssertEqual(storedOriginal, original)
        XCTAssertEqual(storedThumbnail, thumbnail)
    }

    func testInstallVerificationFailureCleansEveryNewFile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseMediaFailedVerificationTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try PulseMediaFileStore(
            rootURL: root,
            readTransform: { context, relativePath, _, data in
                guard case .precommitVerification = context,
                      relativePath.hasPrefix("originals/") else {
                    return data
                }
                return Data(data.dropLast())
            },
            retrySleeper: { _ in }
        )

        do {
            _ = try await store.installVerified(
                originalData: Data([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9]),
                thumbnailData: Data([0xff, 0xd8, 4, 0xff, 0xd9])
            )
            XCTFail("Expected precommit verification to fail.")
        } catch {
            XCTAssertEqual(
                error as? PulseMediaStorageError,
                .precommitVerificationFailed(.identityMismatch)
            )
        }

        XCTAssertTrue(try FileManager.default.contentsOfDirectory(
            atPath: root.appendingPathComponent("originals").path
        ).isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(
            atPath: root.appendingPathComponent("thumbnails").path
        ).isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(
            atPath: root.appendingPathComponent("staging").path
        ).isEmpty)
    }

    func testInstallVerifiesMultiMegabytePayload() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseMediaLargeInstallTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try PulseMediaFileStore(rootURL: root)
        var original = Data(repeating: 0x5a, count: 2_164_482)
        original[0] = 0xff
        original[1] = 0xd8
        original[original.count - 2] = 0xff
        original[original.count - 1] = 0xd9
        var thumbnail = Data(repeating: 0xa5, count: 60_778)
        thumbnail[0] = 0xff
        thumbnail[1] = 0xd8
        thumbnail[thumbnail.count - 2] = 0xff
        thumbnail[thumbnail.count - 1] = 0xd9

        let files = try await store.installVerified(
            originalData: original,
            thumbnailData: thumbnail
        )
        let item = snapshot(files: files, original: original, now: date(hour: 9))
        let storedOriginal = try await store.readCommittedOriginal(for: item)
        let storedThumbnail = try await store.readCommittedThumbnail(for: item)

        XCTAssertEqual(storedOriginal, original)
        XCTAssertEqual(storedThumbnail, thumbnail)
    }

    func testInstallFailureWhenDestinationExistsCleansPartialInstall() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseMediaFailedInstallTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try PulseMediaFileStore(rootURL: root)
        let storageID = UUID()
        let original = Data([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9])
        let thumbnail = Data([0xff, 0xd8, 4, 0xff, 0xd9])
        _ = try await store.installVerified(
            originalData: original,
            thumbnailData: thumbnail,
            storageID: storageID
        )

        do {
            _ = try await store.installVerified(
                originalData: Data([0xff, 0xd8, 9, 0xff, 0xd9]),
                thumbnailData: Data([0xff, 0xd8, 8, 0xff, 0xd9]),
                storageID: storageID
            )
            XCTFail("Expected a duplicate destination install to fail.")
        } catch {
            XCTAssertEqual(error as? PulseMediaStorageError, .storageUnavailable)
        }

        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(
                atPath: root.appendingPathComponent("originals").path
            ).count,
            1
        )
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(
                atPath: root.appendingPathComponent("thumbnails").path
            ).count,
            1
        )
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(
            atPath: root.appendingPathComponent("staging").path
        ).isEmpty)
    }

    func testCommittedReadRetriesOnlyFileUnavailability() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseMediaCommittedRetryTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let readCounter = MediaReadCounter()
        let store = try PulseMediaFileStore(
            rootURL: root,
            readTransform: { context, relativePath, attempt, data in
                guard case .committedRead = context,
                      relativePath.hasPrefix("thumbnails/") else {
                    return data
                }
                readCounter.record()
                if attempt < 2 {
                    throw PulseMediaStorageError.fileUnavailable
                }
                return data
            },
            retrySleeper: { _ in }
        )
        let original = Data([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9])
        let thumbnail = Data([0xff, 0xd8, 4, 0xff, 0xd9])
        let files = try await store.installVerified(
            originalData: original,
            thumbnailData: thumbnail
        )
        let item = snapshot(files: files, original: original, now: date(hour: 9))
        let storedThumbnail = try await store.readCommittedThumbnail(for: item)

        XCTAssertEqual(storedThumbnail, thumbnail)
        XCTAssertEqual(readCounter.value, 3)
    }

    func testCommittedIdentityMismatchDoesNotRetry() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseMediaCommittedIntegrityTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let readCounter = MediaReadCounter()
        let store = try PulseMediaFileStore(
            rootURL: root,
            readTransform: { context, relativePath, _, data in
                guard case .committedRead = context,
                      relativePath.hasPrefix("thumbnails/") else {
                    return data
                }
                readCounter.record()
                return Data(data.dropLast())
            },
            retrySleeper: { _ in }
        )
        let original = Data([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9])
        let thumbnail = Data([0xff, 0xd8, 4, 0xff, 0xd9])
        let files = try await store.installVerified(
            originalData: original,
            thumbnailData: thumbnail
        )
        let item = snapshot(files: files, original: original, now: date(hour: 9))

        do {
            _ = try await store.readCommittedThumbnail(for: item)
            XCTFail("Expected committed identity validation to fail.")
        } catch {
            XCTAssertEqual(error as? PulseMediaStorageError, .identityMismatch)
        }
        XCTAssertEqual(readCounter.value, 1)
    }

    func testFileStoreRejectsThumbnailWhoseIdentityChanged() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseMediaIntegrityTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try PulseMediaFileStore(rootURL: root)
        let original = Data([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9])
        let thumbnail = Data([0xff, 0xd8, 4, 0xff, 0xd9])
        let files = try await store.installVerified(
            originalData: original,
            thumbnailData: thumbnail
        )
        let item = snapshot(files: files, original: original, now: date(hour: 9))
        try Data([0xff, 0xd8, 9, 0xff, 0xd9]).write(
            to: root.appendingPathComponent(files.thumbnailRelativePath),
            options: [.atomic]
        )

        do {
            _ = try await store.readCommittedThumbnail(for: item)
            XCTFail("Expected thumbnail identity validation to fail.")
        } catch {
            XCTAssertEqual(error as? PulseMediaStorageError, .identityMismatch)
        }
    }

    func testFileStoreRejectsSymbolicLinkedMediaFiles() async throws {
        let testRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseMediaFileSymlinkTests-\(UUID().uuidString)")
        let mediaRoot = testRoot.appendingPathComponent("Media", isDirectory: true)
        let externalFile = testRoot.appendingPathComponent("external.jpg")
        addTeardownBlock { try? FileManager.default.removeItem(at: testRoot) }
        let store = try PulseMediaFileStore(rootURL: mediaRoot)
        let original = Data([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9])
        let thumbnail = Data([0xff, 0xd8, 4, 0xff, 0xd9])
        let files = try await store.installVerified(
            originalData: original,
            thumbnailData: thumbnail
        )
        let item = snapshot(files: files, original: original, now: date(hour: 9))
        let thumbnailURL = mediaRoot.appendingPathComponent(files.thumbnailRelativePath)
        try FileManager.default.removeItem(at: thumbnailURL)
        try thumbnail.write(to: externalFile, options: [.atomic])
        try FileManager.default.createSymbolicLink(
            at: thumbnailURL,
            withDestinationURL: externalFile
        )

        do {
            _ = try await store.readCommittedThumbnail(for: item)
            XCTFail("Expected a symbolic-linked media file to be rejected.")
        } catch {
            XCTAssertEqual(error as? PulseMediaStorageError, .fileUnavailable)
        }
        XCTAssertEqual(try Data(contentsOf: externalFile), thumbnail)
    }

    func testFileStoreRejectsManagedDirectorySymbolicLinksAtInitialization() throws {
        let testRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseMediaSymlinkInitTests-\(UUID().uuidString)")
        let mediaRoot = testRoot.appendingPathComponent("Media", isDirectory: true)
        let externalOriginals = testRoot.appendingPathComponent(
            "ExternalOriginals",
            isDirectory: true
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: testRoot) }
        try FileManager.default.createDirectory(
            at: mediaRoot,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: externalOriginals,
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            at: mediaRoot.appendingPathComponent("originals", isDirectory: true),
            withDestinationURL: externalOriginals
        )

        XCTAssertThrowsError(try PulseMediaFileStore(rootURL: mediaRoot)) { error in
            XCTAssertEqual(error as? PulseMediaStorageError, .storageUnavailable)
        }
    }

    func testFileStoreRejectsManagedDirectoryReplacedBySymbolicLink() async throws {
        let testRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseMediaSymlinkRuntimeTests-\(UUID().uuidString)")
        let mediaRoot = testRoot.appendingPathComponent("Media", isDirectory: true)
        let externalOriginals = testRoot.appendingPathComponent(
            "ExternalOriginals",
            isDirectory: true
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: testRoot) }
        let store = try PulseMediaFileStore(rootURL: mediaRoot)
        let originals = mediaRoot.appendingPathComponent("originals", isDirectory: true)
        try FileManager.default.removeItem(at: originals)
        try FileManager.default.createDirectory(
            at: externalOriginals,
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            at: originals,
            withDestinationURL: externalOriginals
        )

        do {
            _ = try await store.installVerified(
                originalData: Data([0xff, 0xd8, 1, 0xff, 0xd9]),
                thumbnailData: Data([0xff, 0xd8, 2, 0xff, 0xd9])
            )
            XCTFail("Expected the replaced managed directory to be rejected.")
        } catch {
            XCTAssertEqual(error as? PulseMediaStorageError, .storageUnavailable)
        }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: externalOriginals.path).isEmpty)
    }

    func testPersistedMediaPathsRequireCanonicalUUIDFilenames() {
        let storageID = UUID()
        let canonical = PulseMediaPath.make(directory: .originals, storageID: storageID)

        XCTAssertTrue(PulseMediaPath.isValid(canonical, directory: .originals))
        XCTAssertFalse(PulseMediaPath.isValid("originals/photo.jpg", directory: .originals))
        XCTAssertFalse(
            PulseMediaPath.isValid(
                "originals/\(storageID.uuidString).jpg",
                directory: .originals
            )
        )
        XCTAssertFalse(PulseMediaPath.isValidStoredPath("other/\(storageID).jpg"))
    }

    private func makeRepository(clock: MutableMediaClock) throws -> SwiftDataPulseRepository {
        SwiftDataPulseRepository(
            container: try PersistenceController.makeInMemoryContainer(
                storeName: "MediaTests-\(UUID().uuidString)"
            ),
            clock: clock,
            primaryHabitProvisioning: .createIfMissing(
                try HabitIdentity(userName: "Move", userPurpose: nil)
            )
        )
    }

    private func draft(
        habitID: UUID,
        recordID: UUID,
        day: LogicalDay,
        createdAt: Date
    ) -> ImprintMediaDraft {
        let id = UUID()
        return ImprintMediaDraft(
            id: id,
            habitID: habitID,
            recordID: recordID,
            logicalDay: day,
            capturedAt: createdAt,
            createdAt: createdAt,
            originalRelativePath: "originals/\(id.uuidString.lowercased()).jpg",
            thumbnailRelativePath: "thumbnails/\(id.uuidString.lowercased()).jpg",
            byteCount: 7,
            thumbnailByteCount: 5,
            pixelWidth: 1_200,
            pixelHeight: 1_600,
            sha256: String(repeating: "a", count: 64),
            thumbnailSHA256: String(repeating: "b", count: 64),
            cameraPosition: .rear
        )
    }

    private func snapshot(
        files: VerifiedImprintFiles,
        original: Data,
        now: Date
    ) -> ImprintMediaSnapshot {
        ImprintMediaSnapshot(
            id: UUID(),
            habitID: UUID(),
            recordID: nil,
            logicalDay: LogicalDay(year: 2026, month: 8, day: 12),
            capturedAt: now,
            createdAt: now,
            modifiedAt: now,
            originalRelativePath: files.originalRelativePath,
            thumbnailRelativePath: files.thumbnailRelativePath,
            mediaType: "image/jpeg",
            byteCount: Int64(original.count),
            thumbnailByteCount: files.thumbnailByteCount,
            pixelWidth: 1_200,
            pixelHeight: 1_600,
            sha256: SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined(),
            thumbnailSHA256: files.thumbnailSHA256,
            cameraPosition: .rear
        )
    }

    private func date(hour: Int) -> Date {
        Calendar.pulseGregorian(timeZone: .gmt).date(
            from: DateComponents(year: 2026, month: 8, day: 12, hour: hour)
        )!
    }
}

private final class MediaReadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func record() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}

private final class MutableMediaClock: PulseClock, @unchecked Sendable {
    var now: Date
    init(now: Date) { self.now = now }
}
