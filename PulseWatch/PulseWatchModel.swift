import Foundation
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
    private var boundaryTask: Task<Void, Never>?

    private(set) var projection = PulseWatchLocalProjection(
        snapshot: nil,
        pendingCommands: [],
        lastReceipt: nil
    )
    private(set) var isSubmitting = false
    private(set) var referenceDate = Date.now

    init(connectivity: PulseWatchConnectivityClient) {
        self.connectivity = connectivity
        connectivity.stateDidChange = { [weak self] projection in
            self?.apply(projection)
        }
        connectivity.start()
    }

    var displayState: PulseWatchDisplayState {
        isSubmitting ? .submitting : projection.displayState(at: referenceDate)
    }

    func start() async {
        do {
            let projection = try await connectivity.currentProjection()
            apply(projection)
            try? await connectivity.retryPendingCommands()
            try? await connectivity.refreshLatestSnapshot()
        } catch {
            apply(.storageUnavailable)
        }
    }

    func checkIn() async {
        guard case .ready = displayState, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await connectivity.submitCheckIn()
            let projection = try await connectivity.currentProjection()
            apply(projection)
        } catch {
            await reloadProjection()
        }
    }

    func retry() async {
        do {
            switch displayState {
            case .pendingSync:
                try await connectivity.retryPendingCommands()
            case .failed:
                try await connectivity.retryAfterFailure()
            case .needsSync:
                try await connectivity.refreshLatestSnapshot()
            case .ready, .submitting, .committed:
                return
            }
            await reloadProjection()
        } catch {
            await reloadProjection()
        }
    }

    private func apply(_ projection: PulseWatchLocalProjection) {
        referenceDate = .now
        let nextState = projection.displayState(at: referenceDate)
        if case .committed = nextState,
           let lastDisplayState,
           lastDisplayState == .pendingSync || lastDisplayState == .submitting {
            WKInterfaceDevice.current().play(.success)
        } else if case .pendingSync = nextState,
                  lastDisplayState == .ready || lastDisplayState == .submitting {
            WKInterfaceDevice.current().play(.click)
        } else if case .failed = nextState,
                  lastDisplayState != nextState {
            WKInterfaceDevice.current().play(.failure)
        }
        self.projection = projection
        lastDisplayState = nextState
        scheduleBoundaryRefresh(for: projection.snapshot?.nextDayBoundary)
    }

    private func reloadProjection() async {
        do {
            apply(try await connectivity.currentProjection())
        } catch {
            apply(.storageUnavailable)
        }
    }

    private func scheduleBoundaryRefresh(for boundary: Date?) {
        boundaryTask?.cancel()
        guard let boundary else { return }
        let delay = boundary.timeIntervalSinceNow
        guard delay > 0 else { return }
        boundaryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            referenceDate = .now
            await reloadProjection()
            try? await connectivity.refreshLatestSnapshot()
            await reloadProjection()
        }
    }
}
