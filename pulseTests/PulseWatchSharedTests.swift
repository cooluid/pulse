import XCTest
@testable import PulseWatchShared

final class PulseWatchSharedTests: XCTestCase {
    func testLocalStoreCanonicalizesEquivalentSystemFileURL() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "PulseWatchSharedTests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let nonstandardDirectory = root
            .appendingPathComponent("intermediate", isDirectory: true)
            .appendingPathComponent("..", isDirectory: true)
            .appendingPathComponent("PulseWatch", isDirectory: true)
        XCTAssertNotEqual(nonstandardDirectory.standardizedFileURL, nonstandardDirectory)

        _ = try PulseWatchLocalStore(directoryURL: nonstandardDirectory)

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: nonstandardDirectory.standardizedFileURL.path,
            isDirectory: &isDirectory
        ))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testLocalStoreRejectsNonFileURL() throws {
        let remoteURL = try XCTUnwrap(URL(string: "https://example.com/PulseWatch"))

        XCTAssertThrowsError(try PulseWatchLocalStore(directoryURL: remoteURL)) { error in
            XCTAssertEqual(error as? PulseWatchLocalStoreError, .invalidDirectory)
        }
    }

    func testLocalStorePersistsOutboxAndAcknowledgesCommittedReceipt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "PulseWatchSharedTests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try PulseWatchLocalStore(directoryURL: directory)
        let snapshot = makeSnapshot()
        let command = PulseWatchCheckInCommand(
            projectID: snapshot.projectID,
            projectRevision: snapshot.projectRevision,
            occurredAt: snapshot.generatedAt,
            projectTimeZoneIdentifierSnapshot: snapshot.projectTimeZoneIdentifier
        )
        try store.save(snapshot: snapshot)
        try store.enqueue(command)

        XCTAssertEqual(try store.projection().pendingCommands, [command])
        XCTAssertEqual(
            try store.projection().displayState(at: snapshot.generatedAt),
            .pendingSync
        )

        let receipt = PulseWatchCheckInReceipt(
            operationID: command.operationID,
            projectID: command.projectID,
            projectRevision: command.projectRevision,
            outcome: .committed(
                logicalDay: snapshot.todayLogicalDay,
                checkedAt: command.occurredAt,
                disposition: .created
            ),
            acknowledgedAt: snapshot.generatedAt.addingTimeInterval(1)
        )
        try store.acknowledge(receipt)

        let reloadedStore = try PulseWatchLocalStore(directoryURL: directory)
        let projection = try reloadedStore.projection()
        XCTAssertTrue(projection.pendingCommands.isEmpty)
        XCTAssertEqual(projection.snapshot?.isCheckedToday, false)
        XCTAssertEqual(projection.lastReceipt, receipt)
        XCTAssertEqual(
            projection.displayState(at: receipt.acknowledgedAt),
            .committed(checkedAt: command.occurredAt)
        )
    }

    func testNewProjectSnapshotPreservesCommandUntilRejectedReceiptArrives() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "PulseWatchSharedTests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try PulseWatchLocalStore(directoryURL: directory)
        let first = makeSnapshot()
        try store.save(snapshot: first)
        let command = PulseWatchCheckInCommand(
            projectID: first.projectID,
            projectRevision: first.projectRevision,
            occurredAt: first.generatedAt,
            projectTimeZoneIdentifierSnapshot: first.projectTimeZoneIdentifier
        )
        try store.enqueue(command)
        let second = makeSnapshot(projectID: UUID())

        try store.save(snapshot: second)

        XCTAssertEqual(try store.projection().pendingCommands, [command])
        XCTAssertEqual(
            try store.projection().displayState(at: second.generatedAt),
            .failed(.projectChanged)
        )

        let receipt = PulseWatchCheckInReceipt(
            operationID: command.operationID,
            projectID: command.projectID,
            projectRevision: command.projectRevision,
            outcome: .rejected(reason: .projectChanged),
            acknowledgedAt: second.generatedAt.addingTimeInterval(1)
        )
        try store.acknowledge(receipt)

        XCTAssertTrue(try store.projection().pendingCommands.isEmpty)
        XCTAssertEqual(
            try store.projection().displayState(at: receipt.acknowledgedAt),
            .failed(.projectChanged)
        )
    }

    func testExpiredSnapshotNeedsSyncInsteadOfProjectingYesterdayAsToday() throws {
        let snapshot = makeSnapshot()
        let projection = PulseWatchLocalProjection(
            snapshot: snapshot,
            pendingCommands: [],
            lastReceipt: nil
        )

        XCTAssertEqual(
            projection.displayState(at: snapshot.nextDayBoundary),
            .needsSync
        )
    }

    func testOlderSnapshotCannotOverwriteNewerProjection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "PulseWatchSharedTests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try PulseWatchLocalStore(directoryURL: directory)
        let projectID = UUID()
        let older = makeSnapshot(projectID: projectID)
        let newer = makeSnapshot(
            projectID: projectID,
            generatedAt: older.generatedAt.addingTimeInterval(60)
        )

        try store.save(snapshot: newer)
        try store.save(snapshot: older)

        XCTAssertEqual(try store.projection().snapshot, newer)
    }

    func testPendingCommandRemainsVisibleAfterSnapshotBoundary() throws {
        let snapshot = makeSnapshot()
        let command = PulseWatchCheckInCommand(
            projectID: snapshot.projectID,
            projectRevision: snapshot.projectRevision,
            occurredAt: snapshot.generatedAt,
            projectTimeZoneIdentifierSnapshot: snapshot.projectTimeZoneIdentifier
        )
        let projection = PulseWatchLocalProjection(
            snapshot: snapshot,
            pendingCommands: [command],
            lastReceipt: nil
        )

        XCTAssertEqual(
            projection.displayState(at: snapshot.nextDayBoundary),
            .pendingSync
        )
    }

    func testPrepareForRetryRemovesOnlyIncompatibleCommandAndFailure() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "PulseWatchSharedTests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try PulseWatchLocalStore(directoryURL: directory)
        let first = makeSnapshot()
        let command = PulseWatchCheckInCommand(
            projectID: first.projectID,
            projectRevision: first.projectRevision,
            occurredAt: first.generatedAt,
            projectTimeZoneIdentifierSnapshot: first.projectTimeZoneIdentifier
        )
        try store.save(snapshot: first)
        try store.enqueue(command)
        let second = makeSnapshot(projectID: UUID())
        try store.save(snapshot: second)

        try store.prepareForRetry()

        let projection = try store.projection()
        XCTAssertTrue(projection.pendingCommands.isEmpty)
        XCTAssertNil(projection.lastReceipt)
        XCTAssertEqual(projection.displayState(at: second.generatedAt), .ready)
    }

    func testProjectRevisionIsDeterministicAndSensitiveToTimeZone() {
        let projectID = UUID()
        let first = PulseWatchProjectRevision.make(
            projectID: projectID,
            startLogicalDay: "2026-08-10",
            timeZoneIdentifier: "Asia/Shanghai"
        )
        let second = PulseWatchProjectRevision.make(
            projectID: projectID,
            startLogicalDay: "2026-08-10",
            timeZoneIdentifier: "Asia/Shanghai"
        )
        let changed = PulseWatchProjectRevision.make(
            projectID: projectID,
            startLogicalDay: "2026-08-10",
            timeZoneIdentifier: "Europe/Paris"
        )

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, changed)
        XCTAssertEqual(first.count, 64)
    }

    func testSnapshotDecoderRejectsContradictoryCompletionState() throws {
        let envelope = PulseWatchSnapshotEnvelope(
            snapshot: makeSnapshot(),
            generatedAt: Date(timeIntervalSince1970: 1_786_334_400)
        )
        let encoded = try PulseWatchCodec.encode(envelope)
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var snapshot = try XCTUnwrap(json["snapshot"] as? [String: Any])
        snapshot["isCheckedToday"] = true
        json["snapshot"] = snapshot
        let corrupted = try JSONSerialization.data(withJSONObject: json)

        XCTAssertThrowsError(try PulseWatchCodec.decodeSnapshotEnvelope(from: corrupted)) {
            error in
            XCTAssertEqual(error as? PulseWatchCodecError, .invalidPayload)
        }
    }

    func testCommandIdentitySurvivesProtocolRejectionForAFormalReceipt() throws {
        let snapshot = makeSnapshot()
        let command = PulseWatchCheckInCommand(
            projectID: snapshot.projectID,
            projectRevision: snapshot.projectRevision,
            occurredAt: snapshot.generatedAt,
            projectTimeZoneIdentifierSnapshot: snapshot.projectTimeZoneIdentifier
        )
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: PulseWatchCodec.encode(command))
                as? [String: Any]
        )
        json["protocolVersion"] = PulseWatchContract.protocolVersion + 1
        let incompatible = try JSONSerialization.data(withJSONObject: json)

        XCTAssertThrowsError(try PulseWatchCodec.decodeCommand(from: incompatible)) {
            error in
            XCTAssertEqual(error as? PulseWatchCodecError, .incompatibleProtocol)
        }
        XCTAssertEqual(
            try PulseWatchCodec.decodeCommandIdentity(from: incompatible),
            PulseWatchCommandIdentity(
                protocolVersion: PulseWatchContract.protocolVersion + 1,
                operationID: command.operationID,
                projectID: command.projectID,
                projectRevision: command.projectRevision
            )
        )
    }

    func testOutboxRejectsCommandFromAnotherProject() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "PulseWatchSharedTests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try PulseWatchLocalStore(directoryURL: directory)
        let snapshot = makeSnapshot()
        try store.save(snapshot: snapshot)
        let otherProjectID = UUID()
        let command = PulseWatchCheckInCommand(
            projectID: otherProjectID,
            projectRevision: PulseWatchProjectRevision.make(
                projectID: otherProjectID,
                startLogicalDay: "2026-08-04",
                timeZoneIdentifier: snapshot.projectTimeZoneIdentifier
            ),
            occurredAt: snapshot.generatedAt,
            projectTimeZoneIdentifierSnapshot: snapshot.projectTimeZoneIdentifier
        )

        XCTAssertThrowsError(try store.enqueue(command)) { error in
            XCTAssertEqual(error as? PulseWatchLocalStoreError, .incompatibleState)
        }
        XCTAssertTrue(try store.projection().pendingCommands.isEmpty)
    }

    private func makeSnapshot(
        projectID: UUID = UUID(),
        generatedAt date: Date = Date(timeIntervalSince1970: 1_786_334_400)
    ) -> PulseWatchProjectSnapshot {
        return PulseWatchProjectSnapshot(
            projectID: projectID,
            projectRevision: PulseWatchProjectRevision.make(
                projectID: projectID,
                startLogicalDay: "2026-08-04",
                timeZoneIdentifier: "Asia/Shanghai"
            ),
            projectTimeZoneIdentifier: "Asia/Shanghai",
            todayLogicalDay: "2026-08-10",
            isCheckedToday: false,
            checkedAt: nil,
            sevenDayPulse: (4...10).map { day in
                PulseWatchDaySnapshot(
                    logicalDay: String(format: "2026-08-%02d", day),
                    state: day == 10 ? .todayPending : .checked
                )
            },
            generatedAt: date,
            nextDayBoundary: date.addingTimeInterval(12 * 60 * 60)
        )
    }
}
