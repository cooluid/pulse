import Foundation
import XCTest
@testable import PulseCore

@MainActor
final class PulseSharedStoreBootstrapperTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "Asia/Shanghai")!

    func testFreshInstallationIsAdmittedThroughStagingAndBecomesReady() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }

        let result = try makeBootstrapper().prepareSharedStore(
            privateLocation: fixture.privateLocation,
            sharedLocation: fixture.sharedLocation,
            systemTimeZone: timeZone,
            clock: makeClock(),
            initialIdentity: try makeIdentity()
        )

        XCTAssertEqual(result, fixture.sharedLocation)
        XCTAssertEqual(
            try PulseSharedStoreMigrator().currentMode(target: fixture.sharedLocation),
            .newInstallation
        )
        XCTAssertEqual(
            try PulseSharedStoreMigrator().currentPhase(target: fixture.sharedLocation),
            .ready
        )
        XCTAssertNotNil(try existingHabit(at: fixture.sharedLocation))
        XCTAssertFalse(anyArtifactExists(at: fixture.privateLocation))
        XCTAssertFalse(anyArtifactExists(at: try fixture.sharedLocation.newInstallationStagingLocation))
    }

    func testExistingPrivateFactsMoveToSharedStoreWithoutFallback() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let expectedHabit = try createPrivateFacts(at: fixture.privateLocation)

        _ = try makeBootstrapper().prepareSharedStore(
            privateLocation: fixture.privateLocation,
            sharedLocation: fixture.sharedLocation,
            systemTimeZone: timeZone,
            clock: makeClock(),
            initialIdentity: try makeIdentity()
        )

        XCTAssertEqual(
            try PulseSharedStoreMigrator().currentMode(target: fixture.sharedLocation),
            .existingStore
        )
        XCTAssertEqual(try existingHabit(at: fixture.sharedLocation), expectedHabit)
        XCTAssertFalse(anyArtifactExists(at: fixture.privateLocation))
    }

    func testInterruptedFreshInstallationResumesFromJournalMode() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let interruptedMigrator = PulseSharedStoreMigrator(
            fileOperator: SystemPulseStoreFileOperator(),
            checkpointHandler: { checkpoint in
                if checkpoint == .copying {
                    throw BootstrapInjectedFailure.interruption
                }
            }
        )
        let interrupted = PulseSharedStoreBootstrapper(
            fileManager: .default,
            migrator: interruptedMigrator
        )

        XCTAssertThrowsError(
            try interrupted.prepareSharedStore(
                privateLocation: fixture.privateLocation,
                sharedLocation: fixture.sharedLocation,
                systemTimeZone: timeZone,
                clock: makeClock(),
                initialIdentity: try makeIdentity()
            )
        ) { error in
            XCTAssertEqual(error as? BootstrapInjectedFailure, .interruption)
        }
        XCTAssertEqual(
            try interruptedMigrator.currentMode(target: fixture.sharedLocation),
            .newInstallation
        )
        XCTAssertEqual(
            try interruptedMigrator.currentPhase(target: fixture.sharedLocation),
            .copying
        )

        _ = try makeBootstrapper().prepareSharedStore(
            privateLocation: fixture.privateLocation,
            sharedLocation: fixture.sharedLocation,
            systemTimeZone: timeZone,
            clock: makeClock(),
            initialIdentity: try makeIdentity()
        )

        XCTAssertEqual(
            try PulseSharedStoreMigrator().currentPhase(target: fixture.sharedLocation),
            .ready
        )
        XCTAssertFalse(
            anyArtifactExists(at: try fixture.sharedLocation.newInstallationStagingLocation)
        )
    }

    func testPrivateSidecarWithoutMainStoreFailsClosed() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        try FileManager.default.createDirectory(
            at: fixture.privateLocation.directoryURL,
            withIntermediateDirectories: true
        )
        try Data("orphaned-sidecar".utf8).write(
            to: fixture.privateLocation.storeArtifactURLs[1]
        )

        XCTAssertThrowsError(
            try makeBootstrapper().prepareSharedStore(
                privateLocation: fixture.privateLocation,
                sharedLocation: fixture.sharedLocation,
                systemTimeZone: timeZone,
                clock: makeClock(),
                initialIdentity: try makeIdentity()
            )
        ) { error in
            XCTAssertEqual(
                error as? PulseSharedStoreBootstrapError,
                .incompletePrivateStore
            )
        }
        XCTAssertFalse(anyArtifactExists(at: fixture.sharedLocation))
    }

    func testReadyNewInstallationRejectsReappearingPrivateStore() throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        _ = try makeBootstrapper().prepareSharedStore(
            privateLocation: fixture.privateLocation,
            sharedLocation: fixture.sharedLocation,
            systemTimeZone: timeZone,
            clock: makeClock(),
            initialIdentity: try makeIdentity()
        )
        try FileManager.default.createDirectory(
            at: fixture.privateLocation.directoryURL,
            withIntermediateDirectories: true
        )
        try Data("unexpected-private-store".utf8).write(
            to: fixture.privateLocation.storeURL
        )

        XCTAssertThrowsError(
            try makeBootstrapper().prepareSharedStore(
                privateLocation: fixture.privateLocation,
                sharedLocation: fixture.sharedLocation,
                systemTimeZone: timeZone,
                clock: makeClock(),
                initialIdentity: try makeIdentity()
            )
        ) { error in
            XCTAssertEqual(
                error as? PulseSharedStoreBootstrapError,
                .conflictingPrivateStore
            )
        }
    }

    private func makeFixture() throws -> BootstrapFixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "PulseSharedStoreBootstrapperTests-\(UUID().uuidString)",
            isDirectory: true
        )
        return BootstrapFixture(
            root: root,
            privateLocation: try PulseStoreLocation(
                directoryURL: root.appendingPathComponent("Private", isDirectory: true)
            ),
            sharedLocation: try PulseStoreLocation(
                directoryURL: root.appendingPathComponent("Shared", isDirectory: true)
            )
        )
    }

    private func makeBootstrapper() -> PulseSharedStoreBootstrapper {
        PulseSharedStoreBootstrapper()
    }

    private func createPrivateFacts(
        at location: PulseStoreLocation
    ) throws -> HabitSnapshot {
        try FileManager.default.createDirectory(
            at: location.directoryURL,
            withIntermediateDirectories: true
        )
        return try autoreleasepool {
            let repository = try repository(at: location)
            let initial = try repository.primaryHabit(systemTimeZone: timeZone)
            let updated = try repository.updateIdentity(
                habitID: initial.id,
                identity: try HabitIdentity(
                    userName: "每天留下一个印记",
                    userPurpose: "保持自己的节奏"
                )
            )
            _ = try repository.checkIn(habitID: updated.id)
            return updated
        }
    }

    private func existingHabit(
        at location: PulseStoreLocation
    ) throws -> HabitSnapshot? {
        try autoreleasepool {
            try repository(at: location).existingPrimaryHabit()
        }
    }

    private func repository(
        at location: PulseStoreLocation
    ) throws -> SwiftDataCheckInRepository {
        SwiftDataCheckInRepository(
            container: try PersistenceController.makeContainer(
                storeName: PulseStoreContract.storeName,
                storeURL: location.storeURL
            ),
            clock: makeClock(),
            initialIdentity: try makeIdentity()
        )
    }

    private func makeClock() -> FixedPulseClock {
        FixedPulseClock(now: makeDate(day: 11, hour: 12))
    }

    private func makeIdentity() throws -> HabitIdentity {
        try HabitIdentity(userName: "今天也留下一印", userPurpose: nil)
    }

    private func makeDate(day: Int, hour: Int) -> Date {
        Calendar.pulseGregorian(timeZone: timeZone).date(
            from: DateComponents(year: 2026, month: 8, day: day, hour: hour)
        )!
    }

    private func anyArtifactExists(at location: PulseStoreLocation) -> Bool {
        location.storeArtifactURLs.contains {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }
}

private struct BootstrapFixture {
    let root: URL
    let privateLocation: PulseStoreLocation
    let sharedLocation: PulseStoreLocation

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private enum BootstrapInjectedFailure: Error, Equatable {
    case interruption
}
