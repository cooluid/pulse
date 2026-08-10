import Foundation

enum PulseError: LocalizedError {
    case persistenceUnavailable
    case missingPrimaryHabit
    case invalidTimeZone(String)
    case invalidRecordDate(String)
    case invalidSettings
    case notificationPermissionDenied
    case exportUnavailable
    case unsupportedImportVersion(Int)
    case invalidImport

    var errorDescription: String? {
        switch self {
        case .persistenceUnavailable:
            String(localized: "error.persistence")
        case .missingPrimaryHabit:
            String(localized: "error.habit_missing")
        case .invalidTimeZone:
            String(localized: "error.timezone")
        case .invalidRecordDate:
            String(localized: "error.record_date")
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
