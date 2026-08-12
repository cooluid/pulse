import Foundation

public enum PulseStoreContract {
    public static let storeName = "Pulse"
    public static let storeFilename = "Pulse.store"
    public static let productDirectoryName = "Pulse"
    public static let mediaDirectoryName = "Media"
    public static let archiveWorkingDirectoryName = "ArchiveWork"
}

public enum PulseStoreLocationError: Error, Equatable, Sendable {
    case invalidApplicationGroupIdentifier
    case applicationGroupContainerUnavailable
    case invalidDirectoryURL
    case incompatibleStoreVersion
}

public struct PulseStoreLocation: Equatable, Sendable {
    public let directoryURL: URL
    public let storeURL: URL
    public let mediaDirectoryURL: URL
    public let archiveWorkingDirectoryURL: URL

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
        mediaDirectoryURL = standardizedDirectoryURL.appendingPathComponent(
            PulseStoreContract.mediaDirectoryName,
            isDirectory: true
        )
        archiveWorkingDirectoryURL = standardizedDirectoryURL.appendingPathComponent(
            PulseStoreContract.archiveWorkingDirectoryName,
            isDirectory: true
        )
    }
}

public struct PulseStoreLocator {
    private let applicationGroupContainerProvider: (String) -> URL?

    public init(fileManager: FileManager = .default) {
        applicationGroupContainerProvider = { identifier in
            fileManager.containerURL(
                forSecurityApplicationGroupIdentifier: identifier
            )
        }
    }

    init(
        applicationGroupContainerProvider: @escaping (String) -> URL?
    ) {
        self.applicationGroupContainerProvider = applicationGroupContainerProvider
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
