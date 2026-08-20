import Foundation
import OSLog
import PulseWatchShared
@preconcurrency import WatchConnectivity

@MainActor
protocol PulseWatchConnectivityProviding: AnyObject {
    var commandHandler: (@MainActor (PulseWatchCheckInCommand) async -> PulseWatchCheckInReceipt?)? {
        get set
    }
    var snapshotHandler: (@MainActor () async throws -> PulseWatchProjectSnapshot?)? {
        get set
    }

    func start()
    func publish(_ snapshot: PulseWatchProjectSnapshot?)
}

@MainActor
enum PulseWatchConnectivityFactory {
    static func make() -> any PulseWatchConnectivityProviding {
        WCSession.isSupported()
            ? PulseWatchConnectivityController()
            : UnsupportedPulseWatchConnectivity()
    }
}

@MainActor
private final class UnsupportedPulseWatchConnectivity: PulseWatchConnectivityProviding {
    var commandHandler: (@MainActor (PulseWatchCheckInCommand) async -> PulseWatchCheckInReceipt?)?
    var snapshotHandler: (@MainActor () async throws -> PulseWatchProjectSnapshot?)?

    func start() {}

    func publish(_ snapshot: PulseWatchProjectSnapshot?) {}
}

@MainActor
final class PulseWatchConnectivityController: NSObject,
    PulseWatchConnectivityProviding,
    WCSessionDelegate {
    private final class ReplyHandlerBox: @unchecked Sendable {
        let handler: (Data) -> Void

        init(_ handler: @escaping (Data) -> Void) {
            self.handler = handler
        }
    }

    private final class ReplyMessageHandlerBox: @unchecked Sendable {
        let handler: ([String: Any]) -> Void

        init(_ handler: @escaping ([String: Any]) -> Void) {
            self.handler = handler
        }
    }

    private let session: WCSession
    private let logger = Logger(
        subsystem: PulseRuntimeIdentity.bundleIdentifier,
        category: "watch-connectivity"
    )
    private var pendingSnapshotEnvelope: PulseWatchSnapshotEnvelope?
    private var latestSnapshotEnvelope: PulseWatchSnapshotEnvelope?
    var commandHandler: (@MainActor (PulseWatchCheckInCommand) async -> PulseWatchCheckInReceipt?)?
    var snapshotHandler: (@MainActor () async throws -> PulseWatchProjectSnapshot?)?

    override init() {
        session = .default
        super.init()
    }

    func start() {
        session.delegate = self
        session.activate()
    }

    func publish(_ snapshot: PulseWatchProjectSnapshot?) {
        let envelope = PulseWatchSnapshotEnvelope(
            snapshot: snapshot,
            generatedAt: .now
        )
        latestSnapshotEnvelope = envelope
        pendingSnapshotEnvelope = envelope
        flushSnapshotIfPossible()
    }

    private func flushSnapshotIfPossible() {
        guard session.activationState == .activated,
              let pendingSnapshotEnvelope else { return }
        do {
            let data = try PulseWatchCodec.encode(pendingSnapshotEnvelope)
            try session.updateApplicationContext([
                PulseWatchContract.snapshotContextKey: data,
            ])
            self.pendingSnapshotEnvelope = nil
        } catch {
            logger.error("Failed to publish Watch snapshot: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func handle(
        commandData: Data,
        reply: (@Sendable (Data) -> Void)?
    ) async {
        let receipt: PulseWatchCheckInReceipt
        do {
            let command = try PulseWatchCodec.decodeCommand(from: commandData)
            if let commandHandler,
               let handledReceipt = await commandHandler(command) {
                receipt = handledReceipt
            } else {
                receipt = PulseWatchCheckInReceipt(
                    operationID: command.operationID,
                    projectID: command.projectID,
                    projectRevision: command.projectRevision,
                    outcome: .rejected(reason: .temporarilyUnavailable),
                    acknowledgedAt: .now
                )
            }
        } catch let error as PulseWatchCodecError {
            guard let identity = try? PulseWatchCodec.decodeCommandIdentity(from: commandData) else {
                return
            }
            let reason: PulseWatchRejectionReason = error == .incompatibleProtocol
                ? .incompatibleProtocol
                : .invalidCommand
            receipt = PulseWatchCheckInReceipt(
                operationID: identity.operationID,
                projectID: identity.projectID,
                projectRevision: identity.projectRevision,
                outcome: .rejected(reason: reason),
                acknowledgedAt: .now
            )
        } catch {
            return
        }
        do {
            try send(receipt, reply: reply)
        } catch {
            // The Watch retains the command until a receipt arrives. A failed
            // reply remains recoverable through a later background delivery.
        }
    }

    private func handleSnapshotRequest(
        protocolVersion: Int,
        reply: @Sendable ([String: Any]) -> Void
    ) async {
        guard protocolVersion == PulseWatchContract.protocolVersion else {
            reply([:])
            return
        }
        if let snapshotHandler {
            do {
                publish(try await snapshotHandler())
            } catch {
                reply([:])
                return
            }
        }
        guard let latestSnapshotEnvelope,
              let data = try? PulseWatchCodec.encode(latestSnapshotEnvelope) else {
            reply([:])
            return
        }
        reply([PulseWatchContract.snapshotContextKey: data])
    }

    private func send(
        _ receipt: PulseWatchCheckInReceipt,
        reply: (@Sendable (Data) -> Void)?
    ) throws {
        let data = try PulseWatchCodec.encode(receipt)
        if let reply {
            reply(data)
        } else {
            session.transferUserInfo([
                PulseWatchContract.receiptUserInfoKey: data,
            ])
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            self?.flushSnapshotIfPossible()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.flushSnapshotIfPossible()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessageData messageData: Data,
        replyHandler: @escaping (Data) -> Void
    ) {
        let replyBox = ReplyHandlerBox(replyHandler)
        Task { @MainActor [weak self] in
            await self?.handle(
                commandData: messageData,
                reply: { data in replyBox.handler(data) }
            )
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let protocolVersion = message[PulseWatchContract.snapshotRequestKey] as? Int else {
            replyHandler([:])
            return
        }
        let replyBox = ReplyMessageHandlerBox(replyHandler)
        Task { @MainActor [weak self] in
            guard let self else {
                replyBox.handler([:])
                return
            }
            await self.handleSnapshotRequest(
                protocolVersion: protocolVersion,
                reply: { message in replyBox.handler(message) }
            )
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        guard let data = userInfo[PulseWatchContract.commandUserInfoKey] as? Data else {
            return
        }
        Task { @MainActor [weak self] in
            await self?.handle(commandData: data, reply: nil)
        }
    }
}
