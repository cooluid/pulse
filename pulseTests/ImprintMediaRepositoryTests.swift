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
        let receipt = try repository.checkIn(habitID: habit.id)
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
        let secondReceipt = try repository.checkIn(habitID: habit.id)
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

        let receipt = try repository.checkIn(habitID: habit.id)
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
        let keptFiles = try await store.install(
            originalData: original,
            thumbnailData: thumbnail
        )
        let orphanFiles = try await store.install(
            originalData: original,
            thumbnailData: thumbnail
        )
        let now = date(hour: 9)
        let kept = snapshot(files: keptFiles, original: original, now: now)
        let storedOriginal = try await store.readOriginal(for: kept)
        let storedThumbnail = try await store.readThumbnail(for: kept)
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

    func testFileStoreRejectsThumbnailWhoseIdentityChanged() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseMediaIntegrityTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try PulseMediaFileStore(rootURL: root)
        let original = Data([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9])
        let thumbnail = Data([0xff, 0xd8, 4, 0xff, 0xd9])
        let files = try await store.install(
            originalData: original,
            thumbnailData: thumbnail
        )
        let item = snapshot(files: files, original: original, now: date(hour: 9))
        try Data([0xff, 0xd8, 9, 0xff, 0xd9]).write(
            to: root.appendingPathComponent(files.thumbnailRelativePath),
            options: [.atomic]
        )

        do {
            _ = try await store.readThumbnail(for: item)
            XCTFail("Expected thumbnail identity validation to fail.")
        } catch {
            XCTAssertEqual(error as? PulseCoreError, .invalidMedia)
        }
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
        files: InstalledImprintFiles,
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

private final class MutableMediaClock: PulseClock, @unchecked Sendable {
    var now: Date
    init(now: Date) { self.now = now }
}
