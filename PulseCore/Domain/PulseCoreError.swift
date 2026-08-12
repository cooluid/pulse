import Foundation

public enum PulseCoreError: Error, Equatable, Sendable {
    case invalidTimeZone(String)
    case invalidTimeZoneTransition
    case invalidRecordDate(String)
    case invalidCheckIn
    case primaryHabitUnavailable
    case invalidHabitIdentity
    case backupUnavailable
    case invalidBackupPassphrase
    case backupAuthenticationFailed
    case unsupportedBackupContainerVersion(UInt16)
    case unsupportedBackupPayloadVersion(Int)
    case invalidBackup
    case invalidMedia
    case mediaFileUnavailable
    case mediaStorageUnavailable
}
