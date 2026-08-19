import Observation
import PulseWatchShared
import SwiftUI
import WatchKit

enum PulseWatchBootstrap {
    case ready(PulseWatchModel)
    case failed

    @MainActor
    static func build() -> PulseWatchBootstrap {
        do {
            let store = try PulseWatchRuntimeIdentity.makeLocalStore()
            return .ready(PulseWatchModel(
                connectivity: PulseWatchConnectivityClient(store: store)
            ))
        } catch {
            return .failed
        }
    }
}

@MainActor
@Observable
final class PulseWatchModel {
    private let connectivity: PulseWatchConnectivityClient
    private var lastDisplayState: PulseWatchDisplayState?

    private(set) var projection = PulseWatchLocalProjection(
        snapshot: nil,
        pendingCommands: [],
        lastReceipt: nil
    )
    private(set) var isSubmitting = false

    init(connectivity: PulseWatchConnectivityClient) {
        self.connectivity = connectivity
        connectivity.stateDidChange = { [weak self] projection in
            self?.apply(projection)
        }
    }

    var displayState: PulseWatchDisplayState {
        isSubmitting ? .submitting : projection.displayState
    }

    func start() async {
        connectivity.start()
        do {
            let projection = try await connectivity.currentProjection()
            apply(projection)
        } catch {
            apply(.storageUnavailable)
        }
    }

    func checkIn() async {
        guard case .ready = projection.displayState, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await connectivity.submitCheckIn()
            let projection = try await connectivity.currentProjection()
            apply(projection)
        } catch {
            apply(.storageUnavailable)
        }
    }

    func retryPending() async {
        do {
            try await connectivity.retryPendingCommands()
        } catch {
            apply(.storageUnavailable)
        }
    }

    private func apply(_ projection: PulseWatchLocalProjection) {
        let nextState = projection.displayState
        if case .committed = nextState,
           let lastDisplayState,
           lastDisplayState == .pendingSync || lastDisplayState == .submitting {
            WKInterfaceDevice.current().play(.success)
        }
        self.projection = projection
        lastDisplayState = nextState
    }
}
