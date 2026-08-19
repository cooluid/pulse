import Foundation
import PulseWatchShared

enum PulseWatchRuntimeError: Error, Equatable {
    case missingAppGroupIdentifier
    case appGroupContainerUnavailable
}

enum PulseWatchRuntimeIdentity {
    static var appGroupIdentifier: String {
        guard let value = Bundle.main.object(
            forInfoDictionaryKey: "PulseAppGroupIdentifier"
        ) as? String,
        value.hasPrefix("group.") else {
            preconditionFailure("PulseAppGroupIdentifier must be configured for Watch targets.")
        }
        return value
    }

    static func makeLocalStore() throws -> PulseWatchLocalStore {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw PulseWatchRuntimeError.appGroupContainerUnavailable
        }
        let directoryURL = containerURL.appendingPathComponent(
            PulseWatchContract.localDirectoryName,
            isDirectory: true
        )
        return try PulseWatchLocalStore(directoryURL: directoryURL)
    }
}
