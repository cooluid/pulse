import XCTest
import UniformTypeIdentifiers
@testable import PulseCore
@testable import pulse

final class PulseExportDocumentTests: XCTestCase {
    func testExportFilenameHasJSONExtension() {
        XCTAssertEqual(
            PulseDataContract.exportFilename(day: "2026-08-11"),
            "pulse-2026-08-11.json"
        )
        XCTAssertEqual(
            PulseDataContract.exportFilename(day: nil),
            "pulse-export.json"
        )
    }

    func testDocumentTypeContractHasOneJSONAuthorityForImportAndExport() {
        XCTAssertEqual(PulseExportDocument.readableContentTypes, [.json])
        XCTAssertEqual(PulseExportDocument.writableContentTypes, [.json])
    }

    func testJSONRoundTripPreservesCompleteV1Contract() throws {
        let habitID = UUID()
        let recordID = UUID()
        let date = Date(timeIntervalSince1970: 1_786_320_000)
        let payload = PulseExportPayload(
            format: PulseDataContract.formatIdentifier,
            schemaVersion: PulseDataContract.exportSchemaVersion,
            exportedAt: date,
            habit: .init(
                id: habitID,
                name: "Daily",
                purpose: "Keep learning",
                isIdentityConfirmed: true,
                createdAt: date,
                startLogicalDay: "2026-08-10",
                creationTimeZoneIdentifier: "Asia/Shanghai",
                timeZoneIdentifier: "Asia/Shanghai"
            ),
            records: [
                .init(
                    id: recordID,
                    logicalDay: "2026-08-10",
                    checkedAt: date,
                    createdAt: date,
                    timeZoneIdentifier: "Asia/Shanghai"
                )
            ]
        )

        let data = try PulseExportDocument.encode(payload)
        let decoded = try PulseExportDocument.decode(data)

        XCTAssertEqual(decoded.format, PulseDataContract.formatIdentifier)
        XCTAssertEqual(decoded.schemaVersion, PulseDataContract.exportSchemaVersion)
        XCTAssertEqual(decoded.habit.id, habitID)
        XCTAssertEqual(decoded.habit.purpose, "Keep learning")
        XCTAssertTrue(decoded.habit.isIdentityConfirmed)
        XCTAssertEqual(decoded.habit.startLogicalDay, "2026-08-10")
        XCTAssertEqual(decoded.habit.creationTimeZoneIdentifier, "Asia/Shanghai")
        XCTAssertEqual(decoded.records.map(\.id), [recordID])
        XCTAssertEqual(decoded.records.map(\.logicalDay), ["2026-08-10"])
        XCTAssertEqual(decoded.records.map(\.timeZoneIdentifier), ["Asia/Shanghai"])
    }

    func testPreReleaseLegacyJSONFailsClosed() {
        let legacyJSON = Data(
            #"{"schemaVersion":1,"exportedAt":"2026-08-10T04:00:00Z","habit":{"id":"53A93055-6F29-48AC-9C6B-BC1E5A0C5F4A","name":"Daily","createdAt":"2026-08-10T04:00:00Z","timeZoneIdentifier":"Asia/Shanghai","dayStartMinutes":0},"records":[]}"#.utf8
        )

        XCTAssertThrowsError(try PulseExportDocument.decode(legacyJSON))
    }

    func testIncompleteV1JSONIsRejectedWithoutCompatibilityUpgrade() {
        let data = Data(
            #"{"format":"co.fanr.pulse.export","schemaVersion":1,"exportedAt":"2026-08-10T04:00:00Z","habit":{"id":"53A93055-6F29-48AC-9C6B-BC1E5A0C5F4A","name":"Daily","createdAt":"2026-08-10T04:00:00Z","startLogicalDay":"2026-08-10","creationTimeZoneIdentifier":"Asia/Shanghai","timeZoneIdentifier":"Asia/Shanghai"},"records":[]}"#.utf8
        )

        XCTAssertThrowsError(try PulseExportDocument.decode(data))
    }

    func testUnsupportedJSONVersionIsRejectedWithoutGuessing() {
        let data = Data(
            #"{"format":"co.fanr.pulse.export","schemaVersion":99}"#.utf8
        )

        XCTAssertThrowsError(try PulseExportDocument.decode(data)) { error in
            XCTAssertEqual(error as? PulseCoreError, .unsupportedImportVersion(99))
        }
    }

    func testImportRejectsCurrentTimeZoneThatPredatesStableStartDay() throws {
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-10T00:30:00Z"))
        let exportedAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-10T01:00:00Z"))
        let payload = PulseExportPayload(
            format: PulseDataContract.formatIdentifier,
            schemaVersion: PulseDataContract.exportSchemaVersion,
            exportedAt: exportedAt,
            habit: .init(
                id: UUID(),
                name: "Daily",
                purpose: nil,
                isIdentityConfirmed: false,
                createdAt: createdAt,
                startLogicalDay: "2026-08-10",
                creationTimeZoneIdentifier: "UTC",
                timeZoneIdentifier: "America/Los_Angeles"
            ),
            records: []
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let hostileData = try encoder.encode(payload)

        XCTAssertThrowsError(try PulseExportCodec.decode(hostileData)) { error in
            XCTAssertEqual(error as? PulseCoreError, .invalidImport)
        }
    }
}
