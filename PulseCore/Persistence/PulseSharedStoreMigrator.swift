import CryptoKit
import Foundation

public enum PulseSharedStoreMigrationPhase: String, Codable, Equatable, Sendable {
    case notStarted
    case copying
    case verified
    case sourceRemoved
    case ready
}

public enum PulseSharedStoreMigrationMode: String, Codable, Equatable, Sendable {
    case existingStore
    case newInstallation
}

public enum PulseSharedStoreMigrationError: Error, Equatable, Sendable {
    case locationsMustDiffer
    case sourceStoreMissing
    case sourceStoreHasNoPrimaryHabit
    case sourceStoreChanged
    case targetStoreExistsWithoutJournal
    case targetStoreMissing
    case targetStoreHasNoPrimaryHabit
    case targetStoreDigestMismatch
    case unexpectedSourceStore
    case invalidJournal
    case unsupportedJournalVersion(Int)
    case invalidDigest
    case persistedNotStartedPhase
    case journalModeMismatch
    case invalidNewInstallationSource
}

struct PulseStoreDigest: Codable, Equatable, Sendable {
    let value: String

    init(value: String) throws {
        guard value.count == 64,
              value.unicodeScalars.allSatisfy({ scalar in
                  (48...57).contains(scalar.value) || (97...102).contains(scalar.value)
              }) else {
            throw PulseSharedStoreMigrationError.invalidDigest
        }
        self.value = value
    }

