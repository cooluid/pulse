import AVFoundation
import PulseCore
import SwiftUI
import UIKit

struct TodayView: View {
    @Bindable var model: PulseAppModel
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @Environment(\.pulseVisualTheme) private var visualTheme
    @ScaledMetric(relativeTo: .largeTitle) private var dayNumberSize = PulseDesign.dayNumberBaseSize
    @ScaledMetric(relativeTo: .largeTitle) private var archiveDayNumberSize =
        PulseDesign.archiveDayNumberBaseSize
    @State private var showsSavingIndicator = false
    @State private var imprintRitualPhase: ImprintRitualPhase = .ready
    @State private var completionAnimationSequence = 0
    @State private var imprintGlyphScale: CGFloat = 1
    @State private var completionRippleVisible = false
    @State private var completionRippleExpanded = false
    @State private var isCheckInPressed = false
    @State private var showsCamera = false
    @State private var showsCameraPermissionAlert = false
    @State private var showsTodayMediaDetail = false
    @State private var showsTodayJournalEditor = false
    @State private var draftJournalNote = ""
    @FocusState private var isJournalFocused: Bool

    var body: some View {
        ZStack {
            PulseScreenBackground()
            PulseFieldBackground(
                presentation: .today,
                isCompleted: model.todayRecord != nil
            )

            VStack(spacing: 0) {
                PulseAppHeader(source: .today)

                GeometryReader { proxy in
                    ScrollView {
                        todayContent
                            .frame(
                                maxWidth: todayContentMaxWidth
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
                                    : PulseDesign.spacing4
                            )
                            .padding(.bottom, PulseDesign.spacing16)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                }
            }

            runtimePresentationMarkers
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
        .sheet(isPresented: $showsTodayMediaDetail) {
            if let media = model.todayMedia {
                TodayMediaDetailSheet(
                    media: media,
                    load: model.thumbnailData,
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
    }

    @ViewBuilder
    private var todayContent: some View {
        switch visualTheme {
        case .tideArchive:
            archiveContent
        case .editorialJournal:
            EditorialTodayContent(
                model: model,
                draftJournalNote: $draftJournalNote,
                isJournalFocused: $isJournalFocused,
                onCheckIn: { performCheckIn(thenOpenCamera: false) },
                onEditJournal: { showsTodayJournalEditor = true },
                onCaptureMedia: requestCamera,
                onShowMedia: { showsTodayMediaDetail = true }
            )
        case .quietField:
            quietFieldContent
        }
    }

    private var runtimePresentationMarkers: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(visualTheme.localizedName(locale: locale))
                .accessibilityIdentifier(themeMarkerIdentifier)

            if imprintRitualPhase == .imprinted {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        PulseLocalization.string("today.accessibility.checked", locale: locale)
                    )
                    .accessibilityIdentifier("today.checkin.presentation.imprinted")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var themeMarkerIdentifier: String {
        switch visualTheme {
        case .quietField:
            "today.theme.quiet-field"
        case .editorialJournal:
            "today.theme.editorial-journal"
        case .tideArchive:
            "today.theme.tide-archive"
        }
    }

    @ViewBuilder
    private var quietFieldContent: some View {
        if usesRegularWidthLayout {
            HStack(alignment: .center, spacing: PulseDesign.regularWidthColumnGap) {
                VStack(spacing: 0) {
                    dayHero
                    checkInControl
                        .padding(.top, PulseDesign.checkInHeroSpacing)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 0) {
                    weekRail
                    rhythmStatus
                        .padding(.top, PulseDesign.spacing32)
                    todayJournalSection
                        .padding(.top, PulseDesign.spacing24)
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: 0) {
                dayHero
                checkInControl
                    .padding(.top, PulseDesign.checkInHeroSpacing)
                todayJournalSection
                    .padding(.top, PulseDesign.spacing24)
                weekRail
                    .padding(.top, PulseDesign.spacing24)
                rhythmStatus
                    .padding(.top, PulseDesign.spacing24)
            }
            .padding(.bottom, PulseDesign.spacing24)
        }
    }

    @ViewBuilder
    private var archiveContent: some View {
        if usesRegularWidthLayout {
            HStack(alignment: .center, spacing: PulseDesign.regularWidthColumnGap) {
                VStack(spacing: 0) {
                    archiveDayHero
                    checkInControl
                        .padding(.top, PulseDesign.checkInHeroSpacing)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 0) {
                    weekRail
                    archiveRhythmStatus
                        .padding(.top, PulseDesign.spacing24)
                    todayJournalSection
                        .padding(.top, PulseDesign.spacing20)
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: 0) {
                archiveDayHero
                checkInControl
                    .padding(.top, PulseDesign.spacing20)
                todayJournalSection
                    .padding(.top, PulseDesign.spacing24)
                weekRail
                    .padding(.top, PulseDesign.spacing24)
                archiveRhythmStatus
                    .padding(.top, PulseDesign.spacing16)
            }
            .padding(.bottom, PulseDesign.spacing24)
        }
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var todayContentMaxWidth: CGFloat {
        if visualTheme == .editorialJournal {
            return PulseDesign.editorialContentMaxWidth
        }
        return usesRegularWidthLayout
            ? PulseDesign.regularWidthContentMaxWidth
            : PulseDesign.screenMaxWidth
    }

    private var dayHero: some View {
        VStack(spacing: 0) {
            if let today = model.today, let timeZone = model.timeZone {
                let weekday = PulseFormatting.fullWeekday(
                    today,
                    timeZone: timeZone,
                    locale: locale
                )

                Text(
                    String(
                        format: PulseLocalization.string(
                            "today.kicker_with_weekday_format",
                            locale: locale
                        ),
                        PulseFormatting.numericYearAndMonth(today, timeZone: timeZone),
                        weekday
                    )
                )
                .font(.system(.caption2, design: .default, weight: .bold))
                .foregroundStyle(PulseDesign.ink)
                .accessibilityIdentifier("today.hero.kicker")

                dayNumber(today)
                    .padding(.top, PulseDesign.spacing12)

                if let commitmentName = model.habit?.name {
                    commitmentCue(commitmentName)
                        .padding(.top, PulseDesign.spacing16)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PulseDesign.spacing20)
        .padding(.top, PulseDesign.spacing32)
        .padding(.bottom, PulseDesign.spacing20)
        .frame(minHeight: PulseDesign.todayHeroMinimumHeight, alignment: .top)
        .accessibilityElement(children: .contain)
    }

    private var archiveDayHero: some View {
        VStack(spacing: 0) {
            if let today = model.today, let timeZone = model.timeZone {
                let weekday = PulseFormatting.fullWeekday(
                    today,
                    timeZone: timeZone,
                    locale: locale
                )

                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
                            Text(today.day, format: .number)
                                .font(
                                    .system(
                                        size: resolvedArchiveDayNumberSize,
                                        weight: .light
                                    )
                                )
                                .monospacedDigit()
                                .tracking(PulseDesign.archiveDayNumberTracking)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundStyle(PulseDesign.ink)
                                .accessibilityIdentifier("today.day.number")

                            Text(weekday)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(PulseDesign.ink)

                            Text(PulseFormatting.numericYearAndMonth(today, timeZone: timeZone))
                                .font(.body)
                                .monospacedDigit()
                                .foregroundStyle(PulseDesign.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("today.hero.kicker")
                    } else {
                        HStack(alignment: .bottom, spacing: PulseDesign.spacing20) {
                            Text(today.day, format: .number)
                                .font(
                                    .system(
                                        size: resolvedArchiveDayNumberSize,
                                        weight: .light
                                    )
                                )
                                .monospacedDigit()
                                .tracking(PulseDesign.archiveDayNumberTracking)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundStyle(PulseDesign.ink)
                                .accessibilityIdentifier("today.day.number")

                            Spacer(minLength: PulseDesign.spacing16)

                            VStack(alignment: .trailing, spacing: PulseDesign.spacing4) {
                                Text(weekday)
                                    .font(.subheadline.weight(.medium))

                                Text(
                                    PulseFormatting.numericYearAndMonth(
                                        today,
                                        timeZone: timeZone
                                    )
                                )
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(PulseDesign.secondary)
                            }
                            .foregroundStyle(PulseDesign.ink)
                            .padding(.bottom, PulseDesign.spacing8)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("today.hero.kicker")
                        }
                    }
                }
                .padding(dynamicTypeSize.isAccessibilitySize ? PulseDesign.spacing16 : 0)
                .background {
                    if dynamicTypeSize.isAccessibilitySize {
                        RoundedRectangle(
                            cornerRadius: PulseDesign.archiveHistoryPanelCornerRadius,
                            style: .continuous
                        )
                        .fill(PulseDesign.archivePaper)
                    }
                }
                .padding(.bottom, PulseDesign.spacing16)
                .overlay(alignment: .bottom) {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(PulseDesign.archiveCopper)
                            .frame(width: PulseDesign.archiveHistoryAccentWidth)
                        Rectangle()
                            .fill(
                                PulseDesign.archiveTide.opacity(
                                    PulseDesign.archiveNavigationDividerOpacity
                                )
                            )
                    }
                    .frame(height: PulseDesign.thinLineWidth)
                    .accessibilityHidden(true)
                }

                if let commitmentName = model.habit?.name {
                    VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                        Text("today.commitment.cue")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(PulseDesign.secondary)

                        Text(commitmentName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(PulseDesign.ink)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(dynamicTypeSize.isAccessibilitySize ? PulseDesign.spacing16 : 0)
                    .background {
                        if dynamicTypeSize.isAccessibilitySize {
                            RoundedRectangle(
                                cornerRadius: PulseDesign.archiveHistoryPanelCornerRadius,
                                style: .continuous
                            )
                            .fill(PulseDesign.archivePaper)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(PulseDesign.archiveCopper)
                                    .frame(width: PulseDesign.emphasisLineWidth)
                                    .padding(.vertical, PulseDesign.spacing12)
                            }
                        }
                    }
                    .padding(.top, PulseDesign.spacing16)
                    .accessibilityElement(children: .ignore)
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
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PulseDesign.spacing20)
        .padding(.top, PulseDesign.spacing24)
        .padding(.bottom, PulseDesign.spacing16)
        .frame(minHeight: PulseDesign.archiveTodayHeroMinimumHeight, alignment: .top)
        .accessibilityElement(children: .contain)
    }

    private func dayNumber(_ today: LogicalDay) -> some View {
        Text(today.day, format: .number)
            .font(.system(size: resolvedDayNumberSize, weight: .regular))
            .monospacedDigit()
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(PulseDesign.ink)
            .accessibilityIdentifier("today.day.number")
    }

    private func commitmentCue(_ name: String) -> some View {
        VStack(spacing: PulseDesign.spacing4) {
            Text("today.commitment.cue")
                .font(.caption.weight(.medium))
                .foregroundStyle(PulseDesign.secondary)

            Text(name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PulseDesign.ink)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: PulseDesign.todayCommitmentMaximumWidth)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: PulseLocalization.string(
                    "today.commitment.accessibility_format",
                    locale: locale
                ),
                name
            )
        )
        .accessibilityIdentifier("today.commitment.name")
    }

    private var resolvedDayNumberSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? min(dayNumberSize, PulseDesign.dayNumberAccessibilityMaximumSize)
            : dayNumberSize
    }

    private var resolvedArchiveDayNumberSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? min(archiveDayNumberSize, PulseDesign.dayNumberAccessibilityMaximumSize)
            : archiveDayNumberSize
    }

    @ViewBuilder
    private var weekRail: some View {
        if visualTheme == .tideArchive {
            archiveWeekRail
        } else {
            quietWeekRail
        }
    }

    private var quietWeekRail: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(PulseDesign.separator)
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
        .frame(width: PulseDesign.weekRailWidth)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.week.rail")
    }

    private var archiveWeekRail: some View {
        VStack(spacing: PulseDesign.spacing12) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(model.recentDays) { item in
                    archiveWeekRailDay(item)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.week.rail")
    }

    private func weekRailDay(_ item: CalendarDayItem) -> some View {
        let isChecked = item.status == .checked
        let isToday = item.day == model.today

        return VStack(spacing: PulseDesign.spacing8) {
            if let timeZone = model.timeZone {
                Text(
                    PulseFormatting.shortWeekday(
                        item.day,
                        timeZone: timeZone,
                        locale: locale
                    )
                )
                .font(.system(.caption2, design: .default, weight: isToday ? .bold : .regular))
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
                            isToday || isChecked
                                ? PulseDesign.grass
                                : PulseDesign.separator,
                            lineWidth: PulseDesign.emphasisLineWidth
                        )
                }
        }
        .animation(completionSecondaryAnimation, value: item.status)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weekDayAccessibilityLabel(item))
        .accessibilityIdentifier("today.week.day.\(item.day.storageValue)")
    }

    private func archiveWeekRailDay(_ item: CalendarDayItem) -> some View {
        let isChecked = item.status == .checked
        let isToday = item.day == model.today

        return VStack(spacing: PulseDesign.spacing8) {
            if let timeZone = model.timeZone {
                Text(
                    PulseFormatting.shortWeekday(
                        item.day,
                        timeZone: timeZone,
                        locale: locale
                    )
                )
                .font(.system(.caption2, design: .default, weight: isToday ? .bold : .regular))
                .foregroundStyle(PulseDesign.archiveForeground.opacity(isToday ? 1 : 0.72))
            }

            ZStack {
                RoundedRectangle(
                    cornerRadius: PulseDesign.archiveWeekMarkCornerRadius,
                    style: .continuous
                )
                    .fill(isChecked ? PulseDesign.archiveCopper : Color.clear)
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: PulseDesign.archiveWeekMarkCornerRadius,
                            style: .continuous
                        )
                            .stroke(
                                isToday
                                    ? PulseDesign.archiveForeground
                                    : PulseDesign.archiveForeground.opacity(
                                        PulseDesign.archiveWeekInactiveStrokeOpacity
                                    ),
                                lineWidth: isToday
                                    ? PulseDesign.emphasisLineWidth
                                    : PulseDesign.thinLineWidth
                            )
                    }

                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(PulseDesign.archiveNight)
                } else if isToday {
                    Text(item.day.day, format: .number)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(PulseDesign.archiveForeground)
                } else {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(
                            PulseDesign.archiveForeground.opacity(
                                PulseDesign.archiveWeekInactiveForegroundOpacity
                            )
                        )
                }
            }
            .frame(
                width: PulseDesign.archiveWeekMarkSize,
                height: PulseDesign.archiveWeekMarkSize
            )
        }
        .animation(completionSecondaryAnimation, value: item.status)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weekDayAccessibilityLabel(item))
        .accessibilityIdentifier("today.week.day.\(item.day.storageValue)")
    }

