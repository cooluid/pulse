import CryptoKit
import Foundation

public struct VerifiedImprintFiles: Equatable, Sendable {
    public let originalRelativePath: String
    public let thumbnailRelativePath: String
    public let byteCount: Int64
    public let thumbnailByteCount: Int64
    public let sha256: String
    public let thumbnailSHA256: String
}

enum PulseMediaReadContext: Sendable {
    case precommitVerification
    case committedRead
}

typealias PulseMediaReadTransform = @Sendable (
    PulseMediaReadContext,
    String,
    Int,
    Data
) throws -> Data

typealias PulseMediaRetrySleeper = @Sendable (UInt64) async throws -> Void

public actor PulseMediaFileStore {
    public static let maximumOriginalBytes = 24 * 1_024 * 1_024
    public static let maximumThumbnailBytes = 2 * 1_024 * 1_024
    private static let transientReadRetryDelays: [UInt64] = [
        0,
        40_000_000,
        80_000_000,
        120_000_000
    ]

    private let rootURL: URL
    private let originalsURL: URL
    private let thumbnailsURL: URL
    private let stagingURL: URL
    private let fileManager: FileManager
    private let readTransform: PulseMediaReadTransform
    private let retrySleeper: PulseMediaRetrySleeper

    public init(rootURL: URL, fileManager: FileManager = .default) throws {
        try self.init(
            rootURL: rootURL,
            fileManager: fileManager,
            readTransform: { _, _, _, data in data },
            retrySleeper: { nanoseconds in
                try await Task.sleep(nanoseconds: nanoseconds)
            }
        )
    }

    init(
        rootURL: URL,
        fileManager: FileManager = .default,
        readTransform: @escaping PulseMediaReadTransform,
        retrySleeper: @escaping PulseMediaRetrySleeper
    ) throws {
        guard rootURL.isFileURL,
              rootURL.standardizedFileURL.path != "/" else {
            throw PulseMediaStorageError.storageUnavailable
        }
        self.rootURL = rootURL.standardizedFileURL
        originalsURL = self.rootURL.appendingPathComponent("originals", isDirectory: true)
        thumbnailsURL = self.rootURL.appendingPathComponent("thumbnails", isDirectory: true)
        stagingURL = self.rootURL.appendingPathComponent("staging", isDirectory: true)
        self.fileManager = fileManager
        self.readTransform = readTransform
        self.retrySleeper = retrySleeper
        try Self.prepareDirectory(self.rootURL, fileManager: fileManager)
        try Self.prepareDirectory(originalsURL, fileManager: fileManager)
        try Self.prepareDirectory(thumbnailsURL, fileManager: fileManager)
        try Self.prepareDirectory(stagingURL, fileManager: fileManager)
    }

    public func installVerified(
        originalData: Data,
        thumbnailData: Data,
        storageID: UUID = UUID()
    ) async throws -> VerifiedImprintFiles {
        guard !originalData.isEmpty,
              originalData.count <= Self.maximumOriginalBytes,
              !thumbnailData.isEmpty,
              thumbnailData.count <= Self.maximumThumbnailBytes else {
            throw PulseMediaStorageError.invalidInput
        }

        try validateManagedDirectories()
        let originalRelativePath = PulseMediaPath.make(
            directory: .originals,
            storageID: storageID
        )
        let thumbnailRelativePath = PulseMediaPath.make(
            directory: .thumbnails,
            storageID: storageID
        )
        let transactionURL = stagingURL.appendingPathComponent(
            UUID().uuidString.lowercased(),
            isDirectory: true
        )
        try Self.prepareDirectory(transactionURL, fileManager: fileManager)
        let stagedOriginal = transactionURL.appendingPathComponent("original.jpg")
        let stagedThumbnail = transactionURL.appendingPathComponent("thumbnail.jpg")
        var installedURLs: [URL] = []

        do {
            try originalData.write(to: stagedOriginal, options: [.atomic])
            try thumbnailData.write(to: stagedThumbnail, options: [.atomic])
            try Self.protect(stagedOriginal, fileManager: fileManager)
            try Self.protect(stagedThumbnail, fileManager: fileManager)

            let finalOriginal = try resolvedURL(for: originalRelativePath)
            let finalThumbnail = try resolvedURL(for: thumbnailRelativePath)
            guard !fileManager.fileExists(atPath: finalOriginal.path),
                  !fileManager.fileExists(atPath: finalThumbnail.path) else {
                throw PulseMediaStorageError.storageUnavailable
            }
            try fileManager.moveItem(at: stagedOriginal, to: finalOriginal)
            installedURLs.append(finalOriginal)
            try fileManager.moveItem(at: stagedThumbnail, to: finalThumbnail)
            installedURLs.append(finalThumbnail)
            let installed = VerifiedImprintFiles(
                originalRelativePath: originalRelativePath,
                thumbnailRelativePath: thumbnailRelativePath,
                byteCount: Int64(originalData.count),
                thumbnailByteCount: Int64(thumbnailData.count),
                sha256: Self.sha256Hex(originalData),
                thumbnailSHA256: Self.sha256Hex(thumbnailData)
            )
            _ = try await readValidated(
                relativePath: installed.originalRelativePath,
                maximumBytes: Self.maximumOriginalBytes,
                expectedByteCount: installed.byteCount,
                expectedSHA256: installed.sha256,
                context: .precommitVerification
            )
            _ = try await readValidated(
                relativePath: installed.thumbnailRelativePath,
                maximumBytes: Self.maximumThumbnailBytes,
                expectedByteCount: installed.thumbnailByteCount,
                expectedSHA256: installed.thumbnailSHA256,
                context: .precommitVerification
            )
            try? fileManager.removeItem(at: transactionURL)
            return installed
        } catch {
            for url in installedURLs {
                try? fileManager.removeItem(at: url)
            }
            try? fileManager.removeItem(at: transactionURL)
            throw error
        }
    }

    public func readCommittedThumbnail(for media: ImprintMediaSnapshot) async throws -> Data {
        try await readValidated(
            relativePath: media.thumbnailRelativePath,
            maximumBytes: Self.maximumThumbnailBytes,
            expectedByteCount: media.thumbnailByteCount,
            expectedSHA256: media.thumbnailSHA256,
            context: .committedRead
        )
    }

    public func readCommittedOriginal(for media: ImprintMediaSnapshot) async throws -> Data {
        try await readValidated(
            relativePath: media.originalRelativePath,
            maximumBytes: Self.maximumOriginalBytes,
            expectedByteCount: media.byteCount,
            expectedSHA256: media.sha256,
            context: .committedRead
        )
    }

    private func readValidated(
        relativePath: String,
        maximumBytes: Int,
        expectedByteCount: Int64,
        expectedSHA256: String,
        context: PulseMediaReadContext
    ) async throws -> Data {
        for (attempt, delay) in Self.transientReadRetryDelays.enumerated() {
            if delay > 0 {
                try await retrySleeper(delay)
            }
            do {
                let persisted = try readFile(
                    relativePath: relativePath,
                    maximumBytes: maximumBytes
                )
                let data = try readTransform(context, relativePath, attempt, persisted)
                guard Int64(data.count) == expectedByteCount,
                      Self.sha256Hex(data) == expectedSHA256 else {
                    throw PulseMediaStorageError.identityMismatch
                }
                return data
            } catch let error as PulseMediaStorageError {
                guard Self.isRetryable(error, in: context) else { throw error }
                guard attempt < Self.transientReadRetryDelays.count - 1 else {
                    if context == .precommitVerification,
                       let failure = Self.verificationFailure(for: error) {
                        throw PulseMediaStorageError.precommitVerificationFailed(failure)
                    }
                    throw error
                }
            }
        }
        throw PulseMediaStorageError.storageUnavailable
    }

    public func remove(_ media: ImprintMediaSnapshot) throws {
        for path in [media.originalRelativePath, media.thumbnailRelativePath] {
            let url = try resolvedURL(for: path)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    public func removeInstalledFiles(_ files: VerifiedImprintFiles) {
        for path in [files.originalRelativePath, files.thumbnailRelativePath] {
            guard let url = try? resolvedURL(for: path) else { continue }
            try? fileManager.removeItem(at: url)
        }
    }

    public func audit(referencedMedia: [ImprintMediaSnapshot]) throws {
        try validateManagedDirectories()
        let referenced = Set(referencedMedia.flatMap {
            [$0.originalRelativePath, $0.thumbnailRelativePath]
        })
        for (directory, prefix) in [(originalsURL, "originals"), (thumbnailsURL, "thumbnails")] {
            let files = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
            for url in files {
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                guard !Self.isSymbolicLink(url, fileManager: fileManager),
                      attributes[.type] as? FileAttributeType == .typeRegular else {
                    throw PulseMediaStorageError.storageUnavailable
                }
                let relativePath = "\(prefix)/\(url.lastPathComponent)"
                if !referenced.contains(relativePath) {
                    try fileManager.removeItem(at: url)
                }
            }
        }
        try removeAllContents(of: stagingURL)

        for media in referencedMedia {
            guard fileManager.fileExists(atPath: try resolvedURL(for: media.originalRelativePath).path),
                  fileManager.fileExists(atPath: try resolvedURL(for: media.thumbnailRelativePath).path) else {
                throw PulseMediaStorageError.fileUnavailable
            }
        }
    }

    public func removeAll() throws {
        try validateManagedDirectories()
        try removeAllContents(of: originalsURL)
        try removeAllContents(of: thumbnailsURL)
        try removeAllContents(of: stagingURL)
    }

    public func storageByteCount() throws -> Int64 {
        try validateManagedDirectories()
        var result: Int64 = 0
        for directory in [originalsURL, thumbnailsURL] {
            let urls = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            for url in urls {
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                guard !Self.isSymbolicLink(url, fileManager: fileManager),
                      attributes[.type] as? FileAttributeType == .typeRegular,
                      let fileSize = attributes[.size] as? NSNumber else {
                    throw PulseMediaStorageError.storageUnavailable
                }
                result += fileSize.int64Value
            }
        }
        return result
    }

    public func writeArchive(
        payload: PulseBackupPayload,
        to destinationURL: URL,
        passphrase: String
    ) throws {
        try PulseEncryptedBackupCodec.write(
            payload,
            to: destinationURL,
            passphrase: passphrase
        ) { relativePath, maximumBytes in
            try readFile(relativePath: relativePath, maximumBytes: maximumBytes)
        }
    }

    private func readFile(relativePath: String, maximumBytes: Int) throws -> Data {
        let url = try resolvedURL(for: relativePath)
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try fileManager.attributesOfItem(atPath: url.path)
        } catch {
            throw PulseMediaStorageError.fileUnavailable
        }
        guard !Self.isSymbolicLink(url, fileManager: fileManager),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let fileSize = attributes[.size] as? NSNumber,
              fileSize.int64Value > 0,
              fileSize.int64Value <= Int64(maximumBytes) else {
            throw PulseMediaStorageError.fileUnavailable
        }
        // Backup encryption zeroizes plaintext media after use. A mapped Data value can
        // point at a read-only file mapping, so it must not cross that mutable boundary.
        do {
            return try Data(contentsOf: url)
        } catch {
            throw PulseMediaStorageError.fileUnavailable
        }
    }

    private static func isRetryable(
        _ error: PulseMediaStorageError,
        in context: PulseMediaReadContext
    ) -> Bool {
        switch (context, error) {
        case (.precommitVerification, .fileUnavailable),
             (.precommitVerification, .identityMismatch),
             (.committedRead, .fileUnavailable):
            true
        default:
            false
        }
    }

    private static func verificationFailure(
        for error: PulseMediaStorageError
    ) -> PulseMediaVerificationFailure? {
        switch error {
        case .fileUnavailable:
            .fileUnavailable
        case .identityMismatch:
            .identityMismatch
        default:
            nil
        }
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func resolvedURL(for relativePath: String) throws -> URL {
        guard PulseMediaPath.isValidStoredPath(relativePath),
              let directory = PulseMediaPath.directory(for: relativePath) else {
            throw PulseMediaStorageError.identityMismatch
        }
        try Self.requireSafeDirectory(rootURL, fileManager: fileManager)
        switch directory {
        case .originals:
            try Self.requireSafeDirectory(originalsURL, fileManager: fileManager)
        case .thumbnails:
            try Self.requireSafeDirectory(thumbnailsURL, fileManager: fileManager)
        }
        let resolved = rootURL.appendingPathComponent(relativePath).standardizedFileURL
        let rootPrefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard resolved.path.hasPrefix(rootPrefix) else {
            throw PulseMediaStorageError.identityMismatch
        }
        return resolved
    }

    private func removeAllContents(of directory: URL) throws {
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: []
        )
        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }

    private static func prepareDirectory(_ url: URL, fileManager: FileManager) throws {
        if isSymbolicLink(url, fileManager: fileManager) {
            throw PulseMediaStorageError.storageUnavailable
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        try requireSafeDirectory(url, fileManager: fileManager)
        try protect(url, fileManager: fileManager)
    }

    private func validateManagedDirectories() throws {
        for directory in [rootURL, originalsURL, thumbnailsURL, stagingURL] {
            try Self.requireSafeDirectory(directory, fileManager: fileManager)
        }
    }

    private static func requireSafeDirectory(_ url: URL, fileManager: FileManager) throws {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard !isSymbolicLink(url, fileManager: fileManager),
              attributes[.type] as? FileAttributeType == .typeDirectory else {
            throw PulseMediaStorageError.storageUnavailable
        }
    }

    private static func isSymbolicLink(_ url: URL, fileManager: FileManager) -> Bool {
        (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    private static func protect(_ url: URL, fileManager: FileManager) throws {
        try fileManager.setAttributes(
            [.protectionKey: PulseStoreProtection.fileProtectionType],
            ofItemAtPath: url.path
        )
    }
}
