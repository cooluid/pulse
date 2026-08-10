import XCTest
@testable import pulse

final class PulseExportDocumentTests: XCTestCase {
    func testJSONRoundTripPreservesContractFields() throws {
        let habitID = UUID()
        let recordID = UUID()
        let date = Date(timeIntervalSince1970: 1_786_320_000)
        let payload = PulseExportPayload(
            schemaVersion: PulseDataContract.exportSchemaVersion,
            exportedAt: date,
            habit: .init(
                id: habitID,
                name: "Daily",
                createdAt: date,
                timeZoneIdentifier: "Asia/Shanghai",
                dayStartMinutes: 0
            ),
            records: [
                .init(
                    id: recordID,
                    logicalDay: "2026-08-10",
                    checkedAt: date,
                    createdAt: date,
                    source: CheckInSource.manual.rawValue
                )
            ]
        )

        let data = try PulseExportDocument.encode(payload)
        let decoded = try PulseExportDocument.decode(data)

        XCTAssertEqual(decoded.schemaVersion, PulseDataContract.exportSchemaVersion)
        XCTAssertEqual(decoded.habit.id, habitID)
        XCTAssertEqual(decoded.habit.timeZoneIdentifier, "Asia/Shanghai")
        XCTAssertEqual(decoded.records.map(\.id), [recordID])
        XCTAssertEqual(decoded.records.map(\.logicalDay), ["2026-08-10"])
    }
}

