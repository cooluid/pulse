import AVFoundation
import PulseCore
import StoreKit
import SwiftUI
import UIKit

enum PulseTodayPresentation {
    static func rhythmStatusText(currentStreak: Int, locale: Locale) -> String {
        guard currentStreak > 0 else {
            return PulseLocalization.string("today.rhythm.start_today", locale: locale)
        }

        return String(
            format: PulseLocalization.string("today.rhythm.streak_format", locale: locale),
            locale: locale,
            arguments: [Int64(currentStreak)]
        )
    }

    static func weekDayAccessibilityLabel(
        _ item: CalendarDayItem,
        timeZone: TimeZone,
        locale: Locale
    ) -> String {
        CalendarDayAccessibility.weekDayLabel(item, timeZone: timeZone, locale: locale)
    }

    static func checkInAccessibilityLabel(
        state: String,
        commitmentName: String?,
        locale: Locale
    ) -> String {
        guard let commitmentName else { return state }
        return String(
            format: PulseLocalization.string(
                "today.accessibility.commitment_state_format",
                locale: locale
            ),
            commitmentName,
            state
        )
    }
}

struct TodayView: View {
    @Bindable var model: PulseAppModel
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @Environment(\.pulseVisualTheme) private var visualTheme
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsSavingIndicator = false
    @State private var imprintRitualPhase: ImprintRitualPhase = .ready
    @State private var completionAnimationSequence = 0
    @State private var imprintGlyphScale: CGFloat = 1
    @State private var isCheckInPressed = false
    @State private var showsCamera = false
    @State private var showsCameraPermissionAlert = false
    @State private var showsTodayMediaDetail = false
    @State private var showsTodayJournalEditor = false
    @State private var draftJournalNote = ""
    @State private var reviewRequestSequence = 0
    @FocusState private var isJournalFocused: Bool

