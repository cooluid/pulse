import Foundation
import SwiftData

enum PulseSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Habit.self, CheckInRecord.self]
    }
}

public enum PersistenceController {
    public static func makeContainer(
        inMemory: Bool = false,
        storeName: String = PulseStoreContract.storeName,
        storeURL: URL? = nil
    ) throws -> ModelContainer {
        precondition(!inMemory || storeURL == nil, "An in-memory store cannot also use a disk URL.")

        let schema = Schema(versionedSchema: PulseSchema.self)
        let configuration: ModelConfiguration
        if let storeURL {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
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

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
