import Foundation
import SwiftData

@MainActor
protocol CheckInRepositoryProtocol: AnyObject {
    func primaryHabit(systemTimeZone: TimeZone) throws -> HabitSnapshot
    func allRecords(habitID: UUID) throws -> [CheckInRecordSnapshot]
    func updateIdentity(habitID: UUID, identity: HabitIdentity) throws -> HabitSnapshot
    func checkIn(habitID: UUID) throws -> CheckInCommitReceipt
    func delete(recordID: UUID) throws
    func updateTimeZone(habitID: UUID, identifier: String) throws
    func resetAll(systemTimeZone: TimeZone) throws -> HabitSnapshot
    func replaceAll(with payload: PulseExportPayload) throws -> HabitSnapshot
}

@MainActor
final class SwiftDataCheckInRepository: CheckInRepositoryProtocol {
    private let container: ModelContainer
    private var context: ModelContext
    private let clock: any PulseClock

    init(container: ModelContainer, clock: any PulseClock) {
        self.container = container
        context = Self.makeContext(container: container)
        self.clock = clock
    }

    func primaryHabit(systemTimeZone: TimeZone) throws -> HabitSnapshot {
        let slotKey = Habit.primarySlotKey
        var descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { habit in
                habit.slotKey == slotKey
            }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            return HabitSnapshot(model: existing)
        }

