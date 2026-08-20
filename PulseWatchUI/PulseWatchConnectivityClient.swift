import Foundation
import PulseWatchShared
import WidgetKit
@preconcurrency import WatchConnectivity

private enum PulseWatchConnectivityError: Error {
    case activationFailed
}

@MainActor
final class PulseWatchConnectivityClient: NSObject {
    private let session: WCSession
    private let store: PulseWatchLocalStore
    private var started = false
    private var activationWaiters: [CheckedContinuation<Void, Error>] = []

    var stateDidChange: (@MainActor (PulseWatchLocalProjection) -> Void)?

    init(store: PulseWatchLocalStore) {
        precondition(WCSession.isSupported(), "WatchConnectivity is required on watchOS.")
        session = .default
        self.store = store
        super.init()
    }

    func start() {
        guard !started else { return }
        started = true
        session.delegate = self
        session.activate()
        if let data = session.receivedApplicationContext[
            PulseWatchContract.snapshotContextKey
        ] as? Data {
            receiveSnapshot(data)
        } else {
            refreshProjection()
        }
    }

    func submitCheckIn(at date: Date = .now) async throws -> PulseWatchCheckInCommand? {
        let projection = try store.projection()
        guard case .ready = projection.displayState(at: date),
              let snapshot = projection.snapshot else {
            return nil
        }
        let command = PulseWatchCheckInCommand(
            projectID: snapshot.projectID,
            projectRevision: snapshot.projectRevision,
            occurredAt: date,
            projectTimeZoneIdentifierSnapshot: snapshot.projectTimeZoneIdentifier
        )
        try store.enqueue(command)
        publishProjection()
        try await deliver(command)
        return command
    }

    func retryPendingCommands() async throws {
        let projection = try store.projection()
        for command in projection.pendingCommands {
            try await deliver(command)
        }
    }

    func retryAfterFailure(at date: Date = .now) async throws {
        try store.prepareForRetry()
        publishProjection()
        _ = try await submitCheckIn(at: date)
    }

    func refreshLatestSnapshot() async throws {
        try await ensureActivated()
        guard session.isReachable else { return }
        await withCheckedContinuation { continuation in
            session.sendMessage([
                PulseWatchContract.snapshotRequestKey: PulseWatchContract.protocolVersion,
            ]) { [self] reply in
                Task { @MainActor in
                    if let data = reply[PulseWatchContract.snapshotContextKey] as? Data {
                        receiveSnapshot(data)
                    }
                    continuation.resume()
                }
            } errorHandler: { _ in
                continuation.resume()
            }
        }
    }

    func currentProjection() async throws -> PulseWatchLocalProjection {
        try store.projection()
    }

    private func deliver(_ command: PulseWatchCheckInCommand) async throws {
        let data = try PulseWatchCodec.encode(command)
        try await ensureActivated()
        if session.isReachable {
            await withCheckedContinuation { continuation in
                session.sendMessageData(data) { [self] receiptData in
                    Task { @MainActor in
                        if !receiveReceipt(receiptData) {
                            scheduleBackground(command, data: data)
                        }
                        continuation.resume()
                    }
                } errorHandler: { [self] _ in
                    Task { @MainActor in
                        scheduleBackground(command, data: data)
                        continuation.resume()
                    }
                }
            }
        } else {
            scheduleBackground(command, data: data)
        }
    }

    private func ensureActivated() async throws {
        if session.activationState == .activated {
            return
        }
        if !started {
            start()
        } else {
            session.activate()
        }
        try await withCheckedThrowingContinuation { continuation in
            if session.activationState == .activated {
                continuation.resume()
            } else {
                activationWaiters.append(continuation)
            }
        }
    }

    private func completeActivation(
        _ activationState: WCSessionActivationState,
        error: (any Error)?
    ) -> Bool {
        let waiters = activationWaiters
        activationWaiters.removeAll()
        if activationState == .activated {
            for waiter in waiters {
                waiter.resume()
            }
        } else {
            let resolvedError = error ?? PulseWatchConnectivityError.activationFailed
            for waiter in waiters {
                waiter.resume(throwing: resolvedError)
            }
        }
        return !waiters.isEmpty
    }

    private func scheduleBackground(
        _ command: PulseWatchCheckInCommand,
        data: Data
    ) {
        let alreadyScheduled = session.outstandingUserInfoTransfers.contains { transfer in
            guard let queuedData = transfer.userInfo[
                PulseWatchContract.commandUserInfoKey
            ] as? Data,
            let queuedCommand = try? PulseWatchCodec.decodeCommand(from: queuedData) else {
                return false
            }
            return queuedCommand.operationID == command.operationID
        }
        guard !alreadyScheduled else { return }
        session.transferUserInfo([
            PulseWatchContract.commandUserInfoKey: data,
        ])
    }

    private func receiveSnapshot(_ data: Data) {
        do {
            let envelope = try PulseWatchCodec.decodeSnapshotEnvelope(from: data)
            if let snapshot = envelope.snapshot {
                try store.save(snapshot: snapshot)
            } else {
                try store.clear()
            }
        } catch {
            // A malformed transport update must never delete the last valid
            // snapshot or a durable command already accepted from the user.
        }
        publishProjection()
    }

    @discardableResult
    private func receiveReceipt(_ data: Data) -> Bool {
        do {
            let receipt = try PulseWatchCodec.decodeReceipt(from: data)
            try store.acknowledge(receipt)
            publishProjection()
            return true
        } catch {
            refreshProjection()
            return false
        }
    }

    private func refreshProjection() {
        publishProjection()
    }

    private func publishProjection() {
        do {
            let projection = try store.projection()
            stateDidChange?(projection)
        } catch {
            stateDidChange?(.storageUnavailable)
        }
        for kind in PulseWatchContract.allWidgetKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}

extension PulseWatchConnectivityClient: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let resumedActiveOperation = self.completeActivation(
                activationState,
                error: error
            )
            guard activationState == .activated else {
                self.refreshProjection()
                return
            }
            if !resumedActiveOperation {
                try? await self.retryPendingCommands()
                try? await self.refreshLatestSnapshot()
            }
            self.refreshProjection()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor [weak self] in
            try? await self?.retryPendingCommands()
            try? await self?.refreshLatestSnapshot()
        }
    }

    nonisolated func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            try? await self?.retryPendingCommands()
            try? await self?.refreshLatestSnapshot()
            self?.refreshProjection()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let data = applicationContext[
            PulseWatchContract.snapshotContextKey
        ] as? Data else { return }
        Task { @MainActor [weak self] in
            self?.receiveSnapshot(data)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        guard let data = userInfo[PulseWatchContract.receiptUserInfoKey] as? Data else {
            return
        }
        Task { @MainActor [weak self] in
            self?.receiveReceipt(data)
        }
    }
}
