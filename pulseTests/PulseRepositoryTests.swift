import SwiftData
import XCTest
@testable import PulseCore
@testable import PulseWatchShared
@testable import pulse

@MainActor
final class PulseRepositoryTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "Asia/Shanghai")!

    func testExistingPrimaryHabitIsAReadOnlyLookup() throws {
        let repository = try makeRepository(
            clock: MutableRepositoryClock(now: makeDate(day: 10, hour: 12))
        )

        XCTAssertNil(try repository.existingPrimaryHabit())
        XCTAssertNil(try repository.existingPrimaryHabit())

        let created = try repository.primaryHabit(systemTimeZone: timeZone)
        XCTAssertEqual(try repository.existingPrimaryHabit(), created)
    }

    func testExistingStoreOnlyProvisioningNeverCreatesAPrimaryHabit() throws {
        let repository = SwiftDataPulseRepository(
            container: try PersistenceController.makeInMemoryContainer(),
            clock: MutableRepositoryClock(now: makeDate(day: 10, hour: 12)),
            primaryHabitProvisioning: .existingStoreOnly
        )

        XCTAssertThrowsError(try repository.primaryHabit(systemTimeZone: timeZone)) { error in
            XCTAssertEqual(error as? PulseCoreError, .primaryHabitUnavailable)
        }
        XCTAssertNil(try repository.existingPrimaryHabit())
    }

    func testPrimaryHabitIsCreatedOnlyOnce() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 12))
        let repository = try makeRepository(clock: clock)

        let first = try repository.primaryHabit(systemTimeZone: timeZone)
        let second = try repository.primaryHabit(systemTimeZone: timeZone)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.startLogicalDay, LogicalDay(year: 2026, month: 8, day: 10))
        XCTAssertEqual(first.creationTimeZoneIdentifier, timeZone.identifier)
        XCTAssertEqual(first.timeZoneIdentifier, timeZone.identifier)
        XCTAssertNil(first.purpose)
        XCTAssertFalse(first.isIdentityConfirmed)
    }

    func testIdentityUpdatePreservesHabitAndCheckInFacts() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)
        let record = try repository.checkIn(habitID: habit.id, journalNote: nil)
        let originalStart = habit.startLogicalDay
        let originalCreatedAt = habit.createdAt

        let updated = try repository.updateIdentity(
            habitID: habit.id,
            identity: try HabitIdentity(
                userName: "  每日阅读 📚  ",
                userPurpose: "  为了保持独立思考  "
            )
        )

        XCTAssertEqual(updated.id, habit.id)
        XCTAssertEqual(updated.name, "每日阅读 📚")
        XCTAssertEqual(updated.purpose, "为了保持独立思考")
        XCTAssertTrue(updated.isIdentityConfirmed)
        XCTAssertEqual(updated.createdAt, originalCreatedAt)
        XCTAssertEqual(updated.startLogicalDay, originalStart)
        XCTAssertEqual(try repository.allRecords(habitID: habit.id).map(\.id), [record.recordID])
    }

    func testIdentityUpdateIsIdempotent() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)
        let identity = try HabitIdentity(userName: "Daily Focus", userPurpose: nil)

        let first = try repository.updateIdentity(habitID: habit.id, identity: identity)
        let second = try repository.updateIdentity(habitID: habit.id, identity: identity)

        XCTAssertEqual(first.id, second.id)
        XCTAssertTrue(second.isIdentityConfirmed)
    }

    func testCheckInIsIdempotentForSameLogicalDay() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)

        let first = try repository.checkIn(habitID: habit.id, journalNote: nil)
        clock.now = makeDate(day: 10, hour: 21)
        let second = try repository.checkIn(
            habitID: habit.id,
            journalNote: "并发签到后补上的记事"
        )
        let records = try repository.allRecords(habitID: habit.id)

        XCTAssertEqual(first.recordID, second.recordID)
        XCTAssertEqual(first.checkedAt, makeDate(day: 10, hour: 9))
        XCTAssertEqual(first.disposition, .created)
        XCTAssertEqual(second.disposition, .alreadyPresent)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.journalNote, "并发签到后补上的记事")
        XCTAssertEqual(records.first?.journalNoteModifiedAt, clock.now)
    }

    func testDelayedWatchCommandPreservesOccurrenceLogicalDay() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 12))
        let repository = try makeRepository(clock: clock)
        let habit = try confirmedHabit(repository)
        clock.now = makeDate(day: 11, hour: 8)
        let command = makeWatchCommand(
            habit: habit,
            occurredAt: makeDate(day: 10, hour: 23)
        )

        let receipt = try repository.checkIn(watchCommand: command)
        let record = try XCTUnwrap(repository.allRecords(habitID: habit.id).first)

        XCTAssertEqual(receipt.logicalDay, LogicalDay(year: 2026, month: 8, day: 10))
        XCTAssertEqual(receipt.checkedAt, command.occurredAt)
        XCTAssertEqual(record.createdAt, clock.now)
        XCTAssertEqual(record.timeZoneIdentifier, timeZone.identifier)
    }

    func testRepeatedWatchCommandConvergesOnOneRecord() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 12))
        let repository = try makeRepository(clock: clock)
        let habit = try confirmedHabit(repository)
        let command = makeWatchCommand(habit: habit, occurredAt: clock.now)

        let first = try repository.checkIn(watchCommand: command)
        clock.now = makeDate(day: 10, hour: 14)
        let second = try repository.checkIn(watchCommand: command)

        XCTAssertEqual(first.recordID, second.recordID)
        XCTAssertEqual(first.disposition, .created)
        XCTAssertEqual(second.disposition, .alreadyPresent)
        XCTAssertEqual(try repository.allRecords(habitID: habit.id).count, 1)
    }

    func testWatchCommandRejectsChangedProjectTimeZoneAndFutureOccurrence() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 12))
        let repository = try makeRepository(clock: clock)
        let habit = try confirmedHabit(repository)
        let staleRevision = makeWatchCommand(habit: habit, occurredAt: clock.now)
        try repository.updateTimeZone(habitID: habit.id, identifier: "Europe/Paris")

        do {
            _ = try repository.checkIn(watchCommand: staleRevision)
            XCTFail("A command created under the previous project time zone must be rejected.")
        } catch {
            XCTAssertEqual(error, .timeZoneChanged)
        }

        let updatedHabit = try XCTUnwrap(repository.existingPrimaryHabit())
        let future = makeWatchCommand(
            habit: updatedHabit,
            occurredAt: clock.now.addingTimeInterval(60)
        )
        do {
            _ = try repository.checkIn(watchCommand: future)
            XCTFail("A Watch command cannot claim an occurrence after receipt time.")
        } catch {
            XCTAssertEqual(error, .occurrenceInFuture)
        }
    }

    func testRepeatedCheckInNeverOverwritesAnExistingJournalNote() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)
        _ = try repository.checkIn(habitID: habit.id, journalNote: "第一条记事")

        clock.now = makeDate(day: 10, hour: 21)
        _ = try repository.checkIn(habitID: habit.id, journalNote: "不应覆盖")
        let record = try XCTUnwrap(repository.allRecords(habitID: habit.id).first)

        XCTAssertEqual(record.journalNote, "第一条记事")
        XCTAssertEqual(record.journalNoteModifiedAt, makeDate(day: 10, hour: 9))
    }

    func testCheckInPersistsOptionalJournalNote() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)

        _ = try repository.checkIn(
            habitID: habit.id,
            journalNote: "  今天状态不错  "
        )
        let records = try repository.allRecords(habitID: habit.id)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.journalNote, "今天状态不错")
        XCTAssertEqual(records.first?.journalNoteModifiedAt, makeDate(day: 10, hour: 9))
    }

    func testJournalNoteCanBeAddedAfterExternalCheckInEditedAndCleared() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)
        let receipt = try repository.checkIn(habitID: habit.id, journalNote: nil)

        clock.now = makeDate(day: 10, hour: 10)
        let added = try repository.updateJournalNote(
            recordID: receipt.recordID,
            journalNote: "  第一次记录  "
        )
        XCTAssertEqual(added.journalNote, "第一次记录")
        XCTAssertEqual(added.journalNoteModifiedAt, clock.now)

        clock.now = makeDate(day: 10, hour: 11)
        let edited = try repository.updateJournalNote(
            recordID: receipt.recordID,
            journalNote: "更新后的记录"
        )
        XCTAssertEqual(edited.journalNote, "更新后的记录")
        XCTAssertEqual(edited.journalNoteModifiedAt, clock.now)

        clock.now = makeDate(day: 10, hour: 12)
        let cleared = try repository.updateJournalNote(
            recordID: receipt.recordID,
            journalNote: "  "
        )
        XCTAssertNil(cleared.journalNote)
        XCTAssertEqual(cleared.journalNoteModifiedAt, clock.now)
    }

    func testInvalidJournalNoteNeverMutatesStoredRecord() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)
        let receipt = try repository.checkIn(
            habitID: habit.id,
            journalNote: "正式记录"
        )
        let oversized = String(repeating: "记", count: JournalNote.maximumCharacterCount + 1)

        XCTAssertThrowsError(
            try repository.updateJournalNote(
                recordID: receipt.recordID,
                journalNote: oversized
            )
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidJournalNote)
        }
        XCTAssertEqual(
            try repository.allRecords(habitID: habit.id).first?.journalNote,
            "正式记录"
        )

        clock.now = makeDate(day: 9, hour: 9)
        XCTAssertThrowsError(
            try repository.updateJournalNote(
                recordID: receipt.recordID,
                journalNote: "不能倒写修改时间"
            )
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidJournalNote)
        }
        XCTAssertEqual(
            try repository.allRecords(habitID: habit.id).first?.journalNote,
            "正式记录"
        )
    }

    func testSeparateContainersObserveOneSharedDiskCheckInFact() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "PulseConcurrentStoreTests-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("Pulse.store")
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let firstRepository = SwiftDataPulseRepository(
            container: try PersistenceController.makeContainer(
                storeName: "PulseConcurrentStore",
                storeURL: storeURL
            ),
            clock: clock,
            primaryHabitProvisioning: .createIfMissing(try makeInitialIdentity())
        )
        let firstHabit = try firstRepository.primaryHabit(systemTimeZone: timeZone)

        let secondRepository = SwiftDataPulseRepository(
            container: try PersistenceController.makeContainer(
                storeName: "PulseConcurrentStore",
                storeURL: storeURL
            ),
            clock: clock,
            primaryHabitProvisioning: .createIfMissing(try makeInitialIdentity())
        )
        let secondHabit = try secondRepository.primaryHabit(systemTimeZone: timeZone)
        XCTAssertEqual(secondHabit.id, firstHabit.id)
        XCTAssertTrue(try secondRepository.allRecords(habitID: secondHabit.id).isEmpty)

        let firstReceipt = try firstRepository.checkIn(habitID: firstHabit.id, journalNote: nil)
        let secondReceipt = try secondRepository.checkIn(habitID: secondHabit.id, journalNote: nil)

        let verificationRepository = SwiftDataPulseRepository(
            container: try PersistenceController.makeContainer(
                storeName: "PulseConcurrentStore",
                storeURL: storeURL
            ),
            clock: clock,
            primaryHabitProvisioning: .createIfMissing(try makeInitialIdentity())
        )
        let records = try verificationRepository.allRecords(habitID: firstHabit.id)

        XCTAssertEqual(firstReceipt.disposition, .created)
        XCTAssertEqual(secondReceipt.disposition, .alreadyPresent)
        XCTAssertEqual(secondReceipt.recordID, firstReceipt.recordID)
        XCTAssertEqual(records.map(\.id), [firstReceipt.recordID])
    }

    func testAuthoritativeClockCreatesDifferentDaysButCannotBackfillBeforeStart() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 23))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)

        _ = try repository.checkIn(habitID: habit.id, journalNote: nil)
        clock.now = makeDate(day: 11, hour: 0)
        _ = try repository.checkIn(habitID: habit.id, journalNote: nil)
        XCTAssertEqual(try repository.allRecords(habitID: habit.id).count, 2)

        clock.now = makeDate(day: 9, hour: 12)
        XCTAssertThrowsError(try repository.checkIn(habitID: habit.id, journalNote: nil)) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidCheckIn)
        }
        XCTAssertEqual(try repository.allRecords(habitID: habit.id).count, 2)
    }

    func testRecordCanBeDeletedWithoutAffectingOtherDays() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)
        let first = try repository.checkIn(
            habitID: habit.id,
            journalNote: "会随签到删除的记事"
        )
        clock.now = makeDate(day: 11, hour: 9)
        let second = try repository.checkIn(habitID: habit.id, journalNote: nil)

        try repository.delete(recordID: first.recordID)
        let remaining = try repository.allRecords(habitID: habit.id)

        XCTAssertEqual(remaining.map(\.id), [second.recordID])
        XCTAssertFalse(remaining.contains { $0.journalNote != nil })
    }

    func testResetCreatesANewEmptyPrimaryHabitAtAuthoritativeNow() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        let original = try repository.primaryHabit(systemTimeZone: timeZone)
        _ = try repository.checkIn(habitID: original.id, journalNote: nil)

        clock.now = makeDate(day: 11, hour: 9)
        let replacement = try repository.resetAll(systemTimeZone: timeZone)

        XCTAssertNotEqual(original.id, replacement.id)
        XCTAssertEqual(replacement.startLogicalDay, LogicalDay(year: 2026, month: 8, day: 11))
        XCTAssertTrue(try repository.allRecords(habitID: replacement.id).isEmpty)
        XCTAssertEqual(try repository.primaryHabit(systemTimeZone: timeZone).id, replacement.id)
        XCTAssertFalse(replacement.isIdentityConfirmed)
    }

    func testTimeZoneUpdateRejectsInvalidOrPreStartTransition() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 12))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)

        XCTAssertThrowsError(
            try repository.updateTimeZone(
                habitID: habit.id,
                identifier: "Invalid/TimeZone"
            )
        )
        XCTAssertThrowsError(
            try repository.updateTimeZone(
                habitID: habit.id,
                identifier: "America/Los_Angeles"
            )
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidTimeZoneTransition)
        }
        XCTAssertEqual(habit.timeZoneIdentifier, timeZone.identifier)
    }

    func testTimeZoneUpdateNeverRewritesStableStartDay() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 12))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)
        let originalStart = habit.startLogicalDay

        try repository.updateTimeZone(habitID: habit.id, identifier: "UTC")
        let updated = try repository.primaryHabit(systemTimeZone: timeZone)

        XCTAssertEqual(habit.startLogicalDay, originalStart)
        XCTAssertEqual(updated.creationTimeZoneIdentifier, timeZone.identifier)
        XCTAssertEqual(updated.timeZoneIdentifier, "UTC")
    }

    func testImportReplacesCurrentDataWithValidatedPayload() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        let original = try repository.primaryHabit(systemTimeZone: timeZone)
        _ = try repository.checkIn(habitID: original.id, journalNote: nil)
        let importedHabitID = UUID()
        let importedRecordID = UUID()
        let createdAt = makeDate(day: 9, hour: 8)
        let checkedAt = makeDate(day: 9, hour: 9)
        let payload = makePayload(
            habitID: importedHabitID,
            createdAt: createdAt,
            exportedAt: makeDate(day: 10, hour: 9),
            records: [
                .init(
                    id: importedRecordID,
                    logicalDay: "2026-08-09",
                    checkedAt: checkedAt,
                    createdAt: checkedAt,
                    timeZoneIdentifier: timeZone.identifier
                )
            ]
        )

        let imported = try repository.replaceAll(with: payload)
        let records = try repository.allRecords(habitID: imported.id)

        XCTAssertEqual(imported.id, importedHabitID)
        XCTAssertEqual(imported.name, "Imported")
        XCTAssertEqual(imported.purpose, "A reason")
        XCTAssertTrue(imported.isIdentityConfirmed)
        XCTAssertEqual(records.map(\.id), [importedRecordID])
        XCTAssertEqual(records.first?.logicalDay.storageValue, "2026-08-09")
        XCTAssertEqual(records.first?.timeZoneIdentifier, timeZone.identifier)
    }

    func testInvalidImportDoesNotDeleteCurrentData() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        let original = try repository.primaryHabit(systemTimeZone: timeZone)
        let originalRecord = try repository.checkIn(habitID: original.id, journalNote: nil)
        let checkedAt = makeDate(day: 9, hour: 9)
        let duplicateDay = PulseBackupPayload.RecordPayload(
            id: UUID(),
            logicalDay: "2026-08-09",
            checkedAt: checkedAt,
            createdAt: checkedAt,
            timeZoneIdentifier: timeZone.identifier
        )
        let payload = makePayload(
            createdAt: makeDate(day: 9, hour: 8),
            exportedAt: makeDate(day: 10, hour: 9),
            records: [
                duplicateDay,
                .init(
                    id: UUID(),
                    logicalDay: duplicateDay.logicalDay,
                    checkedAt: duplicateDay.checkedAt,
                    createdAt: duplicateDay.createdAt,
                    timeZoneIdentifier: duplicateDay.timeZoneIdentifier
                )
            ]
        )

        XCTAssertThrowsError(try repository.replaceAll(with: payload))
        XCTAssertEqual(try repository.primaryHabit(systemTimeZone: timeZone).id, original.id)
        XCTAssertEqual(
            try repository.allRecords(habitID: original.id).map(\.id),
            [originalRecord.recordID]
        )
    }

    func testImportRejectsLogicalDayThatDoesNotMatchRecordTimeZone() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        _ = try repository.primaryHabit(systemTimeZone: timeZone)
        let checkedAt = makeDate(day: 9, hour: 9)
        let payload = makePayload(
            createdAt: makeDate(day: 9, hour: 8),
            exportedAt: makeDate(day: 10, hour: 9),
            records: [
                .init(
                    id: UUID(),
                    logicalDay: "2026-08-10",
                    checkedAt: checkedAt,
                    createdAt: checkedAt,
                    timeZoneIdentifier: timeZone.identifier
                )
            ]
        )

        XCTAssertThrowsError(try repository.replaceAll(with: payload)) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidBackup)
        }
    }

    func testCorruptedHabitCannotEscapeRepositoryAsAValueSnapshot() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let container = try PersistenceController.makeInMemoryContainer()
        let repository = try makeRepository(container: container, clock: clock)
        let original = try repository.primaryHabit(systemTimeZone: timeZone)

        let mutationContext = ModelContext(container)
        mutationContext.autosaveEnabled = false
        let storedHabit = try XCTUnwrap(mutationContext.fetch(FetchDescriptor<Habit>()).first)
        XCTAssertEqual(storedHabit.id, original.id)
        storedHabit.name = " Corrupted "
        try mutationContext.save()

        let validatingRepository = try makeRepository(container: container, clock: clock)
        XCTAssertThrowsError(
            try validatingRepository.primaryHabit(systemTimeZone: timeZone)
        ) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidHabitIdentity)
        }
    }

    func testCorruptedRecordCannotEscapeRepositoryAsAValueSnapshot() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let container = try PersistenceController.makeInMemoryContainer()
        let repository = try makeRepository(container: container, clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)
        let receipt = try repository.checkIn(habitID: habit.id, journalNote: nil)

        let mutationContext = ModelContext(container)
        mutationContext.autosaveEnabled = false
        let storedRecord = try XCTUnwrap(
            mutationContext.fetch(FetchDescriptor<CheckInRecord>()).first
        )
        XCTAssertEqual(storedRecord.id, receipt.recordID)
        storedRecord.recordKey = "corrupted-record-key"
        try mutationContext.save()

        let validatingRepository = try makeRepository(container: container, clock: clock)
        XCTAssertThrowsError(
            try validatingRepository.checkIn(habitID: habit.id, journalNote: nil)
        ) { error in
            XCTAssertEqual(
                error as? PulseCoreError,
                .invalidRecordDate(storedRecord.logicalDayValue)
            )
        }
        XCTAssertThrowsError(
            try validatingRepository.allRecords(habitID: habit.id)
        ) { error in
            XCTAssertEqual(
                error as? PulseCoreError,
                .invalidRecordDate(storedRecord.logicalDayValue)
            )
        }
    }

    private func makePayload(
        habitID: UUID = UUID(),
        createdAt: Date,
        exportedAt: Date,
        records: [PulseBackupPayload.RecordPayload]
    ) -> PulseBackupPayload {
        PulseBackupPayload(
            format: PulseBackupContract.payloadFormatIdentifier,
            schemaVersion: PulseBackupContract.payloadSchemaVersion,
            exportedAt: exportedAt,
            habit: .init(
                id: habitID,
                name: "Imported",
                purpose: "A reason",
                isIdentityConfirmed: true,
                createdAt: createdAt,
                startLogicalDay: LogicalDay.resolve(
                    at: createdAt,
                    timeZone: timeZone
                ).storageValue,
                creationTimeZoneIdentifier: timeZone.identifier,
                timeZoneIdentifier: timeZone.identifier
            ),
            records: records,
            media: []
        )
    }

    private func makeRepository(clock: MutableRepositoryClock) throws -> SwiftDataPulseRepository {
        try makeRepository(
            container: PersistenceController.makeInMemoryContainer(),
            clock: clock
        )
    }

    private func makeRepository(
        container: ModelContainer,
        clock: MutableRepositoryClock
    ) throws -> SwiftDataPulseRepository {
        SwiftDataPulseRepository(
            container: container,
            clock: clock,
            primaryHabitProvisioning: .createIfMissing(try makeInitialIdentity())
        )
    }

    private func makeInitialIdentity() throws -> HabitIdentity {
        try HabitIdentity(userName: "Test Habit", userPurpose: nil)
    }

    private func makeWatchCommand(
        habit: HabitSnapshot,
        occurredAt: Date
    ) -> PulseWatchCheckInCommand {
        PulseWatchCheckInCommand(
            projectID: habit.id,
            projectRevision: PulseWatchProjectRevision.make(
                projectID: habit.id,
                startLogicalDay: habit.startLogicalDay.storageValue,
                timeZoneIdentifier: habit.timeZoneIdentifier
            ),
            occurredAt: occurredAt,
            projectTimeZoneIdentifierSnapshot: habit.timeZoneIdentifier
        )
    }

    private func confirmedHabit(
        _ repository: SwiftDataPulseRepository
    ) throws -> HabitSnapshot {
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)
        return try repository.updateIdentity(
            habitID: habit.id,
            identity: try makeInitialIdentity()
        )
    }

    private func makeDate(day: Int, hour: Int) -> Date {
        Calendar.pulseGregorian(timeZone: timeZone).date(
            from: DateComponents(year: 2026, month: 8, day: day, hour: hour)
        )!
    }
}

@MainActor
private final class MutableRepositoryClock: PulseClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
