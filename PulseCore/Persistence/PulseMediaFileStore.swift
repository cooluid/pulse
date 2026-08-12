import CryptoKit
import Foundation

public struct InstalledImprintFiles: Equatable, Sendable {
    public let originalRelativePath: String
    public let thumbnailRelativePath: String
    public let byteCount: Int64
    public let thumbnailByteCount: Int64
    public let sha256: String
    public let thumbnailSHA256: String
}

public actor PulseMediaFileStore {
    public static let maximumOriginalBytes = 24 * 1_024 * 1_024
    public static let maximumThumbnailBytes = 2 * 1_024 * 1_024

    private let rootURL: URL
    private let originalsURL: URL
    private let thumbnailsURL: URL
    private let stagingURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) throws {
        guard rootURL.isFileURL,
              rootURL.standardizedFileURL.path != "/" else {
            throw PulseCoreError.mediaStorageUnavailable
        }
        self.rootURL = rootURL.standardizedFileURL
        originalsURL = self.rootURL.appendingPathComponent("originals", isDirectory: true)
        thumbnailsURL = self.rootURL.appendingPathComponent("thumbnails", isDirectory: true)
        stagingURL = self.rootURL.appendingPathComponent("staging", isDirectory: true)
        self.fileManager = fileManager
        try Self.prepareDirectory(self.rootURL, fileManager: fileManager)
        try Self.prepareDirectory(originalsURL, fileManager: fileManager)
        try Self.prepareDirectory(thumbnailsURL, fileManager: fileManager)
        try Self.prepareDirectory(stagingURL, fileManager: fileManager)
    }

    public func install(
        originalData: Data,
        thumbnailData: Data,
        storageID: UUID = UUID()
    ) throws -> InstalledImprintFiles {
        guard !originalData.isEmpty,
              originalData.count <= Self.maximumOriginalBytes,
              !thumbnailData.isEmpty,
              thumbnailData.count <= Self.maximumThumbnailBytes else {
            throw PulseCoreError.invalidMedia
        }

        let originalRelativePath = "originals/\(storageID.uuidString.lowercased()).jpg"
        let thumbnailRelativePath = "thumbnails/\(storageID.uuidString.lowercased()).jpg"
        let transactionURL = stagingURL.appendingPathComponent(
            UUID().uuidString.lowercased(),
            isDirectory: true
        )
        try Self.prepareDirectory(transactionURL, fileManager: fileManager)
        let stagedOriginal = transactionURL.appendingPathComponent("original.jpg")
        let stagedThumbnail = transactionURL.appendingPathComponent("thumbnail.jpg")

        do {
            try originalData.write(to: stagedOriginal, options: [.atomic])
            try thumbnailData.write(to: stagedThumbnail, options: [.atomic])
            try Self.protect(stagedOriginal, fileManager: fileManager)
            try Self.protect(stagedThumbnail, fileManager: fileManager)

            let finalOriginal = try resolvedURL(for: originalRelativePath)
            let finalThumbnail = try resolvedURL(for: thumbnailRelativePath)
            guard !fileManager.fileExists(atPath: finalOriginal.path),
                  !fileManager.fileExists(atPath: finalThumbnail.path) else {
                throw PulseCoreError.mediaStorageUnavailable
            }
            try fileManager.moveItem(at: stagedOriginal, to: finalOriginal)
            do {
                try fileManager.moveItem(at: stagedThumbnail, to: finalThumbnail)
            } catch {
                try? fileManager.removeItem(at: finalOriginal)
                throw error
            }
            try? fileManager.removeItem(at: transactionURL)
            return InstalledImprintFiles(
                originalRelativePath: originalRelativePath,
                thumbnailRelativePath: thumbnailRelativePath,
                byteCount: Int64(originalData.count),
                thumbnailByteCount: Int64(thumbnailData.count),
                sha256: SHA256.hash(data: originalData)
                    .map { String(format: "%02x", $0) }
                    .joined(),
                thumbnailSHA256: SHA256.hash(data: thumbnailData)
                    .map { String(format: "%02x", $0) }
                    .joined()
            )
        } catch {
            try? fileManager.removeItem(at: transactionURL)
            throw error
        }
    }

    public func readThumbnail(for media: ImprintMediaSnapshot) throws -> Data {
        let data = try readFile(
            relativePath: media.thumbnailRelativePath,
            maximumBytes: Self.maximumThumbnailBytes
        )
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard hash == media.thumbnailSHA256,
              data.count == media.thumbnailByteCount else {
            throw PulseCoreError.invalidMedia
        }
        return data
    }

    public func readOriginal(for media: ImprintMediaSnapshot) throws -> Data {
        let data = try readFile(
            relativePath: media.originalRelativePath,
            maximumBytes: Self.maximumOriginalBytes
        )
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard hash == media.sha256, data.count == media.byteCount else {
            throw PulseCoreError.invalidMedia
        }
        return data
    }

    public func remove(_ media: ImprintMediaSnapshot) throws {
        for path in [media.originalRelativePath, media.thumbnailRelativePath] {
            let url = try resolvedURL(for: path)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    public func removeInstalledFiles(_ files: InstalledImprintFiles) {
        for path in [files.originalRelativePath, files.thumbnailRelativePath] {
            guard let url = try? resolvedURL(for: path) else { continue }
            try? fileManager.removeItem(at: url)
        }
    }

    public func audit(referencedMedia: [ImprintMediaSnapshot]) throws {
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
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else {
                    throw PulseCoreError.mediaStorageUnavailable
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
                throw PulseCoreError.mediaFileUnavailable
            }
        }
    }

    public func removeAll() throws {
        try removeAllContents(of: originalsURL)
        try removeAllContents(of: thumbnailsURL)
        try removeAllContents(of: stagingURL)
    }

    public func storageByteCount() throws -> Int64 {
        var result: Int64 = 0
        for directory in [originalsURL, thumbnailsURL] {
            let urls = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            for url in urls {
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard values.isRegularFile == true, let fileSize = values.fileSize else {
                    throw PulseCoreError.mediaStorageUnavailable
                }
                result += Int64(fileSize)
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
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey
        ])
        guard values.isRegularFile == true,
              values.isSymbolicLink != true,
              let fileSize = values.fileSize,
              fileSize > 0,
              fileSize <= maximumBytes else {
            throw PulseCoreError.mediaFileUnavailable
        }
        return try Data(contentsOf: url, options: [.mappedIfSafe])
    }

    private func resolvedURL(for relativePath: String) throws -> URL {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.contains(".."),
              !relativePath.contains("\\"),
              relativePath.split(separator: "/").count == 2 else {
            throw PulseCoreError.invalidMedia
        }
        let resolved = rootURL.appendingPathComponent(relativePath).standardizedFileURL
        let rootPrefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard resolved.path.hasPrefix(rootPrefix) else {
            throw PulseCoreError.invalidMedia
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
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        try protect(url, fileManager: fileManager)
    }

    private static func protect(_ url: URL, fileManager: FileManager) throws {
        try fileManager.setAttributes(
            [.protectionKey: PulseStoreProtection.fileProtectionType],
            ofItemAtPath: url.path
        )
    }
}
