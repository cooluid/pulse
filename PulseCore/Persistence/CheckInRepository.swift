import Foundation
import SwiftData

@MainActor
public protocol CheckInRepositoryProtocol: AnyObject {
    func existingPrimaryHabit() throws -> HabitSnapshot?
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
public final class SwiftDataCheckInRepository: CheckInRepositoryProtocol {
    private let container: ModelContainer
    private var context: ModelContext
    private let clock: any PulseClock
    private let initialIdentity: HabitIdentity

    public init(
        container: ModelContainer,
        clock: any PulseClock,
        initialIdentity: HabitIdentity
    ) {
        self.container = container
        context = Self.makeContext(container: container)
        self.clock = clock
        self.initialIdentity = initialIdentity
    }

    public func existingPrimaryHabit() throws -> HabitSnapshot? {
        let slotKey = Habit.primarySlotKey
        var descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { habit in
                habit.slotKey == slotKey
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map(validatedHabitSnapshot)
    }

    public func primaryHabit(systemTimeZone: TimeZone) throws -> HabitSnapshot {
        if let existing = try existingPrimaryHabit() {
            return existing
        }

        let now = clock.now
        let startLogicalDay = LogicalDay.resolve(
            at: now,
            timeZone: systemTimeZone
        )
        let habit = Habit(
            name: initialIdentity.name,
            purpose: initialIdentity.purpose,
            isIdentityConfirmed: false,
            createdAt: now,
            startLogicalDay: startLogicalDay,
            creationTimeZoneIdentifier: systemTimeZone.identifier,
            timeZoneIdentifier: systemTimeZone.identifier
        )
        context.insert(habit)
        try saveOrRollback()
        return try validatedHabitSnapshot(habit)
    }

    public func allRecords(habitID: UUID) throws -> [CheckInRecordSnapshot] {
        let persistedHabit = try requirePrimaryHabit(id: habitID)
        let descriptor = FetchDescriptor<CheckInRecord>(
            predicate: #Predicate { record in
                record.habitID == habitID
            },
            sortBy: [SortDescriptor(\CheckInRecord.checkedAt)]
        )
        return try validatedRecordSnapshots(
            try context.fetch(descriptor),
            habit: persistedHabit
        )
    }

    public func updateIdentity(habitID: UUID, identity: HabitIdentity) throws -> HabitSnapshot {
        let persistedHabit = try requirePrimaryHabit(id: habitID)
        guard persistedHabit.name != identity.name
                || persistedHabit.purpose != identity.purpose
                || !persistedHabit.isIdentityConfirmed else {
            return try validatedHabitSnapshot(persistedHabit)
        }

        persistedHabit.name = identity.name
        persistedHabit.purpose = identity.purpose
        persistedHabit.isIdentityConfirmed = true
        try saveOrRollback()
        return try validatedHabitSnapshot(persistedHabit)
    }

    public func checkIn(habitID: UUID) throws -> CheckInCommitReceipt {
        let persistedHabit = try requirePrimaryHabit(id: habitID)
        let date = clock.now
        let day = try persistedHabit.logicalDay(at: date)
        guard let startLogicalDay = persistedHabit.startLogicalDay,
              day >= startLogicalDay else {
            throw PulseCoreError.invalidCheckIn
        }

        let sameDayRecords = try recordsForLogicalDay(
            habitID: persistedHabit.id,
            day: day
        )
        if let sameDayRecord = sameDayRecords.first {
            _ = try validatedRecordSnapshots(
                sameDayRecords,
                habit: persistedHabit
            )
            return try commitReceipt(
                for: sameDayRecord,
                habitID: persistedHabit.id,
                expectedDay: day,
                disposition: .alreadyPresent
            )
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
                habitID: habitID,
                expectedDay: day,
                disposition: .alreadyPresent
            )
        }
        return try commitReceipt(
            for: newRecord,
            habitID: habitID,
            expectedDay: day,
            disposition: .created
        )
    }

