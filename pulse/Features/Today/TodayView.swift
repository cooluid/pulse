import AVFoundation
import PulseCore
import SwiftUI
import UIKit

struct TodayView: View {
    @Bindable var model: PulseAppModel
    let primaryNavigationClearance: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @ScaledMetric(relativeTo: .largeTitle) private var dayNumberSize = PulseDesign.posterDayNumberSize
    @State private var showsSavingIndicator = false
    @State private var completionScale: CGFloat = 1
    @State private var showsCamera = false
    @State private var showsCameraPermissionAlert = false
    @State private var showsMediaDeleteConfirmation = false

    var body: some View {
        ZStack {
            PulsePosterBackground()

            VStack(spacing: 0) {
                PulseAppHeader(source: .today)

                GeometryReader { proxy in
                    ScrollView {
                        todayContent
                            .frame(
                                maxWidth: usesRegularWidthLayout
                                    ? PulseDesign.regularWidthContentMaxWidth
                                    : PulseDesign.screenMaxWidth
                            )
                            .frame(
                                minHeight: usesRegularWidthLayout ? proxy.size.height : nil,
                                alignment: .center
                            )
                            .padding(.horizontal, PulseDesign.horizontalPadding)
                            .padding(
                                .vertical,
                                usesRegularWidthLayout
                                    ? PulseDesign.regularWidthVerticalPadding
                                    : PulseDesign.spacing16
                            )
                            .padding(.bottom, accessibilityScrollClearance)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showsCamera) {
            ImprintCameraView { image, position in
                showsCamera = false
                Task { _ = await model.saveTodayMedia(image: image, cameraPosition: position) }
            } onCancel: {
                showsCamera = false
            }
            .ignoresSafeArea()
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
    }

    @ViewBuilder
    private var todayContent: some View {
        if usesRegularWidthLayout {
            HStack(alignment: .center, spacing: PulseDesign.regularWidthColumnGap) {
                VStack(alignment: .leading, spacing: PulseDesign.spacing24) {
                    posterHero
                    checkInAction
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: PulseDesign.spacing32) {
                    rhythmBlock
                    mediaStrip
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(alignment: .leading, spacing: PulseDesign.spacing32) {
                posterHero
                checkInAction
                    .frame(maxWidth: .infinity)
                rhythmBlock
                mediaStrip
            }
            .padding(.bottom, PulseDesign.spacing24)
        }
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var accessibilityScrollClearance: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? primaryNavigationClearance : 0
    }

    @ViewBuilder
    private var posterHero: some View {
        if let today = model.today, let timeZone = model.timeZone {
            VStack(alignment: .leading, spacing: PulseDesign.spacing16) {
                HStack(alignment: .bottom, spacing: PulseDesign.spacing16) {
                    Text(today.day, format: .number)
                        .font(.system(size: resolvedDayNumberSize, weight: .black))
                        .monospacedDigit()
                        .tracking(-4)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(PulseDesign.ink)
                        .accessibilityIdentifier("today.day.number")

                    VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                        Text(PulseFormatting.numericYearAndMonth(today, timeZone: timeZone))
                        Text(PulseFormatting.fullWeekday(today, timeZone: timeZone, locale: locale))
                    }
                    .font(.caption.weight(.black))
                    .textCase(.uppercase)
                    .foregroundStyle(PulseDesign.ink)
                    .padding(.bottom, PulseDesign.spacing16)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("today.hero.kicker")
                }

                if let commitmentName = model.habit?.name {
                    Text(commitmentName)
                        .font(.system(.largeTitle, design: .default, weight: .black))
                        .foregroundStyle(PulseDesign.ink)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: PulseDesign.posterCommitmentMaximumWidth, alignment: .leading)
                        .accessibilityLabel(
                            String(
                                format: PulseLocalization.string(
                                    "today.commitment.accessibility_format",
                                    locale: locale
                                ),
                                commitmentName
                            )
                        )
                        .accessibilityIdentifier("today.commitment.name")
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var resolvedDayNumberSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? min(dayNumberSize, PulseDesign.posterDayNumberAccessibilityMaximumSize)
            : dayNumberSize
    }

    private var checkInAction: some View {
        let isChecked = model.todayRecord != nil

        return VStack(spacing: PulseDesign.spacing12) {
            ZStack {
                checkInLabel(isChecked: isChecked)

                PulseCombinedPressControl(
                    isEnabled: !isChecked && model.canCheckInToday,
                    accessibilityLabel: checkInAccessibilityLabel,
                    accessibilityHint: isChecked
                        ? ""
                        : PulseLocalization.string("today.accessibility.hint", locale: locale),
                    accessibilityLongPressName: PulseLocalization.string(
                        "today.accessibility.check_in_and_photo",
                        locale: locale
                    )
                ) {
                    performCheckIn(thenOpenCamera: false)
                } onLongPress: {
                    model.notifyPhotoIntentReady()
                    performCheckIn(thenOpenCamera: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .scaleEffect(completionScale)
            .animation(
                reduceMotion ? nil : .spring(response: PulseDesign.checkInStateDuration),
                value: completionScale
            )

            if !isChecked {
                Text("today.check_in_hint_visible")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseDesign.secondary)
                    .multilineTextAlignment(.center)
            }
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

    @ViewBuilder
    private func checkInLabel(isChecked: Bool) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: PulseDesign.spacing16) {
                ZStack {
                    if isChecked {
                        Circle().fill(PulseDesign.grass)
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.black))
                            .foregroundStyle(PulseDesign.grassForeground)
                    } else {
                        PulseOpenRing(color: PulseDesign.action, lineWidth: 8)
                    }
                }
                .frame(width: 52, height: 52)

                checkInText(isChecked: isChecked)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, PulseDesign.spacing20)
            .frame(maxWidth: .infinity, minHeight: PulseDesign.accessibilityActionMinimumHeight)
            .background(isChecked ? PulseDesign.grass : PulseDesign.surface)
            .overlay {
                Rectangle()
                    .stroke(isChecked ? PulseDesign.grass : PulseDesign.action, lineWidth: PulseDesign.emphasisLineWidth)
            }
            .contentShape(Rectangle())
        } else {
            ZStack {
                if isChecked {
                    Circle()
                        .fill(PulseDesign.grass)
                } else {
                    PulseOpenRing(color: PulseDesign.action)
                }

                checkInText(isChecked: isChecked)
            }
            .frame(width: PulseDesign.checkInDiameter, height: PulseDesign.checkInDiameter)
            .contentShape(Circle())
        }
    }

    @ViewBuilder
    private func checkInText(isChecked: Bool) -> some View {
        if model.isSaving && showsSavingIndicator {
            ProgressView()
                .controlSize(.large)
                .tint(PulseDesign.action)
        } else if isChecked {
            VStack(spacing: PulseDesign.spacing8) {
                Image(systemName: "checkmark")
                    .font(.title.weight(.black))
                if let completedCheckInText {
                    Text(completedCheckInText)
                        .font(.caption.weight(.black))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(PulseDesign.grassForeground)
            .multilineTextAlignment(.center)
        } else {
            VStack(spacing: PulseDesign.spacing8) {
                Circle()
                    .stroke(PulseDesign.action, lineWidth: PulseDesign.emphasisLineWidth)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                Text("today.check_in")
                    .font(.title3.weight(.black))
            }
            .foregroundStyle(PulseDesign.action)
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
        let state: String
        if let completedCheckInText {
            state = completedCheckInText
        } else if model.todayRecord != nil {
            state = PulseLocalization.string("today.accessibility.checked", locale: locale)
        } else {
            state = PulseLocalization.string("today.accessibility.check_in", locale: locale)
        }

        guard let commitmentName = model.habit?.name else { return state }
        return String(
            format: PulseLocalization.string(
                "today.accessibility.commitment_state_format",
                locale: locale
            ),
            commitmentName,
            state
        )
    }

    private var rhythmBlock: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing20) {
            weekRail

            Text(rhythmStatusText)
                .font(.title3.weight(.black))
                .monospacedDigit()
                .foregroundStyle(PulseDesign.ink)
                .contentTransition(.numericText(value: Double(model.statistics.currentStreak)))
                .animation(
                    reduceMotion ? nil : .easeOut(duration: PulseDesign.checkInStateDuration),
                    value: model.statistics.currentStreak
                )
                .accessibilityIdentifier("today.rhythm.status")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weekRail: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(PulseDesign.ink)
                .frame(height: PulseDesign.thinLineWidth)
                .padding(.horizontal, PulseDesign.weekRailDotDiameter / 2)
                .padding(.bottom, PulseDesign.weekRailDotDiameter / 2)
                .accessibilityHidden(true)

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(model.recentDays) { item in
                    weekRailDay(item)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: PulseDesign.weekRailWidth)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.week.rail")
    }

    private func weekRailDay(_ item: CalendarDayItem) -> some View {
        let isChecked = item.status == .checked
        let isToday = item.day == model.today

        return VStack(spacing: PulseDesign.spacing8) {
            if let timeZone = model.timeZone {
                Text(PulseFormatting.shortWeekday(item.day, timeZone: timeZone, locale: locale))
                    .font(.caption2.weight(isToday ? .black : .medium))
                    .foregroundStyle(isToday ? PulseDesign.ink : PulseDesign.secondary)
            }

            Circle()
                .fill(isChecked ? PulseDesign.grass : PulseDesign.background)
                .frame(
                    width: PulseDesign.weekRailDotDiameter,
                    height: PulseDesign.weekRailDotDiameter
                )
                .overlay {
                    Circle()
                        .stroke(
                            isToday ? PulseDesign.action : (isChecked ? PulseDesign.grass : PulseDesign.separator),
                            lineWidth: PulseDesign.emphasisLineWidth
                        )
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weekDayAccessibilityLabel(item))
        .accessibilityIdentifier("today.week.day.\(item.day.storageValue)")
    }

    @ViewBuilder
    private var mediaStrip: some View {
        if model.todayRecord != nil,
           model.settings.mediaInvitationEnabled || model.todayMedia != nil {
            VStack(alignment: .leading, spacing: PulseDesign.spacing16) {
                HStack(alignment: .center) {
                    Text("today.media.title")
                        .font(.title3.weight(.black))
                        .foregroundStyle(PulseDesign.ink)
                    Spacer(minLength: PulseDesign.spacing16)
                    Image(systemName: "camera.aperture")
                        .font(.title2.weight(.black))
                        .foregroundStyle(PulseDesign.action)
                        .accessibilityHidden(true)
                }

                if let media = model.todayMedia {
                    ImprintMediaPreview(media: media, load: model.thumbnailData)

                    HStack(spacing: PulseDesign.spacing12) {
                        Button {
                            requestCamera()
                        } label: {
                            Label("today.media.retake", systemImage: "camera.rotate")
                                .frame(minHeight: PulseDesign.minimumHitTarget)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PulseDesign.action)
                        .foregroundStyle(PulseDesign.actionForeground)
                        .accessibilityIdentifier("today.media.retake.button")

                        Button(role: .destructive) {
                            showsMediaDeleteConfirmation = true
                        } label: {
                            Label("today.media.delete", systemImage: "trash")
                                .frame(minHeight: PulseDesign.minimumHitTarget)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("today.media.delete.button")
                        .confirmationDialog(
                            "media.delete_confirmation.title",
                            isPresented: $showsMediaDeleteConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("media.delete_confirmation.action", role: .destructive) {
                                Task { _ = await model.deleteMedia(id: media.id) }
                            }
                            Button("action.cancel", role: .cancel) {}
                        } message: {
                            Text("media.delete_confirmation.message")
                        }
                    }
                } else {
                    Button {
                        requestCamera()
                    } label: {
                        Label("today.media.capture", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity, minHeight: PulseDesign.minimumHitTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PulseDesign.action)
                    .foregroundStyle(PulseDesign.actionForeground)
                    .accessibilityIdentifier("today.media.capture.button")
                }

                if model.operation == .saveMedia {
                    ProgressView("today.media.saving")
                        .font(.footnote)
                }
            }
            .padding(.vertical, PulseDesign.spacing20)
            .frame(maxWidth: PulseDesign.mediaCardMaxWidth)
            .overlay(alignment: .top) {
                Rectangle().fill(PulseDesign.ink).frame(height: PulseDesign.emphasisLineWidth)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(PulseDesign.ink).frame(height: PulseDesign.thinLineWidth)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("today.media.strip")
        }
    }

    private func performCheckIn(thenOpenCamera: Bool) {
        guard model.canCheckInToday else { return }
        Task {
            guard let receipt = await model.checkIn() else { return }
            if receipt.disposition == .created, !reduceMotion {
                completionScale = 0.88
                await Task.yield()
                completionScale = 1
            }
            if thenOpenCamera, model.todayRecord != nil {
                requestCamera()
            }
        }
    }

    private func requestCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            model.errorMessage = PulseLocalization.string("error.camera_unavailable", locale: locale)
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
            model.errorMessage = PulseLocalization.string("error.camera_unavailable", locale: locale)
        }
    }

    private var rhythmStatusText: String {
        guard model.statistics.currentStreak > 0 else {
            return PulseLocalization.string("today.rhythm.start_today", locale: locale)
        }
        return String(
            format: PulseLocalization.string("today.rhythm.streak_format", locale: locale),
            locale: locale,
            arguments: [Int64(model.statistics.currentStreak)]
        )
    }

    private func weekDayAccessibilityLabel(_ item: CalendarDayItem) -> String {
        guard let timeZone = model.timeZone else { return "" }
        let date = PulseFormatting.fullDate(item.day, timeZone: timeZone, locale: locale)
        let state: String
        switch item.status {
        case .beforeHabit:
            state = PulseLocalization.string("calendar.status.before_habit", locale: locale)
        case .checked:
            state = PulseLocalization.string("calendar.status.checked", locale: locale)
        case .missed:
            state = PulseLocalization.string("calendar.status.missed", locale: locale)
        case .todayPending:
            state = PulseLocalization.string("calendar.status.pending", locale: locale)
        case .future:
            state = PulseLocalization.string("calendar.status.future", locale: locale)
        }
        return String(
            format: PulseLocalization.string("accessibility.date_status_format", locale: locale),
            date,
            state
        )
    }
}

private struct PulseCombinedPressControl: UIViewRepresentable {
    let isEnabled: Bool
    let accessibilityLabel: String
    let accessibilityHint: String
    let accessibilityLongPressName: String
    let onTap: @MainActor () -> Void
    let onLongPress: @MainActor () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PulsePressControl {
        let view = PulsePressControl(frame: .zero)
        view.backgroundColor = .clear
        view.actionHandler = context.coordinator
        configureAccessibility(view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: PulsePressControl, context: Context) {
        context.coordinator.parent = self
        uiView.isEnabled = isEnabled
        configureAccessibility(uiView, coordinator: context.coordinator)
    }

    private func configureAccessibility(
        _ view: PulsePressControl,
        coordinator: Coordinator
    ) {
        view.isAccessibilityElement = true
        view.accessibilityTraits = isEnabled ? .button : [.button, .notEnabled]
        view.accessibilityIdentifier = "today.checkin.button"
        view.accessibilityLabel = accessibilityLabel
        view.accessibilityHint = accessibilityHint
        view.accessibilityCustomActions = isEnabled
            ? [
                UIAccessibilityCustomAction(
                    name: accessibilityLongPressName,
                    target: coordinator,
                    selector: #selector(Coordinator.handleAccessibilityLongPress)
                )
            ]
            : nil
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: PulseCombinedPressControl

        init(parent: PulseCombinedPressControl) {
            self.parent = parent
        }

        @objc func handleTap(_ control: UIControl) {
            guard control.isEnabled else { return }
            parent.onTap()
        }

        func handleLongPress() {
            guard parent.isEnabled else { return }
            parent.onLongPress()
        }

        @objc func handleAccessibilityLongPress() -> Bool {
            guard parent.isEnabled else { return false }
            parent.onLongPress()
            return true
        }
    }

    @MainActor
    final class PulsePressControl: UIControl {
        weak var actionHandler: Coordinator?
        private var longPressTimer: Timer?
        private var touchOrigin: CGPoint?
        private var didRecognizeLongPress = false

        override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            guard isEnabled else { return false }
            touchOrigin = touch.location(in: self)
            didRecognizeLongPress = false
            longPressTimer?.invalidate()
            longPressTimer = Timer.scheduledTimer(
                timeInterval: PulseDesign.checkInLongPressDuration,
                target: self,
                selector: #selector(recognizeLongPress),
                userInfo: nil,
                repeats: false
            )
            return true
        }

        override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            guard let touchOrigin else { return false }
            let point = touch.location(in: self)
            let distance = hypot(point.x - touchOrigin.x, point.y - touchOrigin.y)
            if distance > PulseDesign.checkInPressMovementTolerance {
                cancelPendingPress()
                return false
            }
            return true
        }

        override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
            longPressTimer?.invalidate()
            longPressTimer = nil
            touchOrigin = nil
            if !didRecognizeLongPress {
                actionHandler?.handleTap(self)
            }
            didRecognizeLongPress = false
        }

        override func cancelTracking(with event: UIEvent?) {
            cancelPendingPress()
        }

        @objc private func recognizeLongPress() {
            guard isEnabled, isTracking else { return }
            didRecognizeLongPress = true
            actionHandler?.handleLongPress()
        }

        private func cancelPendingPress() {
            longPressTimer?.invalidate()
            longPressTimer = nil
            touchOrigin = nil
            didRecognizeLongPress = false
        }

        override func accessibilityActivate() -> Bool {
            guard isEnabled, let actionHandler else { return false }
            actionHandler.handleTap(self)
            return true
        }
    }
}
