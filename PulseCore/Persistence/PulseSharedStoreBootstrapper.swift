import Foundation

public enum PulseSharedStoreBootstrapError: Error, Equatable, Sendable {
    case incompletePrivateStore
    case conflictingPrivateStore
    case conflictingStagingStore
    case migrationDidNotBecomeReady
    case sourceArtifactsRemain
}

/// Selects one authoritative startup path and never falls back to an app-private store.
@MainActor
public final class PulseSharedStoreBootstrapper {
    private let fileManager: FileManager
    private let migrator: PulseSharedStoreMigrator

    public convenience init(fileManager: FileManager = .default) {
        self.init(
            fileManager: fileManager,
            migrator: PulseSharedStoreMigrator(fileManager: fileManager)
        )
    }

    init(
        fileManager: FileManager,
        migrator: PulseSharedStoreMigrator
    ) {
        self.fileManager = fileManager
        self.migrator = migrator
    }

    @discardableResult
    public func prepareSharedStore(
        privateLocation: PulseStoreLocation,
        sharedLocation: PulseStoreLocation,
        systemTimeZone: TimeZone,
        clock: any PulseClock,
        initialIdentity: HabitIdentity
    ) throws -> PulseStoreLocation {
        let stagingLocation = try sharedLocation.newInstallationStagingLocation
        let journalMode = try migrator.currentMode(target: sharedLocation)

        switch journalMode {
        case .existingStore:
            guard !anyStoreArtifactExists(stagingLocation) else {
                throw PulseSharedStoreBootstrapError.conflictingStagingStore
            }
            try migrator.migrateExistingStore(
                source: privateLocation,
                target: sharedLocation,
                clock: clock,
                initialIdentity: initialIdentity
            )
        case .newInstallation:
            guard !anyStoreArtifactExists(privateLocation) else {
                throw PulseSharedStoreBootstrapError.conflictingPrivateStore
            }
            try migrator.admitNewInstallation(
                stagingSource: stagingLocation,
                target: sharedLocation,
                systemTimeZone: systemTimeZone,
                clock: clock,
                initialIdentity: initialIdentity
            )
        case nil:
            let privateMainExists = fileManager.fileExists(
                atPath: privateLocation.storeURL.path
            )
            if privateMainExists {
                guard !anyStoreArtifactExists(stagingLocation) else {
                    throw PulseSharedStoreBootstrapError.conflictingStagingStore
                }
                try migrator.migrateExistingStore(
                    source: privateLocation,
                    target: sharedLocation,
                    clock: clock,
                    initialIdentity: initialIdentity
                )
            } else {
                guard !anyStoreArtifactExists(privateLocation) else {
                    throw PulseSharedStoreBootstrapError.incompletePrivateStore
                }
                try migrator.admitNewInstallation(
                    stagingSource: stagingLocation,
                    target: sharedLocation,
                    systemTimeZone: systemTimeZone,
                    clock: clock,
                    initialIdentity: initialIdentity
                )
            }
        }

        guard try migrator.currentPhase(target: sharedLocation) == .ready else {
            throw PulseSharedStoreBootstrapError.migrationDidNotBecomeReady
        }
        guard !anyStoreArtifactExists(privateLocation),
              !anyStoreArtifactExists(stagingLocation) else {
            throw PulseSharedStoreBootstrapError.sourceArtifactsRemain
        }
        return sharedLocation
    }

    private func anyStoreArtifactExists(_ location: PulseStoreLocation) -> Bool {
        location.storeArtifactURLs.contains {
            fileManager.fileExists(atPath: $0.path)
        }
    }
}