    private func commitReceipt(
        for record: CheckInRecord,
        habitID: UUID,
        expectedDay: LogicalDay,
        disposition: CheckInCommitDisposition
    ) throws -> CheckInCommitReceipt {
        let habit = try requirePrimaryHabit(id: habitID)
        guard let snapshot = try validatedRecordSnapshots([record], habit: habit).first,
              snapshot.logicalDay == expectedDay else {
            throw PulseCoreError.invalidRecordDate(record.logicalDayValue)
        }
        return CheckInCommitReceipt(
            recordID: snapshot.id,
            logicalDay: snapshot.logicalDay,
            checkedAt: snapshot.checkedAt,
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

    private func recordsForLogicalDay(
        habitID: UUID,
        day: LogicalDay
    ) throws -> [CheckInRecord] {
        let logicalDayValue = day.storageValue
        return try context.fetch(
            FetchDescriptor<CheckInRecord>(
                predicate: #Predicate { record in
                    record.habitID == habitID
                        && record.logicalDayValue == logicalDayValue
                }
            )
        )
    }

    public func delete(recordID: UUID) throws {
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

    public func updateTimeZone(habitID: UUID, identifier: String) throws {
        guard let timeZone = TimeZone(identifier: identifier) else {
            throw PulseCoreError.invalidTimeZone(identifier)
        }

        let persistedHabit = try requirePrimaryHabit(id: habitID)
        guard let startLogicalDay = persistedHabit.startLogicalDay else {
            throw PulseCoreError.invalidRecordDate(persistedHabit.startLogicalDayValue)
        }
        let newToday = LogicalDay.resolve(at: clock.now, timeZone: timeZone)
        guard newToday >= startLogicalDay else {
            throw PulseCoreError.invalidTimeZoneTransition
        }

        persistedHabit.timeZoneIdentifier = identifier
        try saveOrRollback()
    }

    public func resetAll(systemTimeZone: TimeZone) throws -> HabitSnapshot {
        let records = try context.fetch(FetchDescriptor<CheckInRecord>())
        let habits = try context.fetch(FetchDescriptor<Habit>())
        records.forEach(context.delete)
        habits.forEach(context.delete)

        let now = clock.now
        let startLogicalDay = LogicalDay.resolve(
            at: now,
            timeZone: systemTimeZone
        )
        let newHabit = Habit(
            name: initialIdentity.name,
            purpose: initialIdentity.purpose,
            isIdentityConfirmed: false,
            createdAt: now,
            startLogicalDay: startLogicalDay,
            creationTimeZoneIdentifier: systemTimeZone.identifier,
            timeZoneIdentifier: systemTimeZone.identifier
        )
        context.insert(newHabit)
        try saveOrRollback()
        return try validatedHabitSnapshot(newHabit)
    }

    public func replaceAll(with payload: PulseExportPayload) throws -> HabitSnapshot {
        guard payload.schemaVersion == PulseDataContract.exportSchemaVersion else {
            throw PulseCoreError.unsupportedImportVersion(payload.schemaVersion)
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
        return try validatedHabitSnapshot(importedHabit)
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
            throw PulseCoreError.invalidCheckIn
        }
        _ = try validatedHabitSnapshot(habit)
        return habit
    }

    private func validatedHabitSnapshot(_ habit: Habit) throws -> HabitSnapshot {
        let identity: HabitIdentity
        do {
            identity = try HabitIdentity(
                storedName: habit.name,
                storedPurpose: habit.purpose
            )
        } catch {
            throw PulseCoreError.invalidHabitIdentity
        }

        guard habit.slotKey == Habit.primarySlotKey,
              identity.name == habit.name,
              identity.purpose == habit.purpose,
              let startLogicalDay = habit.startLogicalDay,
              let creationTimeZone = TimeZone(identifier: habit.creationTimeZoneIdentifier),
              let timeZone = TimeZone(identifier: habit.timeZoneIdentifier),
              LogicalDay.resolve(at: habit.createdAt, timeZone: creationTimeZone)
                == startLogicalDay else {
            throw PulseCoreError.invalidRecordDate(habit.startLogicalDayValue)
        }

        return HabitSnapshot(
            model: habit,
            startLogicalDay: startLogicalDay,
            creationTimeZone: creationTimeZone,
            timeZone: timeZone
        )
    }

    private func validatedRecordSnapshots(
        _ records: [CheckInRecord],
        habit: Habit
    ) throws -> [CheckInRecordSnapshot] {
        guard let habitStartDay = habit.startLogicalDay else {
            throw PulseCoreError.invalidRecordDate(habit.startLogicalDayValue)
        }

        var logicalDays = Set<LogicalDay>()
        return try records.map { record in
            guard record.habitID == habit.id,
                  let logicalDay = record.logicalDay,
                  let recordTimeZone = record.timeZone,
                  LogicalDay.resolve(at: record.checkedAt, timeZone: recordTimeZone)
                    == logicalDay,
                  logicalDay >= habitStartDay,
                  record.checkedAt >= habit.createdAt,
                  record.createdAt >= record.checkedAt,
                  record.recordKey == CheckInRecordKey.make(
                    habitID: habit.id,
                    logicalDay: logicalDay
                  ),
                  logicalDays.insert(logicalDay).inserted else {
                throw PulseCoreError.invalidRecordDate(record.logicalDayValue)
            }
            return CheckInRecordSnapshot(
                model: record,
                logicalDay: logicalDay,
                timeZone: recordTimeZone
            )
        }
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
