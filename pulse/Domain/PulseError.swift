import Foundation

enum PulseError: LocalizedError, Equatable {
    case invalidTimeZone(String)
    case invalidTimeZoneTransition
    case invalidRecordDate(String)
    case invalidCheckIn
    case invalidSettings
    case notificationPermissionDenied
    case exportUnavailable
    case unsupportedImportVersion(Int)
    case invalidImport

    var errorDescription: String? {
        switch self {
        case .invalidTimeZone:
            String(localized: "error.timezone")
        case .invalidTimeZoneTransition:
            String(localized: "error.timezone_transition")
        case .invalidRecordDate:
            String(localized: "error.record_date")
        case .invalidCheckIn:
            String(localized: "error.check_in_invalid")
        case .invalidSettings:
            String(localized: "error.settings")
        case .notificationPermissionDenied:
            String(localized: "error.notification_denied")
        case .exportUnavailable:
            String(localized: "error.export")
        case .unsupportedImportVersion:
            String(localized: "error.import_version")
        case .invalidImport:
            String(localized: "error.import_invalid")
        }
    }
}
