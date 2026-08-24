import AppIntents
import PulseCore

/// WidgetKit owns the post-intent timeline reload for Home and Accessory Widgets.
/// A plain AppIntent executes in the Widget extension process, avoiding a cold
/// container-App launch before the authoritative commit can be presented.
struct PulseWidgetCheckInIntent: AppIntent {
    static let title: LocalizedStringResource = "widget.intent.check_in.title"
    static let description = IntentDescription("widget.intent.check_in.description")

    // iOS 18-25 uses this property. iOS 26 uses supportedModes below.
    static let openAppWhenRun = false

    @available(iOS 26.0, *)
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult {
        try await PulseWidgetSharedRuntime.checkInAndCompleteTodayDelivery()
        return .result()
    }
}

/// Live Activities don't own a Widget timeline. Their action requests the one
/// centralized Widget refresh after the authoritative commit and current-day
/// delivery completion.
struct PulseLiveActivityCheckInIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "widget.intent.check_in.title"
    static let description = IntentDescription("widget.intent.check_in.description")

    // iOS 18-25 uses this property. iOS 26 uses supportedModes below.
    static let openAppWhenRun = false

    @available(iOS 26.0, *)
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult {
        try await PulseWidgetSharedRuntime.checkInAndCompleteTodayDelivery()
        PulseExternalCheckInSignal.post()
        PulseWidgetTimelineReloadCoordinator.reloadAllKinds()
        return .result()
    }
}
