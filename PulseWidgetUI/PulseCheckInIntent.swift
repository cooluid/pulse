import AppIntents
import PulseCore
import WidgetKit

struct PulseCheckInIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "widget.intent.check_in.title"
    static let description = IntentDescription("widget.intent.check_in.description")

    // iOS 18-25 uses this property. iOS 26 uses supportedModes below.
    static let openAppWhenRun = false

    @available(iOS 26.0, *)
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult {
        try await PulseWidgetSharedRuntime.checkInAndReconcileReminders()
        for kind in PulseWidgetContract.allKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
        return .result()
    }
}
