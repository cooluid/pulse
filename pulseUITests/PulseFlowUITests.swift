import XCTest

@MainActor
final class PulseFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    private func configureApp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launchEnvironment["PULSE_UI_TEST_RESET"] = "1"
        app.launchEnvironment["PULSE_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["PULSE_UI_TEST_NOW"] = "2026-08-10T04:00:00Z"
    }

    func testCheckInPersistsAcrossRelaunchAndAppearsInHistory() throws {
        configureApp()
        app.launch()

        let checkInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(checkInButton.waitForExistence(timeout: 5))
        XCTAssertTrue(checkInButton.isEnabled)

        let weekRail = app.otherElements["today.week.rail"]
        XCTAssertTrue(weekRail.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(weekRail.frame.minY, checkInButton.frame.maxY)
        assertWeekRailGeometry()
        assertRemovedTodayCopyIsAbsent()
        assertHeroGeometry()

        let pendingAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        pendingAttachment.name = "Today before check-in"
        pendingAttachment.lifetime = .keepAlways
        add(pendingAttachment)

        checkInButton.tap()

        XCTAssertFalse(checkInButton.isEnabled)
        XCTAssertTrue(checkInButton.label.contains("已签到"))
        assertWeekRailGeometry()
        assertRemovedTodayCopyIsAbsent()
        assertHeroGeometry()

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "PULSE_UI_TEST_RESET")
        app.launch()

        let persistedCheckInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(persistedCheckInButton.waitForExistence(timeout: 5))
        XCTAssertFalse(persistedCheckInButton.isEnabled)
        XCTAssertTrue(persistedCheckInButton.label.contains("已签到"))
        assertRemovedTodayCopyIsAbsent()
        assertHeroGeometry()

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

    func testSettingsHidesPrimaryNavigationUntilClosed() throws {
        configureApp()
        app.launch()

        let settingsButton = app.buttons["settings.navigation.open.today"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let settingsNavigationBar = app.navigationBars["设置"]
        XCTAssertTrue(settingsNavigationBar.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["primary.navigation.today"].exists)
        XCTAssertFalse(app.buttons["primary.navigation.history"].exists)
        XCTAssertFalse(app.staticTexts["today.day.number"].exists)
        XCTAssertFalse(app.otherElements["today.week.rail"].exists)
        XCTAssertFalse(app.otherElements["today.streak.band"].exists)

        let settingsAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        settingsAttachment.name = "Settings without primary navigation"
        settingsAttachment.lifetime = .keepAlways
        add(settingsAttachment)

        settingsNavigationBar.buttons.firstMatch.tap()

        XCTAssertTrue(app.buttons["primary.navigation.today"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["primary.navigation.history"].exists)
    }

    func testAccessibilityXXXLUsesExpandableCheckInControl() throws {
        configureApp()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let checkInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(checkInButton.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(checkInButton.frame.width, checkInButton.frame.height)
        XCTAssertGreaterThanOrEqual(checkInButton.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(checkInButton.frame.maxX, app.frame.maxX)
        XCTAssertTrue(app.staticTexts["today.day.number"].exists)

        let settingsButton = app.buttons["settings.navigation.open.today"]
        XCTAssertTrue(settingsButton.exists)

        let todayNavigation = app.buttons["primary.navigation.today"]
        let historyNavigation = app.buttons["primary.navigation.history"]
        XCTAssertTrue(todayNavigation.waitForExistence(timeout: 3))
        XCTAssertTrue(historyNavigation.exists)
        XCTAssertEqual(todayNavigation.frame.width, historyNavigation.frame.width, accuracy: 2)
        XCTAssertEqual(todayNavigation.frame.height, historyNavigation.frame.height, accuracy: 2)
        XCTAssertGreaterThanOrEqual(todayNavigation.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(historyNavigation.frame.maxX, app.frame.maxX)
        XCTAssertLessThanOrEqual(todayNavigation.frame.maxY, app.frame.maxY)
        XCTAssertLessThanOrEqual(historyNavigation.frame.maxY, app.frame.maxY)

        let streakBand = app.descendants(matching: .any)["today.streak.band"]
        XCTAssertTrue(streakBand.exists)
        checkInButton.swipeUp()
        app.swipeUp()
        XCTAssertTrue(streakBand.isHittable)
        XCTAssertLessThanOrEqual(streakBand.frame.maxY, todayNavigation.frame.minY)
    }

    func testHistoryExposesBidirectionalMonthNavigation() throws {
        configureApp()
        app.launch()

        let historyNavigation = app.buttons["primary.navigation.history"]
        XCTAssertTrue(historyNavigation.waitForExistence(timeout: 5))
        historyNavigation.tap()

        let heading = app.descendants(matching: .any)["history.month.heading"]
        let previousMonth = app.buttons["history.month.previous"]
        let nextMonth = app.buttons["history.month.next"]
        XCTAssertTrue(heading.waitForExistence(timeout: 3))
        XCTAssertTrue(previousMonth.exists)
        XCTAssertTrue(nextMonth.exists)
        XCTAssertTrue(previousMonth.isEnabled)
        XCTAssertFalse(nextMonth.isEnabled)

        let currentMonthLabel = heading.label
        previousMonth.tap()

        let changedMonth = NSPredicate(format: "label != %@", currentMonthLabel)
        expectation(for: changedMonth, evaluatedWith: heading)
        waitForExpectations(timeout: 3)
        XCTAssertTrue(nextMonth.isEnabled)

        nextMonth.tap()
        let restoredMonth = NSPredicate(format: "label == %@", currentMonthLabel)
        expectation(for: restoredMonth, evaluatedWith: heading)
        waitForExpectations(timeout: 3)
        XCTAssertFalse(nextMonth.isEnabled)
    }

    func testMissedDayUsesExplicitCalendarSemantics() throws {
        configureApp()
        app.launch()
        XCTAssertTrue(app.buttons["today.checkin.button"].waitForExistence(timeout: 5))

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "PULSE_UI_TEST_RESET")
        app.launchEnvironment["PULSE_UI_TEST_NOW"] = "2026-08-11T04:00:00Z"
        app.launch()

        let historyNavigation = app.buttons["primary.navigation.history"]
        XCTAssertTrue(historyNavigation.waitForExistence(timeout: 5))
        historyNavigation.tap()

        let missedDay = app.descendants(matching: .any)["calendar.day.2026-08-10"]
        XCTAssertTrue(missedDay.waitForExistence(timeout: 3))
        XCTAssertTrue(missedDay.label.contains("漏签"))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "History with explicit missed-day mark"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertRemovedTodayCopyIsAbsent() {
        XCTAssertFalse(app.staticTexts["给今天留下一枚印记"].exists)
        XCTAssertFalse(app.staticTexts["今天已留下一枚印记"].exists)
        XCTAssertFalse(app.staticTexts["写入本机后完成"].exists)
        XCTAssertEqual(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "写入本机")
            ).count,
            0
        )
    }

    private func assertWeekRailGeometry() {
        let today = app.descendants(matching: .any)["today.week.day.2026-08-10"]
        let previousDay = app.descendants(matching: .any)["today.week.day.2026-08-09"]
        XCTAssertTrue(today.waitForExistence(timeout: 3))
        XCTAssertTrue(previousDay.waitForExistence(timeout: 3))
        XCTAssertEqual(today.frame.minY, previousDay.frame.minY, accuracy: 1)
        XCTAssertEqual(today.frame.maxY, previousDay.frame.maxY, accuracy: 1)
    }

    private func assertHeroGeometry() {
        let dayNumber = app.staticTexts["today.day.number"]
        let kicker = app.staticTexts["today.hero.kicker"]
        XCTAssertTrue(dayNumber.exists)
        XCTAssertTrue(kicker.exists)
        XCTAssertTrue(kicker.label.contains("星期"))
        XCTAssertEqual(dayNumber.frame.midX, app.frame.midX, accuracy: 1)
        XCTAssertLessThan(kicker.frame.maxY, dayNumber.frame.minY)
    }
}
