import Foundation
import PulseWatchShared
import WidgetKit
@preconcurrency import WatchConnectivity

@MainActor
final class PulseWatchConnectivityClient: NSObject {
    private let session: WCSession
    private let store: PulseWatchLocalStore
    private var started = false

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
        guard let snapshot = projection.snapshot,
              !snapshot.isCheckedToday,
              projection.pendingCommands.isEmpty else {
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
        deliver(command)
        return command
    }

    func retryPendingCommands() async throws {
        let projection = try store.projection()
        for command in projection.pendingCommands {
            deliver(command)
        }
    }

    func currentProjection() async throws -> PulseWatchLocalProjection {
        try store.projection()
    }

    private func deliver(_ command: PulseWatchCheckInCommand) {
        guard session.activationState == .activated else { return }
        do {
            let data = try PulseWatchCodec.encode(command)
            if session.isReachable {
                session.sendMessageData(data) { [weak self] receiptData in
                    Task { @MainActor in
                        self?.receiveReceipt(receiptData)
                    }
                } errorHandler: { [weak self] _ in
                    Task { @MainActor in
                        self?.scheduleBackground(command, data: data)
                    }
                }
            } else {
                scheduleBackground(command, data: data)
            }
        } catch {
            refreshProjection()
        }
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
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let envelope = try PulseWatchCodec.decodeSnapshotEnvelope(from: data)
                try store.save(snapshot: envelope.snapshot)
                publishProjection()
            } catch {
                try? store.save(snapshot: nil)
                publishProjection()
            }
        }
    }

    private func receiveReceipt(_ data: Data) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let receipt = try PulseWatchCodec.decodeReceipt(from: data)
                try store.acknowledge(receipt)
                publishProjection()
            } catch {
                refreshProjection()
            }
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
            guard activationState == .activated else {
                self?.refreshProjection()
                return
            }
            try? await self?.retryPendingCommands()
            self?.refreshProjection()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor [weak self] in
            try? await self?.retryPendingCommands()
        }
    }

    nonisolated func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            try? await self?.retryPendingCommands()
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
