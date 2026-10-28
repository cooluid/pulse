import XCTest

/// Captures the in-app screens the App Store pages are composed from
/// (`design/app-store-screenshots/source`). Nothing here asserts how a page looks.
@MainActor
final class PulseStoreSourceUITests: XCTestCase {
    private var app: XCUIApplication!

    func testStoreSourcesInChinese() throws {
        try capture(
            language: "zh-Hans",
            locale: "zh_CN",
            habitName: "晚饭后散步",
            notes: ["雨停后出门走了一圈。", "走到桥边再回来。", "看到了傍晚的云。", "绕湖一圈，风很轻。"],
            todayNote: "河边走了二十分钟。"
        )
    }

    func testStoreSourcesInEnglish() throws {
        try capture(
            language: "en",
            locale: "en_US",
            habitName: "Evening walk",
            notes: ["Out after the rain.", "To the bridge and back.", "Clouds at dusk.", "Around the lake, a light wind."],
            todayNote: "Twenty minutes by the river."
        )
    }

    private func capture(
        language: String,
        locale: String,
        habitName: String,
        notes: [String],
        todayNote: String
    ) throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launchEnvironment["TZ"] = "Asia/Shanghai"
        app.launchEnvironment["PULSE_UI_TEST_RESET"] = "1"
        app.launchEnvironment["PULSE_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["PULSE_UI_TEST_ENHANCEMENT_PURCHASED"] = "1"

        let days: [(instant: String, note: String?)] = [
            ("2026-10-08T12:10:00Z", nil),
            ("2026-10-09T13:02:00Z", notes[0]),
            ("2026-10-10T12:44:00Z", nil),
            ("2026-10-12T13:20:00Z", nil),
            ("2026-10-13T12:31:00Z", notes[1]),
            ("2026-10-14T12:58:00Z", nil),
            ("2026-10-15T13:12:00Z", nil),
            ("2026-10-17T12:05:00Z", nil),
            ("2026-10-18T12:49:00Z", notes[2]),
            ("2026-10-19T13:15:00Z", nil),
            ("2026-10-20T12:40:00Z", nil),
            ("2026-10-21T13:05:00Z", nil),
            ("2026-10-23T12:22:00Z", nil),
            ("2026-10-24T12:57:00Z", notes[3]),
            ("2026-10-25T11:58:00Z", nil),
            ("2026-10-26T13:30:00Z", nil),
        ]

        app.launchEnvironment["PULSE_UI_TEST_NOW"] = days[0].instant
        app.launch()
        let nameField = app.textFields["commitment.name.field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 8))
        nameField.tap()
        if let value = nameField.value as? String, !value.isEmpty {
            nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        nameField.typeText(habitName)
        XCTAssertEqual(nameField.value as? String, habitName)
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

        relaunch(at: "2026-10-27T12:41:00Z")
        sleep(1)
        keep("01-today-before")

        checkIn(note: todayNote)
        for _ in 0..<3 {
            app.swipeDown()
        }
        sleep(2)
        keep("02-today-after")

        app.buttons["primary.navigation.history"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["history.stat.total"].waitForExistence(timeout: 3))
        sleep(1)
        keep("03-history")

        app.buttons["history.mode.journal"].tap()
        sleep(1)
        keep("04-journal")
        app.buttons["history.mode.calendar"].tap()

        app.buttons["primary.navigation.today"].tap()
        app.buttons["settings.navigation.open.today"].tap()

        let galleryLink = app.buttons["settings.widget.gallery.link"]
        for _ in 0..<6 where !galleryLink.isHittable {
            app.swipeUp()
        }
        galleryLink.tap()
        XCTAssertTrue(app.segmentedControls["widget.gallery.size"].waitForExistence(timeout: 8))
        sleep(1)
        keep("05-widgets")
        app.buttons["navigation.back"].tap()
        XCTAssertTrue(galleryLink.waitForExistence(timeout: 8))

        let storeLink = app.buttons["settings.store.link"]
        for _ in 0..<6 where !storeLink.isHittable {
            app.swipeDown()
        }
        storeLink.tap()
        XCTAssertTrue(app.descendants(matching: .any)["store.hero"].waitForExistence(timeout: 8))
        sleep(1)
        keep("advanced-features")
        app.buttons["navigation.back"].tap()
        XCTAssertTrue(storeLink.waitForExistence(timeout: 8))

        let backup = app.descendants(matching: .any)["settings.backup.export.button"]
        for _ in 0..<8 where !(backup.exists && backup.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(backup.isHittable)
        sleep(1)
        keep("backup")
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

    private func keep(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
