import Foundation
import SwiftData

@MainActor
public protocol PulseRepositoryProtocol: AnyObject {
    func existingPrimaryHabit() throws -> HabitSnapshot?
    func primaryHabit(systemTimeZone: TimeZone) throws -> HabitSnapshot
    func allRecords(habitID: UUID) throws -> [CheckInRecordSnapshot]
    func allMedia(habitID: UUID) throws -> [ImprintMediaSnapshot]
    func updateIdentity(habitID: UUID, identity: HabitIdentity) throws -> HabitSnapshot
    func checkIn(habitID: UUID, journalNote: String?) throws -> CheckInCommitReceipt
    func updateJournalNote(recordID: UUID, journalNote: String?) throws -> CheckInRecordSnapshot
    func delete(recordID: UUID) throws
    func upsertMedia(_ draft: ImprintMediaDraft) throws -> ImprintMediaSnapshot
    func deleteMedia(id: UUID) throws
    func updateTimeZone(habitID: UUID, identifier: String) throws
    func resetAll(systemTimeZone: TimeZone) throws -> HabitSnapshot
    func replaceAll(with payload: PulseBackupPayload) throws -> HabitSnapshot
}

public enum PrimaryHabitProvisioning: Sendable {
    case existingStoreOnly
    case createIfMissing(HabitIdentity)
}

@MainActor
public final class SwiftDataPulseRepository: PulseRepositoryProtocol {
    private let container: ModelContainer
    private var context: ModelContext
    private let clock: any PulseClock
    private let primaryHabitProvisioning: PrimaryHabitProvisioning

