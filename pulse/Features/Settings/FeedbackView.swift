import SwiftUI
import UIKit
import PhotosUI
@preconcurrency import MessageUI

struct FeedbackView: View {
    @Bindable var model: PulseAppModel
    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme
    @FocusState private var isEditorFocused: Bool
    @State private var category: PulseFeedbackCategory = .problem
    @State private var feedbackBody = ""
    @State private var includesDiagnostics = true
    @State private var showsDiagnosticDetails = true
    @State private var diagnostics: PulseFeedbackDiagnostics?
    @State private var selectedScreenshotItem: PhotosPickerItem?
    @State private var screenshotAttachment: PulseFeedbackAttachment?
    @State private var isLoadingScreenshot = false
    @State private var screenshotError: FeedbackScreenshotPresentationError?
    @State private var presentedMessage: PulseFeedbackMessage?
    @State private var notice: FeedbackNotice?

    var body: some View {
        Form {
            introductionSection.pulseFormRows(for: visualTheme)
            categorySection.pulseFormRows(for: visualTheme)
            messageSection.pulseFormRows(for: visualTheme)
            screenshotSection.pulseFormRows(for: visualTheme)
            diagnosticsSection.pulseFormRows(for: visualTheme)
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(PulseScreenBackground())
        .foregroundStyle(PulseDesign.appInk(for: visualTheme))
        .tint(PulseDesign.appAccent(for: visualTheme))
        .navigationTitle("feedback.navigation_title")
        .navigationBarTitleDisplayMode(.inline)
        .pulseSecondaryNavigation()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("action.done") {
                    isEditorFocused = false
                }
                .accessibilityIdentifier("feedback.keyboard.done")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sendArea
        }
        .task(id: locale.identifier) {
            diagnostics = PulseFeedbackDiagnostics.current(model: model, locale: locale)
        }
        .onChange(of: selectedScreenshotItem) { _, item in
            Task { await loadScreenshot(item) }
        }
        .sheet(item: $presentedMessage) { message in
            PulseMailComposer(message: message) { result, error in
                presentedMessage = nil
                handleMailResult(result, error: error)
            }
            .ignoresSafeArea()
        }
        .alert(item: $notice) { notice in
            notice.alert(locale: locale)
        }
    }

