import Foundation
import PulseCore
import UIKit

enum PulseSupportContract {
    static let emailAddress = "400822@163.com"
    static let maximumFeedbackLength = 2_000
    static let maximumScreenshotInputByteCount = 40 * 1_024 * 1_024
    static let maximumScreenshotOutputByteCount = 8 * 1_024 * 1_024
    static let maximumScreenshotPixelDimension: CGFloat = 2_048

    private static let productSite = URL(string: "https://fanr.co/pulse")!

    static let helpCenterURL = productSite.appending(path: "support")
    static let privacyPolicyURL = productSite.appending(path: "privacy")
}

struct PulseAppMetadata: Equatable, Sendable {
    let shortVersion: String
    let buildVersion: String

    var displayVersion: String {
        [shortVersion, buildVersion.isEmpty ? nil : "(\(buildVersion))"]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    static var current: PulseAppMetadata {
        PulseAppMetadata(
            shortVersion: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "—",
            buildVersion: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleVersion"
            ) as? String ?? ""
        )
    }
}

struct PulseFeedbackDiagnostics: Equatable, Sendable {
    let app: PulseAppMetadata
    let bundleIdentifier: String
    let systemName: String
    let systemVersion: String
    let deviceModelIdentifier: String
    let interfaceLanguageIdentifier: String
    let appearance: String
    let visualTheme: String
    let loadState: String
    let logicalDay: String
    let timeZoneIdentifier: String
    let todayState: String
    let recordCount: Int
    let journalCount: Int
    let mediaCount: Int
    let mediaStorageByteCount: Int64
    let reminderEnabled: Bool
    let notificationPermission: String
    let reminderDeliveryMode: String
    let enhancementUnlocked: Bool
    let availableStorageByteCount: Int64?

    @MainActor
    static func current(model: PulseAppModel, locale: Locale) -> PulseFeedbackDiagnostics {
        let device = UIDevice.current
        return PulseFeedbackDiagnostics(
            app: .current,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "unknown",
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            deviceModelIdentifier: currentDeviceModelIdentifier(),
            interfaceLanguageIdentifier: locale.identifier,
            appearance: model.settings.theme.localizedName(locale: locale),
            visualTheme: model.resolvedVisualTheme.localizedName(locale: locale),
            loadState: PulseLocalization.string(
                "feedback.value.runtime.\(model.loadState.feedbackValue)",
                locale: locale
            ),
            logicalDay: model.today?.storageValue ?? "unavailable",
            timeZoneIdentifier: model.habit?.timeZoneIdentifier ?? "unavailable",
            todayState: model.today == nil
                ? "unavailable"
                : model.todayRecord == nil ? "pending" : "checked",
            recordCount: model.records.count,
            journalCount: model.records.lazy.filter { $0.journalNote != nil }.count,
            mediaCount: model.media.count,
            mediaStorageByteCount: model.mediaStorageByteCount,
            reminderEnabled: model.displayedReminderEnabled,
            notificationPermission: model.notificationPermission.feedbackValue,
            reminderDeliveryMode: model.reminderDeliveryMode.feedbackValue,
            enhancementUnlocked: model.featureAccess.hasEnhancement,
            availableStorageByteCount: currentAvailableStorageByteCount()
        )
    }

    func localizedLines(locale: Locale) -> [PulseFeedbackDiagnosticLine] {
        [
            .init(
                labelKey: "feedback.diagnostics.app",
                value: "Pulse \(app.displayVersion) · \(bundleIdentifier)"
            ),
            .init(
                labelKey: "feedback.diagnostics.system",
                value: "\(systemName) \(systemVersion)"
            ),
            .init(
                labelKey: "feedback.diagnostics.device",
                value: deviceModelIdentifier
            ),
            .init(
                labelKey: "feedback.diagnostics.interface",
                value: "\(interfaceLanguageIdentifier) · \(appearance) · \(visualTheme)"
            ),
            .init(
                labelKey: "feedback.diagnostics.runtime",
                value: loadState
            ),
            .init(
                labelKey: "feedback.diagnostics.calendar",
                value: "\(logicalDay) · \(timeZoneIdentifier)"
            ),
            .init(
                labelKey: "feedback.diagnostics.today",
                value: localizedValue("feedback.value.\(todayState)", locale: locale)
            ),
            .init(
                labelKey: "feedback.diagnostics.data_scale",
                value: String(
                    format: PulseLocalization.string(
                        "feedback.diagnostics.data_scale_format",
                        locale: locale
                    ),
                    locale: locale,
                    Int64(recordCount),
                    Int64(journalCount),
                    Int64(mediaCount),
                    ByteCountFormatter.string(
                        fromByteCount: mediaStorageByteCount,
                        countStyle: .file
                    )
                )
            ),
            .init(
                labelKey: "feedback.diagnostics.reminders",
                value: String(
                    format: PulseLocalization.string(
                        "feedback.diagnostics.reminders_format",
                        locale: locale
                    ),
                    locale: locale,
                    localizedValue(
                        reminderEnabled ? "feedback.value.enabled" : "feedback.value.disabled",
                        locale: locale
                    ),
                    localizedValue(
                        "feedback.value.permission.\(notificationPermission)",
                        locale: locale
                    ),
                    localizedValue(
                        "feedback.value.delivery.\(reminderDeliveryMode)",
                        locale: locale
                    )
                )
            ),
            .init(
                labelKey: "feedback.diagnostics.enhancement",
                value: localizedValue(
                    enhancementUnlocked ? "feedback.value.unlocked" : "feedback.value.not_unlocked",
                    locale: locale
                )
            ),
            .init(
                labelKey: "feedback.diagnostics.available_storage",
                value: availableStorageByteCount.map {
                    ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)
                } ?? localizedValue("feedback.value.unavailable", locale: locale)
            ),
        ]
    }

    private static func currentDeviceModelIdentifier() -> String {
        var information = utsname()
        guard uname(&information) == 0 else { return "unknown" }
        return withUnsafeBytes(of: &information.machine) { buffer in
            let bytes = buffer.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
    }

    private static func currentAvailableStorageByteCount() -> Int64? {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return try? homeURL.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        ).volumeAvailableCapacityForImportantUsage
    }

    private func localizedValue(_ key: String, locale: Locale) -> String {
        PulseLocalization.string(key, locale: locale)
    }
}

