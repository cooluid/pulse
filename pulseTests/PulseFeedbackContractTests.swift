import Foundation
import UIKit
import XCTest
@testable import pulse

@MainActor
final class PulseFeedbackContractTests: XCTestCase {
    func testDraftNormalizesLineEndingsAndPreservesEmojiSequences() throws {
        let draft = try PulseFeedbackDraft(
            category: .suggestion,
            body: "  第一行\r\n👩‍💻 第二行  \r\n"
        )

        XCTAssertEqual(draft.body, "第一行\n👩‍💻 第二行")
        XCTAssertEqual(draft.category, .suggestion)
    }

    func testDraftRejectsEmptyOversizedAndControlCharacterContent() throws {
        XCTAssertThrowsError(
            try PulseFeedbackDraft(category: .problem, body: " \n ")
        ) { error in
            XCTAssertEqual(error as? PulseFeedbackDraftError, .empty)
        }

        XCTAssertThrowsError(
            try PulseFeedbackDraft(
                category: .problem,
                body: String(
                    repeating: "印",
                    count: PulseSupportContract.maximumFeedbackLength + 1
                )
            )
        ) { error in
            XCTAssertEqual(error as? PulseFeedbackDraftError, .tooLong)
        }

        XCTAssertThrowsError(
            try PulseFeedbackDraft(category: .problem, body: "问题\u{0000}描述")
        ) { error in
            XCTAssertEqual(
                error as? PulseFeedbackDraftError,
                .unsupportedControlCharacter
            )
        }
    }

    func testMessageUsesOneSupportAddressAndOnlyExplicitDiagnostics() throws {
        let locale = Locale(identifier: "zh-Hans")
        let draft = try PulseFeedbackDraft(
            category: .problem,
            body: "点击提醒开关后没有变化。"
        )
        let diagnostics = makeDiagnostics()

        let message = PulseFeedbackMessageBuilder.makeMessage(
            draft: draft,
            diagnostics: diagnostics,
            locale: locale
        )

        XCTAssertEqual(message.recipient, PulseSupportContract.emailAddress)
        XCTAssertTrue(message.subject.contains("[一日一印问题反馈]"))
        XCTAssertTrue(message.subject.contains("1.1 (4)"))
        XCTAssertTrue(message.body.contains(draft.body))
        XCTAssertTrue(message.body.contains("iPhone17,1"))
        XCTAssertTrue(message.body.contains("3 条签到"))
        XCTAssertTrue(message.body.contains("Asia/Shanghai"))
        XCTAssertTrue(message.body.contains("没有附带“我的一件事”正文"))
        XCTAssertFalse(message.body.contains("400822@163.com"))

        let privateMessage = PulseFeedbackMessageBuilder.makeMessage(
            draft: draft,
            diagnostics: nil,
            locale: locale
        )
        XCTAssertEqual(privateMessage.subject, "[一日一印问题反馈]")
        XCTAssertFalse(privateMessage.subject.contains("1.1"))
        XCTAssertFalse(privateMessage.body.contains("iPhone17,1"))
        XCTAssertFalse(privateMessage.body.contains("技术信息"))
    }

    func testSelectedScreenshotIsSanitizedResizedAndAttached() throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 3_000, height: 1_500)).image {
            context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3_000, height: 1_500))
            UIColor.black.setFill()
            context.fill(CGRect(x: 100, y: 100, width: 800, height: 200))
        }
        let sourceData = try XCTUnwrap(source.pngData())
        let attachment = try PulseFeedbackScreenshotProcessor.process(sourceData)

        XCTAssertEqual(attachment.mimeType, "image/jpeg")
        XCTAssertEqual(attachment.filename, "pulse-feedback-screenshot.jpg")
        XCTAssertEqual(attachment.pixelWidth, 2_048)
        XCTAssertEqual(attachment.pixelHeight, 1_024)
        XCTAssertLessThanOrEqual(
            attachment.data.count,
            PulseSupportContract.maximumScreenshotOutputByteCount
        )
        XCTAssertNotNil(UIImage(data: attachment.data))

        let draft = try PulseFeedbackDraft(category: .problem, body: "截图问题")
        let message = PulseFeedbackMessageBuilder.makeMessage(
            draft: draft,
            diagnostics: makeDiagnostics(),
            attachment: attachment,
            locale: Locale(identifier: "zh-Hans")
        )
        XCTAssertEqual(message.attachment, attachment)
    }

    func testScreenshotProcessorRejectsInvalidAndOversizedInput() {
        XCTAssertThrowsError(try PulseFeedbackScreenshotProcessor.process(Data([0, 1, 2]))) {
            error in
            XCTAssertEqual(error as? PulseFeedbackScreenshotError, .invalidImage)
        }
        XCTAssertThrowsError(
            try PulseFeedbackScreenshotProcessor.process(
                Data(count: PulseSupportContract.maximumScreenshotInputByteCount + 1)
            )
        ) { error in
            XCTAssertEqual(error as? PulseFeedbackScreenshotError, .inputTooLarge)
        }
    }

    func testSupportURLsAndVersionPresentationAreCanonical() {
        XCTAssertEqual(
            PulseSupportContract.helpCenterURL.absoluteString,
            "https://fanr.co/pulse/support"
        )
        XCTAssertEqual(
            PulseSupportContract.privacyPolicyURL.absoluteString,
            "https://fanr.co/pulse/privacy"
        )
        XCTAssertEqual(
            PulseAppMetadata(shortVersion: "1.1", buildVersion: "4").displayVersion,
            "1.1 (4)"
        )
    }

    private func makeDiagnostics() -> PulseFeedbackDiagnostics {
        PulseFeedbackDiagnostics(
            app: PulseAppMetadata(shortVersion: "1.1", buildVersion: "4"),
            bundleIdentifier: "co.fanr.pulse",
            systemName: "iOS",
            systemVersion: "18.6",
            deviceModelIdentifier: "iPhone17,1",
            interfaceLanguageIdentifier: "zh-Hans",
            appearance: "跟随系统",
            visualTheme: "纸页手记",
            loadState: "就绪",
            logicalDay: "2026-08-18",
            timeZoneIdentifier: "Asia/Shanghai",
            todayState: "checked",
            recordCount: 3,
            journalCount: 2,
            mediaCount: 1,
            mediaStorageByteCount: 1_024,
            reminderEnabled: true,
            notificationPermission: "authorized",
            reminderDeliveryMode: "local_notification",
            enhancementUnlocked: false,
            availableStorageByteCount: 20 * 1_024 * 1_024
        )
    }
}
