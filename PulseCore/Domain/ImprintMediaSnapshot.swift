import Foundation

public enum ImprintCameraPosition: String, Codable, Sendable {
    case rear
    case front
}

public struct ImprintMediaSnapshot: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let habitID: UUID
    public let recordID: UUID?
    public let logicalDay: LogicalDay
    public let capturedAt: Date
    public let createdAt: Date
    public let modifiedAt: Date
    public let originalRelativePath: String
    public let thumbnailRelativePath: String
    public let mediaType: String
    public let byteCount: Int64
    public let thumbnailByteCount: Int64
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let sha256: String
    public let thumbnailSHA256: String
    public let cameraPosition: ImprintCameraPosition

    public init(
        id: UUID,
        habitID: UUID,
        recordID: UUID?,
        logicalDay: LogicalDay,
        capturedAt: Date,
        createdAt: Date,
        modifiedAt: Date,
        originalRelativePath: String,
        thumbnailRelativePath: String,
        mediaType: String,
        byteCount: Int64,
        thumbnailByteCount: Int64,
        pixelWidth: Int,
        pixelHeight: Int,
        sha256: String,
        thumbnailSHA256: String,
        cameraPosition: ImprintCameraPosition
    ) {
        self.id = id
        self.habitID = habitID
        self.recordID = recordID
        self.logicalDay = logicalDay
        self.capturedAt = capturedAt
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.originalRelativePath = originalRelativePath
        self.thumbnailRelativePath = thumbnailRelativePath
        self.mediaType = mediaType
        self.byteCount = byteCount
        self.thumbnailByteCount = thumbnailByteCount
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.sha256 = sha256
        self.thumbnailSHA256 = thumbnailSHA256
        self.cameraPosition = cameraPosition
    }
}

public struct ImprintMediaDraft: Equatable, Sendable {
    public let id: UUID
    public let habitID: UUID
    public let recordID: UUID?
    public let logicalDay: LogicalDay
    public let capturedAt: Date
    public let createdAt: Date
    public let originalRelativePath: String
    public let thumbnailRelativePath: String
    public let byteCount: Int64
    public let thumbnailByteCount: Int64
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let sha256: String
    public let thumbnailSHA256: String
    public let cameraPosition: ImprintCameraPosition

    public init(
        id: UUID = UUID(),
        habitID: UUID,
        recordID: UUID?,
        logicalDay: LogicalDay,
        capturedAt: Date,
        createdAt: Date,
        originalRelativePath: String,
        thumbnailRelativePath: String,
        byteCount: Int64,
        thumbnailByteCount: Int64,
        pixelWidth: Int,
        pixelHeight: Int,
        sha256: String,
        thumbnailSHA256: String,
        cameraPosition: ImprintCameraPosition
    ) {
        self.id = id
        self.habitID = habitID
        self.recordID = recordID
        self.logicalDay = logicalDay
        self.capturedAt = capturedAt
        self.createdAt = createdAt
        self.originalRelativePath = originalRelativePath
        self.thumbnailRelativePath = thumbnailRelativePath
        self.byteCount = byteCount
        self.thumbnailByteCount = thumbnailByteCount
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.sha256 = sha256
        self.thumbnailSHA256 = thumbnailSHA256
        self.cameraPosition = cameraPosition
    }
}
