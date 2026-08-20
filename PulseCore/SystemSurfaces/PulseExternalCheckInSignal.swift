import Foundation

public enum PulseExternalCheckInSignal {
    public static let didCommit = Notification.Name(
        "co.fanr.pulse.external-check-in-did-commit"
    )

    public static func post() {
        NotificationCenter.default.post(name: didCommit, object: nil)
    }
}
