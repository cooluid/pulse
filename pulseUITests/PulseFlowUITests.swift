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

    private func launchAndConfirmDefaultCommitment() {
        app.launch()

        let saveButton = app.buttons["commitment.save.button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        XCTAssertTrue(app.buttons["today.checkin.button"].waitForExistence(timeout: 5))
    }

    func testCheckInPersistsAcrossRelaunchAndAppearsInHistory() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        let checkInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(checkInButton.waitForExistence(timeout: 5))
        XCTAssertTrue(checkInButton.isEnabled)

        let weekRail = app.otherElements["today.week.rail"]
        XCTAssertTrue(weekRail.waitForExistence(timeout: 3))
        assertWeekRailDoesNotOverlapCheckIn()
        assertWeekRailGeometry()
        assertObsoleteTodayDesignIsAbsent()
        assertHeroGeometry()
        assertRhythmStatusFollowsWeekRail()
        assertRhythmStatus(equals: "从今天开始")

        let pendingAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        pendingAttachment.name = "Today before check-in"
        pendingAttachment.lifetime = .keepAlways
        add(pendingAttachment)

        checkInButton.tap()

        XCTAssertFalse(checkInButton.isEnabled)
        XCTAssertTrue(checkInButton.label.contains("已签到"))
        assertRhythmStatus(equals: "连续 1 天")
        assertWeekRailGeometry()
        assertObsoleteTodayDesignIsAbsent()
        assertHeroGeometry()
        assertRhythmStatusFollowsWeekRail()

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "PULSE_UI_TEST_RESET")
        app.launch()

        let persistedCheckInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(persistedCheckInButton.waitForExistence(timeout: 5))
        XCTAssertFalse(persistedCheckInButton.isEnabled)
        XCTAssertTrue(persistedCheckInButton.label.contains("已签到"))
        assertRhythmStatus(equals: "连续 1 天")
        assertObsoleteTodayDesignIsAbsent()
        assertHeroGeometry()
        assertRhythmStatusFollowsWeekRail()

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
        launchAndConfirmDefaultCommitment()

        let settingsButton = app.buttons["settings.navigation.open.today"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let settingsNavigationBar = app.navigationBars["设置"]
        XCTAssertTrue(settingsNavigationBar.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["正在同步提醒计划"].exists)
        XCTAssertFalse(app.buttons["primary.navigation.today"].exists)
        XCTAssertFalse(app.buttons["primary.navigation.history"].exists)
        XCTAssertFalse(app.staticTexts["today.day.number"].exists)
        XCTAssertFalse(app.otherElements["today.week.rail"].exists)
        XCTAssertFalse(app.otherElements["today.rhythm.summary"].exists)

        let settingsAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        settingsAttachment.name = "Settings without primary navigation"
        settingsAttachment.lifetime = .keepAlways
        add(settingsAttachment)

        let backButton = app.buttons["navigation.back"]
        XCTAssertTrue(backButton.exists)
        XCTAssertEqual(backButton.label, "返回")
        backButton.tap()

        XCTAssertTrue(app.buttons["primary.navigation.today"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["primary.navigation.history"].exists)
    }

    func testSettingsExposesPrivacyAndSupportLinks() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        let settingsButton = app.buttons["settings.navigation.open.today"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let privacyLink = app.descendants(matching: .any)["settings.privacy_policy.link"]
        for _ in 0..<4 where !privacyLink.exists {
            app.swipeUp()
        }

        XCTAssertTrue(privacyLink.waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["settings.support.link"].exists)
    }

    func testResetConfirmationIsPresentedFromTheResetRow() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        let settingsButton = app.buttons["settings.navigation.open.today"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let resetButton = app.buttons["settings.reset.button"]
        for _ in 0..<6 where !resetButton.exists {
            app.swipeUp()
        }
        XCTAssertTrue(resetButton.waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["settings.data.note"].exists)
        resetButton.tap()

        let confirmButton = app.buttons
            .matching(identifier: "settings.reset.confirm.button")
            .firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))
        confirmButton.tap()

        XCTAssertTrue(app.textFields["commitment.name.field"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["primary.navigation.today"].exists)
    }

    func testThemeAndLanguageChoicesApplyImmediatelyAndPersistAcrossRelaunch() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

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
        let englishBackButton = app.buttons["navigation.back"]
        XCTAssertTrue(englishBackButton.waitForExistence(timeout: 3))
        XCTAssertEqual(englishBackButton.label, "Back")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label == %@", "返回")).firstMatch.exists)

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
        XCTAssertEqual(app.buttons["navigation.back"].label, "Back")
    }

    func testChineseHistoryUsesLocalizedArchiveHeading() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        let historyNavigation = app.buttons["primary.navigation.history"]
        XCTAssertTrue(historyNavigation.waitForExistence(timeout: 3))
        historyNavigation.tap()

        let localizedHeading = app.staticTexts
            .matching(NSPredicate(format: "label == %@", "记录 / 2026"))
            .firstMatch
        XCTAssertTrue(localizedHeading.waitForExistence(timeout: 3))
        XCTAssertFalse(
            app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS %@", "ARCHIVE"))
                .firstMatch
                .exists
        )
    }

    func testAllWidgetStylesAreSelectableAndPersistAcrossRelaunch() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        let settingsButton = app.buttons["settings.navigation.open.today"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let stylePicker = app.descendants(matching: .any)["settings.widget.style.picker"]
        for _ in 0..<4 where !stylePicker.exists {
            app.swipeUp()
        }
        XCTAssertTrue(stylePicker.waitForExistence(timeout: 3))
        stylePicker.tap()

        let styleNames = ["断层双色", "越界巨环", "承诺宣言", "错版撕页"]
        for styleName in styleNames {
            let option = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", styleName))
                .firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 3))
        }

        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "错版撕页"))
            .firstMatch
            .tap()
        XCTAssertTrue(stylePicker.label.contains("错版撕页"))

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "PULSE_UI_TEST_RESET")
        app.launch()

        let persistedSettingsButton = app.buttons["settings.navigation.open.today"]
        XCTAssertTrue(persistedSettingsButton.waitForExistence(timeout: 5))
        persistedSettingsButton.tap()

        let persistedStylePicker = app.descendants(matching: .any)[
            "settings.widget.style.picker"
        ]
        for _ in 0..<4 where !persistedStylePicker.exists {
            app.swipeUp()
        }
        XCTAssertTrue(persistedStylePicker.waitForExistence(timeout: 3))
        XCTAssertTrue(persistedStylePicker.label.contains("错版撕页"))
    }

    func testRecordDetailUsesSheetDismissalAndSourceAnchoredDeleteConfirmation() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

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
        launchAndConfirmDefaultCommitment()

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

        let rhythmStatus = app.staticTexts["today.rhythm.status"]
        XCTAssertTrue(rhythmStatus.exists)
        checkInButton.swipeUp()
        app.swipeUp()
        XCTAssertTrue(rhythmStatus.isHittable)
        XCTAssertLessThanOrEqual(rhythmStatus.frame.maxY, todayNavigation.frame.minY)
    }

    func testHistoryExposesBidirectionalMonthNavigation() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        let historyNavigation = app.buttons["primary.navigation.history"]
        XCTAssertTrue(historyNavigation.waitForExistence(timeout: 5))
        historyNavigation.tap()

        let heading = app.descendants(matching: .any)["history.month.heading"]
        let previousMonth = app.buttons["history.month.previous"]
        let nextMonth = app.buttons["history.month.next"]
        XCTAssertTrue(heading.waitForExistence(timeout: 3))
        XCTAssertTrue(heading.label.contains("八月"))
        XCTAssertTrue(heading.label.contains("记录 / 2026"))
        XCTAssertFalse(heading.label.contains("ARCHIVE"))
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
        launchAndConfirmDefaultCommitment()
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

    func testCommitmentMustBeConfirmedAndPersistsAcrossRelaunch() throws {
        configureApp()
        app.launch()

        XCTAssertFalse(app.buttons["today.checkin.button"].exists)
        XCTAssertFalse(app.buttons["primary.navigation.today"].exists)

        let nameField = app.textFields["commitment.name.field"]
        let purposeField = app.textFields["commitment.purpose.field"]
        let saveButton = app.buttons["commitment.save.button"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        XCTAssertTrue(purposeField.exists)
        XCTAssertTrue(saveButton.isEnabled)

        let longCommitment = "每日签到，严于律己，坚持，改变，蜕变，积极，心态"
        replaceText(in: nameField, with: longCommitment)
        nameField.typeText(XCUIKeyboardKey.return.rawValue)
        XCTAssertTrue(purposeField.waitForExistence(timeout: 3))
        purposeField.typeText("保持思考")
        purposeField.typeText(XCUIKeyboardKey.return.rawValue)
        saveButton.tap()

        XCTAssertTrue(app.buttons["today.checkin.button"].waitForExistence(timeout: 5))
        let commitmentCue = app.descendants(matching: .any)["today.commitment.name"]
        XCTAssertTrue(commitmentCue.waitForExistence(timeout: 3))
        XCTAssertTrue(commitmentCue.label.contains(longCommitment))
        XCTAssertTrue(app.buttons["today.checkin.button"].label.contains(longCommitment))
        XCTAssertFalse(app.staticTexts["today.commitment.purpose"].exists)
        assertHeroGeometry()
        assertRhythmStatusFollowsWeekRail()

        let longCommitmentAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        longCommitmentAttachment.name = "Today with long commitment cue"
        longCommitmentAttachment.lifetime = .keepAlways
        add(longCommitmentAttachment)

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "PULSE_UI_TEST_RESET")
        app.launch()

        XCTAssertTrue(app.buttons["today.checkin.button"].waitForExistence(timeout: 5))
        XCTAssertTrue(commitmentCue.waitForExistence(timeout: 3))
        XCTAssertTrue(commitmentCue.label.contains(longCommitment))
        XCTAssertFalse(app.staticTexts["today.commitment.purpose"].exists)
        XCTAssertFalse(app.buttons["commitment.save.button"].exists)
        assertHeroGeometry()
        assertRhythmStatusFollowsWeekRail()

        openCommitmentEditorFromToday()
        XCTAssertEqual(
            app.textFields["commitment.name.field"].value as? String,
            longCommitment
        )
        XCTAssertEqual(app.textFields["commitment.purpose.field"].value as? String, "保持思考")
    }

    func testCommitmentRejectsBlankAndOversizedNameAtTheUIBoundary() throws {
        configureApp()
        app.launch()

        let nameField = app.textFields["commitment.name.field"]
        let saveButton = app.buttons["commitment.save.button"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))

        replaceText(in: nameField, with: "  ")
        XCTAssertFalse(saveButton.isEnabled)

        replaceText(
            in: nameField,
            with: String(repeating: "a", count: 81)
        )
        XCTAssertFalse(saveButton.isEnabled)

        replaceText(in: nameField, with: "Read")
        XCTAssertTrue(saveButton.isEnabled)
    }

    func testCommitmentCanBeEditedFromSettingsWithoutChangingCheckInFacts() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        let checkInButton = app.buttons["today.checkin.button"]
        checkInButton.tap()
        XCTAssertFalse(checkInButton.isEnabled)

        app.buttons["settings.navigation.open.today"].tap()
        let commitmentLink = app.descendants(matching: .any)["settings.commitment.link"]
        XCTAssertTrue(commitmentLink.waitForExistence(timeout: 3))
        commitmentLink.tap()

        let nameField = app.textFields["commitment.name.field"]
        let purposeField = app.textFields["commitment.purpose.field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText(" · 深度工作")
        nameField.typeText(XCUIKeyboardKey.return.rawValue)
        XCTAssertTrue(purposeField.waitForExistence(timeout: 3))
        purposeField.typeText("把注意力留给重要的事")
        purposeField.typeText(XCUIKeyboardKey.return.rawValue)
        app.buttons["commitment.save.button"].tap()

        let settingsNavigationBar = app.navigationBars["设置"]
        XCTAssertTrue(settingsNavigationBar.waitForExistence(timeout: 3))

        commitmentLink.tap()
        XCTAssertTrue(app.textFields["commitment.name.field"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            (app.textFields["commitment.name.field"].value as? String)?.contains("深度工作")
                == true
        )
        XCTAssertEqual(
            app.textFields["commitment.purpose.field"].value as? String,
            "把注意力留给重要的事"
        )
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(settingsNavigationBar.waitForExistence(timeout: 3))
        settingsNavigationBar.buttons.firstMatch.tap()

        let commitmentCue = app.descendants(matching: .any)["today.commitment.name"]
        XCTAssertTrue(commitmentCue.waitForExistence(timeout: 3))
        XCTAssertTrue(commitmentCue.label.contains("深度工作"))
        XCTAssertFalse(app.staticTexts["today.commitment.purpose"].exists)
        assertHeroGeometry()
        assertRhythmStatusFollowsWeekRail()
        XCTAssertFalse(app.buttons["today.checkin.button"].isEnabled)
    }

    private func assertObsoleteTodayDesignIsAbsent() {
        XCTAssertFalse(app.staticTexts["给今天留下一枚印记"].exists)
        XCTAssertFalse(app.staticTexts["今天已留下一枚印记"].exists)
        XCTAssertFalse(app.staticTexts["写入本机后完成"].exists)
        XCTAssertFalse(app.staticTexts["还没有留下今天的印"].exists)
        XCTAssertFalse(app.staticTexts["CURRENT RHYTHM"].exists)
        XCTAssertFalse(app.staticTexts["保持自己的节奏，不与别人比较"].exists)
        XCTAssertFalse(app.staticTexts["today.commitment.purpose"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["today.streak.band"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["today.rhythm.commitment"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["today.rhythm.summary"].exists)
        XCTAssertEqual(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "写入本机")
            ).count,
            0
        )
    }

    private func replaceText(in field: XCUIElement, with replacement: String) {
        field.tap()
        if let currentValue = field.value as? String, !currentValue.isEmpty {
            field.typeText(
                String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            )
        }
        field.typeText(replacement)
    }

    private func assertWeekRailGeometry() {
        let today = app.descendants(matching: .any)["today.week.day.2026-08-10"]
        let previousDay = app.descendants(matching: .any)["today.week.day.2026-08-09"]
        XCTAssertTrue(today.waitForExistence(timeout: 3))
        XCTAssertTrue(previousDay.waitForExistence(timeout: 3))
        XCTAssertEqual(today.frame.minY, previousDay.frame.minY, accuracy: 1)
        XCTAssertEqual(today.frame.maxY, previousDay.frame.maxY, accuracy: 1)
    }

    private func assertWeekRailDoesNotOverlapCheckIn() {
        let weekRail = app.otherElements["today.week.rail"]
        let checkInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(weekRail.exists)
        XCTAssertTrue(checkInButton.exists)

        let isVerticallyAfter = weekRail.frame.minY >= checkInButton.frame.maxY
        let isHorizontallySeparate = weekRail.frame.maxX <= checkInButton.frame.minX
            || weekRail.frame.minX >= checkInButton.frame.maxX
        XCTAssertTrue(
            isVerticallyAfter || isHorizontallySeparate,
            "The week rail must follow or sit beside the check-in control without overlap."
        )
    }

    private func assertHeroGeometry() {
        let dayNumber = app.staticTexts["today.day.number"]
        let kicker = app.staticTexts["today.hero.kicker"]
        let commitmentCue = app.descendants(matching: .any)["today.commitment.name"]
        let checkInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(dayNumber.exists)
        XCTAssertTrue(kicker.exists)
        XCTAssertTrue(commitmentCue.waitForExistence(timeout: 3))
        XCTAssertTrue(checkInButton.exists)
        XCTAssertTrue(kicker.label.contains("星期"))
        XCTAssertEqual(dayNumber.frame.midX, kicker.frame.midX, accuracy: 1)
        XCTAssertEqual(dayNumber.frame.midX, commitmentCue.frame.midX, accuracy: 1)
        XCTAssertLessThan(kicker.frame.maxY, dayNumber.frame.minY)
        XCTAssertLessThanOrEqual(dayNumber.frame.maxY, commitmentCue.frame.minY)
        XCTAssertLessThanOrEqual(commitmentCue.frame.maxY, checkInButton.frame.minY)
    }

    private func assertRhythmStatusFollowsWeekRail() {
        let weekRail = app.otherElements["today.week.rail"]
        let rhythmStatus = app.staticTexts["today.rhythm.status"]
        XCTAssertTrue(weekRail.exists)
        XCTAssertTrue(rhythmStatus.exists)
        XCTAssertEqual(rhythmStatus.frame.midX, weekRail.frame.midX, accuracy: 1)
        XCTAssertGreaterThanOrEqual(rhythmStatus.frame.minY, weekRail.frame.maxY)
    }

    private func assertRhythmStatus(equals expectedStatus: String) {
        let rhythmStatus = app.staticTexts["today.rhythm.status"]
        XCTAssertTrue(rhythmStatus.waitForExistence(timeout: 3))
        let expectedLabel = NSPredicate(format: "label == %@", expectedStatus)
        expectation(for: expectedLabel, evaluatedWith: rhythmStatus)
        waitForExpectations(timeout: 3)
    }

    private func openCommitmentEditorFromToday() {
        let settingsButton = app.buttons["settings.navigation.open.today"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()

        let commitmentLink = app.descendants(matching: .any)["settings.commitment.link"]
        XCTAssertTrue(commitmentLink.waitForExistence(timeout: 3))
        commitmentLink.tap()
        XCTAssertTrue(app.textFields["commitment.purpose.field"].waitForExistence(timeout: 3))
    }
}
