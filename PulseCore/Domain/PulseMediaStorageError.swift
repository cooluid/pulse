import Foundation

public enum PulseMediaVerificationFailure: String, Equatable, Sendable {
    case fileUnavailable
    case identityMismatch
}

public enum PulseMediaStorageError: Error, Equatable, Sendable {
    case invalidInput
    case storageUnavailable
    case fileUnavailable
    case identityMismatch
    case precommitVerificationFailed(PulseMediaVerificationFailure)

    public var diagnosticCode: String {
        switch self {
        case .invalidInput:
            "media.input.invalid"
        case .storageUnavailable:
            "media.storage.unavailable"
        case .fileUnavailable:
            "media.committed.file_unavailable"
        case .identityMismatch:
            "media.committed.identity_mismatch"
        case .precommitVerificationFailed(.fileUnavailable):
            "media.precommit.file_unavailable"
        case .precommitVerificationFailed(.identityMismatch):
            "media.precommit.identity_mismatch"
        }
    }
}
