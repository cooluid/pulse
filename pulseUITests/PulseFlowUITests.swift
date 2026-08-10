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

    func testResetConfirmationIsPresentedFromTheResetRow() throws {
        configureApp()
        app.launch()

        let settingsButton = app.buttons["settings.navigation.open.today"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let resetButton = app.buttons["settings.reset.button"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["settings.data.note"].exists)
        resetButton.tap()

        let confirmButton = app.buttons["settings.reset.confirm.button"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))
    }

    func testThemeAndLanguageChoicesApplyImmediatelyAndPersistAcrossRelaunch() throws {
        configureApp()
        app.launch()

        let settingsButton = app.buttons["settings.navigation.open.today"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let languagePicker = app.descendants(matching: .any)["settings.language.picker"]
        XCTAssertTrue(languagePicker.waitForExistence(timeout: 3))
        languagePicker.tap()
        let englishOption = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "English"))
            .firstMatch
        XCTAssertTrue(englishOption.waitForExistence(timeout: 3))
        englishOption.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        let themePicker = app.descendants(matching: .any)["settings.theme.picker"]
        XCTAssertTrue(themePicker.waitForExistence(timeout: 3))
        themePicker.tap()
        let darkOption = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Dark"))
            .firstMatch
        XCTAssertTrue(darkOption.waitForExistence(timeout: 3))
        darkOption.tap()
        let darkThemeApplied = NSPredicate(format: "label CONTAINS %@", "Dark")
        expectation(for: darkThemeApplied, evaluatedWith: themePicker)
        waitForExpectations(timeout: 3)

        let darkEnglishAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        darkEnglishAttachment.name = "Settings in English with dark theme"
        darkEnglishAttachment.lifetime = .keepAlways
        add(darkEnglishAttachment)

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "PULSE_UI_TEST_RESET")
        app.launch()

        let persistedSettingsButton = app.buttons["settings.navigation.open.today"]
        XCTAssertTrue(persistedSettingsButton.waitForExistence(timeout: 5))
        persistedSettingsButton.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))

        let persistedLanguagePicker = app.descendants(matching: .any)["settings.language.picker"]
        let persistedThemePicker = app.descendants(matching: .any)["settings.theme.picker"]
        XCTAssertTrue(persistedLanguagePicker.waitForExistence(timeout: 3))
        XCTAssertTrue(persistedThemePicker.waitForExistence(timeout: 3))
        XCTAssertTrue(persistedLanguagePicker.label.contains("English"))
        XCTAssertTrue(persistedThemePicker.label.contains("Dark"))
    }

    func testRecordDetailUsesSheetDismissalAndSourceAnchoredDeleteConfirmation() throws {
        configureApp()
        app.launch()

        let checkInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(checkInButton.waitForExistence(timeout: 5))
        checkInButton.tap()

        let historyNavigation = app.buttons["primary.navigation.history"]
        XCTAssertTrue(historyNavigation.waitForExistence(timeout: 3))
        historyNavigation.tap()

        let checkedDay = app.descendants(matching: .any)["calendar.day.2026-08-10"]
        XCTAssertTrue(checkedDay.waitForExistence(timeout: 3))
        checkedDay.tap()

        let deleteButton = app.descendants(matching: .any)["history.record.delete.button"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["完成"].exists)
        deleteButton.tap()

        XCTAssertTrue(
            app.buttons["history.record.delete.confirm.button"].waitForExistence(timeout: 3)
        )
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
        XCTAssertFalse(app.staticTexts["还没有留下今天的印"].exists)
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
