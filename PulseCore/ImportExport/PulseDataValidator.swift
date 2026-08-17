import Foundation

struct ValidatedPulseBackup {
    struct Record {
        let payload: PulseBackupPayload.RecordPayload
        let logicalDay: LogicalDay
    }

    struct Media {
        let draft: ImprintMediaDraft
        let modifiedAt: Date
    }

    let startLogicalDay: LogicalDay
    let identity: HabitIdentity
    let records: [Record]
    let media: [Media]
}

enum PulseDataValidator {
    static func validate(_ payload: PulseBackupPayload) throws -> ValidatedPulseBackup {
        guard payload.format == PulseBackupContract.payloadFormatIdentifier,
              payload.schemaVersion == PulseBackupContract.payloadSchemaVersion,
              payload.records.count <= PulseBackupContract.maximumRecordCount,
              payload.media.count <= PulseBackupContract.maximumMediaCount,
              let currentTimeZone = TimeZone(identifier: payload.habit.timeZoneIdentifier),
              let creationTimeZone = TimeZone(identifier: payload.habit.creationTimeZoneIdentifier),
              let startLogicalDay = LogicalDay(storageValue: payload.habit.startLogicalDay),
              LogicalDay.resolve(at: payload.habit.createdAt, timeZone: creationTimeZone)
                == startLogicalDay,
              LogicalDay.resolve(at: payload.exportedAt, timeZone: currentTimeZone)
                >= startLogicalDay,
              payload.habit.createdAt <= payload.exportedAt else {
            throw PulseCoreError.invalidBackup
        }

        let identity: HabitIdentity
        do {
            identity = try HabitIdentity(
                storedName: payload.habit.name,
                storedPurpose: payload.habit.purpose
            )
        } catch {
            throw PulseCoreError.invalidBackup
        }

        var logicalDays = Set<LogicalDay>()
        var recordIDs = Set<UUID>()
        let records: [ValidatedPulseBackup.Record] = try payload.records.map { record in
            guard let logicalDay = LogicalDay(storageValue: record.logicalDay),
                  let recordTimeZone = TimeZone(identifier: record.timeZoneIdentifier),
                  LogicalDay.resolve(at: record.checkedAt, timeZone: recordTimeZone) == logicalDay,
                  logicalDay >= startLogicalDay,
                  record.checkedAt >= payload.habit.createdAt,
                  record.createdAt >= record.checkedAt,
                  record.createdAt <= payload.exportedAt,
                  record.journalNote == nil || record.journalNoteModifiedAt != nil,
                  record.journalNoteModifiedAt == nil
                    || record.journalNoteModifiedAt! >= record.checkedAt,
                  record.journalNoteModifiedAt == nil
                    || record.journalNoteModifiedAt! <= payload.exportedAt,
                  logicalDays.insert(logicalDay).inserted,
                  recordIDs.insert(record.id).inserted,
                  isValidJournalNote(record.journalNote) else {
                throw PulseCoreError.invalidBackup
            }
            return .init(payload: record, logicalDay: logicalDay)
        }

        let recordsByDay = Dictionary(uniqueKeysWithValues: records.map {
            ($0.logicalDay, $0.payload.id)
        })
        var mediaIDs = Set<UUID>()
        var mediaDays = Set<LogicalDay>()
        var mediaPaths = Set<String>()
        let media: [ValidatedPulseBackup.Media] = try payload.media.map { item in
            guard let logicalDay = LogicalDay(storageValue: item.logicalDay),
                  let cameraPosition = ImprintCameraPosition(rawValue: item.cameraPosition),
                  logicalDay >= startLogicalDay,
                  item.capturedAt >= payload.habit.createdAt,
                  item.createdAt >= item.capturedAt,
                  item.modifiedAt >= item.createdAt,
                  item.modifiedAt <= payload.exportedAt,
                  item.byteCount > 0,
                  item.byteCount <= PulseMediaFileStore.maximumOriginalBytes,
                  item.thumbnailByteCount > 0,
                  item.thumbnailByteCount <= PulseMediaFileStore.maximumThumbnailBytes,
                  item.pixelWidth > 0,
                  item.pixelHeight > 0,
                  item.sha256.count == 64,
                  item.sha256.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
                  item.thumbnailSHA256.count == 64,
                  item.thumbnailSHA256.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
                  validPath(item.originalRelativePath, prefix: "originals/"),
                  validPath(item.thumbnailRelativePath, prefix: "thumbnails/"),
                  mediaIDs.insert(item.id).inserted,
                  mediaDays.insert(logicalDay).inserted,
                  mediaPaths.insert(item.originalRelativePath).inserted,
                  mediaPaths.insert(item.thumbnailRelativePath).inserted else {
                throw PulseCoreError.invalidBackup
            }
            if let recordID = item.recordID {
                guard recordsByDay[logicalDay] == recordID else {
                    throw PulseCoreError.invalidBackup
                }
            }
            return .init(
                draft: ImprintMediaDraft(
                    id: item.id,
                    habitID: payload.habit.id,
                    recordID: item.recordID,
                    logicalDay: logicalDay,
                    capturedAt: item.capturedAt,
                    createdAt: item.createdAt,
                    originalRelativePath: item.originalRelativePath,
                    thumbnailRelativePath: item.thumbnailRelativePath,
                    byteCount: item.byteCount,
                    thumbnailByteCount: item.thumbnailByteCount,
                    pixelWidth: item.pixelWidth,
                    pixelHeight: item.pixelHeight,
                    sha256: item.sha256,
                    thumbnailSHA256: item.thumbnailSHA256,
                    cameraPosition: cameraPosition
                ),
                modifiedAt: item.modifiedAt
            )
        }

        return ValidatedPulseBackup(
            startLogicalDay: startLogicalDay,
            identity: identity,
            records: records,
            media: media
        )
    }

    private static func isValidJournalNote(_ note: String?) -> Bool {
        do {
            return try JournalNote.validatedStoredText(note) == note
        } catch {
            return false
        }
    }

    private static func validPath(_ path: String, prefix: String) -> Bool {
        path.hasPrefix(prefix)
            && !path.contains("..")
            && !path.contains("\\")
            && path.split(separator: "/").count == 2
            && path.hasSuffix(".jpg")
    }
}
