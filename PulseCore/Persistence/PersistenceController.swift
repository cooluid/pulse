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
        storeName: String = PulseStoreContract.storeName,
        storeURL: URL
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: PulseSchema.self)
        let directoryURL = storeURL.deletingLastPathComponent()
        try PulseStoreProtection.enforce(in: directoryURL)
        let configuration = ModelConfiguration(
            storeName,
            schema: schema,
            url: storeURL
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        try PulseStoreProtection.enforce(in: directoryURL)
        return container
    }

    public static func makeInMemoryContainer(
        storeName: String = PulseStoreContract.storeName
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: PulseSchema.self)
        let configuration = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

public enum PulseStoreProtection {
    public static let fileProtectionType = FileProtectionType.completeUntilFirstUserAuthentication

    public static func enforce(
        in directoryURL: URL,
        fileManager: FileManager = .default
    ) throws {
        try enforce(
            in: directoryURL,
            fileManager: fileManager,
            attributeApplier: { attributes, path in
                try fileManager.setAttributes(attributes, ofItemAtPath: path)
            }
        )
    }

    static func enforce(
        in directoryURL: URL,
        fileManager: FileManager,
        attributeApplier: ([FileAttributeKey: Any], String) throws -> Void
    ) throws {
        try fileManager.createDirectory(
            at: directoryURL,
                withIntermediateDirectories: true
            )
        try applyProtection(to: directoryURL, attributeApplier: attributeApplier)

        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: [.skipsSubdirectoryDescendants]
        )
        for url in contents {
            let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { continue }
            try applyProtection(to: url, attributeApplier: attributeApplier)
        }
    }

    private static func applyProtection(
        to url: URL,
        attributeApplier: ([FileAttributeKey: Any], String) throws -> Void
    ) throws {
        try attributeApplier(
            [.protectionKey: fileProtectionType],
            url.path
        )
    }
}