    private var introductionSection: some View {
        Section {
            Label {
                Text("feedback.introduction")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .foregroundStyle(PulseDesign.appAccent(for: visualTheme))
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var categorySection: some View {
        Section("feedback.category.section") {
            Picker("feedback.category.label", selection: $category) {
                ForEach(PulseFeedbackCategory.allCases) { category in
                    Text(category.localizedTitle(locale: locale)).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("feedback.category.picker")
        }
    }

    private var messageSection: some View {
        Section {
            ZStack(alignment: .topLeading) {
                if feedbackBody.isEmpty {
                    Text("feedback.message.placeholder")
                        .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                        .padding(.horizontal, PulseDesign.spacing4)
                        .padding(.vertical, PulseDesign.spacing8)
                        .accessibilityHidden(true)
                }

                TextEditor(text: $feedbackBody)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .focused($isEditorFocused)
                    .accessibilityLabel("feedback.message.label")
                    .accessibilityIdentifier("feedback.message.editor")
            }

            HStack {
                validationMessage
                Spacer()
                Text(verbatim: "\(feedbackBody.count)/\(PulseSupportContract.maximumFeedbackLength)")
                    .monospacedDigit()
                    .accessibilityIdentifier("feedback.message.count")
            }
            .font(.caption)
            .foregroundStyle(
                feedbackBody.count > PulseSupportContract.maximumFeedbackLength
                    ? PulseDesign.systemDestructive
                    : PulseDesign.appMuted(for: visualTheme)
            )
        } header: {
            Text("feedback.message.section")
        } footer: {
            Text("feedback.message.privacy_note")
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var validationMessage: some View {
        if feedbackBody.count > PulseSupportContract.maximumFeedbackLength {
            Label("feedback.message.too_long", systemImage: "exclamationmark.circle")
                .foregroundStyle(PulseDesign.systemDestructive)
        } else {
            Text("feedback.message.requirement")
        }
    }

    private var diagnosticsSection: some View {
        Section {
            Toggle("feedback.diagnostics.include", isOn: $includesDiagnostics)
                .accessibilityIdentifier("feedback.diagnostics.toggle")

            if includesDiagnostics, let diagnostics {
                DisclosureGroup(
                    "feedback.diagnostics.preview",
                    isExpanded: $showsDiagnosticDetails
                ) {
                    ForEach(diagnostics.localizedLines(locale: locale)) { line in
                        LabeledContent {
                            Text(line.value)
                                .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                                .multilineTextAlignment(.trailing)
                        } label: {
                            Text(LocalizedStringKey(line.labelKey))
                        }
                    }
                }
                .accessibilityIdentifier("feedback.diagnostics.preview")
            }
        } header: {
            Text("feedback.diagnostics.section")
        } footer: {
            Text("feedback.diagnostics.explanation")
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var screenshotSection: some View {
        Section {
            if let screenshotAttachment,
               let preview = UIImage(data: screenshotAttachment.data) {
                HStack(spacing: PulseDesign.spacing12) {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: PulseDesign.spacing12,
                                style: .continuous
                            )
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                        Text("feedback.screenshot.attached")
                        Text(
                            ByteCountFormatter.string(
                                fromByteCount: Int64(screenshotAttachment.data.count),
                                countStyle: .file
                            )
                        )
                        .font(.footnote)
                        .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                    }

                    Spacer()

                    Button(role: .destructive) {
                        selectedScreenshotItem = nil
                        self.screenshotAttachment = nil
                        screenshotError = nil
                    } label: {
                        Image(systemName: "trash")
                            .frame(
                                minWidth: PulseDesign.minimumHitTarget,
                                minHeight: PulseDesign.minimumHitTarget
                            )
                    }
                    .accessibilityLabel("feedback.screenshot.remove")
                    .accessibilityIdentifier("feedback.screenshot.remove")
                }
            } else if isLoadingScreenshot {
                ProgressView("feedback.screenshot.processing")
                    .accessibilityIdentifier("feedback.screenshot.processing")
            } else {
                PhotosPicker(
                    selection: $selectedScreenshotItem,
                    matching: .images
                ) {
                    Label("feedback.screenshot.choose", systemImage: "photo")
                }
                .accessibilityIdentifier("feedback.screenshot.choose")
            }

            if let screenshotError {
                Label(screenshotError.localizedKey, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(PulseDesign.systemDestructive)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("feedback.screenshot.error")
            }
        } header: {
            Text("feedback.screenshot.section")
        } footer: {
            Text("feedback.screenshot.explanation")
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sendArea: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                isEditorFocused = false
                prepareMail()
            } label: {
                HStack {
                    Spacer()
                    Label("feedback.send", systemImage: "paperplane.fill")
                        .font(.headline.weight(.semibold))
                    Spacer()
                }
                .frame(minHeight: PulseDesign.minimumHitTarget)
                .foregroundStyle(PulseDesign.appAccentForeground(for: visualTheme))
            }
            .buttonStyle(.borderedProminent)
            .tint(PulseDesign.appAccent(for: visualTheme))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, PulseDesign.horizontalPadding)
            .padding(.vertical, PulseDesign.spacing12)
            .disabled(!canSubmit)
            .accessibilityIdentifier("feedback.send.button")
        }
        .background(PulseDesign.appSurface(for: visualTheme))
    }

    private var canSubmit: Bool {
        (try? PulseFeedbackDraft(category: category, body: feedbackBody)) != nil
            && (!includesDiagnostics || diagnostics != nil)
            && !isLoadingScreenshot
    }

    private func prepareMail() {
        guard let draft = try? PulseFeedbackDraft(
            category: category,
            body: feedbackBody
        ) else { return }
        guard MFMailComposeViewController.canSendMail() else {
            notice = .mailUnavailable
            return
        }

        let currentDiagnostics = includesDiagnostics
            ? PulseFeedbackDiagnostics.current(model: model, locale: locale)
            : nil
        diagnostics = currentDiagnostics ?? diagnostics
        presentedMessage = PulseFeedbackMessageBuilder.makeMessage(
            draft: draft,
            diagnostics: currentDiagnostics,
            attachment: screenshotAttachment,
            locale: locale
        )
    }

    private func loadScreenshot(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        screenshotError = nil
        screenshotAttachment = nil
        isLoadingScreenshot = true
        defer { isLoadingScreenshot = false }

        do {
            guard let sourceData = try await item.loadTransferable(type: Data.self) else {
                throw PulseFeedbackScreenshotError.invalidImage
            }
            let attachment = try await Task.detached(priority: .userInitiated) {
                try PulseFeedbackScreenshotProcessor.process(sourceData)
            }.value
            guard selectedScreenshotItem == item else { return }
            screenshotAttachment = attachment
        } catch let error as PulseFeedbackScreenshotError {
            screenshotError = .processing(error)
            selectedScreenshotItem = nil
        } catch {
            screenshotError = .load
            selectedScreenshotItem = nil
        }
    }

    private func handleMailResult(_ result: MFMailComposeResult, error: Error?) {
        if let error {
            notice = .failed(error.localizedDescription)
            return
        }

        switch result {
        case .sent:
            feedbackBody = ""
            notice = .queued
        case .saved:
            notice = .saved
        case .failed:
            notice = .failed(nil)
        case .cancelled:
            break
        @unknown default:
            notice = .failed(nil)
        }
    }
}

private enum FeedbackNotice: Identifiable {
    case mailUnavailable
    case queued
    case saved
    case failed(String?)

    var id: String {
        switch self {
        case .mailUnavailable: "mailUnavailable"
        case .queued: "queued"
        case .saved: "saved"
        case .failed: "failed"
        }
    }

    @MainActor
    func alert(locale: Locale) -> Alert {
        switch self {
        case .mailUnavailable:
            Alert(
                title: Text("feedback.mail_unavailable.title"),
                message: Text(
                    String(
                        format: PulseLocalization.string(
                            "feedback.mail_unavailable.message_format",
                            locale: locale
                        ),
                        locale: locale,
                        PulseSupportContract.emailAddress
                    )
                ),
                primaryButton: .default(Text("feedback.copy_email")) {
                    UIPasteboard.general.string = PulseSupportContract.emailAddress
                },
                secondaryButton: .cancel(Text("action.cancel"))
            )
        case .queued:
            Alert(
                title: Text("feedback.queued.title"),
                message: Text("feedback.queued.message"),
                dismissButton: .default(Text("action.ok"))
            )
        case .saved:
            Alert(
                title: Text("feedback.saved.title"),
                message: Text("feedback.saved.message"),
                dismissButton: .default(Text("action.ok"))
            )
        case .failed(let detail):
            Alert(
                title: Text("feedback.failed.title"),
                message: Text(
                    detail ?? PulseLocalization.string(
                        "feedback.failed.message",
                        locale: locale
                    )
                ),
                dismissButton: .default(Text("action.ok"))
            )
        }
    }
}

private enum FeedbackScreenshotPresentationError: Equatable {
    case load
    case processing(PulseFeedbackScreenshotError)

    var localizedKey: LocalizedStringKey {
        switch self {
        case .load:
            "feedback.screenshot.error.load"
        case .processing(.inputTooLarge), .processing(.outputTooLarge):
            "feedback.screenshot.error.too_large"
        case .processing(.invalidImage):
            "feedback.screenshot.error.invalid"
        }
    }
}

private struct PulseMailComposer: UIViewControllerRepresentable {
    let message: PulseFeedbackMessage
    let onFinish: @MainActor (MFMailComposeResult, Error?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([message.recipient])
        controller.setSubject(message.subject)
        controller.setMessageBody(message.body, isHTML: false)
        if let attachment = message.attachment {
            controller.addAttachmentData(
                attachment.data,
                mimeType: attachment.mimeType,
                fileName: attachment.filename
            )
        }
        return controller
    }

    func updateUIViewController(
        _ uiViewController: MFMailComposeViewController,
        context: Context
    ) {}

    @MainActor
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let onFinish: @MainActor (MFMailComposeResult, Error?) -> Void

        init(onFinish: @escaping @MainActor (MFMailComposeResult, Error?) -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true) {
                self.onFinish(result, error)
            }
        }
    }
}