    init(from decoder: Decoder) throws {
        try self.init(value: decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

struct PulseSharedStoreMigrationJournal: Codable, Equatable, Sendable {
    static let formatVersion = 2

    let version: Int
    let mode: PulseSharedStoreMigrationMode
    let phase: PulseSharedStoreMigrationPhase
    let factDigest: PulseStoreDigest

    init(
        mode: PulseSharedStoreMigrationMode,
        phase: PulseSharedStoreMigrationPhase,
        factDigest: PulseStoreDigest
    ) throws {
        guard phase != .notStarted else {
            throw PulseSharedStoreMigrationError.persistedNotStartedPhase
        }
        version = Self.formatVersion
        self.mode = mode
        self.phase = phase
        self.factDigest = factDigest
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case mode
        case phase
        case factDigest
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)
        guard version == Self.formatVersion else {
            throw PulseSharedStoreMigrationError.unsupportedJournalVersion(version)
        }
        mode = try container.decode(PulseSharedStoreMigrationMode.self, forKey: .mode)
        let phase = try container.decode(
            PulseSharedStoreMigrationPhase.self,
            forKey: .phase
        )
        guard phase != .notStarted else {
            throw PulseSharedStoreMigrationError.persistedNotStartedPhase
        }

        self.version = version
        self.phase = phase
        factDigest = try container.decode(PulseStoreDigest.self, forKey: .factDigest)
    }
}

protocol PulseStoreFileOperating: AnyObject {
    func itemExists(at url: URL) -> Bool
    func createDirectory(at url: URL) throws
    func removeItem(at url: URL) throws
    func readData(at url: URL) throws -> Data
    func writeDataAtomically(_ data: Data, to url: URL) throws
}

final class SystemPulseStoreFileOperator: PulseStoreFileOperating {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func itemExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    func createDirectory(at url: URL) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }

    func removeItem(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    func readData(at url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func writeDataAtomically(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }
}

enum PulseSharedStoreMigrationCheckpoint: Equatable {
    case copying
    case verified
    case sourceRemoved
    case ready
}

@MainActor
public final class PulseSharedStoreMigrator {
    private let fileOperator: any PulseStoreFileOperating
    private let checkpointHandler: (PulseSharedStoreMigrationCheckpoint) throws -> Void

    public convenience init(fileManager: FileManager = .default) {
        self.init(
            fileOperator: SystemPulseStoreFileOperator(fileManager: fileManager),
            checkpointHandler: { _ in }
        )
    }

    init(
        fileOperator: any PulseStoreFileOperating,
        checkpointHandler: @escaping (PulseSharedStoreMigrationCheckpoint) throws -> Void
    ) {
        self.fileOperator = fileOperator
        self.checkpointHandler = checkpointHandler
    }

    public func currentPhase(
        target: PulseStoreLocation
    ) throws -> PulseSharedStoreMigrationPhase {
        try readJournal(at: target.migrationJournalURL)?.phase ?? .notStarted
    }

    public func currentMode(
        target: PulseStoreLocation
    ) throws -> PulseSharedStoreMigrationMode? {
        try readJournal(at: target.migrationJournalURL)?.mode
    }

    public func migrateExistingStore(
        source: PulseStoreLocation,
        target: PulseStoreLocation,
        clock: any PulseClock,
        initialIdentity: HabitIdentity
    ) throws {
        try migrateStore(
            mode: .existingStore,
            source: source,
            target: target,
            clock: clock,
            initialIdentity: initialIdentity
        )
    }

    public func admitNewInstallation(
        stagingSource: PulseStoreLocation,
        target: PulseStoreLocation,
        systemTimeZone: TimeZone,
        clock: any PulseClock,
        initialIdentity: HabitIdentity
    ) throws {
        let journal = try readJournal(at: target.migrationJournalURL)
        if journal == nil {
            if anyStoreArtifactExists(stagingSource) {
                guard mainStoreExists(stagingSource) else {
                    throw PulseSharedStoreMigrationError.invalidNewInstallationSource
                }
            } else {
                try createNewInstallationSource(
                    at: stagingSource,
                    systemTimeZone: systemTimeZone,
                    clock: clock,
                    initialIdentity: initialIdentity
                )
            }
        }

        try migrateStore(
            mode: .newInstallation,
            source: stagingSource,
            target: target,
            clock: clock,
            initialIdentity: initialIdentity
        )
    }

    private func migrateStore(
        mode: PulseSharedStoreMigrationMode,
        source: PulseStoreLocation,
        target: PulseStoreLocation,
        clock: any PulseClock,
        initialIdentity: HabitIdentity
    ) throws {
        guard source.storeURL.standardizedFileURL.resolvingSymlinksInPath()
                != target.storeURL.standardizedFileURL.resolvingSymlinksInPath() else {
            throw PulseSharedStoreMigrationError.locationsMustDiffer
        }

        try fileOperator.createDirectory(at: target.directoryURL)
        let journal = try readJournal(at: target.migrationJournalURL)

        guard let journal else {
            guard mainStoreExists(source) else {
                throw mode == .existingStore
                    ? PulseSharedStoreMigrationError.sourceStoreMissing
                    : PulseSharedStoreMigrationError.invalidNewInstallationSource
            }
            guard !anyStoreArtifactExists(target) else {
                throw PulseSharedStoreMigrationError.targetStoreExistsWithoutJournal
            }

            let sourceFacts = try readFacts(
                at: source,
                clock: clock,
                initialIdentity: initialIdentity,
                missingHabitError: mode == .existingStore
                    ? .sourceStoreHasNoPrimaryHabit
                    : .invalidNewInstallationSource
            )
            let copyingJournal = try PulseSharedStoreMigrationJournal(
                mode: mode,
                phase: .copying,
                factDigest: sourceFacts.digest
            )
            try writeJournal(copyingJournal, at: target.migrationJournalURL)
            try checkpointHandler(.copying)
            try resumeCopying(
                journal: copyingJournal,
                source: source,
                target: target,
                clock: clock,
                initialIdentity: initialIdentity
            )
            return
        }

        guard journal.mode == mode else {
            throw PulseSharedStoreMigrationError.journalModeMismatch
        }

        switch journal.phase {
        case .notStarted:
            throw PulseSharedStoreMigrationError.persistedNotStartedPhase
        case .copying:
            try resumeCopying(
                journal: journal,
                source: source,
                target: target,
                clock: clock,
                initialIdentity: initialIdentity
            )
        case .verified:
            try resumeVerified(
                journal: journal,
                source: source,
                target: target,
                clock: clock,
                initialIdentity: initialIdentity
            )
        case .sourceRemoved:
            try resumeSourceRemoved(
                journal: journal,
                source: source,
                target: target,
                clock: clock,
                initialIdentity: initialIdentity
            )
        case .ready:
            try validateReady(
                journal: journal,
                source: source,
                target: target,
                clock: clock,
                initialIdentity: initialIdentity
            )
        }
    }

    private func createNewInstallationSource(
        at location: PulseStoreLocation,
        systemTimeZone: TimeZone,
        clock: any PulseClock,
        initialIdentity: HabitIdentity
    ) throws {
        try fileOperator.createDirectory(at: location.directoryURL)
        try autoreleasepool {
            let container = try PersistenceController.makeContainer(
                storeName: PulseStoreContract.storeName,
                storeURL: location.storeURL
            )
            let repository = SwiftDataCheckInRepository(
                container: container,
                clock: clock,
                initialIdentity: initialIdentity
            )
            _ = try repository.primaryHabit(systemTimeZone: systemTimeZone)
        }
    }

    private func resumeCopying(
        journal: PulseSharedStoreMigrationJournal,
        source: PulseStoreLocation,
        target: PulseStoreLocation,
        clock: any PulseClock,
        initialIdentity: HabitIdentity
    ) throws {
        guard mainStoreExists(source) else {
            throw journal.mode == .existingStore
                ? PulseSharedStoreMigrationError.sourceStoreMissing
                : PulseSharedStoreMigrationError.invalidNewInstallationSource
        }
        let sourceFacts = try readFacts(
            at: source,
            clock: clock,
            initialIdentity: initialIdentity,
            missingHabitError: journal.mode == .existingStore
                ? .sourceStoreHasNoPrimaryHabit
                : .invalidNewInstallationSource
        )
        guard sourceFacts.digest == journal.factDigest else {
            throw PulseSharedStoreMigrationError.sourceStoreChanged
        }

        try removeStoreArtifacts(at: target)
        try writeFacts(
            sourceFacts,
            at: target,
            clock: clock,
            initialIdentity: initialIdentity
        )
        try verifyTarget(
            target,
            expectedDigest: journal.factDigest,
            clock: clock,
            initialIdentity: initialIdentity
        )

        let verifiedJournal = try PulseSharedStoreMigrationJournal(
            mode: journal.mode,
            phase: .verified,
            factDigest: journal.factDigest
        )
        try writeJournal(verifiedJournal, at: target.migrationJournalURL)
        try checkpointHandler(.verified)
        try resumeVerified(
            journal: verifiedJournal,
            source: source,
            target: target,
            clock: clock,
            initialIdentity: initialIdentity
        )
    }

    private func resumeVerified(
        journal: PulseSharedStoreMigrationJournal,
        source: PulseStoreLocation,
        target: PulseStoreLocation,
        clock: any PulseClock,
        initialIdentity: HabitIdentity
    ) throws {
        try verifyTarget(
            target,
            expectedDigest: journal.factDigest,
            clock: clock,
            initialIdentity: initialIdentity
        )
        try removeStoreArtifacts(at: source)
        guard !anyStoreArtifactExists(source) else {
            throw PulseSharedStoreMigrationError.unexpectedSourceStore
        }

        let sourceRemovedJournal = try PulseSharedStoreMigrationJournal(
            mode: journal.mode,
            phase: .sourceRemoved,
            factDigest: journal.factDigest
        )
        try writeJournal(sourceRemovedJournal, at: target.migrationJournalURL)
        try checkpointHandler(.sourceRemoved)
        try resumeSourceRemoved(
            journal: sourceRemovedJournal,
            source: source,
            target: target,
            clock: clock,
            initialIdentity: initialIdentity
        )
    }

    private func resumeSourceRemoved(
        journal: PulseSharedStoreMigrationJournal,
        source: PulseStoreLocation,
        target: PulseStoreLocation,
        clock: any PulseClock,
        initialIdentity: HabitIdentity
    ) throws {
        guard !anyStoreArtifactExists(source) else {
            throw PulseSharedStoreMigrationError.unexpectedSourceStore
        }
        try verifyTarget(
            target,
            expectedDigest: journal.factDigest,
            clock: clock,
            initialIdentity: initialIdentity
        )

        let readyJournal = try PulseSharedStoreMigrationJournal(
            mode: journal.mode,
            phase: .ready,
            factDigest: journal.factDigest
        )
        try writeJournal(readyJournal, at: target.migrationJournalURL)
        try checkpointHandler(.ready)
    }

    private func validateReady(
        journal: PulseSharedStoreMigrationJournal,
        source: PulseStoreLocation,
        target: PulseStoreLocation,
        clock: any PulseClock,
        initialIdentity: HabitIdentity
    ) throws {
        guard !anyStoreArtifactExists(source) else {
            throw PulseSharedStoreMigrationError.unexpectedSourceStore
        }
        try verifyReadyTarget(
            target,
            clock: clock,
            initialIdentity: initialIdentity
        )
    }

    /// Once ownership has switched, the target is the mutable source of truth.
    /// The journal digest proves the migration transaction only; comparing it
    /// after `ready` would reject every legitimate check-in or identity edit.
    private func verifyReadyTarget(
        _ target: PulseStoreLocation,
        clock: any PulseClock,
        initialIdentity: HabitIdentity
    ) throws {
        guard mainStoreExists(target) else {
            throw PulseSharedStoreMigrationError.targetStoreMissing
        }
        try autoreleasepool {
            let container = try PersistenceController.makeContainer(
                storeName: PulseStoreContract.storeName,
                storeURL: target.storeURL
            )
            let repository = SwiftDataCheckInRepository(
                container: container,
                clock: clock,
                initialIdentity: initialIdentity
            )
            guard try repository.existingPrimaryHabit() != nil else {
                throw PulseSharedStoreMigrationError.targetStoreHasNoPrimaryHabit
            }
        }
    }

    private func verifyTarget(
        _ target: PulseStoreLocation,
        expectedDigest: PulseStoreDigest,
        clock: any PulseClock,
        initialIdentity: HabitIdentity
    ) throws {
        guard mainStoreExists(target) else {
            throw PulseSharedStoreMigrationError.targetStoreMissing
        }
        let facts = try readFacts(
            at: target,
            clock: clock,
            initialIdentity: initialIdentity,
            missingHabitError: .targetStoreHasNoPrimaryHabit
        )
        guard facts.digest == expectedDigest else {
            throw PulseSharedStoreMigrationError.targetStoreDigestMismatch
        }
    }

    private func readFacts(
        at location: PulseStoreLocation,
        clock: any PulseClock,
        initialIdentity: HabitIdentity,
        missingHabitError: PulseSharedStoreMigrationError
    ) throws -> PulseMigrationFacts {
        try autoreleasepool {
            let container = try PersistenceController.makeContainer(
                storeName: PulseStoreContract.storeName,
                storeURL: location.storeURL
            )
            let repository = SwiftDataCheckInRepository(
                container: container,
                clock: clock,
                initialIdentity: initialIdentity
            )
            guard let habit = try repository.existingPrimaryHabit() else {
                throw missingHabitError
            }
            return try PulseMigrationFacts(
                habit: habit,
                records: repository.allRecords(habitID: habit.id)
            )
        }
    }

    private func writeFacts(
        _ facts: PulseMigrationFacts,
        at location: PulseStoreLocation,
        clock: any PulseClock,
        initialIdentity: HabitIdentity
    ) throws {
        try autoreleasepool {
            let container = try PersistenceController.makeContainer(
                storeName: PulseStoreContract.storeName,
                storeURL: location.storeURL
            )
            let repository = SwiftDataCheckInRepository(
                container: container,
                clock: clock,
                initialIdentity: initialIdentity
            )
            _ = try repository.replaceAll(with: facts.payload)
        }
    }

    private func mainStoreExists(_ location: PulseStoreLocation) -> Bool {
        fileOperator.itemExists(at: location.storeURL)
    }

    private func anyStoreArtifactExists(_ location: PulseStoreLocation) -> Bool {
        location.storeArtifactURLs.contains(where: fileOperator.itemExists)
    }

    private func removeStoreArtifacts(at location: PulseStoreLocation) throws {
        for artifactURL in location.storeArtifactURLs
        where fileOperator.itemExists(at: artifactURL) {
            try fileOperator.removeItem(at: artifactURL)
        }
    }

    private func readJournal(at url: URL) throws -> PulseSharedStoreMigrationJournal? {
        guard fileOperator.itemExists(at: url) else { return nil }
        do {
            let data = try fileOperator.readData(at: url)
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  Set(object.keys) == ["version", "mode", "phase", "factDigest"] else {
                throw PulseSharedStoreMigrationError.invalidJournal
            }
            return try JSONDecoder().decode(
                PulseSharedStoreMigrationJournal.self,
                from: data
            )
        } catch let error as PulseSharedStoreMigrationError {
            throw error
        } catch {
            throw PulseSharedStoreMigrationError.invalidJournal
        }
    }

    private func writeJournal(
        _ journal: PulseSharedStoreMigrationJournal,
        at url: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(journal)
        try fileOperator.writeDataAtomically(data, to: url)
        guard try readJournal(at: url) == journal else {
            throw PulseSharedStoreMigrationError.invalidJournal
        }
    }
}

private struct PulseMigrationFacts {
    let payload: PulseExportPayload
    let digest: PulseStoreDigest

    init(habit: HabitSnapshot, records: [CheckInRecordSnapshot]) throws {
        let sortedRecords = records.sorted { lhs, rhs in
            if lhs.logicalDay != rhs.logicalDay {
                return lhs.logicalDay < rhs.logicalDay
            }
            if lhs.checkedAt != rhs.checkedAt {
                return lhs.checkedAt < rhs.checkedAt
            }
            return lhs.id.uuidString.lowercased() < rhs.id.uuidString.lowercased()
        }
        let exportedAt = sortedRecords.reduce(habit.createdAt) { latest, record in
            max(latest, record.createdAt)
        }
        let payload = PulseExportPayload(
            format: PulseDataContract.formatIdentifier,
            schemaVersion: PulseDataContract.exportSchemaVersion,
            exportedAt: exportedAt,
            habit: .init(
                id: habit.id,
                name: habit.name,
                purpose: habit.purpose,
                isIdentityConfirmed: habit.isIdentityConfirmed,
                createdAt: habit.createdAt,
                startLogicalDay: habit.startLogicalDay.storageValue,
                creationTimeZoneIdentifier: habit.creationTimeZoneIdentifier,
                timeZoneIdentifier: habit.timeZoneIdentifier
            ),
            records: sortedRecords.map { record in
                .init(
                    id: record.id,
                    logicalDay: record.logicalDay.storageValue,
                    checkedAt: record.checkedAt,
                    createdAt: record.createdAt,
                    timeZoneIdentifier: record.timeZoneIdentifier
                )
            }
        )
        _ = try PulseDataValidator.validate(payload)
        self.payload = payload
        digest = try PulseStoreFactDigester.digest(payload)
    }
}

private enum PulseStoreFactDigester {
    static func digest(_ payload: PulseExportPayload) throws -> PulseStoreDigest {
        var writer = CanonicalDigestWriter()
        writer.append("co.fanr.pulse.store-facts-v1")
        writer.append(payload.habit.id)
        writer.append(Habit.primarySlotKey)
        writer.append(payload.habit.name)
        writer.append(payload.habit.purpose)
        writer.append(payload.habit.isIdentityConfirmed)
        writer.append(payload.habit.createdAt)
        writer.append(payload.habit.startLogicalDay)
        writer.append(payload.habit.creationTimeZoneIdentifier)
        writer.append(payload.habit.timeZoneIdentifier)
        writer.append(UInt64(payload.records.count))

        for record in payload.records {
            writer.append(record.id)
            writer.append(payload.habit.id)
            writer.append(
                "\(payload.habit.id.uuidString.lowercased()):\(record.logicalDay)"
            )
            writer.append(record.logicalDay)
            writer.append(record.checkedAt)
            writer.append(record.createdAt)
            writer.append(record.timeZoneIdentifier)
        }

        return try PulseStoreDigest(value: writer.finalize())
    }
}

private struct CanonicalDigestWriter {
    private var hasher = SHA256()

    mutating func append(_ value: String) {
        let bytes = Data(value.utf8)
        append(UInt64(bytes.count))
        hasher.update(data: bytes)
    }

    mutating func append(_ value: String?) {
        append(value != nil)
        if let value {
            append(value)
        }
    }

    mutating func append(_ value: UUID) {
        append(value.uuidString.lowercased())
    }

    mutating func append(_ value: Bool) {
        hasher.update(data: Data([value ? 1 : 0]))
    }

    mutating func append(_ value: Date) {
        append(value.timeIntervalSinceReferenceDate.bitPattern)
    }

    mutating func append(_ value: UInt64) {
        var bigEndianValue = value.bigEndian
        withUnsafeBytes(of: &bigEndianValue) { bytes in
            hasher.update(data: Data(bytes))
        }
    }

    mutating func finalize() -> String {
        hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
