import Foundation
import SwiftData
import XCTest
@testable import PulseCore

@MainActor
final class PulseSharedStoreMigratorTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "Asia/Shanghai")!

    func testMigrationCopiesValidatedFactsRemovesEverySourceArtifactAndBecomesReady() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let expected = try createSourceFacts(at: fixture.source)
        let migrator = PulseSharedStoreMigrator(
            fileOperator: SystemPulseStoreFileOperator(),
            checkpointHandler: { checkpoint in
                guard checkpoint == .verified else { return }
                for sidecarURL in fixture.source.storeArtifactURLs.dropFirst() {
                    try Data("owned-sidecar".utf8).write(to: sidecarURL)
                }
            }
        )

        try migrate(migrator, fixture: fixture)

        XCTAssertEqual(try migrator.currentPhase(target: fixture.target), .ready)
        XCTAssertFalse(fixture.source.storeArtifactURLs.contains(where: fileExists))
        XCTAssertTrue(fileExists(fixture.target.storeURL))
        XCTAssertEqual(try readFacts(at: fixture.target), expected)

        let journal = try readJournal(at: fixture.target.migrationJournalURL)
        XCTAssertEqual(journal.version, PulseSharedStoreMigrationJournal.formatVersion)
        XCTAssertEqual(journal.mode, .existingStore)
        XCTAssertEqual(journal.phase, .ready)
        XCTAssertEqual(journal.factDigest.value.count, 64)
    }

    func testMigrationOpensARealV1StoreThroughTheSchemaPlanBeforeValueCopy() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let expected = try createV1Source(at: fixture.source)
        let migrator = PulseSharedStoreMigrator()

        try migrate(migrator, fixture: fixture)

        let migrated = try readFacts(at: fixture.target)
        XCTAssertEqual(try migrator.currentPhase(target: fixture.target), .ready)
        XCTAssertFalse(fixture.source.storeArtifactURLs.contains(where: fileExists))
        XCTAssertEqual(migrated.habit.id, expected.habitID)
        XCTAssertEqual(migrated.habit.name, "Legacy")
        XCTAssertNil(migrated.habit.purpose)
        XCTAssertFalse(migrated.habit.isIdentityConfirmed)
        XCTAssertEqual(migrated.habit.startLogicalDay.storageValue, expected.logicalDay)
        XCTAssertEqual(migrated.records.map(\.id), [expected.recordID])
        XCTAssertEqual(migrated.records.first?.logicalDay.storageValue, expected.logicalDay)
    }

    func testEveryPersistedCheckpointRecoversIdempotently() throws {
        for checkpoint in [
            PulseSharedStoreMigrationCheckpoint.copying,
            .verified,
            .sourceRemoved
        ] {
            let fixture = try makeFixture()
            defer { fixture.remove() }
            let expected = try createSourceFacts(at: fixture.source)
            let interrupted = PulseSharedStoreMigrator(
                fileOperator: SystemPulseStoreFileOperator(),
                checkpointHandler: { reached in
                    if reached == checkpoint {
                        throw InjectedFailure.interruption
                    }
                }
            )

            XCTAssertThrowsError(try migrate(interrupted, fixture: fixture)) { error in
                XCTAssertEqual(error as? InjectedFailure, .interruption)
            }
            XCTAssertEqual(
                try interrupted.currentPhase(target: fixture.target),
                phase(for: checkpoint)
            )

            let recovered = PulseSharedStoreMigrator()
            try migrate(recovered, fixture: fixture)

            XCTAssertEqual(try recovered.currentPhase(target: fixture.target), .ready)
            XCTAssertFalse(fixture.source.storeArtifactURLs.contains(where: fileExists))
            XCTAssertEqual(try readFacts(at: fixture.target), expected)
        }
    }

    func testCopyingRefusesToContinueWhenSourceFactsChanged() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        _ = try createSourceFacts(at: fixture.source)
        let interrupted = interruptedMigrator(at: .copying)
        XCTAssertThrowsError(try migrate(interrupted, fixture: fixture))

        try mutateIdentity(at: fixture.source, name: "Changed after checkpoint")

        XCTAssertThrowsError(try migrate(PulseSharedStoreMigrator(), fixture: fixture)) { error in
            XCTAssertEqual(error as? PulseSharedStoreMigrationError, .sourceStoreChanged)
        }
        XCTAssertEqual(try interrupted.currentPhase(target: fixture.target), .copying)
        XCTAssertTrue(fileExists(fixture.source.storeURL))
    }

    func testVerifiedRefusesToDeleteSourceWhenTargetFactsChanged() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        _ = try createSourceFacts(at: fixture.source)
        let interrupted = interruptedMigrator(at: .verified)
        XCTAssertThrowsError(try migrate(interrupted, fixture: fixture))

        try mutateIdentity(at: fixture.target, name: "Corrupted target truth")

        XCTAssertThrowsError(try migrate(PulseSharedStoreMigrator(), fixture: fixture)) { error in
            XCTAssertEqual(
                error as? PulseSharedStoreMigrationError,
                .targetStoreDigestMismatch
            )
        }
        XCTAssertEqual(try interrupted.currentPhase(target: fixture.target), .verified)
        XCTAssertTrue(fileExists(fixture.source.storeURL))
    }

    func testSourceDeletionFailureKeepsVerifiedJournalAndCanResume() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let expected = try createSourceFacts(at: fixture.source)
        let interrupted = interruptedMigrator(at: .verified)
        XCTAssertThrowsError(try migrate(interrupted, fixture: fixture))

        let failingOperator = FailingRemovalFileOperator(failingURL: fixture.source.storeURL)
        let deletionFailureMigrator = PulseSharedStoreMigrator(
            fileOperator: failingOperator,
            checkpointHandler: { _ in }
        )
        XCTAssertThrowsError(try migrate(deletionFailureMigrator, fixture: fixture)) { error in
            XCTAssertEqual(error as? InjectedFailure, .removal)
        }
        XCTAssertEqual(
            try deletionFailureMigrator.currentPhase(target: fixture.target),
            .verified
        )
        XCTAssertTrue(fileExists(fixture.source.storeURL))

        let recovered = PulseSharedStoreMigrator()
        try migrate(recovered, fixture: fixture)
        XCTAssertEqual(try recovered.currentPhase(target: fixture.target), .ready)
        XCTAssertEqual(try readFacts(at: fixture.target), expected)
    }

    func testReadyRejectsAnyReappearingPrivateStoreArtifactWithoutMerging() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let expected = try createSourceFacts(at: fixture.source)
        let migrator = PulseSharedStoreMigrator()
        try migrate(migrator, fixture: fixture)
        try Data("unexpected-old-store".utf8).write(to: fixture.source.storeURL)

        XCTAssertThrowsError(try migrate(migrator, fixture: fixture)) { error in
            XCTAssertEqual(error as? PulseSharedStoreMigrationError, .unexpectedSourceStore)
        }
        XCTAssertEqual(try migrator.currentPhase(target: fixture.target), .ready)
        XCTAssertEqual(try readFacts(at: fixture.target), expected)
    }

    func testReadyAcceptsLegitimateChangesInTheAuthoritativeTargetStore() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        _ = try createSourceFacts(at: fixture.source)
        let migrator = PulseSharedStoreMigrator()
        try migrate(migrator, fixture: fixture)

        try mutateIdentity(at: fixture.target, name: "Changed after ownership switched")

        XCTAssertNoThrow(try migrate(migrator, fixture: fixture))
        XCTAssertEqual(try migrator.currentPhase(target: fixture.target), .ready)
        XCTAssertEqual(
            try readFacts(at: fixture.target).habit.name,
            "Changed after ownership switched"
        )
    }

    func testMissingSourceDoesNotSilentlyCreateAnEmptyTarget() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let migrator = PulseSharedStoreMigrator()

        XCTAssertThrowsError(try migrate(migrator, fixture: fixture)) { error in
            XCTAssertEqual(error as? PulseSharedStoreMigrationError, .sourceStoreMissing)
        }
        XCTAssertEqual(try migrator.currentPhase(target: fixture.target), .notStarted)
        XCTAssertFalse(fileExists(fixture.target.storeURL))
    }

    func testSourceStoreWithoutAPrimaryHabitDoesNotBecomeANewInstallation() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        try FileManager.default.createDirectory(
            at: fixture.source.directoryURL,
            withIntermediateDirectories: true
        )
        try autoreleasepool {
            _ = try PersistenceController.makeContainer(
                storeName: PulseStoreContract.storeName,
                storeURL: fixture.source.storeURL
            )
        }

        XCTAssertThrowsError(
            try migrate(PulseSharedStoreMigrator(), fixture: fixture)
        ) { error in
            XCTAssertEqual(
                error as? PulseSharedStoreMigrationError,
                .sourceStoreHasNoPrimaryHabit
            )
        }
        XCTAssertTrue(fileExists(fixture.source.storeURL))
        XCTAssertFalse(fileExists(fixture.target.migrationJournalURL))
        XCTAssertFalse(fileExists(fixture.target.storeURL))
    }

    func testExistingTargetWithoutJournalIsNotGuessedOrOverwritten() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        _ = try createSourceFacts(at: fixture.source)
        try FileManager.default.createDirectory(
            at: fixture.target.directoryURL,
            withIntermediateDirectories: true
        )
        try Data("unowned-target".utf8).write(to: fixture.target.storeURL)

        XCTAssertThrowsError(
            try migrate(PulseSharedStoreMigrator(), fixture: fixture)
        ) { error in
            XCTAssertEqual(
                error as? PulseSharedStoreMigrationError,
                .targetStoreExistsWithoutJournal
            )
        }
        XCTAssertEqual(
            try Data(contentsOf: fixture.target.storeURL),
            Data("unowned-target".utf8)
        )
        XCTAssertTrue(fileExists(fixture.source.storeURL))
    }

    func testMalformedAndUnsupportedJournalsFailClosed() throws {
        let malformed = try makeFixture()
        defer { malformed.remove() }
        _ = try createSourceFacts(at: malformed.source)
        try FileManager.default.createDirectory(
            at: malformed.target.directoryURL,
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(to: malformed.target.migrationJournalURL)

        XCTAssertThrowsError(
            try migrate(PulseSharedStoreMigrator(), fixture: malformed)
        ) { error in
            XCTAssertEqual(error as? PulseSharedStoreMigrationError, .invalidJournal)
        }
        XCTAssertTrue(fileExists(malformed.source.storeURL))

        let unsupported = try makeFixture()
        defer { unsupported.remove() }
        _ = try createSourceFacts(at: unsupported.source)
        try FileManager.default.createDirectory(
            at: unsupported.target.directoryURL,
            withIntermediateDirectories: true
        )
        let digest = String(repeating: "a", count: 64)
        let data = Data(
            "{\"factDigest\":\"\(digest)\",\"mode\":\"existingStore\",\"phase\":\"copying\",\"version\":99}"
                .utf8
        )
        try data.write(to: unsupported.target.migrationJournalURL)

        XCTAssertThrowsError(
            try migrate(PulseSharedStoreMigrator(), fixture: unsupported)
        ) { error in
            XCTAssertEqual(
                error as? PulseSharedStoreMigrationError,
                .unsupportedJournalVersion(99)
            )
        }
        XCTAssertTrue(fileExists(unsupported.source.storeURL))
    }

    func testJournalWithUnknownFieldsFailsClosed() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        _ = try createSourceFacts(at: fixture.source)
        try FileManager.default.createDirectory(
            at: fixture.target.directoryURL,
            withIntermediateDirectories: true
        )
        let digest = String(repeating: "a", count: 64)
        let data = Data(
            "{\"extra\":true,\"factDigest\":\"\(digest)\",\"mode\":\"existingStore\",\"phase\":\"copying\",\"version\":2}"
                .utf8
        )
        try data.write(to: fixture.target.migrationJournalURL)

        XCTAssertThrowsError(
            try migrate(PulseSharedStoreMigrator(), fixture: fixture)
        ) { error in
            XCTAssertEqual(error as? PulseSharedStoreMigrationError, .invalidJournal)
        }
        XCTAssertTrue(fileExists(fixture.source.storeURL))
    }

    func testJournalRejectsInvalidDigestAndPersistedNotStartedPhase() {
        XCTAssertThrowsError(try PulseStoreDigest(value: String(repeating: "A", count: 64))) {
            error in
            XCTAssertEqual(error as? PulseSharedStoreMigrationError, .invalidDigest)
        }
        XCTAssertThrowsError(
            try PulseSharedStoreMigrationJournal(
                mode: .existingStore,
                phase: .notStarted,
                factDigest: PulseStoreDigest(value: String(repeating: "a", count: 64))
            )
        ) { error in
            XCTAssertEqual(
                error as? PulseSharedStoreMigrationError,
                .persistedNotStartedPhase
            )
        }
    }

    func testMigrationRejectsSourceAndTargetThatResolveToTheSameStore() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        _ = try createSourceFacts(at: fixture.source)
        let aliasDirectory = fixture.root.appendingPathComponent("PrivateAlias")
        try FileManager.default.createSymbolicLink(
            at: aliasDirectory,
            withDestinationURL: fixture.source.directoryURL
        )
        let aliasedTarget = try PulseStoreLocation(directoryURL: aliasDirectory)

        XCTAssertThrowsError(
            try PulseSharedStoreMigrator().migrateExistingStore(
                source: fixture.source,
                target: aliasedTarget,
                clock: makeClock(),
                initialIdentity: try makeIdentity()
            )
        ) { error in
            XCTAssertEqual(error as? PulseSharedStoreMigrationError, .locationsMustDiffer)
        }
        XCTAssertTrue(fileExists(fixture.source.storeURL))
    }

    private func makeFixture() throws -> MigrationFixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "PulseSharedStoreMigratorTests-\(UUID().uuidString)",
            isDirectory: true
        )
        return MigrationFixture(
            root: root,
            source: try PulseStoreLocation(
                directoryURL: root.appendingPathComponent("Private", isDirectory: true)
            ),
            target: try PulseStoreLocation(
                directoryURL: root.appendingPathComponent("Group", isDirectory: true)
            )
        )
    }

    private func createSourceFacts(at location: PulseStoreLocation) throws -> StoredFacts {
        try FileManager.default.createDirectory(
            at: location.directoryURL,
            withIntermediateDirectories: true
        )
        return try autoreleasepool {
            let clock = MutableMigrationClock(now: makeDate(day: 9, hour: 8))
            let repository = SwiftDataCheckInRepository(
                container: try PersistenceController.makeContainer(
                    storeName: PulseStoreContract.storeName,
                    storeURL: location.storeURL
                ),
                clock: clock,
                initialIdentity: try makeIdentity()
            )
            let initialHabit = try repository.primaryHabit(systemTimeZone: timeZone)
            let habit = try repository.updateIdentity(
                habitID: initialHabit.id,
                identity: try HabitIdentity(
                    userName: "保持自己的节奏",
                    userPurpose: "不与别人比较"
                )
            )
            let first = try repository.checkIn(habitID: habit.id)
            clock.now = makeDate(day: 10, hour: 21)
            let second = try repository.checkIn(habitID: habit.id)
            return StoredFacts(
                habit: habit,
                records: try repository.allRecords(habitID: habit.id),
                receiptIDs: [first.recordID, second.recordID]
            )
        }
    }

    private func createV1Source(at location: PulseStoreLocation) throws -> V1Facts {
        try FileManager.default.createDirectory(
            at: location.directoryURL,
            withIntermediateDirectories: true
        )
        let habitID = UUID()
        let recordID = UUID()
        let createdAt = makeDate(day: 9, hour: 8)
        let logicalDay = "2026-08-09"
        try autoreleasepool {
            let schema = Schema(versionedSchema: PulseSchemaV1.self)
            let container = try ModelContainer(
                for: schema,
                configurations: [
                    ModelConfiguration(
                        PulseStoreContract.storeName,
                        schema: schema,
                        url: location.storeURL
                    )
                ]
            )
            let context = ModelContext(container)
            context.autosaveEnabled = false
            context.insert(
                PulseSchemaV1.Habit(
                    id: habitID,
                    name: "Legacy",
                    createdAt: createdAt,
                    startLogicalDayValue: logicalDay,
                    creationTimeZoneIdentifier: timeZone.identifier,
                    timeZoneIdentifier: timeZone.identifier
                )
            )
            context.insert(
                PulseSchemaV1.CheckInRecord(
                    id: recordID,
                    recordKey: "\(habitID.uuidString.lowercased()):\(logicalDay)",
                    habitID: habitID,
                    logicalDayValue: logicalDay,
                    checkedAt: createdAt,
                    createdAt: createdAt,
                    timeZoneIdentifier: timeZone.identifier
                )
            )
            try context.save()
        }
        return V1Facts(habitID: habitID, recordID: recordID, logicalDay: logicalDay)
    }

    private func readFacts(at location: PulseStoreLocation) throws -> StoredFacts {
        try autoreleasepool {
            let repository = SwiftDataCheckInRepository(
                container: try PersistenceController.makeContainer(
                    storeName: PulseStoreContract.storeName,
                    storeURL: location.storeURL
                ),
                clock: makeClock(),
                initialIdentity: try makeIdentity()
            )
            let habit = try XCTUnwrap(repository.existingPrimaryHabit())
            let records = try repository.allRecords(habitID: habit.id)
            return StoredFacts(habit: habit, records: records, receiptIDs: records.map(\.id))
        }
    }

    private func mutateIdentity(at location: PulseStoreLocation, name: String) throws {
        try autoreleasepool {
            let repository = SwiftDataCheckInRepository(
                container: try PersistenceController.makeContainer(
                    storeName: PulseStoreContract.storeName,
                    storeURL: location.storeURL
                ),
                clock: makeClock(),
                initialIdentity: try makeIdentity()
            )
            let habit = try XCTUnwrap(repository.existingPrimaryHabit())
            _ = try repository.updateIdentity(
                habitID: habit.id,
                identity: try HabitIdentity(userName: name, userPurpose: habit.purpose)
            )
        }
    }

    private func readJournal(at url: URL) throws -> PulseSharedStoreMigrationJournal {
        try JSONDecoder().decode(
            PulseSharedStoreMigrationJournal.self,
            from: Data(contentsOf: url)
        )
    }

    private func migrate(
        _ migrator: PulseSharedStoreMigrator,
        fixture: MigrationFixture
    ) throws {
        try migrator.migrateExistingStore(
            source: fixture.source,
            target: fixture.target,
            clock: makeClock(),
            initialIdentity: try makeIdentity()
        )
    }

    private func interruptedMigrator(
        at checkpoint: PulseSharedStoreMigrationCheckpoint
    ) -> PulseSharedStoreMigrator {
        PulseSharedStoreMigrator(
            fileOperator: SystemPulseStoreFileOperator(),
            checkpointHandler: { reached in
                if reached == checkpoint {
                    throw InjectedFailure.interruption
                }
            }
        )
    }

    private func phase(
        for checkpoint: PulseSharedStoreMigrationCheckpoint
    ) -> PulseSharedStoreMigrationPhase {
        switch checkpoint {
        case .copying: .copying
        case .verified: .verified
        case .sourceRemoved: .sourceRemoved
        case .ready: .ready
        }
    }

    private func makeIdentity() throws -> HabitIdentity {
        try HabitIdentity(userName: "Initial", userPurpose: nil)
    }

    private func makeClock() -> FixedPulseClock {
        FixedPulseClock(now: makeDate(day: 11, hour: 12))
    }

    private func makeDate(day: Int, hour: Int) -> Date {
        Calendar.pulseGregorian(timeZone: timeZone).date(
            from: DateComponents(year: 2026, month: 8, day: day, hour: hour)
        )!
    }

    private func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}

