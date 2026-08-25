import Foundation

public enum PulseWatchLocalStoreError: Error, Equatable, Sendable {
    case invalidDirectory
    case coordinatedAccessFailed
    case incompatibleState
}

public final class PulseWatchLocalStore: @unchecked Sendable {
    private struct PersistentState: Codable, Equatable, Sendable {
        var version = PulseWatchContract.localStateVersion
        var snapshot: PulseWatchProjectSnapshot?
        var outbox: [PulseWatchCheckInCommand] = []
        var lastReceipt: PulseWatchCheckInReceipt?
    }

    private let stateURL: URL
    private let fileManager: FileManager
    private let lock = NSLock()

    public init(directoryURL: URL, fileManager: FileManager = .default) throws {
        guard directoryURL.isFileURL else {
            throw PulseWatchLocalStoreError.invalidDirectory
        }
        let canonicalDirectoryURL = directoryURL.standardizedFileURL
        self.stateURL = canonicalDirectoryURL.appendingPathComponent(
            PulseWatchContract.localStateFilename,
            isDirectory: false
        )
        self.fileManager = fileManager
        try Self.prepareDirectory(canonicalDirectoryURL, fileManager: fileManager)
    }

    public func projection() throws -> PulseWatchLocalProjection {
        lock.lock()
        defer { lock.unlock() }
        let state = try coordinatedRead()
        return PulseWatchLocalProjection(
            snapshot: state.snapshot,
            pendingCommands: state.outbox,
            lastReceipt: state.lastReceipt
        )
    }

    public func save(snapshot: PulseWatchProjectSnapshot) throws {
        lock.lock()
        defer { lock.unlock() }
        try PulseWatchCodec.validate(snapshot)
        try coordinatedMutation { state in
            if let currentSnapshot = state.snapshot,
               currentSnapshot.generatedAt > snapshot.generatedAt {
                return
            }
            state.snapshot = snapshot
            if let lastReceipt = state.lastReceipt,
               snapshot.generatedAt >= lastReceipt.acknowledgedAt {
                state.lastReceipt = nil
            }
        }
    }

    public func enqueue(_ command: PulseWatchCheckInCommand) throws {
        lock.lock()
        defer { lock.unlock() }
        try PulseWatchCodec.validate(command)
        try coordinatedMutation { state in
            guard let snapshot = state.snapshot,
                  command.projectID == snapshot.projectID,
                  command.projectRevision == snapshot.projectRevision,
                  command.projectTimeZoneIdentifierSnapshot
                    == snapshot.projectTimeZoneIdentifier else {
                throw PulseWatchLocalStoreError.incompatibleState
            }
            guard !state.outbox.contains(where: { $0.operationID == command.operationID }) else {
                return
            }
            state.outbox.append(command)
            state.lastReceipt = nil
        }
    }

    public func acknowledge(_ receipt: PulseWatchCheckInReceipt) throws {
        lock.lock()
        defer { lock.unlock() }
        try PulseWatchCodec.validate(receipt)
        try coordinatedMutation { state in
            if state.lastReceipt == receipt {
                return
            }
            guard state.outbox.contains(where: { command in
                command.operationID == receipt.operationID
                    && command.projectID == receipt.projectID
                    && command.projectRevision == receipt.projectRevision
            }) else {
                throw PulseWatchLocalStoreError.incompatibleState
            }
            state.outbox.removeAll { $0.operationID == receipt.operationID }
            state.lastReceipt = receipt
        }
    }

    public func prepareForRetry() throws {
        lock.lock()
        defer { lock.unlock() }
        try coordinatedMutation { state in
            if let snapshot = state.snapshot {
                state.outbox.removeAll { command in
                    command.projectID != snapshot.projectID
                        || command.projectRevision != snapshot.projectRevision
                        || command.projectTimeZoneIdentifierSnapshot
                            != snapshot.projectTimeZoneIdentifier
                }
            }
            state.lastReceipt = nil
        }
    }

    public func clearSnapshot() throws {
        lock.lock()
        defer { lock.unlock() }
        try coordinatedMutation { state in
            state.snapshot = nil
        }
    }

#if DEBUG
    public func reset() throws {
        lock.lock()
        defer { lock.unlock() }
        try coordinatedMutation { state in
            state = PersistentState()
        }
    }
#endif

    private func coordinatedRead() throws -> PersistentState {
        var coordinatorError: NSError?
        var result: Result<PersistentState, Error>?
        NSFileCoordinator().coordinate(
            readingItemAt: stateURL,
            options: .withoutChanges,
            error: &coordinatorError
        ) { coordinatedURL in
            result = Result { try readState(at: coordinatedURL) }
        }
        if coordinatorError != nil {
            throw PulseWatchLocalStoreError.coordinatedAccessFailed
        }
        guard let result else {
            throw PulseWatchLocalStoreError.coordinatedAccessFailed
        }
        return try result.get()
    }

    private func coordinatedMutation(
        _ mutation: (inout PersistentState) throws -> Void
    ) throws {
        var coordinatorError: NSError?
        var result: Result<Void, Error>?
        NSFileCoordinator().coordinate(
            writingItemAt: stateURL,
            options: .forMerging,
            error: &coordinatorError
        ) { coordinatedURL in
            result = Result {
                var state = try readState(at: coordinatedURL)
                try mutation(&state)
                try writeState(state, at: coordinatedURL)
            }
        }
        if coordinatorError != nil {
            throw PulseWatchLocalStoreError.coordinatedAccessFailed
        }
        guard let result else {
            throw PulseWatchLocalStoreError.coordinatedAccessFailed
        }
        try result.get()
    }

    private func readState(at url: URL) throws -> PersistentState {
        guard fileManager.fileExists(atPath: url.path) else {
            return PersistentState()
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let state = try JSONDecoder().decode(PersistentState.self, from: data)
        guard state.version == PulseWatchContract.localStateVersion else {
            throw PulseWatchLocalStoreError.incompatibleState
        }
        if let snapshot = state.snapshot {
            try PulseWatchCodec.validate(snapshot)
        }
        var operationIDs = Set<UUID>()
        for command in state.outbox {
            try PulseWatchCodec.validate(command)
            guard operationIDs.insert(command.operationID).inserted else {
                throw PulseWatchLocalStoreError.incompatibleState
            }
        }
        if let lastReceipt = state.lastReceipt {
            try PulseWatchCodec.validate(lastReceipt)
        }
        return state
    }

    private func writeState(_ state: PersistentState, at url: URL) throws {
        let data = try PulseWatchCodec.encode(state)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private static func prepareDirectory(
        _ directoryURL: URL,
        fileManager: FileManager
    ) throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw PulseWatchLocalStoreError.invalidDirectory
            }
        } else {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        }
    }
}
