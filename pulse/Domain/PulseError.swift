import Foundation

enum PulseError: LocalizedError, Equatable {
    case invalidTimeZone(String)
    case invalidTimeZoneTransition
    case invalidRecordDate(String)
    case invalidCheckIn
    case invalidHabitIdentity
    case invalidSettings
    case notificationPermissionDenied
    case exportUnavailable
    case unsupportedImportVersion(Int)
    case invalidImport

    var errorDescription: String? {
        localizedMessage(locale: .autoupdatingCurrent)
    }

    func localizedMessage(locale: Locale) -> String {
        switch self {
        case .invalidTimeZone:
            PulseLocalization.string("error.timezone", locale: locale)
        case .invalidTimeZoneTransition:
            PulseLocalization.string("error.timezone_transition", locale: locale)
        case .invalidRecordDate:
            PulseLocalization.string("error.record_date", locale: locale)
        case .invalidCheckIn:
            PulseLocalization.string("error.check_in_invalid", locale: locale)
        case .invalidHabitIdentity:
            PulseLocalization.string("error.habit_identity", locale: locale)
        case .invalidSettings:
            PulseLocalization.string("error.settings", locale: locale)
        case .notificationPermissionDenied:
            PulseLocalization.string("error.notification_denied", locale: locale)
        case .exportUnavailable:
            PulseLocalization.string("error.export", locale: locale)
        case .unsupportedImportVersion:
            PulseLocalization.string("error.import_version", locale: locale)
        case .invalidImport:
            PulseLocalization.string("error.import_invalid", locale: locale)
        }
    }
}
