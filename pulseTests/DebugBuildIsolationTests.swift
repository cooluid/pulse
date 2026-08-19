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

        XCTAssertEqual(project.occurrences(of: "PULSE_APP_GROUP_IDENTIFIER = group.co.fanr.pulse.dev;"), 3)
        XCTAssertEqual(project.occurrences(of: "PULSE_APP_GROUP_IDENTIFIER = group.co.fanr.pulse;"), 3)
        XCTAssertEqual(project.occurrences(of: "PRODUCT_BUNDLE_IDENTIFIER = co.fanr.pulse.dev;"), 1)
        XCTAssertEqual(project.occurrences(of: "PRODUCT_BUNDLE_IDENTIFIER = co.fanr.pulse;"), 1)
        XCTAssertEqual(project.occurrences(of: "PRODUCT_BUNDLE_IDENTIFIER = co.fanr.pulse.dev.widgets;"), 1)
        XCTAssertEqual(project.occurrences(of: "PRODUCT_BUNDLE_IDENTIFIER = co.fanr.pulse.widgets;"), 1)
        XCTAssertEqual(
            project.occurrences(of: "PRODUCT_BUNDLE_IDENTIFIER = co.fanr.pulse.dev.watchkitapp;"),
            1
        )
        XCTAssertEqual(
            project.occurrences(of: "PRODUCT_BUNDLE_IDENTIFIER = co.fanr.pulse.watchkitapp;"),
            1
        )
        XCTAssertEqual(
            project.occurrences(
                of: "PRODUCT_BUNDLE_IDENTIFIER = co.fanr.pulse.dev.watchkitapp.widgets;"
            ),
            1
        )
        XCTAssertEqual(
            project.occurrences(of: "PRODUCT_BUNDLE_IDENTIFIER = co.fanr.pulse.watchkitapp.widgets;"),
            1
        )
        XCTAssertEqual(project.occurrences(of: "PULSE_URL_SCHEME = \"pulse-dev\";"), 1)
        XCTAssertEqual(project.occurrences(of: "PULSE_URL_SCHEME = pulse;"), 1)
        XCTAssertEqual(project.occurrences(of: "PULSE_DISPLAY_NAME = \"一日一印 Dev\";"), 3)
        XCTAssertEqual(project.occurrences(of: "PULSE_DISPLAY_NAME = Pulse;"), 1)
        XCTAssertEqual(project.occurrences(of: "EXCLUDED_SOURCE_FILE_NAMES = InfoPlist.xcstrings;"), 1)
    }

    func testWatchTargetsUseFormalCompanionAndSharedRuntimeIdentities() throws {
        let root = projectRoot
        let project = try source(
            at: root
                .appendingPathComponent("pulse.xcodeproj", isDirectory: true)
                .appendingPathComponent("project.pbxproj")
        )
        let watchWidgetInfo = try source(
            at: root.appendingPathComponent("Config/PulseWatchWidgets-Info.plist")
        )

        XCTAssertTrue(project.contains("name = PulseWatch;"))
        XCTAssertTrue(project.contains("name = PulseWatchWidgetsExtension;"))
        XCTAssertTrue(project.contains("name = PulseWatchShared;"))
        XCTAssertTrue(project.contains("PULSE_COMPANION_BUNDLE_IDENTIFIER = co.fanr.pulse;"))
        XCTAssertTrue(project.contains("WATCHOS_DEPLOYMENT_TARGET = 10.0;"))
        XCTAssertTrue(watchWidgetInfo.contains("$(PULSE_APP_GROUP_IDENTIFIER)"))
        let watchInfo = try source(
            at: root.appendingPathComponent("Config/PulseWatch-Info.plist")
        )
        XCTAssertTrue(watchInfo.contains("$(PULSE_APP_GROUP_IDENTIFIER)"))
        XCTAssertTrue(watchInfo.contains("$(PULSE_COMPANION_BUNDLE_IDENTIFIER)"))
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
        XCTAssertTrue(
            settingsSource.contains(
                "#if DEBUG\n            developerSection.pulseFormRows(for: visualTheme)\n#endif"
            )
        )
        XCTAssertTrue(settingsSource.contains("#if DEBUG\n    private var developerSection"))
    }

    func testUITestRuntimeUsesAnIsolatedStoreAndDeterministicSystemDependencies() throws {
        let root = projectRoot
        let appSource = try source(at: root.appendingPathComponent("pulse/App/PulseApp.swift"))
        let modelSource = try source(
            at: root.appendingPathComponent("pulse/App/PulseAppModel.swift")
        )

        XCTAssertTrue(appSource.contains("PULSE_UI_TEST_STORE_ID"))
        XCTAssertTrue(appSource.contains("PulseUITestReminderScheduler"))
        XCTAssertTrue(appSource.contains("UITestStoreKitAccessClient"))
        XCTAssertFalse(modelSource.contains("PULSE_UI_TEST_RESET"))
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
