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
#if DEBUG
            try seedAppStoreCaptureSnapshotIfNeeded(in: store)
#endif
            return .ready(PulseWatchModel(
                connectivity: PulseWatchConnectivityClient(store: store)
            ))
        } catch {
            return .failed
        }
    }

#if DEBUG
    private static func seedAppStoreCaptureSnapshotIfNeeded(
        in store: PulseWatchLocalStore
    ) throws {
        guard let requestedState = ProcessInfo.processInfo.environment[
            "PULSE_WATCH_APP_STORE_CAPTURE_STATE"
        ], requestedState == "ready" || requestedState == "committed" else {
            return
        }
        let now = Date()
        let isCommitted = requestedState == "committed"
        let logicalDays = [
            "2026-08-17", "2026-08-18", "2026-08-19", "2026-08-20",
            "2026-08-21", "2026-08-22", "2026-08-23",
        ]
        let states: [PulseWatchDayState] = [
            .missed, .checked, .missed, .checked, .checked, .checked,
            isCommitted ? .checked : .todayPending,
        ]
        try store.reset()
        let projectID = UUID(uuidString: "7E4A69A5-2B20-4A18-9E10-0C225D52688F")!
        try store.save(snapshot: PulseWatchProjectSnapshot(
            projectID: projectID,
            projectRevision: PulseWatchProjectRevision.make(
                projectID: projectID,
                startLogicalDay: "2026-08-01",
                timeZoneIdentifier: "Asia/Shanghai"
            ),
            projectTimeZoneIdentifier: "Asia/Shanghai",
            todayLogicalDay: logicalDays.last!,
            isCheckedToday: isCommitted,
            checkedAt: isCommitted ? now.addingTimeInterval(-60 * 30) : nil,
            waveMotionEnabled: true,
            sevenDayPulse: zip(logicalDays, states).map {
                PulseWatchDaySnapshot(logicalDay: $0.0, state: $0.1)
            },
            generatedAt: now,
            nextDayBoundary: now.addingTimeInterval(60 * 60 * 12)
        ))
    }
#endif
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