    var body: some View {
        ZStack {
            PulseScreenBackground()
            PulseFieldBackground(presentation: .today, allowsMotion: isActive)
            PulseThemeBackdrop(facts: todayFacts)

            VStack(spacing: 0) {
                PulseAppHeader(source: .today)

                ScrollView {
                    todayContent
                        .frame(maxWidth: todayContentMaxWidth)
                        .padding(.horizontal, PulseDesign.horizontalPadding)
                        .padding(.top, usesRegularWidthLayout ? PulseDesign.regularWidthVerticalPadding : PulseDesign.spacing4)
                        .padding(.bottom, PulseDesign.spacing16)
                        .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }

        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showsCamera) {
            ImprintCameraView(
                onCapture: { image, position in
                    showsCamera = false
                    Task {
                        _ = await model.saveTodayMedia(
                            image: image,
                            cameraPosition: position
                        )
                    }
                },
                onCancel: {
                    showsCamera = false
                },
                onFailure: {
                    showsCamera = false
                    model.errorMessage = PulseLocalization.string(
                        "error.camera_capture_failed",
                        locale: locale
                    )
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showsTodayMediaDetail) {
            if let media = model.todayMedia {
                TodayMediaDetailSheet(
                    media: media,
                    load: model.thumbnailData,
                    loadOriginal: model.originalData,
                    onRetake: {
                        showsTodayMediaDetail = false
                        Task { @MainActor in
                            try? await Task.sleep(
                                for: .seconds(PulseDesign.mediaDetailDismissDelay)
                            )
                            requestCamera()
                        }
                    },
                    onDelete: {
                        await model.deleteMedia(id: media.id)
                    }
                )
            }
        }
        .sheet(isPresented: $showsTodayJournalEditor) {
            if let record = model.todayRecord {
                JournalNoteEditorSheet(record: record, model: model)
            }
        }
        .alert("camera.permission.title", isPresented: $showsCameraPermissionAlert) {
            Button("camera.permission.open_settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("camera.permission.message")
        }
        .onAppear(perform: synchronizeJournalDraft)
        .onChange(of: model.today) { _, _ in
            synchronizeJournalDraft()
        }
        .onChange(of: model.todayRecord?.id) { _, _ in
            synchronizeJournalDraft()
        }
        .task(id: reviewRequestSequence) {
            await requestAppStoreReviewIfAppropriate()
        }
    }

    private var todayFacts: PulseTodayFacts {
        PulseTodayFacts(
            today: model.today,
            timeZone: model.timeZone,
            habitName: model.habit?.name,
            recentDays: model.recentDays,
            currentStreak: model.statistics.currentStreak,
            isChecked: model.todayRecord != nil
        )
    }

    private var todayContent: some View {
        PulseTodayPage(
            today: todayFacts.today,
            timeZone: todayFacts.timeZone,
            habitName: todayFacts.habitName,
            recentDays: todayFacts.recentDays,
            currentStreak: todayFacts.currentStreak,
            isChecked: todayFacts.isChecked,
            checkIn: checkInControl,
            journal: todayJournalSection,
            media: mediaCompanionAction
        )
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var todayContentMaxWidth: CGFloat {
        usesRegularWidthLayout ? PulseDesign.regularWidthContentMaxWidth : PulseDesign.screenMaxWidth
    }

    private var checkInControl: some View {
        let isChecked = model.todayRecord != nil
        return PulseCheckInFace(
            completedText: completedCheckInText,
            day: model.today,
            completedTime: completedCheckInTime,
            isSaving: model.isSaving && showsSavingIndicator,
            glyphScale: imprintGlyphScale
        )
        .contentShape(Rectangle())
        .overlay {
            PulseCombinedPressControl(
                isEnabled: !isChecked && model.canCheckInToday && isJournalDraftValid,
                accessibilityLabel: checkInAccessibilityLabel,
                accessibilityHint: isChecked ? "" : PulseLocalization.string("today.accessibility.hint", locale: locale),
                accessibilityLongPressName: PulseLocalization.string("today.accessibility.check_in_and_photo", locale: locale),
                onPressChanged: { isCheckInPressed = $0 },
                onTap: { performCheckIn(thenOpenCamera: false) },
                onLongPress: {
                    model.notifyPhotoIntentReady()
                    performCheckIn(thenOpenCamera: true)
                }
            )
        }
        .scaleEffect(!reduceMotion && isCheckInPressed ? 0.97 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isCheckInPressed)
        .onAppear {
            synchronizeRitualState(isChecked: isChecked)
        }
        .onChange(of: isChecked) { wasChecked, isNowChecked in
            if !isNowChecked {
                resetRitualPresentation(phase: .ready)
            } else if !wasChecked, imprintRitualPhase != .saving {
                resetRitualPresentation(phase: .imprinted)
            }
        }
        .onChange(of: reduceMotion) { _, shouldReduceMotion in
            if shouldReduceMotion {
                isCheckInPressed = false
                if isChecked, imprintRitualPhase != .imprinted {
                    completionAnimationSequence += 1
                } else {
                    resetRitualPresentation(phase: isChecked ? .imprinted : .ready)
                }
            }
        }
        .task(id: completionAnimationSequence) {
            await runCompletionMotion()
        }
        .task(id: model.isSaving) {
            guard model.isSaving else {
                showsSavingIndicator = false
                return
            }

            do {
                try await Task.sleep(for: .seconds(PulseDesign.savingIndicatorDelay))
            } catch {
                return
            }
            guard !Task.isCancelled, model.isSaving else { return }
            showsSavingIndicator = true
        }
    }

    private var completedCheckInTime: String? {
        model.todayRecord.map {
            PulseFormatting.time($0.checkedAt, timeZone: $0.timeZone, locale: locale)
        }
    }

    private var completedCheckInText: String? {
        guard let record = model.todayRecord else { return nil }
        return String(
            format: PulseLocalization.string("today.checked_with_time", locale: locale),
            PulseFormatting.time(record.checkedAt, timeZone: record.timeZone, locale: locale)
        )
    }

    private var checkInAccessibilityLabel: String {
        PulseTodayPresentation.checkInAccessibilityLabel(
            state: completedCheckInText ?? PulseLocalization.string("today.accessibility.check_in", locale: locale),
            commitmentName: model.habit?.name,
            locale: locale
        )
    }

    @ViewBuilder
    private var todayJournalSection: some View {
        if let record = model.todayRecord {
            JournalNoteSummary(record: record) { showsTodayJournalEditor = true }
        } else {
            JournalDraftComposer(
                text: $draftJournalNote,
                isFocused: $isJournalFocused,
                isDisabled: model.isSaving
            )
        }
    }

    @ViewBuilder
    private var mediaCompanionAction: some View {
        if model.todayRecord != nil && (model.settings.mediaInvitationEnabled || model.todayMedia != nil) {
            Button {
                if model.todayMedia == nil {
                    requestCamera()
                } else {
                    showsTodayMediaDetail = true
                }
            } label: {
                if model.operation == .saveMedia {
                    ProgressView()
                        .tint(PulseDesign.action)
                        .frame(minWidth: PulseDesign.minimumHitTarget)
                } else {
                    HStack(spacing: PulseDesign.spacing8) {
                        if let media = model.todayMedia {
                            ImprintMediaThumbnail(media: media, load: model.thumbnailData)
                        } else {
                            Image(systemName: "camera.fill")
                                .accessibilityHidden(true)
                        }

                        Text(
                            model.todayMedia == nil
                                ? "today.media.capture_compact"
                                : "today.media.view_compact"
                        )
                        .font(.subheadline.weight(.medium))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    }
                }
            }
            .foregroundStyle(mediaActionForeground)
            .padding(.horizontal, PulseDesign.spacing12)
            .frame(minHeight: PulseDesign.minimumHitTarget)
            .frame(maxWidth: .infinity, alignment: visualTheme == .editorialJournal ? .leading : .center)
            .buttonStyle(.plain)
            .disabled(model.operation == .saveMedia)
            .accessibilityIdentifier(
                model.todayMedia == nil
                    ? "today.media.capture.button"
                    : "today.media.preview.button"
            )
        }
    }

    private var mediaActionForeground: Color { PulseDesign.appInk(for: visualTheme) }

    private func performCheckIn(thenOpenCamera: Bool) {
        guard model.canCheckInToday, isJournalDraftValid else { return }
        isJournalFocused = false
        imprintRitualPhase = .saving

        Task {
            guard let receipt = await model.checkIn(journalNote: draftJournalNote) else {
                synchronizeRitualState(isChecked: model.todayRecord != nil)
                return
            }

            switch receipt.disposition {
            case .created:
                completionAnimationSequence += 1
                if !thenOpenCamera {
                    reviewRequestSequence += 1
                }
            case .alreadyPresent:
                resetRitualPresentation(phase: .imprinted)
            }

            if thenOpenCamera, model.todayRecord != nil {
                requestCamera()
            }
        }
    }

    private func requestAppStoreReviewIfAppropriate() async {
        guard reviewRequestSequence > 0 else { return }
#if DEBUG
        guard ProcessInfo.processInfo.environment["PULSE_UI_TEST_STORE_ID"] == nil else {
            return
        }
#endif
        do {
            try await Task.sleep(for: PulseReviewRequestPolicy.presentationDelay)
        } catch {
            return
        }
        guard !Task.isCancelled,
              isActive,
              scenePhase == .active,
              model.loadState == .ready,
              model.operation == nil,
              model.errorMessage == nil,
              model.todayRecord != nil,
              imprintRitualPhase == .imprinted,
              !showsCamera,
              !showsCameraPermissionAlert,
              !showsTodayMediaDetail,
              !showsTodayJournalEditor,
              model.settings.reserveReviewRequestMilestone(
                totalCheckInCount: model.statistics.totalCount
              ) != nil else {
            return
        }
        requestReview()
    }

    private var isJournalDraftValid: Bool {
        JournalNote.accepts(userInput: draftJournalNote)
    }

    private func synchronizeJournalDraft() {
        draftJournalNote = model.todayRecord?.journalNote ?? ""
    }

    private func requestCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            model.errorMessage = PulseLocalization.string(
                "error.camera_unavailable", locale: locale)
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showsCamera = true
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted {
                    showsCamera = true
                } else {
                    showsCameraPermissionAlert = true
                }
            }
        case .denied, .restricted:
            showsCameraPermissionAlert = true
        @unknown default:
            model.errorMessage = PulseLocalization.string(
                "error.camera_unavailable", locale: locale)
        }
    }

    private func runCompletionMotion() async {
        guard completionAnimationSequence > 0 else { return }
        guard model.todayRecord != nil else {
            resetRitualPresentation(phase: .ready)
            return
        }
        guard !reduceMotion else {
            resetRitualPresentation(phase: .imprinting)
            withAnimation(.easeOut(duration: PulseDesign.imprintReducedMotionFadeDuration)) {
                imprintRitualPhase = .imprinted
            }
            return
        }

        resetRitualPresentation(phase: .contracting)
        await Task.yield()

        withAnimation(.easeIn(duration: PulseDesign.imprintContractionDuration)) {
            imprintGlyphScale = PulseDesign.imprintDotScale
        }

        do {
            try await Task.sleep(for: .seconds(PulseDesign.imprintContractionDuration))
        } catch {
            synchronizeRitualState(isChecked: model.todayRecord != nil)
            return
        }

        imprintRitualPhase = .imprinting
        withAnimation(.easeOut(duration: PulseDesign.imprintFormationDuration)) {
            imprintGlyphScale = PulseDesign.imprintOvershootScale
        }

        do {
            try await Task.sleep(for: .seconds(PulseDesign.imprintFormationDuration))
        } catch {
            synchronizeRitualState(isChecked: model.todayRecord != nil)
            return
        }

        withAnimation(
            .spring(
                response: PulseDesign.imprintSettleDuration,
                dampingFraction: PulseDesign.completionSettleDamping
            )
        ) {
            imprintGlyphScale = 1
        }

        do {
            try await Task.sleep(for: .seconds(PulseDesign.imprintSettleDuration))
        } catch {
            synchronizeRitualState(isChecked: model.todayRecord != nil)
            return
        }
        resetRitualPresentation(phase: .imprinted)
    }

    private func synchronizeRitualState(isChecked: Bool) {
        resetRitualPresentation(phase: isChecked ? .imprinted : .ready)
    }

    private func resetRitualPresentation(phase: ImprintRitualPhase) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            imprintRitualPhase = phase
            imprintGlyphScale = 1
        }
    }


}

