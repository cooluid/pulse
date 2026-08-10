import SwiftData
import XCTest
@testable import pulse

@MainActor
final class CheckInRepositoryTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "Asia/Shanghai")!

    func testPrimaryHabitIsCreatedOnlyOnce() throws {
        let repository = try makeRepository()
        let now = makeDate(day: 10, hour: 12)

        let first = try repository.primaryHabit(now: now, systemTimeZone: timeZone)
        let second = try repository.primaryHabit(now: now, systemTimeZone: timeZone)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.timeZoneIdentifier, timeZone.identifier)
    }

    func testCheckInIsIdempotentForSameLogicalDay() throws {
        let repository = try makeRepository()
        let firstTime = makeDate(day: 10, hour: 9)
        let secondTime = makeDate(day: 10, hour: 21)
        let habit = try repository.primaryHabit(now: firstTime, systemTimeZone: timeZone)

        let first = try repository.checkIn(habit: habit, at: firstTime)
        let second = try repository.checkIn(habit: habit, at: secondTime)
        let records = try repository.allRecords(habitID: habit.id)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.checkedAt, firstTime)
        XCTAssertEqual(records.count, 1)
    }

    func testDifferentLogicalDaysCreateDifferentRecords() throws {
        let repository = try makeRepository()
        let firstTime = makeDate(day: 10, hour: 23)
        let secondTime = makeDate(day: 11, hour: 0)
        let habit = try repository.primaryHabit(now: firstTime, systemTimeZone: timeZone)

        _ = try repository.checkIn(habit: habit, at: firstTime)
        _ = try repository.checkIn(habit: habit, at: secondTime)

        XCTAssertEqual(try repository.allRecords(habitID: habit.id).count, 2)
    }

    func testRecordCanBeDeletedWithoutAffectingOtherDays() throws {
        let repository = try makeRepository()
        let firstTime = makeDate(day: 10, hour: 9)
        let secondTime = makeDate(day: 11, hour: 9)
        let habit = try repository.primaryHabit(now: firstTime, systemTimeZone: timeZone)
        let first = try repository.checkIn(habit: habit, at: firstTime)
        let second = try repository.checkIn(habit: habit, at: secondTime)

        try repository.delete(recordID: first.id)
        let remaining = try repository.allRecords(habitID: habit.id)

        XCTAssertEqual(remaining.map(\.id), [second.id])
    }

    func testResetCreatesANewEmptyPrimaryHabit() throws {
        let repository = try makeRepository()
        let now = makeDate(day: 10, hour: 9)
        let original = try repository.primaryHabit(now: now, systemTimeZone: timeZone)
        _ = try repository.checkIn(habit: original, at: now)

        let replacement = try repository.resetAll(
            now: makeDate(day: 11, hour: 9),
            systemTimeZone: timeZone
        )

        XCTAssertNotEqual(original.id, replacement.id)
        XCTAssertTrue(try repository.allRecords(habitID: replacement.id).isEmpty)
        XCTAssertEqual(
            try repository.primaryHabit(now: now, systemTimeZone: timeZone).id,
            replacement.id
        )
    }

    func testTimeZoneUpdateRejectsInvalidIdentifiers() throws {
        let repository = try makeRepository()
        let now = makeDate(day: 10, hour: 9)
        let habit = try repository.primaryHabit(now: now, systemTimeZone: timeZone)

        XCTAssertThrowsError(try repository.updateTimeZone(habit: habit, identifier: "Invalid/TimeZone"))
        XCTAssertEqual(habit.timeZoneIdentifier, timeZone.identifier)
    }

    func testImportReplacesCurrentDataWithValidatedPayload() throws {
        let repository = try makeRepository()
        let now = makeDate(day: 10, hour: 9)
        let original = try repository.primaryHabit(now: now, systemTimeZone: timeZone)
        _ = try repository.checkIn(habit: original, at: now)
        let importedHabitID = UUID()
        let importedRecordID = UUID()
        let payload = PulseExportPayload(
            schemaVersion: PulseDataContract.exportSchemaVersion,
            exportedAt: now,
            habit: .init(
                id: importedHabitID,
                name: "Imported",
                createdAt: now,
                timeZoneIdentifier: timeZone.identifier,
                dayStartMinutes: 0
            ),
            records: [
                .init(
                    id: importedRecordID,
                    logicalDay: "2026-08-09",
                    checkedAt: makeDate(day: 9, hour: 9),
                    createdAt: makeDate(day: 9, hour: 9),
                    source: CheckInSource.manual.rawValue
                )
            ]
        )

        let imported = try repository.replaceAll(with: payload)
        let records = try repository.allRecords(habitID: imported.id)

        XCTAssertEqual(imported.id, importedHabitID)
        XCTAssertEqual(imported.name, "Imported")
        XCTAssertEqual(records.map(\.id), [importedRecordID])
        XCTAssertEqual(records.first?.logicalDayValue, "2026-08-09")
    }

    func testInvalidImportDoesNotDeleteCurrentData() throws {
        let repository = try makeRepository()
        let now = makeDate(day: 10, hour: 9)
        let original = try repository.primaryHabit(now: now, systemTimeZone: timeZone)
        let originalRecord = try repository.checkIn(habit: original, at: now)
        let duplicateDay = PulseExportPayload.RecordPayload(
            id: UUID(),
            logicalDay: "2026-08-09",
            checkedAt: makeDate(day: 9, hour: 9),
            createdAt: makeDate(day: 9, hour: 9),
            source: CheckInSource.manual.rawValue
        )
        let payload = PulseExportPayload(
            schemaVersion: PulseDataContract.exportSchemaVersion,
            exportedAt: now,
            habit: .init(
                id: UUID(),
                name: "Imported",
                createdAt: now,
                timeZoneIdentifier: timeZone.identifier,
                dayStartMinutes: 0
            ),
            records: [
                duplicateDay,
                .init(
                    id: UUID(),
                    logicalDay: duplicateDay.logicalDay,
                    checkedAt: duplicateDay.checkedAt,
                    createdAt: duplicateDay.createdAt,
                    source: duplicateDay.source
                )
            ]
        )

        XCTAssertThrowsError(try repository.replaceAll(with: payload))
        XCTAssertEqual(try repository.primaryHabit(now: now, systemTimeZone: timeZone).id, original.id)
        XCTAssertEqual(try repository.allRecords(habitID: original.id).map(\.id), [originalRecord.id])
    }

    private func makeRepository() throws -> SwiftDataCheckInRepository {
        SwiftDataCheckInRepository(container: try PersistenceController.makeContainer(inMemory: true))
    }

    private func makeDate(day: Int, hour: Int) -> Date {
        Calendar.pulseGregorian(timeZone: timeZone).date(
            from: DateComponents(year: 2026, month: 8, day: day, hour: hour)
        )!
    }
}