    public init(
        container: ModelContainer,
        clock: any PulseClock,
        primaryHabitProvisioning: PrimaryHabitProvisioning
    ) {
        self.container = container
        context = Self.makeContext(container: container)
        self.clock = clock
        self.primaryHabitProvisioning = primaryHabitProvisioning
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
        guard case .createIfMissing(let initialIdentity) = primaryHabitProvisioning else {
            throw PulseCoreError.primaryHabitUnavailable
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

    public func allMedia(habitID: UUID) throws -> [ImprintMediaSnapshot] {
        let persistedHabit = try requirePrimaryHabit(id: habitID)
        let descriptor = FetchDescriptor<ImprintMedia>(
            predicate: #Predicate { media in
                media.habitID == habitID
            },
            sortBy: [SortDescriptor(\ImprintMedia.capturedAt)]
        )
        return try validatedMediaSnapshots(
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

    public func checkIn(habitID: UUID, journalNote: String?) throws -> CheckInCommitReceipt {
        let persistedHabit = try requirePrimaryHabit(id: habitID)
        let date = clock.now
        let day = try persistedHabit.logicalDay(at: date)
        guard let startLogicalDay = persistedHabit.startLogicalDay,
              day >= startLogicalDay else {
            throw PulseCoreError.invalidCheckIn
        }
        let canonicalJournalNote = try JournalNote.canonicalText(userInput: journalNote)

        let sameDayRecords = try recordsForLogicalDay(
            habitID: persistedHabit.id,
            day: day
        )
        if let sameDayRecord = sameDayRecords.first {
            _ = try validatedRecordSnapshots(
                sameDayRecords,
                habit: persistedHabit
            )
            try attachJournalNoteIfNeeded(
                to: sameDayRecord,
                journalNote: canonicalJournalNote,
                modifiedAt: date
            )
            try attachMediaIfNeeded(
                habitID: persistedHabit.id,
                day: day,
                recordID: sameDayRecord.id
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
            timeZoneIdentifier: persistedHabit.timeZoneIdentifier,
            journalNote: canonicalJournalNote,
            journalNoteModifiedAt: canonicalJournalNote == nil ? nil : date
        )
        context.insert(newRecord)
        try attachMediaIfNeeded(
            habitID: persistedHabit.id,
            day: day,
            recordID: newRecord.id,
            savesChanges: false
        )
        return try saveNewCheckInOrResolveConcurrentWriter(
            newRecord,
            habitID: persistedHabit.id,
            day: day,
            journalNote: canonicalJournalNote,
            journalNoteModifiedAt: date
        )
    }

    public func updateJournalNote(
        recordID: UUID,
        journalNote: String?
    ) throws -> CheckInRecordSnapshot {
        var descriptor = FetchDescriptor<CheckInRecord>(
            predicate: #Predicate { record in record.id == recordID }
        )
        descriptor.fetchLimit = 1
        guard let record = try context.fetch(descriptor).first else {
            throw PulseCoreError.invalidCheckIn
        }
        let habit = try requirePrimaryHabit(id: record.habitID)
        let canonicalJournalNote = try JournalNote.canonicalText(userInput: journalNote)
        guard record.journalNote != canonicalJournalNote else {
            return try validatedRecordSnapshots([record], habit: habit)[0]
        }
        let modificationDate = clock.now
        guard modificationDate >= record.checkedAt else {
            throw PulseCoreError.invalidJournalNote
        }

        record.journalNote = canonicalJournalNote
        record.journalNoteModifiedAt = modificationDate
        try saveOrRollback()
        return try validatedRecordSnapshots([record], habit: habit)[0]
    }

    private func saveNewCheckInOrResolveConcurrentWriter(
        _ newRecord: CheckInRecord,
        habitID: UUID,
        day: LogicalDay,
        journalNote: String?,
        journalNoteModifiedAt: Date
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
            try attachJournalNoteIfNeeded(
                to: concurrentRecord,
                journalNote: journalNote,
                modifiedAt: journalNoteModifiedAt
            )
            try attachMediaIfNeeded(
                habitID: habitID,
                day: day,
                recordID: concurrentRecord.id
            )
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

    private func attachJournalNoteIfNeeded(
        to record: CheckInRecord,
        journalNote: String?,
        modifiedAt: Date
    ) throws {
        guard record.journalNote == nil, let journalNote else { return }
        guard modifiedAt >= record.checkedAt else {
            throw PulseCoreError.invalidJournalNote
        }
        record.journalNote = journalNote
        record.journalNoteModifiedAt = modifiedAt
        try saveOrRollback()
    }

    private func attachMediaIfNeeded(
        habitID: UUID,
        day: LogicalDay,
        recordID: UUID,
        savesChanges: Bool = true
    ) throws {
        let mediaKey = ImprintMediaKey.make(habitID: habitID, logicalDay: day)
        var descriptor = FetchDescriptor<ImprintMedia>(
            predicate: #Predicate { media in media.mediaKey == mediaKey }
        )
        descriptor.fetchLimit = 1
        guard let media = try context.fetch(descriptor).first,
              media.recordID != recordID else { return }
        media.recordID = recordID
        if savesChanges {
            try saveOrRollback()
        }
    }

    public func delete(recordID: UUID) throws {
        var descriptor = FetchDescriptor<CheckInRecord>(
            predicate: #Predicate { record in
                record.id == recordID
            }
        )
        descriptor.fetchLimit = 1

        guard let record = try context.fetch(descriptor).first else { return }
        let recordID = record.id
        let media = try context.fetch(
            FetchDescriptor<ImprintMedia>(
                predicate: #Predicate { media in
                    media.recordID == recordID
                }
            )
        )
        media.forEach { $0.recordID = nil }
        context.delete(record)
        try saveOrRollback()
    }

    public func upsertMedia(_ draft: ImprintMediaDraft) throws -> ImprintMediaSnapshot {
        let habit = try requirePrimaryHabit(id: draft.habitID)
        guard let record = try record(habitID: draft.habitID, day: draft.logicalDay),
              draft.recordID == record.id else {
            throw PulseCoreError.invalidMedia
        }

        let mediaKey = ImprintMediaKey.make(
            habitID: draft.habitID,
            logicalDay: draft.logicalDay
        )
        var descriptor = FetchDescriptor<ImprintMedia>(
            predicate: #Predicate { media in
                media.mediaKey == mediaKey
            }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
        }
        let media = ImprintMedia(draft: draft, modifiedAt: clock.now)
        context.insert(media)
        try saveOrRollback()
        return try validatedMediaSnapshots([media], habit: habit)[0]
    }

    public func deleteMedia(id: UUID) throws {
        var descriptor = FetchDescriptor<ImprintMedia>(
            predicate: #Predicate { media in media.id == id }
        )
        descriptor.fetchLimit = 1
        guard let media = try context.fetch(descriptor).first else { return }
        context.delete(media)
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
        guard case .createIfMissing(let initialIdentity) = primaryHabitProvisioning else {
            throw PulseCoreError.primaryHabitUnavailable
        }
        let records = try context.fetch(FetchDescriptor<CheckInRecord>())
        let media = try context.fetch(FetchDescriptor<ImprintMedia>())
        let habits = try context.fetch(FetchDescriptor<Habit>())
        media.forEach(context.delete)
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

    public func replaceAll(with payload: PulseBackupPayload) throws -> HabitSnapshot {
        guard payload.schemaVersion == PulseBackupContract.payloadSchemaVersion else {
            throw PulseCoreError.unsupportedBackupPayloadVersion(payload.schemaVersion)
        }
        let validated = try PulseDataValidator.validate(payload)

        let currentRecords = try context.fetch(FetchDescriptor<CheckInRecord>())
        let currentMedia = try context.fetch(FetchDescriptor<ImprintMedia>())
        let currentHabits = try context.fetch(FetchDescriptor<Habit>())
        currentMedia.forEach(context.delete)
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
                    timeZoneIdentifier: record.timeZoneIdentifier,
                    journalNote: record.journalNote,
                    journalNoteModifiedAt: record.journalNoteModifiedAt
                )
            )
        }

        for validatedMedia in validated.media {
            context.insert(
                ImprintMedia(
                    draft: validatedMedia.draft,
                    modifiedAt: validatedMedia.modifiedAt
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
            let validatedJournalNote: String?
            do {
                validatedJournalNote = try JournalNote.validatedStoredText(record.journalNote)
            } catch {
                throw PulseCoreError.invalidJournalNote
            }
            guard record.habitID == habit.id,
                  let logicalDay = record.logicalDay,
                  let recordTimeZone = record.timeZone,
                  LogicalDay.resolve(at: record.checkedAt, timeZone: recordTimeZone)
                    == logicalDay,
                  logicalDay >= habitStartDay,
                  record.checkedAt >= habit.createdAt,
                  record.createdAt >= record.checkedAt,
                  validatedJournalNote == record.journalNote,
                  record.journalNote == nil || record.journalNoteModifiedAt != nil,
                  record.journalNoteModifiedAt == nil
                    || record.journalNoteModifiedAt! >= record.checkedAt,
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

    private func validatedMediaSnapshots(
        _ mediaItems: [ImprintMedia],
        habit: Habit
    ) throws -> [ImprintMediaSnapshot] {
        guard let habitStartDay = habit.startLogicalDay else {
            throw PulseCoreError.invalidRecordDate(habit.startLogicalDayValue)
        }
        var days = Set<LogicalDay>()
        return try mediaItems.map { media in
            guard media.habitID == habit.id,
                  let logicalDay = media.logicalDay,
                  logicalDay >= habitStartDay,
                  media.mediaKey == ImprintMediaKey.make(
                    habitID: habit.id,
                    logicalDay: logicalDay
                  ),
                  media.mediaType == "image/jpeg",
                  media.byteCount > 0,
                  media.byteCount <= PulseMediaFileStore.maximumOriginalBytes,
                  media.thumbnailByteCount > 0,
                  media.thumbnailByteCount <= PulseMediaFileStore.maximumThumbnailBytes,
                  media.pixelWidth > 0,
                  media.pixelHeight > 0,
                  media.sha256.count == 64,
                  media.sha256.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
                  media.thumbnailSHA256.count == 64,
                  media.thumbnailSHA256.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
                  PulseMediaPath.isValid(media.originalRelativePath, directory: .originals),
                  PulseMediaPath.isValid(media.thumbnailRelativePath, directory: .thumbnails),
                  media.capturedAt >= habit.createdAt,
                  media.createdAt >= media.capturedAt,
                  media.modifiedAt >= media.createdAt,
                  let cameraPosition = media.cameraPosition,
                  days.insert(logicalDay).inserted else {
                throw PulseCoreError.invalidMedia
            }
            if let recordID = media.recordID {
                guard try record(habitID: habit.id, day: logicalDay)?.id == recordID else {
                    throw PulseCoreError.invalidMedia
                }
            }
            return ImprintMediaSnapshot(
                id: media.id,
                habitID: media.habitID,
                recordID: media.recordID,
                logicalDay: logicalDay,
                capturedAt: media.capturedAt,
                createdAt: media.createdAt,
                modifiedAt: media.modifiedAt,
                originalRelativePath: media.originalRelativePath,
                thumbnailRelativePath: media.thumbnailRelativePath,
                mediaType: media.mediaType,
                byteCount: media.byteCount,
                thumbnailByteCount: media.thumbnailByteCount,
                pixelWidth: media.pixelWidth,
                pixelHeight: media.pixelHeight,
                sha256: media.sha256,
                thumbnailSHA256: media.thumbnailSHA256,
                cameraPosition: cameraPosition
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
