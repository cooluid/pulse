import Foundation
import PulseCore

enum PulseAppError: Error, Equatable {
    case invalidSettings
    case notificationPermissionDenied
    case liveActivitiesUnavailable
    case liveActivitySchedulingFailed
    case reminderUnavailable
    case enhancementRequired
}

enum PulseErrorPresentation {
    static func localizedMessage(for error: Error, locale: Locale) -> String? {
        if let coreError = error as? PulseCoreError {
            if case .invalidHabitIdentity = coreError {
                return String(
                    format: PulseLocalization.string(
                        "error.habit_identity_format",
                        locale: locale
                    ),
                    locale: locale,
                    Int64(HabitIdentity.minimumNameLength),
                    Int64(HabitIdentity.maximumNameLength),
                    Int64(HabitIdentity.maximumPurposeLength)
                )
            }
            if case .invalidBackupPassphrase = coreError {
                return String(
                    format: PulseLocalization.string(
                        "error.backup_passphrase_format",
                        locale: locale
                    ),
                    locale: locale,
                    Int64(PulseBackupContract.minimumPassphraseCharacterCount)
                )
            }

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
                "error.habit_identity_format"
            case .backupUnavailable:
                "error.backup_unavailable"
            case .invalidBackupPassphrase:
                "error.backup_passphrase_format"
            case .backupAuthenticationFailed:
                "error.backup_authentication"
            case .unsupportedBackupContainerVersion, .unsupportedBackupPayloadVersion:
                "error.backup_version"
            case .invalidBackup:
                "error.backup_invalid"
            case .invalidMedia:
                "error.media_invalid"
            case .mediaFileUnavailable:
                "error.media_file_unavailable"
            case .mediaStorageUnavailable:
                "error.media_storage_unavailable"
            }
            return PulseLocalization.string(key, locale: locale)
        }

        if let appError = error as? PulseAppError {
            let key = switch appError {
            case .invalidSettings:
                "error.settings"
            case .notificationPermissionDenied:
                "error.notification_denied"
            case .liveActivitiesUnavailable:
                "error.live_activities_unavailable"
            case .liveActivitySchedulingFailed:
                "error.live_activity_scheduling"
            case .reminderUnavailable:
                "error.reminder_unavailable"
            case .enhancementRequired:
                "error.enhancement_required"
            }
            return PulseLocalization.string(key, locale: locale)
        }

        if let reminderError = error as? PulseReminderSchedulingError {
            let key = switch reminderError {
            case .notificationPermissionDenied:
                "error.notification_denied"
            case .liveActivitiesUnavailable:
                "error.live_activities_unavailable"
            case .liveActivitySchedulingFailed:
                "error.live_activity_scheduling"
            }
            return PulseLocalization.string(key, locale: locale)
        }

        if let storeError = error as? StoreAccessError {
            let key = switch storeError {
            case .productUnavailable:
                "error.purchase_product_unavailable"
            case .verificationFailed:
                "error.purchase_verification"
            case .nothingToRestore:
                "error.purchase_nothing_to_restore"
            }
            return PulseLocalization.string(key, locale: locale)
        }

        return nil
    }
}
