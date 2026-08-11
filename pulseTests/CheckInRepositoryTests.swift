import SwiftData
import XCTest
@testable import pulse

@MainActor
final class CheckInRepositoryTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "Asia/Shanghai")!

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
        let record = try repository.checkIn(habit: habit)
        let originalStart = habit.startLogicalDay
        let originalCreatedAt = habit.createdAt

        let updated = try repository.updateIdentity(
            habit: habit,
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
        let identity = try HabitIdentity(userName: "Daily Reading", userPurpose: nil)

        let first = try repository.updateIdentity(habit: habit, identity: identity)
        let second = try repository.updateIdentity(habit: habit, identity: identity)

        XCTAssertEqual(first.id, second.id)
        XCTAssertTrue(second.isIdentityConfirmed)
    }

    func testCheckInIsIdempotentForSameLogicalDay() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)

        let first = try repository.checkIn(habit: habit)
        clock.now = makeDate(day: 10, hour: 21)
        let second = try repository.checkIn(habit: habit)
        let records = try repository.allRecords(habitID: habit.id)

        XCTAssertEqual(first.recordID, second.recordID)
        XCTAssertEqual(first.checkedAt, makeDate(day: 10, hour: 9))
        XCTAssertEqual(first.disposition, .created)
        XCTAssertEqual(second.disposition, .alreadyPresent)
        XCTAssertEqual(records.count, 1)
    }

    func testAuthoritativeClockCreatesDifferentDaysButCannotBackfillBeforeStart() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 23))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)

        _ = try repository.checkIn(habit: habit)
        clock.now = makeDate(day: 11, hour: 0)
        _ = try repository.checkIn(habit: habit)
        XCTAssertEqual(try repository.allRecords(habitID: habit.id).count, 2)

        clock.now = makeDate(day: 9, hour: 12)
        XCTAssertThrowsError(try repository.checkIn(habit: habit)) { error in
            XCTAssertEqual(error as? PulseError, .invalidCheckIn)
        }
        XCTAssertEqual(try repository.allRecords(habitID: habit.id).count, 2)
    }

    func testRecordCanBeDeletedWithoutAffectingOtherDays() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)
        let first = try repository.checkIn(habit: habit)
        clock.now = makeDate(day: 11, hour: 9)
        let second = try repository.checkIn(habit: habit)

        try repository.delete(recordID: first.recordID)
        let remaining = try repository.allRecords(habitID: habit.id)

        XCTAssertEqual(remaining.map(\.id), [second.recordID])
    }

    func testResetCreatesANewEmptyPrimaryHabitAtAuthoritativeNow() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        let original = try repository.primaryHabit(systemTimeZone: timeZone)
        _ = try repository.checkIn(habit: original)

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

        XCTAssertThrowsError(try repository.updateTimeZone(habit: habit, identifier: "Invalid/TimeZone"))
        XCTAssertThrowsError(try repository.updateTimeZone(habit: habit, identifier: "America/Los_Angeles")) { error in
            XCTAssertEqual(error as? PulseError, .invalidTimeZoneTransition)
        }
        XCTAssertEqual(habit.timeZoneIdentifier, timeZone.identifier)
    }

    func testTimeZoneUpdateNeverRewritesStableStartDay() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 12))
        let repository = try makeRepository(clock: clock)
        let habit = try repository.primaryHabit(systemTimeZone: timeZone)
        let originalStart = habit.startLogicalDay

        try repository.updateTimeZone(habit: habit, identifier: "UTC")

        XCTAssertEqual(habit.startLogicalDay, originalStart)
        XCTAssertEqual(habit.creationTimeZoneIdentifier, timeZone.identifier)
        XCTAssertEqual(habit.timeZoneIdentifier, "UTC")
    }

    func testImportReplacesCurrentDataWithValidatedPayload() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        let original = try repository.primaryHabit(systemTimeZone: timeZone)
        _ = try repository.checkIn(habit: original)
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
        XCTAssertEqual(records.first?.logicalDayValue, "2026-08-09")
        XCTAssertEqual(records.first?.timeZoneIdentifier, timeZone.identifier)
    }

    func testInvalidImportDoesNotDeleteCurrentData() throws {
        let clock = MutableRepositoryClock(now: makeDate(day: 10, hour: 9))
        let repository = try makeRepository(clock: clock)
        let original = try repository.primaryHabit(systemTimeZone: timeZone)
        let originalRecord = try repository.checkIn(habit: original)
        let checkedAt = makeDate(day: 9, hour: 9)
        let duplicateDay = PulseExportPayload.RecordPayload(
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
            XCTAssertEqual(error as? PulseError, .invalidImport)
        }
    }

    private func makePayload(
        habitID: UUID = UUID(),
        createdAt: Date,
        exportedAt: Date,
        records: [PulseExportPayload.RecordPayload]
    ) -> PulseExportPayload {
        PulseExportPayload(
            format: PulseDataContract.formatIdentifier,
            schemaVersion: PulseDataContract.exportSchemaVersion,
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
            records: records
        )
    }

    private func makeRepository(clock: MutableRepositoryClock) throws -> SwiftDataCheckInRepository {
        SwiftDataCheckInRepository(
            container: try PersistenceController.makeContainer(inMemory: true),
            clock: clock
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
