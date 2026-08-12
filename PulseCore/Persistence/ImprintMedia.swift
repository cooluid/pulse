import Foundation
import SwiftData

typealias ImprintMedia = PulseSchema.ImprintMedia

enum ImprintMediaKey {
    static func make(habitID: UUID, logicalDay: LogicalDay) -> String {
        "\(habitID.uuidString.lowercased())|\(logicalDay.storageValue)"
    }
}

extension PulseSchema {
    @Model
    final class ImprintMedia {
        @Attribute(.unique) var id: UUID
        @Attribute(.unique) var mediaKey: String
        var habitID: UUID
        var recordID: UUID?
        var logicalDayValue: String
        var capturedAt: Date
        var createdAt: Date
        var modifiedAt: Date
        var originalRelativePath: String
        var thumbnailRelativePath: String
        var mediaType: String
        var byteCount: Int64
        var thumbnailByteCount: Int64
        var pixelWidth: Int
        var pixelHeight: Int
        var sha256: String
        var thumbnailSHA256: String
        var cameraPositionValue: String

        init(draft: ImprintMediaDraft, modifiedAt: Date) {
            id = draft.id
            mediaKey = ImprintMediaKey.make(
                habitID: draft.habitID,
                logicalDay: draft.logicalDay
            )
            habitID = draft.habitID
            recordID = draft.recordID
            logicalDayValue = draft.logicalDay.storageValue
            capturedAt = draft.capturedAt
            createdAt = draft.createdAt
            self.modifiedAt = modifiedAt
            originalRelativePath = draft.originalRelativePath
            thumbnailRelativePath = draft.thumbnailRelativePath
            mediaType = "image/jpeg"
            byteCount = draft.byteCount
            thumbnailByteCount = draft.thumbnailByteCount
            pixelWidth = draft.pixelWidth
            pixelHeight = draft.pixelHeight
            sha256 = draft.sha256
            thumbnailSHA256 = draft.thumbnailSHA256
            cameraPositionValue = draft.cameraPosition.rawValue
        }

        var logicalDay: LogicalDay? { LogicalDay(storageValue: logicalDayValue) }
        var cameraPosition: ImprintCameraPosition? {
            ImprintCameraPosition(rawValue: cameraPositionValue)
        }
    }
}