struct PulseFeedbackDiagnosticLine: Identifiable, Equatable, Sendable {
    let labelKey: String
    let value: String

    var id: String { labelKey }
}

private extension AppLoadState {
    var feedbackValue: String {
        switch self {
        case .loading: "loading"
        case .ready: "ready"
        case .failed: "failed"
        }
    }
}

private extension NotificationPermissionState {
    var feedbackValue: String {
        switch self {
        case .notDetermined: "not_determined"
        case .authorized: "authorized"
        case .denied: "denied"
        }
    }
}

private extension PulseReminderDeliveryMode {
    var feedbackValue: String {
        switch self {
        case .disabled: "disabled"
        case .localNotification: "local_notification"
        case .scheduledLiveActivity: "scheduled_live_activity"
        }
    }
}

enum PulseFeedbackCategory: String, CaseIterable, Identifiable, Sendable {
    case problem
    case suggestion

    var id: Self { self }

    func localizedTitle(locale: Locale) -> String {
        PulseLocalization.string("feedback.category.\(rawValue)", locale: locale)
    }

    func localizedSubject(locale: Locale) -> String {
        PulseLocalization.string("feedback.subject.\(rawValue)", locale: locale)
    }
}

enum PulseFeedbackDraftError: Error, Equatable {
    case empty
    case tooLong
    case unsupportedControlCharacter
}

struct PulseFeedbackDraft: Equatable, Sendable {
    let category: PulseFeedbackCategory
    let body: String

    init(category: PulseFeedbackCategory, body: String) throws {
        let normalized = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            throw PulseFeedbackDraftError.empty
        }
        guard normalized.count <= PulseSupportContract.maximumFeedbackLength else {
            throw PulseFeedbackDraftError.tooLong
        }
        guard normalized.unicodeScalars.allSatisfy(Self.isSupported) else {
            throw PulseFeedbackDraftError.unsupportedControlCharacter
        }

        self.category = category
        self.body = normalized
    }

    private static func isSupported(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value == 0x09
            || scalar.value == 0x0A
            || scalar.value >= 0x20 && scalar.value != 0x7F
    }
}

struct PulseFeedbackMessage: Identifiable, Equatable, Sendable {
    let id = UUID()
    let recipient: String
    let subject: String
    let body: String
    let attachment: PulseFeedbackAttachment?
}

enum PulseFeedbackMessageBuilder {
    static func makeMessage(
        draft: PulseFeedbackDraft,
        diagnostics: PulseFeedbackDiagnostics?,
        attachment: PulseFeedbackAttachment? = nil,
        locale: Locale
    ) -> PulseFeedbackMessage {
        let separator = "\n\n——\n"
        var sections = [draft.body]

        if let diagnostics {
            let lines = diagnostics.localizedLines(locale: locale).map { line in
                String(
                    format: PulseLocalization.string(
                        "feedback.diagnostics.line_format",
                        locale: locale
                    ),
                    locale: locale,
                    PulseLocalization.string(line.labelKey, locale: locale),
                    line.value
                )
            }
            sections.append(
                ([PulseLocalization.string("feedback.diagnostics.heading", locale: locale)]
                    + lines).joined(separator: "\n")
            )
        }

        sections.append(
            PulseLocalization.string("feedback.mail.privacy_footer", locale: locale)
        )

        let subject = if let diagnostics {
            "\(draft.category.localizedSubject(locale: locale)) · Pulse \(diagnostics.app.displayVersion)"
        } else {
            draft.category.localizedSubject(locale: locale)
        }

        return PulseFeedbackMessage(
            recipient: PulseSupportContract.emailAddress,
            subject: subject,
            body: sections.joined(separator: separator),
            attachment: attachment
        )
    }

}
