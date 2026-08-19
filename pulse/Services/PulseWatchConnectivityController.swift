import Foundation
import OSLog
import PulseWatchShared
@preconcurrency import WatchConnectivity

@MainActor
protocol PulseWatchConnectivityProviding: AnyObject {
    var commandHandler: (@MainActor (PulseWatchCheckInCommand) async -> PulseWatchCheckInReceipt?)? {
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

    private let session: WCSession
    private let logger = Logger(
        subsystem: PulseRuntimeIdentity.bundleIdentifier,
        category: "watch-connectivity"
    )
    private var pendingSnapshotEnvelope: PulseWatchSnapshotEnvelope?
    var commandHandler: (@MainActor (PulseWatchCheckInCommand) async -> PulseWatchCheckInReceipt?)?

    override init() {
        session = .default
        super.init()
    }

    func start() {
        session.delegate = self
        session.activate()
    }

    func publish(_ snapshot: PulseWatchProjectSnapshot?) {
        pendingSnapshotEnvelope = PulseWatchSnapshotEnvelope(
            snapshot: snapshot,
            generatedAt: .now
        )
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
            guard let commandHandler else {
                return
            }
            guard let handledReceipt = await commandHandler(command) else {
                return
            }
            receipt = handledReceipt
        } catch PulseWatchCodecError.incompatibleProtocol {
            return
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
