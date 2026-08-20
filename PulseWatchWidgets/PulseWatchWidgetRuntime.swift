import PulseWatchShared

@MainActor
enum PulseWatchWidgetRuntime {
    private struct Runtime {
        let store: PulseWatchLocalStore
        let connectivity: PulseWatchConnectivityClient
    }

    private static let bootstrap: Result<Runtime, Error> = Result {
        let store = try PulseWatchRuntimeIdentity.makeLocalStore()
        return Runtime(
            store: store,
            connectivity: PulseWatchConnectivityClient(store: store)
        )
    }

    static func start() {
        try? connectivity().start()
    }

    static func localStore() throws -> PulseWatchLocalStore {
        try bootstrap.get().store
    }

    static func connectivity() throws -> PulseWatchConnectivityClient {
        try bootstrap.get().connectivity
    }
}
