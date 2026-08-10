import Foundation
import SwiftData

@MainActor
protocol CheckInRepositoryProtocol: AnyObject {
    func primaryHabit(now: Date, systemTimeZone: TimeZone) throws -> Habit
    func allRecords(habitID: UUID) throws -> [CheckInRecord]
    func record(habitID: UUID, day: LogicalDay) throws -> CheckInRecord?
    func checkIn(habit: Habit, at date: Date) throws -> CheckInRecord
    func delete(recordID: UUID) throws
    func updateTimeZone(habit: Habit, identifier: String) throws
    func resetAll(now: Date, systemTimeZone: TimeZone) throws -> Habit
    func replaceAll(with payload: PulseExportPayload) throws -> Habit
}

@MainActor
final class SwiftDataCheckInRepository: CheckInRepositoryProtocol {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func primaryHabit(now: Date, systemTimeZone: TimeZone) throws -> Habit {
        let slotKey = Habit.primarySlotKey
        var descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { habit in
                habit.slotKey == slotKey && habit.isArchived == false
            }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            return existing
        }

        let habit = Habit(
            name: String(localized: "habit.default_name"),
            createdAt: now,
            timeZoneIdentifier: systemTimeZone.identifier
        )
        context.insert(habit)
        try saveOrRollback()
        return habit
    }

    func allRecords(habitID: UUID) throws -> [CheckInRecord] {
        let descriptor = FetchDescriptor<CheckInRecord>(
            predicate: #Predicate { record in
                record.habitID == habitID
            },
            sortBy: [SortDescriptor(\CheckInRecord.checkedAt)]
        )
        return try context.fetch(descriptor)
    }

    func record(habitID: UUID, day: LogicalDay) throws -> CheckInRecord? {
        let recordKey = CheckInRecord.makeRecordKey(habitID: habitID, logicalDay: day)
        var descriptor = FetchDescriptor<CheckInRecord>(
            predicate: #Predicate { record in
                record.recordKey == recordKey
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func checkIn(habit: Habit, at date: Date) throws -> CheckInRecord {
        let day = try habit.logicalDay(at: date)
        if let existing = try record(habitID: habit.id, day: day) {
            return existing
        }

        let newRecord = CheckInRecord(
            habitID: habit.id,
            logicalDay: day,
            checkedAt: date,
            createdAt: date,
            source: .manual
        )
        context.insert(newRecord)
        try saveOrRollback()
        return newRecord
    }

    func delete(recordID: UUID) throws {
        var descriptor = FetchDescriptor<CheckInRecord>(
            predicate: #Predicate { record in
                record.id == recordID
            }
        )
        descriptor.fetchLimit = 1

        guard let record = try context.fetch(descriptor).first else { return }
        context.delete(record)
        try saveOrRollback()
    }

    func updateTimeZone(habit: Habit, identifier: String) throws {
        guard TimeZone(identifier: identifier) != nil else {
            throw PulseError.invalidTimeZone(identifier)
        }

        habit.timeZoneIdentifier = identifier
        try saveOrRollback()
    }

    func resetAll(now: Date, systemTimeZone: TimeZone) throws -> Habit {
        let records = try context.fetch(FetchDescriptor<CheckInRecord>())
        let habits = try context.fetch(FetchDescriptor<Habit>())
        records.forEach(context.delete)
        habits.forEach(context.delete)

        let newHabit = Habit(
            name: String(localized: "habit.default_name"),
            createdAt: now,
            timeZoneIdentifier: systemTimeZone.identifier
        )
        context.insert(newHabit)
        try saveOrRollback()
        return newHabit
    }

    func replaceAll(with payload: PulseExportPayload) throws -> Habit {
        guard payload.schemaVersion == PulseDataContract.exportSchemaVersion else {
            throw PulseError.unsupportedImportVersion(payload.schemaVersion)
        }
        guard TimeZone(identifier: payload.habit.timeZoneIdentifier) != nil,
              (0..<1_440).contains(payload.habit.dayStartMinutes) else {
            throw PulseError.invalidImport
        }

        var logicalDays = Set<LogicalDay>()
        var recordIDs = Set<UUID>()
        let validatedRecords: [(PulseExportPayload.RecordPayload, LogicalDay, CheckInSource)] = try payload.records.map { record in
            guard let day = LogicalDay(storageValue: record.logicalDay),
                  let source = CheckInSource(rawValue: record.source),
                  logicalDays.insert(day).inserted,
                  recordIDs.insert(record.id).inserted else {
                throw PulseError.invalidImport
            }
            return (record, day, source)
        }

        let currentRecords = try context.fetch(FetchDescriptor<CheckInRecord>())
        let currentHabits = try context.fetch(FetchDescriptor<Habit>())
        currentRecords.forEach(context.delete)
        currentHabits.forEach(context.delete)

        let importedHabit = Habit(
            id: payload.habit.id,
            name: payload.habit.name,
            createdAt: payload.habit.createdAt,
            timeZoneIdentifier: payload.habit.timeZoneIdentifier,
            dayStartMinutes: payload.habit.dayStartMinutes
        )
        context.insert(importedHabit)

        for (record, day, source) in validatedRecords {
            context.insert(
                CheckInRecord(
                    id: record.id,
                    habitID: importedHabit.id,
                    logicalDay: day,
                    checkedAt: record.checkedAt,
                    createdAt: record.createdAt,
                    source: source
                )
            )
        }

        try saveOrRollback()
        return importedHabit
    }

    private func saveOrRollback() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
