import SwiftData

enum PulseSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Habit.self, CheckInRecord.self]
    }
}

enum PulseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PulseSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum PersistenceController {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(PulseSchemaV1.models)
        let configuration = ModelConfiguration(
            "Pulse",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: PulseMigrationPlan.self,
            configurations: [configuration]
        )
    }
}

