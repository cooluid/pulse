import Foundation

public enum PulseCoreError: Error, Equatable, Sendable {
    case invalidTimeZone(String)
    case invalidTimeZoneTransition
    case invalidRecordDate(String)
    case invalidCheckIn
    case primaryHabitUnavailable
    case invalidHabitIdentity
    case exportUnavailable
    case unsupportedImportVersion(Int)
    case invalidImport
}
