import Foundation
import XCTest

final class DebugBuildIsolationTests: XCTestCase {
    func testDebugAndReleaseUseDistinctRuntimeIdentities() throws {
        let root = projectRoot
        let project = try String(
            contentsOf: root
                .appendingPathComponent("pulse.xcodeproj", isDirectory: true)
                .appendingPathComponent("project.pbxproj"),
            encoding: .utf8
        )

        XCTAssertEqual(project.occurrences(of: "PULSE_APP_GROUP_IDENTIFIER = group.co.fanr.pulse.dev;"), 1)
        XCTAssertEqual(project.occurrences(of: "PULSE_APP_GROUP_IDENTIFIER = group.co.fanr.pulse;"), 1)
        XCTAssertEqual(project.occurrences(of: "PRODUCT_BUNDLE_IDENTIFIER = co.fanr.pulse.dev;"), 1)
        XCTAssertEqual(project.occurrences(of: "PRODUCT_BUNDLE_IDENTIFIER = co.fanr.pulse;"), 1)
        XCTAssertEqual(project.occurrences(of: "PRODUCT_BUNDLE_IDENTIFIER = co.fanr.pulse.dev.widgets;"), 1)
        XCTAssertEqual(project.occurrences(of: "PRODUCT_BUNDLE_IDENTIFIER = co.fanr.pulse.widgets;"), 1)
        XCTAssertEqual(project.occurrences(of: "PULSE_URL_SCHEME = \"pulse-dev\";"), 1)
        XCTAssertEqual(project.occurrences(of: "PULSE_URL_SCHEME = pulse;"), 1)
        XCTAssertEqual(project.occurrences(of: "PULSE_DISPLAY_NAME = \"一日一印 Dev\";"), 1)
        XCTAssertEqual(project.occurrences(of: "PULSE_DISPLAY_NAME = Pulse;"), 1)
        XCTAssertEqual(project.occurrences(of: "EXCLUDED_SOURCE_FILE_NAMES = InfoPlist.xcstrings;"), 1)
    }

    func testRuntimeMetadataUsesBuildSettingsInsteadOfProductionConstants() throws {
        let root = projectRoot
        let appInfo = try source(at: root.appendingPathComponent("Config/Pulse-Info.plist"))
        let widgetInfo = try source(at: root.appendingPathComponent("Config/PulseWidgets-Info.plist"))
        let runtimeIdentity = try source(
            at: root.appendingPathComponent("PulseWidgetUI/PulseRuntimeIdentity.swift")
        )
        let activityContract = try source(
            at: root.appendingPathComponent(
                "PulseCore/Activity/PulseReminderActivityAttributes.swift"
            )
        )

        for info in [appInfo, widgetInfo] {
            XCTAssertTrue(info.contains("$(PULSE_DISPLAY_NAME)"))
            XCTAssertTrue(info.contains("$(PULSE_APP_GROUP_IDENTIFIER)"))
            XCTAssertTrue(info.contains("$(PULSE_URL_SCHEME)"))
        }
        XCTAssertTrue(appInfo.contains("$(PRODUCT_BUNDLE_IDENTIFIER).today"))
        XCTAssertTrue(runtimeIdentity.contains("static var todayDeepLink: URL"))
        XCTAssertFalse(activityContract.contains("pulse://today"))
        XCTAssertFalse(activityContract.contains("static let deepLink"))
    }

    func testActivityLabIsCompiledOnlyForDebugAndUsesRealActivityKit() throws {
        let root = projectRoot
        let debugSource = try source(
            at: root.appendingPathComponent(
                "pulse/Features/Settings/ReminderActivityDebugView.swift"
            )
        )
        let settingsSource = try source(
            at: root.appendingPathComponent("pulse/Features/Settings/SettingsView.swift")
        )

        XCTAssertTrue(debugSource.hasPrefix("#if DEBUG\n"))
        XCTAssertTrue(debugSource.hasSuffix("#endif\n"))
        XCTAssertTrue(debugSource.contains("Activity<PulseReminderActivityAttributes>.request"))
        XCTAssertTrue(debugSource.contains("await model.checkIn()"))
        XCTAssertTrue(debugSource.contains("await activity.end"))
        XCTAssertTrue(debugSource.contains("isIsolatedRuntimeIdentity"))
        XCTAssertTrue(debugSource.contains("身份异常，已禁用全部测试操作"))
        XCTAssertTrue(settingsSource.contains("#if DEBUG\n            developerSection\n#endif"))
        XCTAssertTrue(settingsSource.contains("#if DEBUG\n    private var developerSection"))
    }

    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }
}

private extension String {
    func occurrences(of value: String) -> Int {
        components(separatedBy: value).count - 1
    }
}