    private var checkInControl: some View {
        let isChecked = model.todayRecord != nil
        let controlFill = visualTheme == .tideArchive
            ? (isChecked ? PulseDesign.archiveCopper : PulseDesign.archiveForeground)
            : (isChecked ? PulseDesign.grass : PulseDesign.action)
        let controlForeground = visualTheme == .tideArchive
            ? PulseDesign.archiveNight
            : (isChecked ? PulseDesign.grassForeground : PulseDesign.actionForeground)

        return VStack(spacing: PulseDesign.spacing12) {
            checkInVisual(
                isChecked: isChecked,
                fill: controlFill,
                foreground: controlForeground
            )
            .overlay {
                PulseCombinedPressControl(
                    isEnabled: !isChecked && model.canCheckInToday && isJournalDraftValid,
                    accessibilityLabel: checkInAccessibilityLabel,
                    accessibilityHint: isChecked
                        ? ""
                        : PulseLocalization.string("today.accessibility.hint", locale: locale),
                    accessibilityLongPressName: PulseLocalization.string(
                        "today.accessibility.check_in_and_photo",
                        locale: locale
                    ),
                    onPressChanged: { isPressed in
                        isCheckInPressed = isPressed
                    },
                    onTap: {
                        performCheckIn(thenOpenCamera: false)
                    },
                    onLongPress: {
                        model.notifyPhotoIntentReady()
                        performCheckIn(thenOpenCamera: true)
                    }
                )
            }
            .overlay(alignment: .bottomTrailing) {
                if isChecked, !dynamicTypeSize.isAccessibilitySize {
                    mediaCompanionAction
                        .offset(
                            x: PulseDesign.mediaCompanionOffsetX,
                            y: PulseDesign.mediaCompanionOffsetY
                        )
                }
            }
            .scaleEffect(
                !reduceMotion && (isCheckInPressed || model.isSaving) ? 0.97 : 1
            )
            .animation(
                reduceMotion ? nil : .easeInOut(duration: PulseDesign.savingAnimationDuration),
                value: isCheckInPressed
            )
            .animation(
                reduceMotion ? nil : .easeInOut(duration: PulseDesign.savingAnimationDuration),
                value: model.isSaving
            )

            if isChecked, dynamicTypeSize.isAccessibilitySize {
                mediaCompanionAction
            }

            if !isChecked {
                Text("today.check_in_hint_visible")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(
                        visualTheme == .tideArchive
                            ? PulseDesign.archiveForeground.opacity(
                                PulseDesign.archiveNavigationUnselectedOpacity
                            )
                            : PulseDesign.secondary
                    )
                    .multilineTextAlignment(.center)
            }
        }
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

    @ViewBuilder
    private func checkInVisual(
        isChecked: Bool,
        fill: Color,
        foreground: Color
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: PulseDesign.spacing12) {
                checkInStatusContent(foreground: foreground)
            }
            .padding(.horizontal, PulseDesign.spacing24)
            .frame(maxWidth: .infinity, minHeight: PulseDesign.accessibilityActionMinimumHeight)
            .background(fill, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        foreground.opacity(PulseDesign.actionBorderOpacity),
                        lineWidth: PulseDesign.thinLineWidth
                    )
            }
            .contentShape(Capsule())
        } else if visualTheme == .tideArchive {
            ZStack {
                Circle()
                    .fill(fill)
                    .overlay {
                        Circle()
                            .stroke(
                                PulseDesign.archiveCopper.opacity(
                                    isChecked ? 0.62 : 1
                                ),
                                lineWidth: PulseDesign.emphasisLineWidth
                            )
                    }
                    .shadow(
                        color: PulseDesign.archiveNight.opacity(
                            PulseDesign.archiveCheckInShadowOpacity
                        ),
                        radius: PulseDesign.spacing16,
                        y: PulseDesign.spacing8
                    )

                checkInStatusContent(foreground: foreground)
            }
            .frame(
                width: PulseDesign.archiveCheckInDiameter,
                height: PulseDesign.archiveCheckInDiameter
            )
            .background {
                ZStack {
                    Rectangle()
                        .fill(
                            PulseDesign.archiveMist.opacity(
                                PulseDesign.archiveHorizonGuideOpacity
                            )
                        )
                        .frame(
                            width: PulseDesign.archiveHorizonMarkerWidth,
                            height: PulseDesign.thinLineWidth
                        )

                    Circle()
                        .fill(PulseDesign.archiveCopper)
                        .frame(
                            width: PulseDesign.archiveHorizonMarkerDot,
                            height: PulseDesign.archiveHorizonMarkerDot
                        )
                        .offset(x: -PulseDesign.archiveHorizonMarkerWidth / 2)

                    Circle()
                        .stroke(
                            PulseDesign.archiveCopper.opacity(
                                PulseDesign.completionRippleOpacity
                            ),
                            lineWidth: PulseDesign.emphasisLineWidth
                        )
                        .frame(
                            width: PulseDesign.archiveCheckInDiameter,
                            height: PulseDesign.archiveCheckInDiameter
                        )
                        .scaleEffect(
                            completionRippleExpanded
                                ? PulseDesign.completionRippleEndScale
                                : PulseDesign.completionRippleStartScale
                        )
                        .opacity(completionRippleVisible ? 1 : 0)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .contentShape(Circle())
            .animation(completionSecondaryAnimation, value: isChecked)
        } else {
            ZStack {
                Circle()
                    .fill(fill)
                    .overlay {
                        Circle()
                            .stroke(
                                foreground.opacity(PulseDesign.actionBorderOpacity),
                                lineWidth: PulseDesign.thinLineWidth
                            )
                    }
                    .shadow(
                        color: PulseDesign.shadow.opacity(PulseDesign.actionShadowOpacity),
                        radius: PulseDesign.actionShadowRadius,
                        y: PulseDesign.actionShadowY
                    )

                checkInStatusContent(foreground: foreground)
            }
            .frame(width: PulseDesign.checkInDiameter, height: PulseDesign.checkInDiameter)
            .background {
                ZStack {
                    PulseCheckInIdleAura(
                        isBreathing: isActive && !isChecked && model.canCheckInToday
                    )

                    Circle()
                        .stroke(
                            PulseDesign.grass.opacity(PulseDesign.completionRippleOpacity),
                            lineWidth: PulseDesign.emphasisLineWidth
                        )
                        .frame(
                            width: PulseDesign.checkInDiameter,
                            height: PulseDesign.checkInDiameter
                        )
                        .scaleEffect(
                            completionRippleExpanded
                                ? PulseDesign.completionRippleEndScale
                                : PulseDesign.completionRippleStartScale
                        )
                        .opacity(completionRippleVisible ? 1 : 0)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .contentShape(Circle())
        }
    }

    @ViewBuilder
    private func checkInStatusContent(foreground: Color) -> some View {
        if imprintRitualPhase == .contracting || imprintRitualPhase == .imprinting {
            PulseImprintGlyph(
                isSolid: imprintRitualPhase.usesSolidGlyph,
                foreground: foreground
            )
            .scaleEffect(imprintGlyphScale)
        } else if imprintRitualPhase == .saving {
            if model.isSaving && showsSavingIndicator {
                ProgressView()
                    .controlSize(.large)
                    .tint(foreground)
                    .transition(.opacity)
            } else {
                pendingCheckInStatusContent(foreground: foreground)
            }
        } else if let completedCheckInText {
            VStack(spacing: PulseDesign.spacing4) {
                PulseImprintGlyph(isSolid: true, foreground: foreground)

                Text(completedCheckInText)
                    .font(.headline.bold())
            }
            .foregroundStyle(foreground)
            .multilineTextAlignment(.center)
            .transition(.opacity)
        } else {
            pendingCheckInStatusContent(foreground: foreground)
        }
    }

    private func pendingCheckInStatusContent(foreground: Color) -> some View {
        VStack(spacing: PulseDesign.spacing8) {
            PulseImprintGlyph(isSolid: false, foreground: foreground)

            Text("today.check_in")
                .font(.headline.bold())
        }
        .foregroundStyle(foreground)
        .transition(.opacity)
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

    private var rhythmStatus: some View {
        Text(rhythmStatusText)
            .font(.footnote.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(PulseDesign.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .contentTransition(.numericText(value: Double(model.statistics.currentStreak)))
            .animation(
                completionSecondaryAnimation,
                value: model.statistics.currentStreak
            )
            .accessibilityIdentifier("today.rhythm.status")
    }

    private var archiveRhythmStatus: some View {
        Text(rhythmStatusText)
            .font(.footnote.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(
                PulseDesign.archiveForeground.opacity(PulseDesign.archiveRhythmOpacity)
            )
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .contentTransition(.numericText(value: Double(model.statistics.currentStreak)))
            .animation(
                completionSecondaryAnimation,
                value: model.statistics.currentStreak
            )
        .accessibilityIdentifier("today.rhythm.status")
    }

    @ViewBuilder
    private var todayJournalSection: some View {
        if let record = model.todayRecord {
            JournalNoteSummary(record: record) {
                showsTodayJournalEditor = true
            }
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
        if model.settings.mediaInvitationEnabled || model.todayMedia != nil {
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
                        .font(.caption.bold())
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    }
                }
            }
            .foregroundStyle(
                visualTheme == .tideArchive
                    ? PulseDesign.archiveNight
                    : PulseDesign.action
            )
            .padding(.horizontal, PulseDesign.spacing12)
            .frame(minHeight: PulseDesign.minimumHitTarget)
            .background(
                visualTheme == .tideArchive
                    ? PulseDesign.archiveForeground
                    : PulseDesign.surface,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        visualTheme == .tideArchive
                            ? PulseDesign.archiveCopper
                            : PulseDesign.grass,
                        lineWidth: PulseDesign.thinLineWidth
                    )
            }
            .shadow(
                color: PulseDesign.shadow.opacity(PulseDesign.mediaCompanionShadowOpacity),
                radius: PulseDesign.mediaCompanionShadowRadius,
                y: PulseDesign.mediaCompanionShadowY
            )
            .buttonStyle(.plain)
            .disabled(model.operation == .saveMedia)
            .accessibilityIdentifier(
                model.todayMedia == nil
                    ? "today.media.capture.button"
                    : "today.media.preview.button"
            )
        }
    }

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
            case .alreadyPresent:
                resetRitualPresentation(phase: .imprinted)
            }

            if thenOpenCamera, model.todayRecord != nil {
                requestCamera()
            }
        }
    }

    private var isJournalDraftValid: Bool {
        JournalNote.accepts(userInput: draftJournalNote)
    }

    private func synchronizeJournalDraft() {
        draftJournalNote = model.todayRecord?.journalNote ?? ""
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

    private var completionSecondaryAnimation: Animation? {
        reduceMotion
            ? nil
            : .easeOut(duration: PulseDesign.completionSecondaryDuration)
                .delay(PulseDesign.completionSecondaryDelay)
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
        completionRippleVisible = true
        completionRippleExpanded = false
        withAnimation(.easeOut(duration: PulseDesign.completionRippleDuration)) {
            completionRippleExpanded = true
            completionRippleVisible = false
        }
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
            completionRippleVisible = false
            completionRippleExpanded = false
        }
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
private struct PulseImprintGlyph: View {
    let isSolid: Bool
    let foreground: Color

    var body: some View {
        Circle()
            .fill(isSolid ? foreground : .clear)
            .overlay {
                Circle()
                    .stroke(
                        foreground,
                        lineWidth: PulseDesign.imprintGlyphLineWidth
                    )
                    .opacity(isSolid ? 0 : 1)
            }
            .frame(
                width: PulseDesign.imprintGlyphSize,
                height: PulseDesign.imprintGlyphSize
            )
            .accessibilityHidden(true)
    }
}

private struct PulseCheckInIdleAura: View {
    let isBreathing: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            Circle()
                .fill(PulseDesign.grass.opacity(PulseDesign.outerHaloOpacity))
                .frame(
                    width: PulseDesign.checkInDiameter + PulseDesign.checkInOuterHalo * 2,
                    height: PulseDesign.checkInDiameter + PulseDesign.checkInOuterHalo * 2
                )
                .scaleEffect(auraScale)
                .opacity(auraOpacity)

            Circle()
                .stroke(
                    PulseDesign.grass.opacity(PulseDesign.idleAuraRingOpacity),
                    lineWidth: PulseDesign.thinLineWidth
                )
                .frame(
                    width: PulseDesign.checkInDiameter + PulseDesign.checkInInnerHalo * 2,
                    height: PulseDesign.checkInDiameter + PulseDesign.checkInInnerHalo * 2
                )
                .scaleEffect(auraScale)
                .opacity(idleRingOpacity)

            Circle()
                .fill(PulseDesign.grass.opacity(PulseDesign.innerHaloOpacity))
                .frame(
                    width: PulseDesign.checkInDiameter + PulseDesign.checkInInnerHalo * 2,
                    height: PulseDesign.checkInDiameter + PulseDesign.checkInInnerHalo * 2
                )
        }
        .task(id: motionEnabled) {
            await runFiniteBreath()
        }
    }

    private var motionEnabled: Bool {
        isBreathing && !reduceMotion && scenePhase == .active
    }

    private var auraScale: CGFloat {
        guard motionEnabled else { return 1 }
        return isExpanded
            ? PulseDesign.idleAuraExpandedScale
            : PulseDesign.idleAuraCollapsedScale
    }

    private var auraOpacity: Double {
        guard motionEnabled else { return 1 }
        return isExpanded ? 1 : PulseDesign.idleAuraCollapsedOpacity
    }

    private var idleRingOpacity: Double {
        guard motionEnabled else { return 0 }
        return isExpanded
            ? PulseDesign.idleAuraRingExpandedOpacity
            : 1
    }

    private func runFiniteBreath() async {
        guard motionEnabled else {
            resetMotion()
            return
        }

        resetMotion()
        await Task.yield()
        withAnimation(.easeInOut(duration: PulseDesign.idleAuraBreathHalfDuration)) {
            isExpanded = true
        }

        do {
            try await Task.sleep(for: .seconds(PulseDesign.idleAuraBreathHalfDuration))
        } catch {
            resetMotion()
            return
        }

        withAnimation(.easeInOut(duration: PulseDesign.idleAuraBreathHalfDuration)) {
            isExpanded = false
        }
    }

    private func resetMotion() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isExpanded = false
        }
    }
}

