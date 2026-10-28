import Foundation
import XCTest

@testable import pulse

@MainActor
final class ImprintRitualContractTests: XCTestCase {
    func testEraseAllDisclosureNamesEveryDeletedUserFact() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalog = try String(
            contentsOf: repositoryRoot.appending(path: "pulse/Localizable.xcstrings"),
            encoding: .utf8
        )

        XCTAssertTrue(
            catalog.contains(
                "All check-ins, daily notes, photos, preferences, and Pulse reminder plans will be removed."
            ))
        XCTAssertTrue(
            catalog.contains(
                "所有签到、每日记事、照片、偏好设置和一日一印创建的提醒计划都会被删除"
            ))
    }
}
