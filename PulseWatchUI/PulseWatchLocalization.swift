import Foundation
import PulseWatchShared

enum PulseWatchLocalization {
    static func string(_ key: String.LocalizationValue, locale: Locale) -> String {
        String(localized: key, locale: locale)
    }

    static func status(
        for state: PulseWatchDisplayState,
        locale: Locale
    ) -> String {
        string(statusKey(for: state), locale: locale)
    }

    static func statusKey(
        for state: PulseWatchDisplayState
    ) -> String.LocalizationValue {
        switch state {
        case .needsSync: "watch.state.needs_sync"
        case .ready: "watch.state.ready"
        case .submitting: "watch.state.submitting"
        case .pendingSync: "watch.state.pending"
        case .committed: "watch.state.checked"
        case .failed(let reason): failureStatusKey(for: reason)
        }
    }

    private static func failureStatusKey(
        for reason: PulseWatchRejectionReason
    ) -> String.LocalizationValue {
        switch reason {
        case .incompatibleProtocol:
            "watch.state.failed_update"
        case .projectChanged, .timeZoneChanged, .occurrenceInFuture,
             .occurrenceBeforeProjectStart,
             .invalidCommand, .temporarilyUnavailable, .persistenceFailure:
            "watch.state.failed_retry"
        }
    }
}
