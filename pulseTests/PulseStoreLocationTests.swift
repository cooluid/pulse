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
}
