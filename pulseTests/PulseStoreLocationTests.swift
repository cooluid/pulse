import SwiftData
import XCTest
@testable import PulseCore

final class PulseStoreLocationTests: XCTestCase {
    func testPrivateLocationMatchesTheExistingSwiftDataDefaultStore() throws {
        let location = try PulseStoreLocator().appPrivateLocation()
        let swiftDataURL = ModelConfiguration(PulseStoreContract.storeName).url

        XCTAssertEqual(location.storeURL, swiftDataURL)
        XCTAssertEqual(location.storeURL.lastPathComponent, "Pulse.store")
    }

    func testAppGroupLocationUsesTheSystemContainerAndCanonicalSubdirectory() throws {
        let groupRoot = URL(fileURLWithPath: "/private/group-container", isDirectory: true)
        var requestedIdentifier: String?
        let locator = PulseStoreLocator(
            applicationSupportDirectoryProvider: {
                XCTFail("App Group lookup must not inspect the private Application Support path.")
                return URL(fileURLWithPath: "/unused")
            },
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
            applicationSupportDirectoryProvider: { URL(fileURLWithPath: "/unused") },
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
            applicationSupportDirectoryProvider: { URL(fileURLWithPath: "/unused") },
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

    func testStoreArtifactsAreAnExactMainWalShmAllowlist() throws {
        let location = try PulseStoreLocation(
            directoryURL: URL(fileURLWithPath: "/tmp/pulse-location", isDirectory: true)
        )

        XCTAssertEqual(
            location.storeArtifactURLs.map(\.lastPathComponent),
            ["Pulse.store", "Pulse.store-wal", "Pulse.store-shm"]
        )
        XCTAssertEqual(
            location.migrationJournalURL.lastPathComponent,
            "SharedStoreMigration.json"
        )
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
}