private struct TodayMediaDetailSheet: View {
    let media: ImprintMediaSnapshot
    let load: (ImprintMediaSnapshot) async throws -> Data
    let loadOriginal: (ImprintMediaSnapshot) async throws -> Data
    let onRetake: () -> Void
    let onDelete: () async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var showsDeleteConfirmation = false
    @State private var showsOriginal = false

    var body: some View {
        PulseDetailSheetScaffold(
            title: "today.media.title",
            detents: [.large]
        ) {
            ImprintMediaPreviewButton(
                media: media,
                load: load,
                accessibilityIdentifier: "today.media.preview",
                onOpen: { showsOriginal = true }
            )
                .frame(maxWidth: .infinity)
        } actions: {
            PulseDetailActionsMenu(
                accessibilityLabel: "media.actions",
                accessibilityHint: "media.actions_hint",
                accessibilityIdentifier: "today.media.actions.menu"
            ) {
                Button {
                    onRetake()
                } label: {
                    Label("today.media.retake", systemImage: "camera.rotate")
                }
                .accessibilityIdentifier("today.media.retake.action")

                Divider()

                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
                    Label("today.media.delete", systemImage: "trash")
                }
                .tint(PulseDesign.systemDestructive)
                .accessibilityIdentifier("today.media.delete.action")
            }
            .confirmationDialog(
                "media.delete_confirmation.title",
                isPresented: $showsDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("media.delete_confirmation.action", role: .destructive) {
                    Task {
                        if await onDelete() {
                            dismiss()
                        }
                    }
                }
                Button("action.cancel", role: .cancel) {}
            } message: {
                Text("media.delete_confirmation.message")
            }
        }
        .fullScreenCover(isPresented: $showsOriginal) {
            ImprintMediaFullscreenViewer(media: media, load: loadOriginal)
        }
    }
}