        let now = clock.now
        let startLogicalDay = LogicalDay.resolve(
            at: now,
            timeZone: systemTimeZone
        )
        let identity = try HabitIdentity(
            userName: String(localized: "habit.default_name"),
            userPurpose: nil
        )
        let habit = Habit(
            name: identity.name,
            purpose: identity.purpose,
            isIdentityConfirmed: false,
            createdAt: now,
            startLogicalDay: startLogicalDay,
            creationTimeZoneIdentifier: systemTimeZone.identifier,
            timeZoneIdentifier: systemTimeZone.identifier
        )
        context.insert(habit)
        try saveOrRollback()
        return HabitSnapshot(model: habit)
    }

    func allRecords(habitID: UUID) throws -> [CheckInRecordSnapshot] {
        let descriptor = FetchDescriptor<CheckInRecord>(
            predicate: #Predicate { record in
                record.habitID == habitID
            },
            sortBy: [SortDescriptor(\CheckInRecord.checkedAt)]
        )
        return try context.fetch(descriptor).map(CheckInRecordSnapshot.init(model:))
    }

    func updateIdentity(habitID: UUID, identity: HabitIdentity) throws -> HabitSnapshot {
        let persistedHabit = try requirePrimaryHabit(id: habitID)
        guard persistedHabit.name != identity.name
                || persistedHabit.purpose != identity.purpose
                || !persistedHabit.isIdentityConfirmed else {
            return HabitSnapshot(model: persistedHabit)
        }

        persistedHabit.name = identity.name
        persistedHabit.purpose = identity.purpose
        persistedHabit.isIdentityConfirmed = true
        try saveOrRollback()
        return HabitSnapshot(model: persistedHabit)
    }

    func checkIn(habitID: UUID) throws -> CheckInCommitReceipt {
        let persistedHabit = try requirePrimaryHabit(id: habitID)
        let date = clock.now
        let day = try persistedHabit.logicalDay(at: date)
        guard let startLogicalDay = persistedHabit.startLogicalDay,
              day >= startLogicalDay else {
            throw PulseError.invalidCheckIn
        }

        if let existing = try record(habitID: persistedHabit.id, day: day) {
            return try commitReceipt(for: existing, disposition: .alreadyPresent)
        }

        let newRecord = CheckInRecord(
            habitID: persistedHabit.id,
            logicalDay: day,
            checkedAt: date,
            createdAt: date,
            timeZoneIdentifier: persistedHabit.timeZoneIdentifier
        )
        context.insert(newRecord)
        return try saveNewCheckInOrResolveConcurrentWriter(
            newRecord,
            habitID: persistedHabit.id,
            day: day
        )
    }

    private func saveNewCheckInOrResolveConcurrentWriter(
        _ newRecord: CheckInRecord,
        habitID: UUID,
        day: LogicalDay
    ) throws -> CheckInCommitReceipt {
        do {
            try context.save()
        } catch {
            let saveError = error
            context.rollback()
            context = Self.makeContext(container: container)

            let concurrentRecord: CheckInRecord?
            do {
                concurrentRecord = try record(habitID: habitID, day: day)
            } catch {
                throw saveError
            }
            guard let concurrentRecord else {
                throw saveError
            }
            return try commitReceipt(
                for: concurrentRecord,
                disposition: .alreadyPresent
            )
        }
        return try commitReceipt(for: newRecord, disposition: .created)
    }

    private func commitReceipt(
        for record: CheckInRecord,
        disposition: CheckInCommitDisposition
    ) throws -> CheckInCommitReceipt {
        guard let logicalDay = record.logicalDay else {
            throw PulseError.invalidRecordDate(record.logicalDayValue)
        }
        return CheckInCommitReceipt(
            recordID: record.id,
            logicalDay: logicalDay,
            checkedAt: record.checkedAt,
            disposition: disposition
        )
    }

    private func record(habitID: UUID, day: LogicalDay) throws -> CheckInRecord? {
        let recordKey = CheckInRecordKey.make(habitID: habitID, logicalDay: day)
        var descriptor = FetchDescriptor<CheckInRecord>(
            predicate: #Predicate { record in
                record.recordKey == recordKey
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
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

    func updateTimeZone(habitID: UUID, identifier: String) throws {
        guard let timeZone = TimeZone(identifier: identifier) else {
            throw PulseError.invalidTimeZone(identifier)
        }

        let persistedHabit = try requirePrimaryHabit(id: habitID)
        guard let startLogicalDay = persistedHabit.startLogicalDay else {
            throw PulseError.invalidRecordDate(persistedHabit.startLogicalDayValue)
        }
        let newToday = LogicalDay.resolve(at: clock.now, timeZone: timeZone)
        guard newToday >= startLogicalDay else {
            throw PulseError.invalidTimeZoneTransition
        }

        persistedHabit.timeZoneIdentifier = identifier
        try saveOrRollback()
    }

    func resetAll(systemTimeZone: TimeZone) throws -> HabitSnapshot {
        let records = try context.fetch(FetchDescriptor<CheckInRecord>())
        let habits = try context.fetch(FetchDescriptor<Habit>())
        records.forEach(context.delete)
        habits.forEach(context.delete)

        let now = clock.now
        let startLogicalDay = LogicalDay.resolve(
            at: now,
            timeZone: systemTimeZone
        )
        let identity = try HabitIdentity(
            userName: String(localized: "habit.default_name"),
            userPurpose: nil
        )
        let newHabit = Habit(
            name: identity.name,
            purpose: identity.purpose,
            isIdentityConfirmed: false,
            createdAt: now,
            startLogicalDay: startLogicalDay,
            creationTimeZoneIdentifier: systemTimeZone.identifier,
            timeZoneIdentifier: systemTimeZone.identifier
        )
        context.insert(newHabit)
        try saveOrRollback()
        return HabitSnapshot(model: newHabit)
    }

    func replaceAll(with payload: PulseExportPayload) throws -> HabitSnapshot {
        guard payload.schemaVersion == PulseDataContract.exportSchemaVersion else {
            throw PulseError.unsupportedImportVersion(payload.schemaVersion)
        }
        let validated = try PulseDataValidator.validate(payload)

        let currentRecords = try context.fetch(FetchDescriptor<CheckInRecord>())
        let currentHabits = try context.fetch(FetchDescriptor<Habit>())
        currentRecords.forEach(context.delete)
        currentHabits.forEach(context.delete)

        let importedHabit = Habit(
            id: payload.habit.id,
            name: validated.identity.name,
            purpose: validated.identity.purpose,
            isIdentityConfirmed: payload.habit.isIdentityConfirmed,
            createdAt: payload.habit.createdAt,
            startLogicalDay: validated.startLogicalDay,
            creationTimeZoneIdentifier: payload.habit.creationTimeZoneIdentifier,
            timeZoneIdentifier: payload.habit.timeZoneIdentifier
        )
        context.insert(importedHabit)

        for validatedRecord in validated.records {
            let record = validatedRecord.payload
            context.insert(
                CheckInRecord(
                    id: record.id,
                    habitID: importedHabit.id,
                    logicalDay: validatedRecord.logicalDay,
                    checkedAt: record.checkedAt,
                    createdAt: record.createdAt,
                    timeZoneIdentifier: record.timeZoneIdentifier
                )
            )
        }

        try saveOrRollback()
        return HabitSnapshot(model: importedHabit)
    }

    private func requirePrimaryHabit(id: UUID) throws -> Habit {
        let slotKey = Habit.primarySlotKey
        var descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { habit in
                habit.slotKey == slotKey && habit.id == id
            }
        )
        descriptor.fetchLimit = 1
        guard let habit = try context.fetch(descriptor).first else {
            throw PulseError.invalidCheckIn
        }
        return habit
    }

    private func saveOrRollback() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func makeContext(container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }
}
