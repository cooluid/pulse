import Foundation
import OSLog
import PulseCore
import UIKit

struct ProcessedImprintImage: Sendable {
    let originalData: Data
    let thumbnailData: Data
    let pixelWidth: Int
    let pixelHeight: Int
}

enum ImprintImageProcessor {
    static let maximumDimension: CGFloat = 4_096
    static let thumbnailMaximumDimension: CGFloat = 720

    @MainActor
    static func materializeCameraCapture(_ image: UIImage) throws -> UIImage {
        guard image.size.width > 0, image.size.height > 0 else {
            throw PulseCoreError.invalidMedia
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    static func process(_ image: UIImage) throws -> ProcessedImprintImage {
        let upright = normalizedUprightImage(image)
        guard upright.size.width > 0, upright.size.height > 0 else {
            throw PulseCoreError.invalidMedia
        }
        let normalized = try renderedImage(upright, maximumDimension: maximumDimension)
        let thumbnail = try renderedImage(normalized, maximumDimension: thumbnailMaximumDimension)
        guard let originalData = normalized.jpegData(compressionQuality: 0.9),
              let thumbnailData = thumbnail.jpegData(compressionQuality: 0.82),
              !originalData.isEmpty,
              !thumbnailData.isEmpty else {
            throw PulseCoreError.invalidMedia
        }
        return ProcessedImprintImage(
            originalData: originalData,
            thumbnailData: thumbnailData,
            pixelWidth: Int(normalized.size.width * normalized.scale),
            pixelHeight: Int(normalized.size.height * normalized.scale)
        )
    }

    private static func normalizedUprightImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func renderedImage(
        _ image: UIImage,
        maximumDimension: CGFloat
    ) throws -> UIImage {
        let sourcePixelWidth = image.size.width * image.scale
        let sourcePixelHeight = image.size.height * image.scale
        let longest = max(sourcePixelWidth, sourcePixelHeight)
        let factor = min(1, maximumDimension / longest)
        let target = CGSize(
            width: max(1, (sourcePixelWidth * factor).rounded()),
            height: max(1, (sourcePixelHeight * factor).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

@MainActor
final class ImprintMediaService {
    private static let logger = Logger(
        subsystem: PulseRuntimeIdentity.bundleIdentifier,
        category: "media-storage"
    )
    private let repository: any PulseRepositoryProtocol
    private let fileStore: PulseMediaFileStore
    private let clock: any PulseClock

    init(
        repository: any PulseRepositoryProtocol,
        fileStore: PulseMediaFileStore,
        clock: any PulseClock
    ) {
        self.repository = repository
        self.fileStore = fileStore
        self.clock = clock
    }

    func audit(habitID: UUID) async throws {
        try await fileStore.audit(referencedMedia: repository.allMedia(habitID: habitID))
    }

    func save(
        image: UIImage,
        habit: HabitSnapshot,
        record: CheckInRecordSnapshot,
        cameraPosition: ImprintCameraPosition
    ) async throws -> ImprintMediaSnapshot {
        let processed: ProcessedImprintImage
        do {
            processed = try await Task.detached(priority: .userInitiated) {
                try ImprintImageProcessor.process(image)
            }.value
        } catch {
            Self.logSaveFailure(stage: "encode", error: error)
            throw error
        }

        let installed: VerifiedImprintFiles
        do {
            installed = try await fileStore.installVerified(
                originalData: processed.originalData,
                thumbnailData: processed.thumbnailData
            )
        } catch {
            Self.logSaveFailure(
                stage: "precommit_file_verification",
                error: error,
                originalByteCount: processed.originalData.count,
                thumbnailByteCount: processed.thumbnailData.count
            )
            throw error
        }
        let previous = try repository.allMedia(habitID: habit.id)
            .first { $0.logicalDay == record.logicalDay }
        let now = clock.now
        let draft = ImprintMediaDraft(
            habitID: habit.id,
            recordID: record.id,
            logicalDay: record.logicalDay,
            capturedAt: now,
            createdAt: now,
            originalRelativePath: installed.originalRelativePath,
            thumbnailRelativePath: installed.thumbnailRelativePath,
            byteCount: installed.byteCount,
            thumbnailByteCount: installed.thumbnailByteCount,
            pixelWidth: processed.pixelWidth,
            pixelHeight: processed.pixelHeight,
            sha256: installed.sha256,
            thumbnailSHA256: installed.thumbnailSHA256,
            cameraPosition: cameraPosition
        )
        do {
            let result = try repository.upsertMedia(draft)
            if let previous {
                try? await fileStore.remove(previous)
            }
            Self.logger.info(
                "Media save committed; original_bytes=\(processed.originalData.count, privacy: .public); thumbnail_bytes=\(processed.thumbnailData.count, privacy: .public)."
            )
            return result
        } catch {
            await fileStore.removeInstalledFiles(installed)
            Self.logSaveFailure(stage: "repository_commit", error: error)
            throw error
        }
    }

    func delete(_ media: ImprintMediaSnapshot) async throws {
        try repository.deleteMedia(id: media.id)
        try? await fileStore.remove(media)
    }

    func thumbnailData(for media: ImprintMediaSnapshot) async throws -> Data {
        try await fileStore.readCommittedThumbnail(for: media)
    }

    func originalData(for media: ImprintMediaSnapshot) async throws -> Data {
        try await fileStore.readCommittedOriginal(for: media)
    }

    func storageByteCount() async throws -> Int64 {
        try await fileStore.storageByteCount()
    }

    func removeAllFiles() async throws {
        try await fileStore.removeAll()
    }

    func writeArchive(
        payload: PulseBackupPayload,
        to destinationURL: URL,
        passphrase: String
    ) async throws {
        try await fileStore.writeArchive(
            payload: payload,
            to: destinationURL,
            passphrase: passphrase
        )
    }

    func restore(_ decoded: PulseDecodedBackup) async throws -> HabitSnapshot {
        var installedFiles: [VerifiedImprintFiles] = []
        var restoredMedia: [PulseBackupPayload.MediaPayload] = []
        let habit: HabitSnapshot
        do {
            for item in decoded.payload.media {
                let originalURL = try stagingURL(
                    root: decoded.mediaDirectoryURL,
                    relativePath: item.originalRelativePath
                )
                let thumbnailURL = try stagingURL(
                    root: decoded.mediaDirectoryURL,
                    relativePath: item.thumbnailRelativePath
                )
                let original = try Data(
                    contentsOf: originalURL,
                    options: [.mappedIfSafe]
                )
                let thumbnail = try Data(
                    contentsOf: thumbnailURL,
                    options: [.mappedIfSafe]
                )
                let installed = try await fileStore.installVerified(
                    originalData: original,
                    thumbnailData: thumbnail
                )
                installedFiles.append(installed)
                restoredMedia.append(
                    .init(
                        id: item.id,
                        recordID: item.recordID,
                        logicalDay: item.logicalDay,
                        capturedAt: item.capturedAt,
                        createdAt: item.createdAt,
                        modifiedAt: item.modifiedAt,
                        originalRelativePath: installed.originalRelativePath,
                        thumbnailRelativePath: installed.thumbnailRelativePath,
                        byteCount: installed.byteCount,
                        thumbnailByteCount: installed.thumbnailByteCount,
                        pixelWidth: item.pixelWidth,
                        pixelHeight: item.pixelHeight,
                        sha256: installed.sha256,
                        thumbnailSHA256: installed.thumbnailSHA256,
                        cameraPosition: item.cameraPosition
                    )
                )
            }
            let replacement = PulseBackupPayload(
                format: decoded.payload.format,
                schemaVersion: decoded.payload.schemaVersion,
                exportedAt: decoded.payload.exportedAt,
                habit: decoded.payload.habit,
                records: decoded.payload.records,
                media: restoredMedia
            )
            habit = try repository.replaceAll(with: replacement)
        } catch {
            for installed in installedFiles {
                await fileStore.removeInstalledFiles(installed)
            }
            throw error
        }

        // At this point the authoritative database transaction is committed and every
        // referenced immutable file was installed first. Orphan cleanup is a separate,
        // retryable maintenance transaction and must never roll back by deleting the
        // newly committed files.
        do {
            try await fileStore.audit(referencedMedia: repository.allMedia(habitID: habit.id))
        } catch {
            Self.logger.error(
                "Post-restore orphan cleanup will be retried at activation: \(String(describing: error), privacy: .private)"
            )
        }
        decoded.discard()
        return habit
    }

    private static func logSaveFailure(
        stage: String,
        error: Error,
        originalByteCount: Int? = nil,
        thumbnailByteCount: Int? = nil
    ) {
        let code: String
        if let mediaError = error as? PulseMediaStorageError {
            code = mediaError.diagnosticCode
        } else if let coreError = error as? PulseCoreError {
            code = switch coreError {
            case .invalidMedia: "media.domain.invalid"
            default: "media.domain.failure"
            }
        } else {
            code = "media.unknown"
        }

        if let originalByteCount, let thumbnailByteCount {
            logger.error(
                "Media save failed; stage=\(stage, privacy: .public); code=\(code, privacy: .public); original_bytes=\(originalByteCount, privacy: .public); thumbnail_bytes=\(thumbnailByteCount, privacy: .public)."
            )
        } else {
            logger.error(
                "Media save failed; stage=\(stage, privacy: .public); code=\(code, privacy: .public)."
            )
        }
    }

    private func stagingURL(root: URL, relativePath: String) throws -> URL {
        guard PulseMediaPath.isValidStoredPath(relativePath) else {
            throw PulseCoreError.invalidBackup
        }
        let url = root.appendingPathComponent(relativePath).standardizedFileURL
        guard url.path.hasPrefix(root.standardizedFileURL.path + "/") else {
            throw PulseCoreError.invalidBackup
        }
        return url
    }
}
