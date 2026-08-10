import XCTest

final class PulseFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["PULSE_UI_TEST_RESET"] = "1"
    }

    func testCheckInPersistsAcrossRelaunchAndAppearsInHistory() throws {
        app.launch()

        let checkInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(checkInButton.waitForExistence(timeout: 5))
        XCTAssertTrue(checkInButton.isEnabled)

        checkInButton.tap()

        let checkedTime = app.staticTexts["today.checked.time"]
        XCTAssertTrue(checkedTime.waitForExistence(timeout: 3))
        XCTAssertFalse(checkInButton.isEnabled)

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "PULSE_UI_TEST_RESET")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.checked.time"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["today.checkin.button"].isEnabled)

        let todayAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        todayAttachment.name = "Today after persisted check-in"
        todayAttachment.lifetime = .keepAlways
        add(todayAttachment)

        let historyNavigation = app.buttons["primary.navigation.history"]
        XCTAssertTrue(historyNavigation.waitForExistence(timeout: 3))
        historyNavigation.tap()
        let totalStatistic = app.descendants(matching: .any)
            .matching(identifier: "history.stat.total")
            .firstMatch
        XCTAssertTrue(totalStatistic.waitForExistence(timeout: 3))
        XCTAssertTrue(totalStatistic.label.contains("1"))

        let weekdayHeaders = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "calendar.weekday.")
        )
        XCTAssertEqual(weekdayHeaders.count, 7)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "History after first check-in"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
