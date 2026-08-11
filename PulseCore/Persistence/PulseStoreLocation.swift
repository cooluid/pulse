import Foundation

public enum PulseStoreContract {
    public static let storeName = "Pulse"
    public static let storeFilename = "Pulse.store"
    public static let productDirectoryName = "Pulse"
    public static let migrationJournalFilename = "SharedStoreMigration.json"
}

public enum PulseStoreLocationError: Error, Equatable, Sendable {
    case applicationSupportDirectoryUnavailable
    case invalidApplicationGroupIdentifier
    case applicationGroupContainerUnavailable
    case invalidDirectoryURL
}

public struct PulseStoreLocation: Equatable, Sendable {
    public let directoryURL: URL
    public let storeURL: URL
    public let migrationJournalURL: URL

    public init(directoryURL: URL) throws {
        guard directoryURL.isFileURL,
              directoryURL.standardizedFileURL.path != "/" else {
            throw PulseStoreLocationError.invalidDirectoryURL
        }

        let standardizedDirectoryURL = directoryURL.standardizedFileURL
        self.directoryURL = standardizedDirectoryURL
        storeURL = standardizedDirectoryURL.appendingPathComponent(
            PulseStoreContract.storeFilename,
            isDirectory: false
        )
        migrationJournalURL = standardizedDirectoryURL.appendingPathComponent(
            PulseStoreContract.migrationJournalFilename,
            isDirectory: false
        )
    }

    public var storeArtifactURLs: [URL] {
        [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm")
        ]
    }
}

public struct PulseStoreLocator {
    private let applicationSupportDirectoryProvider: () throws -> URL
    private let applicationGroupContainerProvider: (String) -> URL?

    public init(fileManager: FileManager = .default) {
        applicationSupportDirectoryProvider = {
            guard let directory = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw PulseStoreLocationError.applicationSupportDirectoryUnavailable
            }
            return directory
        }
        applicationGroupContainerProvider = { identifier in
            fileManager.containerURL(
                forSecurityApplicationGroupIdentifier: identifier
            )
        }
    }

    init(
        applicationSupportDirectoryProvider: @escaping () throws -> URL,
        applicationGroupContainerProvider: @escaping (String) -> URL?
    ) {
        self.applicationSupportDirectoryProvider = applicationSupportDirectoryProvider
        self.applicationGroupContainerProvider = applicationGroupContainerProvider
    }

    public func appPrivateLocation() throws -> PulseStoreLocation {
        try PulseStoreLocation(directoryURL: applicationSupportDirectoryProvider())
    }

    public func appGroupLocation(identifier: String) throws -> PulseStoreLocation {
        let suffix = identifier.dropFirst("group.".count)
        let allowedScalars = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-."
        )
        guard identifier.hasPrefix("group."),
              !suffix.isEmpty,
              !suffix.hasPrefix("."),
              !suffix.hasSuffix("."),
              !suffix.contains(".."),
              suffix.unicodeScalars.allSatisfy(allowedScalars.contains) else {
            throw PulseStoreLocationError.invalidApplicationGroupIdentifier
        }
        guard let containerURL = applicationGroupContainerProvider(identifier) else {
            throw PulseStoreLocationError.applicationGroupContainerUnavailable
        }

        let directoryURL = containerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(PulseStoreContract.productDirectoryName, isDirectory: true)
        return try PulseStoreLocation(directoryURL: directoryURL)
    }
}