private struct TodayMediaDetailSheet: View {
    let media: ImprintMediaSnapshot
    let load: (ImprintMediaSnapshot) async throws -> Data
    let onRetake: () -> Void
    let onDelete: () async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var showsDeleteConfirmation = false

    var body: some View {
        PulseDetailSheetScaffold(
            title: "today.media.title",
            detents: [.large]
        ) {
            ImprintMediaPreview(media: media, load: load)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("today.media.preview")
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
    }
}

private struct PulseCombinedPressControl: UIViewRepresentable {
    let isEnabled: Bool
    let accessibilityLabel: String
    let accessibilityHint: String
    let accessibilityLongPressName: String
    let onPressChanged: @MainActor (Bool) -> Void
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
        let shouldResetPress = uiView.isEnabled && !isEnabled
        uiView.isEnabled = isEnabled
        configureAccessibility(uiView, coordinator: context.coordinator)
        if shouldResetPress {
            Task { @MainActor in
                context.coordinator.handlePressChanged(false)
            }
        }
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

        func handlePressChanged(_ isPressed: Bool) {
            parent.onPressChanged(isPressed)
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
            actionHandler?.handlePressChanged(true)
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
            actionHandler?.handlePressChanged(false)
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
            actionHandler?.handlePressChanged(false)
        }

        override func accessibilityActivate() -> Bool {
            guard isEnabled, let actionHandler else { return false }
            actionHandler.handleTap(self)
            return true
        }
    }
}
