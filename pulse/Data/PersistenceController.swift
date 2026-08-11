import Foundation
import SwiftData

enum PulseSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Habit.self, CheckInRecord.self]
    }

    @Model
    final class Habit {
        @Attribute(.unique) var id: UUID
        @Attribute(.unique) var slotKey: String
        var name: String
        var createdAt: Date
        var startLogicalDayValue: String
        var creationTimeZoneIdentifier: String
        var timeZoneIdentifier: String

        init(
            id: UUID = UUID(),
            slotKey: String = "primary",
            name: String,
            createdAt: Date,
            startLogicalDayValue: String,
            creationTimeZoneIdentifier: String,
            timeZoneIdentifier: String
        ) {
            self.id = id
            self.slotKey = slotKey
            self.name = name
            self.createdAt = createdAt
            self.startLogicalDayValue = startLogicalDayValue
            self.creationTimeZoneIdentifier = creationTimeZoneIdentifier
            self.timeZoneIdentifier = timeZoneIdentifier
        }
    }

    @Model
    final class CheckInRecord {
        @Attribute(.unique) var id: UUID
        @Attribute(.unique) var recordKey: String
        var habitID: UUID
        var logicalDayValue: String
        var checkedAt: Date
        var createdAt: Date
        var timeZoneIdentifier: String

        init(
            id: UUID = UUID(),
            recordKey: String,
            habitID: UUID,
            logicalDayValue: String,
            checkedAt: Date,
            createdAt: Date,
            timeZoneIdentifier: String
        ) {
            self.id = id
            self.recordKey = recordKey
            self.habitID = habitID
            self.logicalDayValue = logicalDayValue
            self.checkedAt = checkedAt
            self.createdAt = createdAt
            self.timeZoneIdentifier = timeZoneIdentifier
        }
    }
}

enum PulseSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Habit.self, CheckInRecord.self]
    }
}

enum PulseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PulseSchemaV1.self, PulseSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1ToV2]
    }

    private static let migrateV1ToV2 = MigrationStage.lightweight(
        fromVersion: PulseSchemaV1.self,
        toVersion: PulseSchemaV2.self
    )
}

enum PersistenceController {
    static func makeContainer(
        inMemory: Bool = false,
        storeName: String = "Pulse",
        storeURL: URL? = nil
    ) throws -> ModelContainer {
        precondition(!inMemory || storeURL == nil, "An in-memory store cannot also use a disk URL.")

        let schema = Schema(versionedSchema: PulseSchemaV2.self)
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(
                storeName,
                schema: schema,
                url: storeURL
            )
        } else {
            configuration = ModelConfiguration(
                storeName,
                schema: schema,
                isStoredInMemoryOnly: inMemory
            )
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: PulseMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
