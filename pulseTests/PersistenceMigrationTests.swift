import SwiftData
import XCTest
@testable import PulseCore
@testable import pulse

@MainActor
final class PersistenceMigrationTests: XCTestCase {
    func testV1DiskStoreMigratesToV2WithoutChangingFacts() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("Pulse.store")
        let habitID = UUID()
        let recordID = UUID()
        let createdAt = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-08-10T04:00:00Z")
        )
        let logicalDay = "2026-08-10"
        let recordKey = "\(habitID.uuidString.lowercased()):\(logicalDay)"

        try createV1Store(
            at: storeURL,
            habitID: habitID,
            recordID: recordID,
            recordKey: recordKey,
            logicalDay: logicalDay,
            createdAt: createdAt
        )

        let container = try PersistenceController.makeContainer(
            storeName: "PulseMigrationFixture",
            storeURL: storeURL
        )
        let context = ModelContext(container)
        let habits = try context.fetch(FetchDescriptor<Habit>())
        let records = try context.fetch(FetchDescriptor<CheckInRecord>())

        XCTAssertEqual(habits.count, 1)
        XCTAssertEqual(habits.first?.id, habitID)
        XCTAssertEqual(habits.first?.name, "Daily")
        XCTAssertNil(habits.first?.purpose)
        XCTAssertFalse(habits.first?.isIdentityConfirmed ?? true)
        XCTAssertEqual(habits.first?.startLogicalDayValue, logicalDay)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, recordID)
        XCTAssertEqual(records.first?.recordKey, recordKey)
        XCTAssertEqual(records.first?.habitID, habitID)
        XCTAssertEqual(records.first?.logicalDayValue, logicalDay)
    }

    func testVersionedSchemasKeepTheSameEntityNames() {
        let v1Names = Set(Schema(versionedSchema: PulseSchemaV1.self).entitiesByName.keys)
        let v2Names = Set(Schema(versionedSchema: PulseSchemaV2.self).entitiesByName.keys)

        XCTAssertEqual(v1Names, ["Habit", "CheckInRecord"])
        XCTAssertEqual(v2Names, v1Names)
    }

    private func createV1Store(
        at storeURL: URL,
        habitID: UUID,
        recordID: UUID,
        recordKey: String,
        logicalDay: String,
        createdAt: Date
    ) throws {
        let schema = Schema(versionedSchema: PulseSchemaV1.self)
        let configuration = ModelConfiguration(
            "PulseMigrationFixture",
            schema: schema,
            url: storeURL
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        context.insert(
            PulseSchemaV1.Habit(
                id: habitID,
                name: "Daily",
                createdAt: createdAt,
                startLogicalDayValue: logicalDay,
                creationTimeZoneIdentifier: "Asia/Shanghai",
                timeZoneIdentifier: "Asia/Shanghai"
            )
        )
        context.insert(
            PulseSchemaV1.CheckInRecord(
                id: recordID,
                recordKey: recordKey,
                habitID: habitID,
                logicalDayValue: logicalDay,
                checkedAt: createdAt,
                createdAt: createdAt,
                timeZoneIdentifier: "Asia/Shanghai"
            )
        )
        try context.save()
    }
}
