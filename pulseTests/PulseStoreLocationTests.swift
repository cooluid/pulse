import CryptoKit
import XCTest
@testable import PulseCore

final class PulseStoreLocationTests: XCTestCase {
    func testSigningEntitlementsDoNotOverrideTheRequiredAfterFirstUnlockDefault() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let entitlementURLs = [
            repositoryRoot.appendingPathComponent("pulse/pulse.entitlements"),
            repositoryRoot.appendingPathComponent("PulseWidgets/PulseWidgets.entitlements")
        ]

        for entitlementURL in entitlementURLs {
            let data = try Data(contentsOf: entitlementURL)
            let propertyList = try XCTUnwrap(
                PropertyListSerialization.propertyList(from: data, format: nil)
                    as? [String: Any]
            )

            XCTAssertNil(
                propertyList["com.apple.developer.default-data-protection"],
                "The system default is already After First Unlock; declaring this entitlement "
                    + "makes the signed profile authoritative and can force Complete protection."
            )
            XCTAssertNotNil(propertyList["com.apple.security.application-groups"])
        }

        XCTAssertEqual(
            PulseStoreProtection.fileProtectionType,
            .completeUntilFirstUserAuthentication
        )
    }

    func testAppGroupLocationUsesTheSystemContainerAndCanonicalSubdirectory() throws {
        let groupRoot = URL(fileURLWithPath: "/private/group-container", isDirectory: true)
        var requestedIdentifier: String?
        let locator = PulseStoreLocator(
            applicationGroupContainerProvider: { identifier in
                requestedIdentifier = identifier
                return groupRoot
            }
        )

        let location = try locator.appGroupLocation(identifier: "group.co.fanr.pulse")

        XCTAssertEqual(requestedIdentifier, "group.co.fanr.pulse")
        XCTAssertEqual(
            location.directoryURL.path,
            "/private/group-container/Library/Application Support/Pulse"
        )
        XCTAssertEqual(
            location.storeURL.path,
            "/private/group-container/Library/Application Support/Pulse/Pulse.store"
        )
    }

    func testApplicationMediaDirectoryUsesAppSupportNotAppGroup() throws {
        let supportRoot = URL(fileURLWithPath: "/private/app-support", isDirectory: true)
        let locator = PulseStoreLocator(
            applicationGroupContainerProvider: { _ in
                URL(fileURLWithPath: "/private/group-container", isDirectory: true)
            },
            applicationSupportDirectoryProvider: { supportRoot }
        )

        let mediaURL = try locator.applicationMediaDirectoryURL()

        XCTAssertEqual(
            mediaURL.path,
            "/private/app-support/Pulse/Media"
        )
    }

    func testMediaMigrationCopiesAndVerifiesEveryReferencedFileBeforeRemovingLegacyRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseMediaMigration-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appendingPathComponent("group/Pulse/Media", isDirectory: true)
        let destination = root.appendingPathComponent("app/Pulse/Media", isDirectory: true)
        let legacyOriginals = legacy.appendingPathComponent("originals", isDirectory: true)
        let legacyThumbnails = legacy.appendingPathComponent("thumbnails", isDirectory: true)
        try FileManager.default.createDirectory(
            at: legacyOriginals,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: legacyThumbnails,
            withIntermediateDirectories: true
        )
        let storageID = UUID()
        let original = Data([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9])
        let thumbnail = Data([0xff, 0xd8, 4, 0xff, 0xd9])
        let media = mediaSnapshot(
            storageID: storageID,
            original: original,
            thumbnail: thumbnail
        )
        try original.write(to: legacy.appendingPathComponent(media.originalRelativePath))
        try thumbnail.write(to: legacy.appendingPathComponent(media.thumbnailRelativePath))

        try PulseMediaFileStore.migrateLegacyMediaIfNeeded(
            from: legacy,
            to: destination,
            referencedMedia: [media]
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertEqual(
            try Data(contentsOf: destination.appendingPathComponent(media.originalRelativePath)),
            original
        )
        XCTAssertEqual(
            try Data(contentsOf: destination.appendingPathComponent(media.thumbnailRelativePath)),
            thumbnail
        )
    }

    func testMediaMigrationPreservesSourceWhenDestinationIdentityConflicts() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseMediaMigrationConflict-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appendingPathComponent("group/Pulse/Media", isDirectory: true)
        let destination = root.appendingPathComponent("app/Pulse/Media", isDirectory: true)
        let storageID = UUID()
        let original = Data([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9])
        let thumbnail = Data([0xff, 0xd8, 4, 0xff, 0xd9])
        let media = mediaSnapshot(
            storageID: storageID,
            original: original,
            thumbnail: thumbnail
        )
        try FileManager.default.createDirectory(
            at: legacy.appendingPathComponent("originals"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: legacy.appendingPathComponent("thumbnails"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: destination.appendingPathComponent("originals"),
            withIntermediateDirectories: true
        )
        try original.write(to: legacy.appendingPathComponent(media.originalRelativePath))
        try thumbnail.write(to: legacy.appendingPathComponent(media.thumbnailRelativePath))
        let conflicting = Data([0xff, 0xd8, 9, 9, 9, 0xff, 0xd9])
        try conflicting.write(
            to: destination.appendingPathComponent(media.originalRelativePath)
        )

        XCTAssertThrowsError(
            try PulseMediaFileStore.migrateLegacyMediaIfNeeded(
                from: legacy,
                to: destination,
                referencedMedia: [media]
            )
        ) { error in
            XCTAssertEqual(error as? PulseMediaStorageError, .identityMismatch)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertEqual(
            try Data(contentsOf: legacy.appendingPathComponent(media.originalRelativePath)),
            original
        )
        XCTAssertEqual(
            try Data(contentsOf: destination.appendingPathComponent(media.originalRelativePath)),
            conflicting
        )
    }

    func testMediaMigrationRejectsLegacyDirectorySymlinks() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseMediaMigrationSymlink-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appendingPathComponent("group/Pulse/Media", isDirectory: true)
        let destination = root.appendingPathComponent("app/Pulse/Media", isDirectory: true)
        let external = root.appendingPathComponent("external", isDirectory: true)
        try FileManager.default.createDirectory(
            at: legacy,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: external,
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            at: legacy.appendingPathComponent("originals", isDirectory: true),
            withDestinationURL: external
        )

        XCTAssertThrowsError(
            try PulseMediaFileStore.migrateLegacyMediaIfNeeded(
                from: legacy,
                to: destination,
                referencedMedia: []
            )
        ) { error in
            XCTAssertEqual(error as? PulseMediaStorageError, .storageUnavailable)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: external.path))
    }

    func testAppGroupLocationRejectsInvalidIdentifierWithoutCallingProvider() {
        var providerWasCalled = false
        let locator = PulseStoreLocator(
            applicationGroupContainerProvider: { _ in
                providerWasCalled = true
                return URL(fileURLWithPath: "/unused")
            }
        )

        for identifier in [
            "",
            "co.fanr.pulse",
            "group.",
            "group.co fanr.pulse",
            "group.co/fanr/pulse",
            "group..co.fanr.pulse",
            "group.co.fanr.pulse."
        ] {
            XCTAssertThrowsError(try locator.appGroupLocation(identifier: identifier)) { error in
                XCTAssertEqual(
                    error as? PulseStoreLocationError,
                    .invalidApplicationGroupIdentifier
                )
            }
        }
        XCTAssertFalse(providerWasCalled)
    }

    func testAppGroupLocationFailsWhenTheSystemDoesNotReturnAContainer() {
        let locator = PulseStoreLocator(
            applicationGroupContainerProvider: { _ in nil }
        )

        XCTAssertThrowsError(
            try locator.appGroupLocation(identifier: "group.co.fanr.pulse")
        ) { error in
            XCTAssertEqual(
                error as? PulseStoreLocationError,
                .applicationGroupContainerUnavailable
            )
        }
    }

    func testStoreLocationHasOneCanonicalStoreURL() throws {
        let location = try PulseStoreLocation(
            directoryURL: URL(fileURLWithPath: "/tmp/pulse-location", isDirectory: true)
        )

        XCTAssertEqual(location.directoryURL.path, "/tmp/pulse-location")
        XCTAssertEqual(location.storeURL.lastPathComponent, "Pulse.store")
    }

    func testSchemaMarkerUsesCleanBaselineAndRejectsExperimentalVersion() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseSchemaMarker-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let storeURL = root.appendingPathComponent("Pulse.store")

        _ = try PersistenceController.makeContainer(
            storeName: "PulseSchemaMarker",
            storeURL: storeURL
        )
        let markerURL = root.appendingPathComponent(".pulse-schema-version")
        XCTAssertEqual(try String(contentsOf: markerURL, encoding: .utf8), "1.1.1")

        try "1.1.0".write(to: markerURL, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(
            try PersistenceController.makeContainer(
                storeName: "PulseSchemaMarker",
                storeURL: storeURL
            )
        ) { error in
            XCTAssertEqual(
                error as? PulseStoreLocationError,
                .incompatibleStoreVersion
            )
        }
    }

    func testLocationRejectsNonFileURL() {
        XCTAssertThrowsError(
            try PulseStoreLocation(directoryURL: URL(string: "https://example.com/store")!)
        ) { error in
            XCTAssertEqual(error as? PulseStoreLocationError, .invalidDirectoryURL)
        }
        XCTAssertThrowsError(
            try PulseStoreLocation(directoryURL: URL(fileURLWithPath: "/"))
        ) { error in
            XCTAssertEqual(error as? PulseStoreLocationError, .invalidDirectoryURL)
        }
    }

    func testStoreProtectionCoversDirectoryAndExistingFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = root.appendingPathComponent("Pulse.store")
        let sidecar = root.appendingPathComponent("Pulse.store-wal")
        try Data("store".utf8).write(to: store)
        try Data("wal".utf8).write(to: sidecar)

        var protectedPaths = Set<String>()
        try PulseStoreProtection.enforce(
            in: root,
            fileManager: .default,
            attributeApplier: { attributes, path in
                XCTAssertEqual(
                    attributes[.protectionKey] as? FileProtectionType,
                    PulseStoreProtection.fileProtectionType
                )
                protectedPaths.insert(path)
            }
        )

        XCTAssertEqual(protectedPaths, Set([root.path, store.path, sidecar.path]))
    }

    private func mediaSnapshot(
        storageID: UUID,
        original: Data,
        thumbnail: Data
    ) -> ImprintMediaSnapshot {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        return ImprintMediaSnapshot(
            id: UUID(),
            habitID: UUID(),
            recordID: nil,
            logicalDay: LogicalDay(year: 2026, month: 8, day: 25),
            capturedAt: now,
            createdAt: now,
            modifiedAt: now,
            originalRelativePath: PulseMediaPath.make(
                directory: .originals,
                storageID: storageID
            ),
            thumbnailRelativePath: PulseMediaPath.make(
                directory: .thumbnails,
                storageID: storageID
            ),
            mediaType: "image/jpeg",
            byteCount: Int64(original.count),
            thumbnailByteCount: Int64(thumbnail.count),
            pixelWidth: 1_200,
            pixelHeight: 1_600,
            sha256: SHA256.hash(data: original)
                .map { String(format: "%02x", $0) }
                .joined(),
            thumbnailSHA256: SHA256.hash(data: thumbnail)
                .map { String(format: "%02x", $0) }
                .joined(),
            cameraPosition: .rear
        )
    }
}
