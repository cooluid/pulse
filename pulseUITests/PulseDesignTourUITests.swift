import XCTest

/// Walks every primary surface once and keeps a screenshot of each for people to look at.
/// Nothing here asserts how a page looks; it only makes sure each page was reached.
@MainActor
final class PulseDesignTourUITests: XCTestCase {
    private var app: XCUIApplication!

    private struct RecordedDay {
        let instant: String
        let note: String?
    }

    func testDesignTourInChinese() throws {
        try runTour(
            language: "zh-Hans",
            locale: "zh_CN",
            habitName: "晚饭后散步",
            notes: ["雨停后出门走了一圈。", "走到桥边再回来。", "看到了傍晚的云。"],
            todayNote: "河边走了二十分钟。"
        )
    }

    func testDesignTourInEnglish() throws {
        try runTour(
            language: "en",
            locale: "en_US",
            habitName: "Evening walk",
            notes: ["Out after the rain.", "To the bridge and back.", "Clouds at dusk."],
            todayNote: "Twenty minutes by the river."
        )
    }

    func testDesignTourInChineseAtLargestText() throws {
        try runTour(
            language: "zh-Hans",
            locale: "zh_CN",
            habitName: "晚饭后散步",
            notes: ["雨停后出门走了一圈。", "走到桥边再回来。", "看到了傍晚的云。"],
            todayNote: "河边走了二十分钟。",
            extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        )
    }

