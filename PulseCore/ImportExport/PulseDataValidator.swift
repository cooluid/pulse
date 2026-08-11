import Foundation

struct ValidatedPulseImport {
    struct Record {
        let payload: PulseExportPayload.RecordPayload
        let logicalDay: LogicalDay
    }

    let startLogicalDay: LogicalDay
    let identity: HabitIdentity
    let records: [Record]
}

enum PulseDataValidator {
    static func validate(_ payload: PulseExportPayload) throws -> ValidatedPulseImport {
        guard payload.format == PulseDataContract.formatIdentifier,
              payload.schemaVersion == PulseDataContract.exportSchemaVersion,
              payload.records.count <= PulseDataContract.maximumRecordCount,
              let currentTimeZone = TimeZone(identifier: payload.habit.timeZoneIdentifier),
              let creationTimeZone = TimeZone(identifier: payload.habit.creationTimeZoneIdentifier),
              let startLogicalDay = LogicalDay(storageValue: payload.habit.startLogicalDay),
              LogicalDay.resolve(
                at: payload.habit.createdAt,
                timeZone: creationTimeZone
              ) == startLogicalDay,
              LogicalDay.resolve(at: payload.exportedAt, timeZone: currentTimeZone)
                >= startLogicalDay,
              payload.habit.createdAt <= payload.exportedAt else {
            throw PulseCoreError.invalidImport
        }

        let identity: HabitIdentity
        do {
            identity = try HabitIdentity(
                storedName: payload.habit.name,
                storedPurpose: payload.habit.purpose
            )
        } catch {
            throw PulseCoreError.invalidImport
        }

        var logicalDays = Set<LogicalDay>()
        var recordIDs = Set<UUID>()
        let records: [ValidatedPulseImport.Record] = try payload.records.map { record in
            guard let logicalDay = LogicalDay(storageValue: record.logicalDay),
                  let recordTimeZone = TimeZone(identifier: record.timeZoneIdentifier),
                  LogicalDay.resolve(
                    at: record.checkedAt,
                    timeZone: recordTimeZone
                  ) == logicalDay,
                  logicalDay >= startLogicalDay,
                  record.checkedAt >= payload.habit.createdAt,
                  record.createdAt >= record.checkedAt,
                  record.createdAt <= payload.exportedAt,
                  logicalDays.insert(logicalDay).inserted,
                  recordIDs.insert(record.id).inserted else {
                throw PulseCoreError.invalidImport
            }
            return .init(payload: record, logicalDay: logicalDay)
        }

        return ValidatedPulseImport(
            startLogicalDay: startLogicalDay,
            identity: identity,
            records: records
        )
    }
}
