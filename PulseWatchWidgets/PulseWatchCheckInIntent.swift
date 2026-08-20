import AppIntents
import PulseWatchShared

struct PulseWatchCheckInIntent: AppIntent {
    static let title: LocalizedStringResource = "watch.action.check_in"
    static let description = IntentDescription("watch.widget.today.description")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let client = try PulseWatchWidgetRuntime.connectivity()
        client.start()
        do {
            _ = try await client.submitCheckIn(
                at: systemContext.preciseTimestamp ?? .now
            )
        } catch {
            // WidgetKit reloads the timeline after perform returns. The local
            // projection remains the only source for unavailable or pending UI.
        }
        return .result()
    }
}