    private func runTour(
        language: String,
        locale: String,
        habitName: String,
        notes: [String],
        todayNote: String,
        extraArguments: [String] = []
    ) throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale] + extraArguments
        app.launchEnvironment["TZ"] = "Asia/Shanghai"
        app.launchEnvironment["PULSE_UI_TEST_RESET"] = "1"
        app.launchEnvironment["PULSE_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["PULSE_UI_TEST_ENHANCEMENT_PURCHASED"] = "1"

        let days = [
            RecordedDay(instant: "2026-10-21T13:12:00Z", note: notes[0]),
            RecordedDay(instant: "2026-10-22T12:40:00Z", note: nil),
            RecordedDay(instant: "2026-10-24T13:05:00Z", note: notes[1]),
            RecordedDay(instant: "2026-10-25T11:58:00Z", note: nil),
            RecordedDay(instant: "2026-10-26T13:30:00Z", note: notes[2]),
        ]

        app.launchEnvironment["PULSE_UI_TEST_NOW"] = days[0].instant
        app.launch()
        let nameField = app.textFields["commitment.name.field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 8))
        replaceText(in: nameField, with: "")
        sleep(1)
        keep("01 onboarding empty")
        nameField.typeText(habitName)
        sleep(1)
        keep("02 onboarding named")
        nameField.typeText(XCUIKeyboardKey.return.rawValue)
        let purpose = app.descendants(matching: .any)["commitment.purpose.field"]
        if purpose.waitForExistence(timeout: 2) {
            purpose.typeText(XCUIKeyboardKey.return.rawValue)
        }
        app.buttons["commitment.save.button"].tap()
        XCTAssertTrue(app.buttons["today.checkin.button"].waitForExistence(timeout: 5))

        for (index, day) in days.enumerated() {
            if index > 0 {
                relaunch(at: day.instant)
            }
            checkIn(note: day.note)
        }

        relaunch(at: "2026-10-27T13:42:00Z")
        keep("03 today pending")
        checkIn(note: todayNote)
        sleep(1)
        keep("04 today checked")

        app.buttons["primary.navigation.history"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["history.stat.total"].waitForExistence(timeout: 3))
        sleep(1)
        keep("05 history calendar")

        app.buttons["history.mode.journal"].tap()
        sleep(1)
        keep("06 history journal")

        app.buttons["history.mode.calendar"].tap()
        let keptDay = app.descendants(matching: .any)["calendar.day.2026-10-26"]
        for _ in 0..<6 where !(keptDay.exists && keptDay.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(keptDay.waitForExistence(timeout: 3))
        keptDay.tap()
        XCTAssertTrue(app.buttons["detail.sheet.close"].waitForExistence(timeout: 3))
        sleep(1)
        keep("07 day detail")
        app.buttons["detail.sheet.close"].tap()

        app.buttons["primary.navigation.today"].tap()
        app.buttons["settings.navigation.open.today"].tap()
        sleep(1)
        keep("08 settings")

        for theme in ["quietField", "sunlitDay"] {
            openThemePicker()
            if theme == "quietField" {
                keep("09 theme picker")
                let preview = app.buttons["settings.visual-theme.preview.quietField"]
                if preview.waitForExistence(timeout: 2) {
                    preview.tap()
                    let close = app.buttons["settings.visual-theme.preview.close"]
                    if close.waitForExistence(timeout: 3) {
                        sleep(1)
                        keep("09b theme preview")
                        close.tap()
                    }
                }
            }
            let choice = app.buttons["settings.visual-theme.\(theme)"]
            for _ in 0..<6 where !choice.isHittable {
                app.swipeUp()
            }
            choice.tap()
            app.buttons["navigation.back"].tap()
            app.buttons["navigation.back"].tap()
            XCTAssertTrue(app.buttons["today.checkin.button"].waitForExistence(timeout: 3))
            sleep(1)
            keep("1\(theme == "quietField" ? "0" : "2") \(theme) today")
            app.buttons["primary.navigation.history"].tap()
            sleep(1)
            keep("1\(theme == "quietField" ? "1" : "3") \(theme) history")
            app.buttons["primary.navigation.today"].tap()
            app.buttons["settings.navigation.open.today"].tap()
        }

        openThemePicker()
        let vermilion = app.buttons["settings.visual-theme.editorialJournal"]
        vermilion.tap()
        app.buttons["navigation.back"].tap()

        let storeLink = app.buttons["settings.store.link"]
        for _ in 0..<6 where !storeLink.isHittable {
            app.swipeUp()
        }
        storeLink.tap()
        sleep(1)
        keep("14 store")
        app.buttons["navigation.back"].tap()

        let galleryLink = app.buttons["settings.widget.gallery.link"]
        for _ in 0..<6 where !galleryLink.isHittable {
            app.swipeUp()
        }
        galleryLink.tap()
        sleep(1)
        keep("15 widget gallery")
        app.swipeUp()
        keep("16 widget gallery scrolled")
        app.swipeDown()
        app.swipeDown()
        let sizePicker = app.segmentedControls["widget.gallery.size"]
        if sizePicker.waitForExistence(timeout: 2) {
            sizePicker.buttons.element(boundBy: 0).tap()
            sleep(1)
            keep("17 widget gallery small")
            app.swipeUp()
            keep("18 widget gallery small scrolled")
        }
    }

    private func relaunch(at instant: String) {
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "PULSE_UI_TEST_RESET")
        app.launchEnvironment["PULSE_UI_TEST_NOW"] = instant
        app.launch()
        XCTAssertTrue(app.buttons["today.checkin.button"].waitForExistence(timeout: 8))
    }

    private func checkIn(note: String?) {
        let checkIn = app.buttons["today.checkin.button"]
        XCTAssertTrue(checkIn.waitForExistence(timeout: 3))
        if let note {
            let draft = app.descendants(matching: .any)["journal.draft.input"]
            XCTAssertTrue(draft.waitForExistence(timeout: 3))
            for _ in 0..<4 where !draft.isHittable {
                app.swipeUp()
            }
            draft.tap()
            draft.typeText(note)
            let done = app.buttons["journal.keyboard.done"]
            if done.waitForExistence(timeout: 2) {
                done.tap()
            }
            for _ in 0..<4 where !checkIn.isHittable {
                app.swipeDown()
            }
        }
        checkIn.tap()
        expectation(for: NSPredicate(format: "isEnabled == false"), evaluatedWith: checkIn)
        waitForExpectations(timeout: 4)
    }

    private func openThemePicker() {
        let link = app.buttons["settings.visual-theme.link"]
        for _ in 0..<6 where !link.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(link.waitForExistence(timeout: 3))
        link.tap()
        XCTAssertTrue(app.buttons["settings.visual-theme.editorialJournal"].waitForExistence(timeout: 3))
    }

    private func replaceText(in field: XCUIElement, with replacement: String) {
        field.tap()
        if let currentValue = field.value as? String, !currentValue.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count))
        }
        if !replacement.isEmpty {
            field.typeText(replacement)
        }
    }

    private func keep(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
