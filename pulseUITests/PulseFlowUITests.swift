import XCTest
import UIKit

@MainActor
final class PulseFlowUITests: XCTestCase {
    private var app: XCUIApplication!
    private let bottomInteractionSafetyInset: CGFloat = 80

    private func configureApp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launchEnvironment["PULSE_UI_TEST_RESET"] = "1"
        app.launchEnvironment["PULSE_UI_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["PULSE_UI_TEST_NOW"] = "2026-08-10T04:00:00Z"
        app.launchEnvironment["PULSE_UI_TEST_ENHANCEMENT_PURCHASED"] = "0"
    }

    private func launchAndConfirmDefaultCommitment() {
        app.launch()

        let saveButton = app.buttons["commitment.save.button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        XCTAssertTrue(app.buttons["today.checkin.button"].waitForExistence(timeout: 5))
    }

    private func selectOption(named optionLabel: String, in picker: XCUIElement) {
        picker.tap()
        let option = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", optionLabel))
            .firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 3))
        option.tap()
    }

    private func openVisualThemePicker() {
        let link = app.buttons["settings.visual-theme.link"]
        for _ in 0..<6 where !link.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(link.waitForExistence(timeout: 3))
        XCTAssertTrue(link.isHittable)
        link.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.visual-theme.selector"]
                .waitForExistence(timeout: 3)
        )
    }

    private func assertVisualThemeCardsStayWithinWindow() {
        let identifiers = [
            "settings.visual-theme.editorialJournal",
            "settings.visual-theme.quietField",
            "settings.visual-theme.sunlitDay",
        ]
        let cards = identifiers.map { app.buttons[$0] }
        for card in cards {
            XCTAssertTrue(card.waitForExistence(timeout: 3))
            XCTAssertGreaterThanOrEqual(card.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(card.frame.maxX, app.frame.maxX)
        }
        XCTAssertLessThan(cards[0].frame.maxY, cards[1].frame.minY)
        XCTAssertLessThan(cards[1].frame.maxY, cards[2].frame.minY)
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
        assertRedundantTodayCopyIsAbsent()
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
        assertRedundantTodayCopyIsAbsent()
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
        assertRedundantTodayCopyIsAbsent()
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

    func testCheckInRevealsOptionalMediaInvitation() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        app.buttons["today.checkin.button"].tap()
        let captureButton = app.buttons["today.media.capture.button"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 3))
        XCTAssertTrue(captureButton.label.contains("拍照"))
        XCTAssertFalse(app.navigationBars["照片"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["today.media.strip"].exists)

        let checkInButton = app.buttons["today.checkin.button"]
        let weekRail = app.descendants(matching: .any)["today.week.rail"]
        let primaryNavigation = app.buttons["primary.navigation.today"]
        XCTAssertTrue(checkInButton.exists)
        XCTAssertTrue(weekRail.exists)
        XCTAssertTrue(primaryNavigation.exists)
        let isTrailingCompanion = captureButton.frame.midX > checkInButton.frame.midX
            && captureButton.frame.minY < checkInButton.frame.maxY
        let isFollowingCompanion = captureButton.frame.minY >= checkInButton.frame.maxY
        XCTAssertTrue(
            isTrailingCompanion || isFollowingCompanion,
            "The media invitation must remain adjacent to the completed check-in."
        )
        XCTAssertLessThan(
            captureButton.frame.maxY,
            primaryNavigation.frame.minY,
            "The companion media action must not compete with primary navigation."
        )

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Today with companion media action"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLongPressCommitsCheckInBeforeRequestingCamera() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        let checkInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(checkInButton.waitForExistence(timeout: 5))
        checkInButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.6)

        let completed = NSPredicate(format: "isEnabled == false")
        expectation(for: completed, evaluatedWith: checkInButton)
        waitForExpectations(timeout: 3)
        XCTAssertTrue(checkInButton.label.contains("已签到"))
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

    func testDebugActivityLabShowsOnlyIsolatedRuntimeIdentity() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        app.buttons["settings.navigation.open.today"].tap()
        let activityLabLink = app.descendants(matching: .any)[
            "settings.debug.activity-lab.link"
        ]
        for _ in 0..<6 where !activityLabLink.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(activityLabLink.waitForExistence(timeout: 3))
        XCTAssertTrue(activityLabLink.isHittable)
        activityLabLink.tap()

        let appIdentity = app.descendants(matching: .any)["debug.identity.app"]
        let appGroupIdentity = app.descendants(matching: .any)["debug.identity.app-group"]
        let urlSchemeIdentity = app.descendants(matching: .any)["debug.identity.url-scheme"]
        XCTAssertTrue(
            appIdentity.waitForExistence(timeout: 5),
            "The Debug activity lab did not expose its runtime identity."
        )
        XCTAssertTrue(appIdentity.label.contains("co.fanr.pulse.dev"))
        XCTAssertTrue(appGroupIdentity.label.contains("group.co.fanr.pulse.dev"))
        XCTAssertTrue(urlSchemeIdentity.label.contains("pulse-dev"))
        XCTAssertFalse(appIdentity.label.contains("co.fanr.pulse,"))
        XCTAssertFalse(appGroupIdentity.label.contains("group.co.fanr.pulse,"))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Debug Dynamic Island lab with isolated identity"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testEnhancementPurchaseLeavesFreeReminderAvailableAndUnlocksEnhancement() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        app.buttons["settings.navigation.open.today"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["settings.reminder.toggle"]
                .waitForExistence(timeout: 3)
        )

        let storeLink = app.descendants(matching: .any)["settings.store.link"]
        XCTAssertTrue(storeLink.waitForExistence(timeout: 3))
        storeLink.tap()

        let purchaseButton = app.buttons["store.buy"]
        XCTAssertTrue(purchaseButton.waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.descendants(matching: .any)["store.activity.preview.section"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["store.activity.preview.signature"].exists,
            "Missing the signature Live Activity preview."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["store.capability.interfaceThemes"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "store.capability.interfaceThemes.preview.quietField"
            ].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "store.capability.interfaceThemes.preview.sunlitDay"
            ].exists
        )
        XCTAssertEqual(
            app.buttons.matching(
                identifier: "store.capability.interfaceThemes.preview.quietField"
            ).count,
            0
        )
        XCTAssertEqual(
            app.buttons.matching(
                identifier: "store.capability.interfaceThemes.preview.sunlitDay"
            ).count,
            0
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["store.theme.editorial-journal"].exists,
            "Theme specimens must not apply a paid theme before purchase."
        )

        let storeAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        storeAttachment.name = "Advanced benefits before purchase"
        storeAttachment.lifetime = .keepAlways
        add(storeAttachment)

        let finalCapability = app.descendants(matching: .any)[
            "store.capability.scheduledLiveActivity"
        ]
        let restoreButton = app.buttons["store.restore"]
        for _ in 0..<8 where !restoreButton.isHittable
            || restoreButton.frame.maxY > purchaseButton.frame.minY {
            app.swipeUp()
        }
        XCTAssertTrue(finalCapability.waitForExistence(timeout: 3))
        XCTAssertTrue(finalCapability.isHittable)
        XCTAssertTrue(restoreButton.isHittable)
        XCTAssertLessThanOrEqual(restoreButton.frame.maxY, purchaseButton.frame.minY)

        purchaseButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["store.status"]
                .waitForExistence(timeout: 3)
        )

        let purchasedSettingsAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        purchasedSettingsAttachment.name = "Advanced benefits purchased with free reminder retained"
        purchasedSettingsAttachment.lifetime = .keepAlways
        add(purchasedSettingsAttachment)

        app.buttons["navigation.back"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.reminder.toggle"].exists)
        app.buttons["navigation.back"].tap()
        XCTAssertTrue(app.buttons["today.checkin.button"].waitForExistence(timeout: 3))
    }

    func testWidgetGalleryKeepsAccessStatusOnlyWhereActionIsRequired() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        app.buttons["settings.navigation.open.today"].tap()

        let galleryLink = app.descendants(matching: .any)["settings.widget.gallery.link"]
        for _ in 0..<4 where !galleryLink.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(galleryLink.waitForExistence(timeout: 3))
        galleryLink.tap()

        let includedOption = app.descendants(matching: .any)[
            "widget.gallery.style.place"
        ]
        let premiumOption = app.descendants(matching: .any)["widget.gallery.style.orbit"]
        let premiumStoreButton = app.buttons["widget.gallery.enhancement.orbit"]
        XCTAssertTrue(includedOption.waitForExistence(timeout: 3))
        XCTAssertTrue(premiumOption.waitForExistence(timeout: 3))
        XCTAssertFalse(includedOption.label.contains("已包含"))
        XCTAssertFalse(includedOption.label.contains("已解锁"))
        XCTAssertEqual(
            app.buttons.matching(identifier: "widget.gallery.enhancement.orbit").count,
            1
        )
        XCTAssertTrue(premiumStoreButton.label.contains("高级功能"))
        XCTAssertTrue(premiumStoreButton.isHittable)

        let previewButton = app.buttons["widget.gallery.preview.place"]
        XCTAssertTrue(previewButton.waitForExistence(timeout: 3))
        previewButton.tap()
        let replayLabel = NSPredicate(format: "label == %@", "再次预览")
        expectation(for: replayLabel, evaluatedWith: previewButton)
        waitForExpectations(timeout: 7)

        let previewAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        previewAttachment.name = "Widget ambient periods and check-in preview completed"
        previewAttachment.lifetime = .keepAlways
        add(previewAttachment)

        let optionsAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        optionsAttachment.name = "Free and advanced widget compositions"
        optionsAttachment.lifetime = .keepAlways
        add(optionsAttachment)

        let window = app.windows.firstMatch
        for _ in 0..<4 where !premiumStoreButton.isHittable
            || premiumStoreButton.frame.maxY > window.frame.maxY - 20 {
            app.swipeUp()
        }
        XCTAssertTrue(premiumStoreButton.waitForExistence(timeout: 3))
        XCTAssertTrue(premiumStoreButton.isHittable)
        XCTAssertLessThanOrEqual(premiumStoreButton.frame.maxY, window.frame.maxY - 20)

        premiumStoreButton.tap()
        XCTAssertTrue(
            app.buttons["store.buy"]
                .waitForExistence(timeout: 3)
        )
    }

    func testPathWidgetPreviewShowsDistinctArrivalMidpoint() throws {
        configureApp()
        app.launchEnvironment["PULSE_UI_TEST_ENHANCEMENT_PURCHASED"] = "1"
        launchAndConfirmDefaultCommitment()

        app.buttons["settings.navigation.open.today"].tap()
        let galleryLink = app.descendants(matching: .any)["settings.widget.gallery.link"]
        for _ in 0..<4 where !galleryLink.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(galleryLink.waitForExistence(timeout: 3))
        galleryLink.tap()

        let card = app.descendants(matching: .any)["widget.gallery.style.path"]
        let previewButton = app.buttons["widget.gallery.preview.path"]
        let window = app.windows.firstMatch
        for _ in 0..<8 where !card.exists
            || card.frame.maxY > window.frame.maxY - 20 {
            app.swipeUp()
        }
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        XCTAssertTrue(previewButton.waitForExistence(timeout: 3))
        XCTAssertTrue(previewButton.isHittable)

        let previewRect = CGRect(
            x: card.frame.minX,
            y: card.frame.minY,
            width: card.frame.width,
            height: min(card.frame.height * 0.54, card.frame.width * 0.48)
        )
        let pendingScreenshot = XCUIScreen.main.screenshot()
        let pendingPixels = try XCTUnwrap(croppedPNG(
            from: pendingScreenshot,
            screenRect: previewRect
        ))

        previewButton.tap()
        Thread.sleep(forTimeInterval: 3.45)

        let midpointScreenshot = XCUIScreen.main.screenshot()
        let midpointPixels = try XCTUnwrap(croppedPNG(
            from: midpointScreenshot,
            screenRect: previewRect
        ))
        XCTAssertNotEqual(
            pendingPixels,
            midpointPixels,
            "The path preview must render a visible in-flight arrival frame."
        )

        let replayLabel = NSPredicate(format: "label == %@", "再次预览")
        expectation(for: replayLabel, evaluatedWith: previewButton)
        waitForExpectations(timeout: 4)

        let completedScreenshot = XCUIScreen.main.screenshot()
        let completedPixels = try XCTUnwrap(croppedPNG(
            from: completedScreenshot,
            screenRect: previewRect
        ))
        XCTAssertNotEqual(
            midpointPixels,
            completedPixels,
            "The path arrival must continue from its midpoint into a distinct final state."
        )

        for (name, screenshot) in [
            ("Path arrival pending", pendingScreenshot),
            ("Path arrival midpoint", midpointScreenshot),
            ("Path arrival completed", completedScreenshot),
        ] {
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func croppedPNG(
        from screenshot: XCUIScreenshot,
        screenRect: CGRect
    ) -> Data? {
        let image = screenshot.image
        let pixelRect = CGRect(
            x: screenRect.minX * image.scale,
            y: screenRect.minY * image.scale,
            width: screenRect.width * image.scale,
            height: screenRect.height * image.scale
        ).integral
        guard let cropped = image.cgImage?.cropping(to: pixelRect) else { return nil }
        return UIImage(
            cgImage: cropped,
            scale: image.scale,
            orientation: image.imageOrientation
        ).pngData()
    }

    func testSettingsExposesFormalFeedbackHelpAndPrivacyFlow() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        let settingsButton = app.buttons["settings.navigation.open.today"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let feedbackLink = app.buttons["settings.feedback.link"]
        for _ in 0..<8 where !feedbackLink.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(feedbackLink.waitForExistence(timeout: 3))
        XCTAssertTrue(feedbackLink.isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["settings.help-center.link"].exists)
        let privacyLink = app.descendants(matching: .any)["settings.privacy_policy.link"]
        XCTAssertTrue(privacyLink.waitForExistence(timeout: 3))

        feedbackLink.tap()
        XCTAssertTrue(app.navigationBars["反馈与建议"].waitForExistence(timeout: 3))

        let editor = app.textViews["feedback.message.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        let sendButton = app.buttons["feedback.send.button"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 3))
        XCTAssertFalse(sendButton.isEnabled)

        editor.tap()
        editor.typeText("希望月历切换月份时保留当前的查看模式。")
        XCTAssertTrue(sendButton.isEnabled)
        let keyboardDone = app.buttons["feedback.keyboard.done"]
        XCTAssertTrue(keyboardDone.waitForExistence(timeout: 3))
        keyboardDone.tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)

        let screenshotChooser = app.buttons["feedback.screenshot.choose"]
        let diagnosticsPreview = app.descendants(matching: .any)[
            "feedback.diagnostics.preview"
        ]
        for _ in 0..<8 where !diagnosticsPreview.exists {
            app.swipeUp()
        }
        XCTAssertTrue(screenshotChooser.waitForExistence(timeout: 3))
        XCTAssertTrue(diagnosticsPreview.waitForExistence(timeout: 3))
        app.swipeUp()
        app.swipeUp()

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Formal feedback composer"
        attachment.lifetime = .keepAlways
        add(attachment)

        sendButton.tap()
        XCTAssertTrue(app.alerts["邮件尚未配置"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["复制邮箱"].exists)
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
        XCTAssertTrue(resetButton.isHittable)
        resetButton.tap()

        let confirmButton = app.buttons
            .matching(identifier: "settings.reset.confirm.button")
            .firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))
        confirmButton.tap()

        XCTAssertTrue(app.textFields["commitment.name.field"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["primary.navigation.today"].exists)
    }

    func testEncryptedBackupRequiresMatchingProductPassphrase() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        app.buttons["settings.navigation.open.today"].tap()
        let exportButton = app.buttons["settings.backup.export.button"]
        for _ in 0..<8 where !exportButton.exists {
            app.swipeUp()
        }
        XCTAssertTrue(exportButton.waitForExistence(timeout: 3))
        for _ in 0..<6 where exportButton.frame.maxY > app.frame.maxY - 80 {
            app.swipeUp()
        }
        XCTAssertTrue(exportButton.isHittable)
        XCTAssertLessThanOrEqual(exportButton.frame.maxY, app.frame.maxY - 80)
        exportButton.tap()

        XCTAssertTrue(app.navigationBars["加密备份"].waitForExistence(timeout: 3))
        let passphraseField = app.secureTextFields["backup.passphrase.field"]
        let confirmationField = app.secureTextFields["backup.passphrase.confirmation"]
        let submitButton = app.buttons["backup.passphrase.submit"]
        XCTAssertTrue(passphraseField.waitForExistence(timeout: 3))
        XCTAssertTrue(confirmationField.exists)
        XCTAssertFalse(submitButton.isEnabled)

        passphraseField.typeText("abc")
        confirmationField.tap()
        confirmationField.typeText("abc")
        XCTAssertFalse(submitButton.isEnabled)

        replaceText(in: passphraseField, with: "1234")
        replaceText(in: confirmationField, with: "1235")
        XCTAssertTrue(submitButton.isEnabled)
        submitButton.tap()
        let error = app.staticTexts["backup.passphrase.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 3))
        XCTAssertTrue(error.label.contains("两次输入的密码不一致"))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Encrypted backup passphrase validation"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.buttons["取消"].tap()
        XCTAssertFalse(app.navigationBars["加密备份"].exists)
    }

    func testThemeAndLanguageChoicesApplyImmediatelyAndPersistAcrossRelaunch() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        let settingsButton = app.buttons["settings.navigation.open.today"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let languagePicker = app.descendants(matching: .any)["settings.language.picker"]
        for _ in 0..<8 where !languagePicker.exists {
            app.swipeUp()
        }
        XCTAssertTrue(languagePicker.waitForExistence(timeout: 3))
        for _ in 0..<6
            where languagePicker.frame.maxY > app.frame.maxY - bottomInteractionSafetyInset {
            app.swipeUp()
        }
        XCTAssertTrue(languagePicker.isHittable)
        XCTAssertLessThanOrEqual(
            languagePicker.frame.maxY,
            app.frame.maxY - bottomInteractionSafetyInset
        )
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
        for _ in 0..<8 where !themePicker.exists {
            app.swipeUp()
        }
        XCTAssertTrue(themePicker.waitForExistence(timeout: 3))
        for _ in 0..<6
            where themePicker.frame.maxY > app.frame.maxY - bottomInteractionSafetyInset {
            app.swipeUp()
        }
        XCTAssertTrue(themePicker.isHittable)
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
        for _ in 0..<8 where !persistedLanguagePicker.exists || !persistedThemePicker.exists {
            app.swipeUp()
        }
        XCTAssertTrue(persistedLanguagePicker.waitForExistence(timeout: 3))
        XCTAssertTrue(persistedThemePicker.waitForExistence(timeout: 3))
        XCTAssertTrue(persistedLanguagePicker.label.contains("English"))
        XCTAssertTrue(persistedThemePicker.label.contains("Dark"))
        XCTAssertEqual(app.buttons["navigation.back"].label, "Back")

        app.buttons["navigation.back"].tap()
        XCTAssertTrue(app.buttons["primary.navigation.today"].waitForExistence(timeout: 3))
        let darkTodayAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        darkTodayAttachment.name = "Today in English with dark theme"
        darkTodayAttachment.lifetime = .keepAlways
        add(darkTodayAttachment)
    }

    func testVisualThemeAppliesImmediatelyAndPersistsAcrossRelaunch() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        let freeTheme = app.descendants(matching: .any)["today.theme.editorial-journal"]
        XCTAssertTrue(freeTheme.waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.descendants(matching: .any)["journal.draft.input"]
                .waitForExistence(timeout: 3)
        )

        let freeAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        freeAttachment.name = "Free Journal Page before check-in"
        freeAttachment.lifetime = .keepAlways
        add(freeAttachment)

        app.buttons["primary.navigation.history"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["history.theme.editorial-journal"]
                .waitForExistence(timeout: 3)
        )
        let freeHistoryAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        freeHistoryAttachment.name = "Free Journal Page history calendar"
        freeHistoryAttachment.lifetime = .keepAlways
        add(freeHistoryAttachment)

        app.buttons["history.mode.journal"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["history.journal.section"]
                .waitForExistence(timeout: 3)
        )
        let freeJournalAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        freeJournalAttachment.name = "Free Journal Page journal records"
        freeJournalAttachment.lifetime = .keepAlways
        add(freeJournalAttachment)
        app.buttons["history.mode.calendar"].tap()
        app.buttons["primary.navigation.today"].tap()

        let settingsButton = app.buttons["settings.navigation.open.today"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()
        openVisualThemePicker()
        assertVisualThemeCardsStayWithinWindow()

        let quietThemeChoice = app.buttons["settings.visual-theme.quietField"]
        let sunlitThemeChoice = app.buttons["settings.visual-theme.sunlitDay"]
        XCTAssertTrue(quietThemeChoice.waitForExistence(timeout: 3))
        XCTAssertTrue(sunlitThemeChoice.exists)
        XCTAssertEqual(quietThemeChoice.value as? String, "高级功能")
        XCTAssertEqual(sunlitThemeChoice.value as? String, "高级功能")

        let lockedThemesAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        lockedThemesAttachment.name = "Locked paid interface themes"
        lockedThemesAttachment.lifetime = .keepAlways
        add(lockedThemesAttachment)

        sunlitThemeChoice.tap()

        let purchaseButton = app.buttons["store.buy"]
        XCTAssertTrue(purchaseButton.waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.descendants(matching: .any)["store.capability.interfaceThemes"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "store.capability.interfaceThemes.preview.sunlitDay"
            ].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["store.theme.editorial-journal"].exists,
            "Opening Advanced Features from a locked theme must not enable that theme."
        )
        purchaseButton.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["store.status"]
                .waitForExistence(timeout: 3)
        )
        app.buttons["navigation.back"].tap()
        XCTAssertTrue(sunlitThemeChoice.waitForExistence(timeout: 3))
        XCTAssertEqual(sunlitThemeChoice.value as? String, "")
        sunlitThemeChoice.tap()

        let settingsAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        settingsAttachment.name = "Sunlit Day visual selector"
        settingsAttachment.lifetime = .keepAlways
        add(settingsAttachment)

        app.buttons["navigation.back"].tap()
        app.buttons["navigation.back"].tap()
        let sunlitTheme = app.descendants(matching: .any)["today.theme.sunlit-day"]
        XCTAssertTrue(sunlitTheme.waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.descendants(matching: .any)["journal.draft.input"]
                .waitForExistence(timeout: 3)
        )

        let pendingAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        pendingAttachment.name = "Sunlit Day before check-in"
        pendingAttachment.lifetime = .keepAlways
        add(pendingAttachment)

        let checkInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(checkInButton.waitForExistence(timeout: 3))
        checkInButton.tap()
        XCTAssertFalse(checkInButton.isEnabled)
        XCTAssertTrue(checkInButton.label.contains("已签到"))
        XCTAssertTrue(
            app.descendants(matching: .any)["today.checkin.presentation.imprinted"]
                .waitForExistence(timeout: 3)
        )

        let completedAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        completedAttachment.name = "Sunlit Day after check-in"
        completedAttachment.lifetime = .keepAlways
        add(completedAttachment)

        app.buttons["primary.navigation.history"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["history.theme.sunlit-day"]
                .waitForExistence(timeout: 3)
        )
        let checkedCalendarDay = app.descendants(matching: .any)["calendar.day.2026-08-10"]
        XCTAssertTrue(checkedCalendarDay.waitForExistence(timeout: 3))
        XCTAssertTrue(checkedCalendarDay.label.contains("已签到"))

        let journalMode = app.buttons["history.mode.journal"]
        XCTAssertTrue(journalMode.waitForExistence(timeout: 3))
        journalMode.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["history.journal.section"]
                .waitForExistence(timeout: 3)
        )

        let journalHistoryAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        journalHistoryAttachment.name = "Sunlit Day journal records"
        journalHistoryAttachment.lifetime = .keepAlways
        add(journalHistoryAttachment)

        app.buttons["history.mode.calendar"].tap()
        assertHistorySurfaceClearsPrimaryNavigation()

        let historyAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        historyAttachment.name = "Sunlit Day redesigned history"
        historyAttachment.lifetime = .keepAlways
        add(historyAttachment)

        checkedCalendarDay.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["history.record.detail.identity"]
                .waitForExistence(timeout: 3)
        )
        let detailAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        detailAttachment.name = "Sunlit Day record detail"
        detailAttachment.lifetime = .keepAlways
        add(detailAttachment)
        app.buttons["detail.sheet.close"].tap()

        app.buttons["primary.navigation.today"].tap()
        app.buttons["settings.navigation.open.today"].tap()
        let storeLink = app.descendants(matching: .any)["settings.store.link"]
        XCTAssertTrue(storeLink.waitForExistence(timeout: 3))
        storeLink.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["store.theme.sunlit-day"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["store.status"]
                .waitForExistence(timeout: 3)
        )

        let storeAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        storeAttachment.name = "Sunlit Day advanced features"
        storeAttachment.lifetime = .keepAlways
        add(storeAttachment)

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "PULSE_UI_TEST_RESET")
        app.launchEnvironment["PULSE_UI_TEST_ENHANCEMENT_PURCHASED"] = "1"
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["today.theme.sunlit-day"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.buttons["today.checkin.button"].isEnabled)
    }

    func testJournalPageKeepsNotePhotoHistoryAndEditingCapabilitiesUnified() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        app.buttons["settings.navigation.open.today"].tap()
        openVisualThemePicker()
        let journalTheme = app.buttons["settings.visual-theme.editorialJournal"]
        XCTAssertTrue(journalTheme.waitForExistence(timeout: 3))
        journalTheme.tap()
        app.buttons["navigation.back"].tap()
        app.buttons["navigation.back"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["today.theme.editorial-journal"]
                .waitForExistence(timeout: 3)
        )
        let inlineNote = app.descendants(matching: .any)["journal.draft.input"]
        XCTAssertTrue(inlineNote.waitForExistence(timeout: 3))

        let editorialTodayAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        editorialTodayAttachment.name = "Editorial Journal before check-in"
        editorialTodayAttachment.lifetime = .keepAlways
        add(editorialTodayAttachment)

        replaceText(in: inlineNote, with: "Today stayed focused")

        let checkInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(checkInButton.isEnabled)
        checkInButton.tap()
        XCTAssertFalse(checkInButton.isEnabled)
        XCTAssertTrue(app.buttons["today.media.capture.button"].waitForExistence(timeout: 3))

        let noteSummary = app.descendants(matching: .any)["journal.summary.text"]
        XCTAssertTrue(noteSummary.waitForExistence(timeout: 3))
        XCTAssertEqual(noteSummary.label, "Today stayed focused")
        app.buttons["journal.edit.button"].tap()

        let editor = app.descendants(matching: .any)["journal.editor.input"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        let save = app.buttons["journal.editor.save"]
        XCTAssertFalse(save.isEnabled)
        replaceText(in: editor, with: "Edited after check-in")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(noteSummary.waitForExistence(timeout: 3))
        XCTAssertEqual(noteSummary.label, "Edited after check-in")

        app.buttons["primary.navigation.history"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["history.theme.editorial-journal"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.descendants(matching: .any)["history.stat.total"].exists)
        app.buttons["history.mode.journal"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["history.journal.section"]
                .waitForExistence(timeout: 3)
        )

        let editorialHistoryAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        editorialHistoryAttachment.name = "Editorial Journal record stream"
        editorialHistoryAttachment.lifetime = .keepAlways
        add(editorialHistoryAttachment)

        let journalEntry = app.descendants(matching: .any)[
            "history.journal.entry.2026-08-10"
        ]
        XCTAssertTrue(journalEntry.waitForExistence(timeout: 3))
        journalEntry.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["journal.summary"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(identifier: "journal.summary.text")
                .firstMatch
                .label,
            "Edited after check-in"
        )

        let detailEdit = try XCTUnwrap(
            app.buttons
                .matching(identifier: "journal.edit.button")
                .allElementsBoundByIndex
                .first(where: \.isHittable)
        )
        detailEdit.tap()
        let deleteNote = app.buttons["journal.delete.button"]
        XCTAssertTrue(deleteNote.waitForExistence(timeout: 3))
        deleteNote.tap()
        let confirmDeleteNote = app.buttons["journal.delete.confirmation.action"].firstMatch
        XCTAssertTrue(confirmDeleteNote.waitForExistence(timeout: 3))
        confirmDeleteNote.tap()
        let clearedNote = app.descendants(matching: .any)
            .matching(identifier: "journal.summary.text")
            .firstMatch
        XCTAssertTrue(clearedNote.waitForExistence(timeout: 3))
        XCTAssertEqual(clearedNote.label, "这一天还没有记事")
    }

    func testSunlitDayHistoryRemainsStructuredInDarkAppearance() throws {
        configureApp()
        app.launchEnvironment["PULSE_UI_TEST_ENHANCEMENT_PURCHASED"] = "1"
        launchAndConfirmDefaultCommitment()

        app.buttons["settings.navigation.open.today"].tap()
        openVisualThemePicker()

        let sunlitThemeChoice = app.buttons["settings.visual-theme.sunlitDay"]
        XCTAssertTrue(sunlitThemeChoice.waitForExistence(timeout: 3))
        sunlitThemeChoice.tap()
        app.buttons["navigation.back"].tap()

        let appearancePicker = app.descendants(matching: .any)["settings.theme.picker"]
        for _ in 0..<4 where !appearancePicker.exists {
            app.swipeUp()
        }
        XCTAssertTrue(appearancePicker.waitForExistence(timeout: 3))
        selectOption(named: "深色", in: appearancePicker)

        let darkAppearanceApplied = NSPredicate(format: "label CONTAINS %@", "深色")
        expectation(for: darkAppearanceApplied, evaluatedWith: appearancePicker)
        waitForExpectations(timeout: 3)

        app.buttons["navigation.back"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["today.theme.sunlit-day"]
                .waitForExistence(timeout: 3)
        )

        let checkInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(checkInButton.waitForExistence(timeout: 3))
        checkInButton.tap()
        XCTAssertFalse(checkInButton.isEnabled)

        let historyNavigation = app.buttons["primary.navigation.history"]
        XCTAssertTrue(historyNavigation.waitForExistence(timeout: 3))
        historyNavigation.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["history.theme.sunlit-day"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["calendar.day.2026-08-10"]
                .waitForExistence(timeout: 3)
        )
        assertHistorySurfaceClearsPrimaryNavigation()

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Sunlit Day history in dark appearance"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSunlitDayAccessibilityXXXLKeepsItsOwnOperableComposition() throws {
        configureApp()
        app.launchEnvironment["PULSE_UI_TEST_ENHANCEMENT_PURCHASED"] = "1"
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchAndConfirmDefaultCommitment()

        app.buttons["settings.navigation.open.today"].tap()
        openVisualThemePicker()
        let sunlitThemeChoice = app.buttons["settings.visual-theme.sunlitDay"]
        for _ in 0..<8 where !sunlitThemeChoice.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(sunlitThemeChoice.waitForExistence(timeout: 3))
        XCTAssertTrue(sunlitThemeChoice.isHittable)
        sunlitThemeChoice.tap()
        app.buttons["navigation.back"].tap()
        app.buttons["navigation.back"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["today.theme.sunlit-day"]
                .waitForExistence(timeout: 3)
        )
        let checkInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(checkInButton.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(checkInButton.frame.width, checkInButton.frame.height)
        XCTAssertGreaterThanOrEqual(checkInButton.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(checkInButton.frame.maxX, app.frame.maxX)

        let todayNavigation = app.buttons["primary.navigation.today"]
        XCTAssertTrue(todayNavigation.waitForExistence(timeout: 3))
        for _ in 0..<6 where checkInButton.frame.maxY > todayNavigation.frame.minY {
            app.swipeUp()
        }

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Sunlit Day accessibility XXXL"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertTrue(checkInButton.isHittable)
        XCTAssertLessThanOrEqual(checkInButton.frame.maxY, todayNavigation.frame.minY)
    }

    func testChineseHistoryUsesLocalizedArchiveHeading() throws {
        configureApp()
        launchAndConfirmDefaultCommitment()

        let historyNavigation = app.buttons["primary.navigation.history"]
        XCTAssertTrue(historyNavigation.waitForExistence(timeout: 3))
        historyNavigation.tap()

        let localizedHeading = app.staticTexts
            .matching(NSPredicate(format: "label == %@", "记录 · 2026"))
            .firstMatch
        XCTAssertTrue(localizedHeading.waitForExistence(timeout: 3))
        XCTAssertFalse(
            app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS %@", "ARCHIVE"))
                .firstMatch
                .exists
        )
    }

    func testPurchasedUserCanBrowseAllPerInstanceWidgetCompositions() throws {
        configureApp()
        app.launchEnvironment["PULSE_UI_TEST_ENHANCEMENT_PURCHASED"] = "1"
        launchAndConfirmDefaultCommitment()

        let settingsButton = app.buttons["settings.navigation.open.today"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let galleryLink = app.descendants(matching: .any)["settings.widget.gallery.link"]
        for _ in 0..<4 where !galleryLink.exists {
            app.swipeUp()
        }
        XCTAssertTrue(galleryLink.waitForExistence(timeout: 3))
        galleryLink.tap()

        let styleIdentifiers = [
            "place",
            "orbit",
            "stack",
            "bleed",
            "letter",
            "field",
            "path",
            "tide",
        ]
        reviewWidgetCompositions(styleIdentifiers, state: "pending")

        app.buttons["navigation.back"].tap()
        let galleryLinkAfterPendingReview = app.descendants(matching: .any)[
            "settings.widget.gallery.link"
        ]
        XCTAssertTrue(galleryLinkAfterPendingReview.waitForExistence(timeout: 3))

        app.buttons["navigation.back"].tap()
        let checkInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(checkInButton.waitForExistence(timeout: 3))
        checkInButton.tap()
        XCTAssertFalse(checkInButton.isEnabled)

        let settingsButtonAfterCheckIn = app.buttons["settings.navigation.open.today"]
        XCTAssertTrue(settingsButtonAfterCheckIn.waitForExistence(timeout: 3))
        settingsButtonAfterCheckIn.tap()

        let galleryLinkAfterCheckIn = app.descendants(matching: .any)[
            "settings.widget.gallery.link"
        ]
        for _ in 0..<4 where !galleryLinkAfterCheckIn.exists {
            app.swipeUp()
        }
        XCTAssertTrue(galleryLinkAfterCheckIn.waitForExistence(timeout: 3))
        galleryLinkAfterCheckIn.tap()

        reviewWidgetCompositions(styleIdentifiers, state: "completed")

        app.buttons["navigation.back"].tap()
        let galleryLinkAfterReview = app.descendants(matching: .any)[
            "settings.widget.gallery.link"
        ]
        XCTAssertTrue(galleryLinkAfterReview.waitForExistence(timeout: 3))
        XCTAssertTrue(galleryLinkAfterReview.label.contains("每个小组件独立设置"))
    }

    private func reviewWidgetCompositions(
        _ styleIdentifiers: [String],
        state: String
    ) {
        let window = app.windows.firstMatch
        for (index, identifier) in styleIdentifiers.enumerated() {
            let option = app.descendants(matching: .any)[
                "widget.gallery.style.\(identifier)"
            ]
            for _ in 0..<8 where !option.exists
                || option.frame.maxY > window.frame.maxY - 20 {
                app.swipeUp()
            }
            XCTAssertTrue(option.waitForExistence(timeout: 3))
            XCTAssertLessThanOrEqual(option.frame.maxY, window.frame.maxY - 20)

            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "Widget compositions \(state) \(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testRecordDetailUsesStableCompactSheetAndToolbarActionsMenu() throws {
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

        let identity = app.descendants(matching: .any)["history.record.detail.identity"]
        let actionsMenu = app.buttons["history.record.actions.menu"]
        let closeButton = app.buttons["detail.sheet.close"]
        XCTAssertTrue(identity.waitForExistence(timeout: 3))
        XCTAssertTrue(identity.label.contains("2026年8月10日"))
        XCTAssertTrue(actionsMenu.waitForExistence(timeout: 3))
        XCTAssertTrue(closeButton.exists)
        XCTAssertTrue(actionsMenu.isHittable)
        XCTAssertTrue(closeButton.isHittable)
        XCTAssertFalse(app.buttons["完成"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["history.media.preview"].exists)

        let detailAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        detailAttachment.name = "Unified compact record detail without media"
        detailAttachment.lifetime = .keepAlways
        add(detailAttachment)

        actionsMenu.tap()

        let deleteAction = app.descendants(matching: .any)["history.record.delete.action"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["history.media.export.action"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["history.media.delete.action"].exists)

        let menuAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        menuAttachment.name = "Record detail toolbar actions menu"
        menuAttachment.lifetime = .keepAlways
        add(menuAttachment)

        deleteAction.tap()

        XCTAssertTrue(
            app.buttons["history.record.delete.confirmation.action"]
                .waitForExistence(timeout: 3)
        )
    }

    func testAccessibilityXXXLRecordDetailKeepsSingleActionsMenu() throws {
        configureApp()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchAndConfirmDefaultCommitment()

        let checkInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(checkInButton.waitForExistence(timeout: 5))
        checkInButton.tap()

        let historyNavigation = app.buttons["primary.navigation.history"]
        XCTAssertTrue(historyNavigation.waitForExistence(timeout: 3))
        historyNavigation.tap()

        let checkedDay = app.descendants(matching: .any)["calendar.day.2026-08-10"]
        for _ in 0..<6 where !checkedDay.exists || !checkedDay.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(checkedDay.waitForExistence(timeout: 3))
        checkedDay.tap()

        let identity = app.descendants(matching: .any)["history.record.detail.identity"]
        let actionsMenu = app.buttons["history.record.actions.menu"]
        let closeButton = app.buttons["detail.sheet.close"]
        XCTAssertTrue(identity.waitForExistence(timeout: 3))
        XCTAssertTrue(actionsMenu.waitForExistence(timeout: 3))
        XCTAssertTrue(closeButton.exists)
        XCTAssertTrue(actionsMenu.isHittable)
        XCTAssertTrue(closeButton.isHittable)
        XCTAssertFalse(app.descendants(matching: .any)["history.media.preview"].exists)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Accessibility XXXL record detail"
        attachment.lifetime = .keepAlways
        add(attachment)

        actionsMenu.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["history.record.delete.action"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.descendants(matching: .any)["history.media.export.action"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["history.media.delete.action"].exists)
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
        XCTAssertTrue(
            app.descendants(matching: .any)["today.theme.editorial-journal"].exists
        )
        XCTAssertTrue(app.descendants(matching: .any)["today.commitment.name"].exists)

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
        app.swipeUp()
        for _ in 0..<6 where rhythmStatus.frame.maxY > todayNavigation.frame.minY {
            app.swipeUp()
        }

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Accessibility XXXL primary layout"
        attachment.lifetime = .keepAlways
        add(attachment)

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
        XCTAssertTrue(heading.label.contains("记录 · 2026"))
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

        let onboardingAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        onboardingAttachment.name = "Grass pulse onboarding"
        onboardingAttachment.lifetime = .keepAlways
        add(onboardingAttachment)

        let longCommitment = "每天阅读三十分钟并做笔记"
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
            with: String(repeating: "a", count: 13)
        )
        XCTAssertFalse(saveButton.isEnabled)

        replaceText(in: nameField, with: "读书")
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

    private func assertRedundantTodayCopyIsAbsent() {
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

        let isVerticallySeparate = weekRail.frame.minY >= checkInButton.frame.maxY
            || weekRail.frame.maxY <= checkInButton.frame.minY
        let isHorizontallySeparate = weekRail.frame.maxX <= checkInButton.frame.minX
            || weekRail.frame.minX >= checkInButton.frame.maxX
        XCTAssertTrue(
            isVerticallySeparate || isHorizontallySeparate,
            "The week rail and check-in control must remain visibly separate."
        )
    }

    private func assertHeroGeometry() {
        let opticalCenterTolerance: CGFloat = 12
        let dayNumber = app.staticTexts["today.day.number"]
        let kicker = app.staticTexts["today.hero.kicker"]
        let commitmentCue = app.descendants(matching: .any)["today.commitment.name"]
        let checkInButton = app.buttons["today.checkin.button"]
        XCTAssertTrue(kicker.exists)
        XCTAssertTrue(commitmentCue.waitForExistence(timeout: 3))
        XCTAssertTrue(checkInButton.exists)
        XCTAssertTrue(kicker.label.contains("星期"))
        guard dayNumber.exists else {
            XCTAssertLessThan(kicker.frame.maxY, commitmentCue.frame.minY)
            XCTAssertLessThanOrEqual(commitmentCue.frame.maxY, checkInButton.frame.minY)
            return
        }
        XCTAssertEqual(
            dayNumber.frame.midX,
            kicker.frame.midX,
            accuracy: opticalCenterTolerance
        )
        XCTAssertEqual(
            dayNumber.frame.midX,
            commitmentCue.frame.midX,
            accuracy: opticalCenterTolerance
        )
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

    private func assertHistorySurfaceClearsPrimaryNavigation() {
        let calendarSurface = app.descendants(matching: .any)["calendar.day.2026-08-10"]
        let historyNavigation = app.buttons["primary.navigation.history"]
        XCTAssertTrue(calendarSurface.waitForExistence(timeout: 3))
        XCTAssertTrue(historyNavigation.waitForExistence(timeout: 3))
        XCTAssertLessThanOrEqual(
            calendarSurface.frame.maxY,
            historyNavigation.frame.minY,
            "The history surface must end before the persistent primary navigation begins."
        )
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