private struct MigrationFixture {
    let root: URL
    let source: PulseStoreLocation
    let target: PulseStoreLocation

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private struct StoredFacts: Equatable {
    let habit: HabitSnapshot
    let records: [CheckInRecordSnapshot]
    let receiptIDs: [UUID]
}

private struct V1Facts {
    let habitID: UUID
    let recordID: UUID
    let logicalDay: String
}

private enum InjectedFailure: Error, Equatable {
    case interruption
    case removal
}

@MainActor
private final class MutableMigrationClock: PulseClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private final class FailingRemovalFileOperator: PulseStoreFileOperating {
    private let base = SystemPulseStoreFileOperator()
    private let failingURL: URL
    private var hasFailed = false

    init(failingURL: URL) {
        self.failingURL = failingURL
    }

    func itemExists(at url: URL) -> Bool {
        base.itemExists(at: url)
    }

    func createDirectory(at url: URL) throws {
        try base.createDirectory(at: url)
    }

    func removeItem(at url: URL) throws {
        if url == failingURL, !hasFailed {
            hasFailed = true
            throw InjectedFailure.removal
        }
        try base.removeItem(at: url)
    }

    func readData(at url: URL) throws -> Data {
        try base.readData(at: url)
    }

    func writeDataAtomically(_ data: Data, to url: URL) throws {
        try base.writeDataAtomically(data, to: url)
    }
}
