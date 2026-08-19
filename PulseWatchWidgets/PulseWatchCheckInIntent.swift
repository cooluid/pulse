import AppIntents
import PulseWatchShared

struct PulseWatchCheckInIntent: AppIntent {
    static let title: LocalizedStringResource = "watch.action.check_in"
    static let description = IntentDescription("watch.widget.today.description")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = try PulseWatchRuntimeIdentity.makeLocalStore()
        let client = PulseWatchConnectivityClient(store: store)
        client.start()
        _ = try await client.submitCheckIn()
        return .result()
    }
}
