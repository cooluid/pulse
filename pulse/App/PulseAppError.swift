import Foundation
import PulseCore

enum PulseAppError: Error, Equatable {
    case invalidSettings
    case notificationPermissionDenied
}

enum PulseErrorPresentation {
    static func localizedMessage(for error: Error, locale: Locale) -> String? {
        if let coreError = error as? PulseCoreError {
            let key = switch coreError {
            case .invalidTimeZone:
                "error.timezone"
            case .invalidTimeZoneTransition:
                "error.timezone_transition"
            case .invalidRecordDate:
                "error.record_date"
            case .invalidCheckIn:
                "error.check_in_invalid"
            case .primaryHabitUnavailable:
                "error.primary_habit_unavailable"
            case .invalidHabitIdentity:
                "error.habit_identity"
            case .exportUnavailable:
                "error.export"
            case .unsupportedImportVersion:
                "error.import_version"
            case .invalidImport:
                "error.import_invalid"
            }
            return PulseLocalization.string(key, locale: locale)
        }

        if let appError = error as? PulseAppError {
            let key = switch appError {
            case .invalidSettings:
                "error.settings"
            case .notificationPermissionDenied:
                "error.notification_denied"
            }
            return PulseLocalization.string(key, locale: locale)
        }

        return nil
    }
}
