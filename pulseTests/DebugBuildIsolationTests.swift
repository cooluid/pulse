import Foundation
import XCTest

final class DebugBuildIsolationTests: XCTestCase {
    func testProductDeclaresTheSingleSceneRuntimeItActuallySupports() throws {
        let infoURL = projectRoot.appendingPathComponent("Config/Pulse-Info.plist")
        let data = try Data(contentsOf: infoURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let sceneManifest = try XCTUnwrap(
            plist["UIApplicationSceneManifest"] as? [String: Any]
        )

        XCTAssertEqual(sceneManifest["UIApplicationSupportsMultipleScenes"] as? Bool, false)
    }

    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
