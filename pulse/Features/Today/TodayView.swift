import AVFoundation
import PulseCore
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
    @ScaledMetric(relativeTo: .largeTitle) private var dayNumberSize = PulseDesign.dayNumberBaseSize
    @ScaledMetric(relativeTo: .largeTitle) private var sunlitDayNumberSize =
        PulseDesign.sunlitDayNumberBaseSize
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
            PulseFieldBackground(presentation: .today, allowsMotion: isActive)

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
        case .sunlitDay:
            sunlitContent
        case .editorialJournal:
            EditorialTodayContent(
                model: model,
                draftJournalNote: $draftJournalNote,
                isJournalFocused: $isJournalFocused,
                onEditJournal: { showsTodayJournalEditor = true },
                checkInControl: checkInControl
            )
        case .quietField:
            quietFieldContent
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
    private var sunlitContent: some View {
        if usesRegularWidthLayout {
            HStack(alignment: .center, spacing: PulseDesign.regularWidthColumnGap) {
                VStack(spacing: 0) {
                    sunlitDayHero
                    checkInControl
                        .padding(.top, PulseDesign.checkInHeroSpacing)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 0) {
                    weekRail
                    sunlitRhythmStatus
                        .padding(.top, PulseDesign.spacing24)
                    todayJournalSection
                        .padding(.top, PulseDesign.spacing20)
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: 0) {
                sunlitDayHero
                checkInControl
                    .padding(.top, PulseDesign.spacing8)
                todayJournalSection
                    .padding(.top, PulseDesign.spacing20)
                weekRail
                    .padding(.top, PulseDesign.spacing24)
                sunlitRhythmStatus
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
                .font(.system(.caption2, design: .rounded, weight: .black))
                .foregroundStyle(PulseDesign.quietChromeForeground)
                .textCase(.uppercase)
                .padding(.horizontal, PulseDesign.spacing16)
                .frame(minHeight: PulseDesign.spacing32)
                .background(PulseDesign.quietChrome, in: Capsule())
                .accessibilityIdentifier("today.hero.kicker")

                dayNumber(today)
                    .padding(.top, PulseDesign.spacing8)

                if let commitmentName = model.habit?.name {
                    commitmentCue(commitmentName)
                        .padding(.top, PulseDesign.spacing8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PulseDesign.spacing20)
        .padding(.top, PulseDesign.spacing20)
        .padding(.bottom, PulseDesign.spacing12)
        .frame(minHeight: PulseDesign.todayHeroMinimumHeight, alignment: .top)
        .accessibilityElement(children: .contain)
    }

    private var sunlitDayHero: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            if let today = model.today, let timeZone = model.timeZone {
                let weekday = PulseFormatting.fullWeekday(
                    today,
                    timeZone: timeZone,
                    locale: locale
                )

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
                        Text(today.day, format: .number)
                            .font(
                                .system(
                                    size: min(resolvedSunlitDayNumberSize, 112),
                                    weight: .black,
                                    design: .rounded
                                )
                            )
                            .monospacedDigit()
                            .tracking(PulseDesign.sunlitDayNumberTracking)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(PulseDesign.sunlitInk)
                            .accessibilityIdentifier("today.day.number")

                        Text(weekday)
                            .font(.system(.title3, design: .rounded, weight: .black))
                            .foregroundStyle(PulseDesign.sunlitInk)

                        Text(PulseFormatting.numericYearAndMonth(today, timeZone: timeZone))
                            .font(.body.bold())
                            .monospacedDigit()
                            .foregroundStyle(PulseDesign.sunlitMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("today.hero.kicker")
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: PulseDesign.spacing20) {
                        Text(today.day, format: .number)
                            .font(
                                .system(
                                    size: resolvedSunlitDayNumberSize,
                                    weight: .black,
                                    design: .rounded
                                )
                            )
                            .monospacedDigit()
                            .tracking(PulseDesign.sunlitDayNumberTracking)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(PulseDesign.sunlitInk)
                            .accessibilityIdentifier("today.day.number")

                        VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                            Text(weekday)
                                .font(.system(.title3, design: .rounded, weight: .black))

                            Text(
                                PulseFormatting.numericYearAndMonth(
                                    today,
                                    timeZone: timeZone
                                )
                            )
                            .font(.caption.bold())
                            .monospacedDigit()
                            .foregroundStyle(PulseDesign.sunlitMuted)
                        }
                        .foregroundStyle(PulseDesign.sunlitInk)
                        .padding(.bottom, PulseDesign.spacing8)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("today.hero.kicker")

                        Spacer(minLength: 0)
                    }
                }

                if let commitmentName = model.habit?.name {
                    VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                        Text("today.commitment.cue")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseDesign.sunlitMuted)

                        Text(commitmentName)
                            .font(
                                .system(
                                    dynamicTypeSize.isAccessibilitySize ? .title3 : .headline,
                                    design: .rounded,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(PulseDesign.sunlitInk)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        .padding(.horizontal, PulseDesign.spacing8)
        .padding(.top, PulseDesign.spacing16)
        .padding(.bottom, PulseDesign.spacing8)
        .frame(minHeight: PulseDesign.sunlitTodayHeroMinimumHeight, alignment: .top)
        .accessibilityElement(children: .contain)
    }

    private func dayNumber(_ today: LogicalDay) -> some View {
        Text(today.day, format: .number)
            .font(.system(size: resolvedDayNumberSize, weight: .black, design: .rounded))
            .monospacedDigit()
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(PulseDesign.quietInk)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sparkle")
                    .font(.system(size: PulseDesign.spacing20, weight: .black))
                    .foregroundStyle(PulseDesign.quietPink)
                    .offset(x: PulseDesign.spacing16, y: PulseDesign.spacing8)
                    .accessibilityHidden(true)
            }
            .accessibilityIdentifier("today.day.number")
    }

    private func commitmentCue(_ name: String) -> some View {
        VStack(spacing: PulseDesign.spacing4) {
            Text("today.commitment.cue")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(PulseDesign.quietMuted)

            Text(name)
                .font(.system(.headline, design: .rounded, weight: .black))
                .foregroundStyle(PulseDesign.quietInk)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, PulseDesign.spacing20)
        .padding(.top, PulseDesign.spacing12)
        .padding(.bottom, PulseDesign.spacing16 + PulseDesign.spacing4)
        .background {
            PulseQuietSpeechBubbleShape()
                .fill(PulseDesign.quietSurface)
        }
        .overlay {
            PulseQuietSpeechBubbleShape()
                .stroke(PulseDesign.quietDivider, lineWidth: PulseDesign.thinLineWidth)
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

    private var resolvedSunlitDayNumberSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? min(sunlitDayNumberSize, PulseDesign.dayNumberAccessibilityMaximumSize)
            : sunlitDayNumberSize
    }

    @ViewBuilder
    private var weekRail: some View {
        if visualTheme == .sunlitDay {
            sunlitWeekRail
        } else {
            quietWeekRail
        }
    }

    private var quietWeekRail: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(PulseDesign.quietDivider)
                .frame(height: PulseDesign.thinLineWidth)
                .padding(.horizontal, (PulseDesign.weekRailDotDiameter + PulseDesign.spacing4) / 2)
                .padding(.bottom, (PulseDesign.weekRailDotDiameter + PulseDesign.spacing4) / 2)
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

    private var sunlitWeekRail: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(PulseDesign.sunlitMapDeep.opacity(0.42))
                .frame(height: PulseDesign.thinLineWidth)
                .padding(.horizontal, PulseDesign.sunlitWeekMarkSize / 2)
                .padding(.bottom, PulseDesign.sunlitWeekMarkSize / 2)
                .accessibilityHidden(true)

            HStack(alignment: .top, spacing: 0) {
                ForEach(model.recentDays) { item in
                    sunlitWeekRailDay(item)
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
                .font(.system(.caption2, design: .rounded, weight: isToday ? .black : .medium))
                .foregroundStyle(isToday ? PulseDesign.quietInk : PulseDesign.quietMuted)
            }

            ZStack {
                Circle()
                    .fill(isChecked ? PulseDesign.quietGreen : PulseDesign.quietSurface)
                Circle()
                    .stroke(
                        isToday
                            ? PulseDesign.quietPink
                            : (isChecked ? PulseDesign.quietGreenDeep : PulseDesign.quietDivider),
                        lineWidth: isToday
                            ? PulseDesign.emphasisLineWidth
                            : PulseDesign.thinLineWidth
                    )
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 6, weight: .black))
                        .foregroundStyle(PulseDesign.quietOnGreen)
                }
            }
            .frame(
                width: PulseDesign.weekRailDotDiameter + PulseDesign.spacing4,
                height: PulseDesign.weekRailDotDiameter + PulseDesign.spacing4
            )
        }
        .animation(completionSecondaryAnimation, value: item.status)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weekDayAccessibilityLabel(item))
        .accessibilityIdentifier("today.week.day.\(item.day.storageValue)")
    }

    private func sunlitWeekRailDay(_ item: CalendarDayItem) -> some View {
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
                .foregroundStyle(isToday ? PulseDesign.sunlitInk : PulseDesign.sunlitMuted)
            }

            ZStack {
                Circle()
                    .fill(
                        isChecked
                            ? PulseDesign.sunlitChrome
                            : PulseDesign.sunlitSurface
                    )
                    .overlay {
                        Circle()
                            .stroke(
                                isToday
                                    ? PulseDesign.sunlitChrome
                                    : PulseDesign.sunlitMapDeep.opacity(
                                        PulseDesign.sunlitWeekInactiveStrokeOpacity
                                    ),
                                lineWidth: isToday
                                    ? PulseDesign.emphasisLineWidth
                                    : PulseDesign.thinLineWidth
                            )
                    }

                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(PulseDesign.sunlitChromeForeground)
                } else if isToday {
                    Text(item.day.day, format: .number)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(PulseDesign.sunlitOnAccent)
                } else {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(
                            PulseDesign.sunlitMuted.opacity(
                                PulseDesign.sunlitWeekInactiveForegroundOpacity
                            )
                        )
                }
            }
            .frame(
                width: PulseDesign.sunlitWeekMarkSize + PulseDesign.spacing4,
                height: PulseDesign.sunlitWeekMarkSize + PulseDesign.spacing4
            )
        }
        .animation(completionSecondaryAnimation, value: item.status)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weekDayAccessibilityLabel(item))
        .accessibilityIdentifier("today.week.day.\(item.day.storageValue)")
    }

    private var checkInControl: some View {
        let isChecked = model.todayRecord != nil
        let controlFill =
            switch visualTheme {
            case .sunlitDay:
                PulseDesign.sunlitChrome
            case .editorialJournal:
                isChecked ? PulseDesign.grass : PulseDesign.action
            case .quietField:
                PulseDesign.quietGreen
            }
        let controlForeground =
            switch visualTheme {
            case .sunlitDay:
                PulseDesign.sunlitChromeForeground
            case .editorialJournal:
                isChecked ? PulseDesign.grassForeground : PulseDesign.actionForeground
            case .quietField:
                PulseDesign.quietOnGreen
            }

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
                if isChecked,
                    !dynamicTypeSize.isAccessibilitySize,
                    visualTheme != .sunlitDay
                {
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

            if isChecked, visualTheme == .sunlitDay {
                HStack {
                    Spacer(minLength: 0)
                    mediaCompanionAction
                }
                .frame(maxWidth: PulseDesign.sunlitCheckInMaximumWidth)
            } else if isChecked, dynamicTypeSize.isAccessibilitySize {
                mediaCompanionAction
            }

            if !isChecked,
                !dynamicTypeSize.isAccessibilitySize,
                visualTheme != .sunlitDay
            {
                Text("today.check_in_hint_visible")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(
                        visualTheme == .sunlitDay
                            ? PulseDesign.sunlitMuted
                            : (visualTheme == .quietField
                                ? PulseDesign.quietMuted
                                : PulseDesign.secondary)
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
        } else if visualTheme == .quietField {
            ZStack {
                PulseQuietCompanionShape()
                    .fill(fill)
                    .overlay {
                        PulseQuietCompanionShape()
                            .stroke(
                                PulseDesign.quietOnGreen.opacity(0.18),
                                lineWidth: PulseDesign.quietCompanionLineWidth
                            )
                    }
                    .shadow(
                        color: PulseDesign.shadow.opacity(
                            PulseDesign.quietCompanionShadowOpacity
                        ),
                        radius: PulseDesign.quietCompanionShadowRadius,
                        y: PulseDesign.quietCompanionShadowY
                    )

                quietCheckInStatusContent
                    .padding(.horizontal, PulseDesign.spacing20)
            }
            .frame(
                width: PulseDesign.quietCompanionWidth,
                height: PulseDesign.quietCompanionHeight
            )
            .background {
                ZStack {
                    PulseQuietCompanionShape()
                        .fill(PulseDesign.quietGreenSoft.opacity(0.72))
                        .frame(
                            width: PulseDesign.quietCompanionWidth + PulseDesign.spacing32,
                            height: PulseDesign.quietCompanionHeight + PulseDesign.spacing24
                        )
                        .rotationEffect(.degrees(-7))

                    PulseQuietCompanionShape()
                        .stroke(
                            PulseDesign.quietPink.opacity(PulseDesign.completionRippleOpacity),
                            lineWidth: PulseDesign.emphasisLineWidth
                        )
                        .frame(
                            width: PulseDesign.quietCompanionWidth,
                            height: PulseDesign.quietCompanionHeight
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
            .contentShape(PulseQuietCompanionShape())
        } else if visualTheme == .sunlitDay {
            HStack(spacing: PulseDesign.spacing16) {
                sunlitCheckInStatusContent

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(PulseDesign.sunlitAccent)

                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.headline.weight(.black))
                            .foregroundStyle(PulseDesign.sunlitOnAccent)
                    } else {
                        PulseImprintGlyph(
                            isSolid: false,
                            foreground: PulseDesign.sunlitOnAccent
                        )
                        .padding(PulseDesign.spacing12)
                        .scaleEffect(imprintGlyphScale)
                    }
                }
                .frame(
                    width: PulseDesign.sunlitCheckInGlyphDiameter,
                    height: PulseDesign.sunlitCheckInGlyphDiameter
                )
                .accessibilityHidden(true)
            }
            .padding(.horizontal, PulseDesign.spacing20)
            .frame(
                maxWidth: PulseDesign.sunlitCheckInMaximumWidth,
                minHeight: PulseDesign.sunlitCheckInMinimumHeight
            )
            .background(
                fill,
                in: RoundedRectangle(
                    cornerRadius: PulseDesign.primaryNavigationCornerRadius,
                    style: .continuous
                )
            )
            .background {
                RoundedRectangle(
                    cornerRadius: PulseDesign.primaryNavigationCornerRadius,
                    style: .continuous
                )
                .stroke(
                    PulseDesign.sunlitAccent.opacity(PulseDesign.completionRippleOpacity),
                    lineWidth: PulseDesign.emphasisLineWidth
                )
                .frame(
                    maxWidth: PulseDesign.sunlitCheckInMaximumWidth,
                    minHeight: PulseDesign.sunlitCheckInMinimumHeight
                )
                .scaleEffect(
                    completionRippleExpanded
                        ? PulseDesign.completionRippleEndScale
                        : PulseDesign.completionRippleStartScale
                )
                .opacity(completionRippleVisible ? 1 : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .contentShape(
                RoundedRectangle(
                    cornerRadius: PulseDesign.primaryNavigationCornerRadius,
                    style: .continuous
                )
            )
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

    @ViewBuilder
    private var sunlitCheckInStatusContent: some View {
        if imprintRitualPhase == .saving, model.isSaving && showsSavingIndicator {
            ProgressView()
                .controlSize(.large)
                .tint(PulseDesign.sunlitChromeForeground)
        } else {
            VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                Text(model.todayRecord == nil ? "today.check_in_hint_visible" : "tab.today")
                    .font(.caption.bold())
                    .foregroundStyle(PulseDesign.sunlitChromeForeground.opacity(0.66))

                Text(
                    completedCheckInText
                        ?? PulseLocalization.string("today.check_in_action", locale: locale)
                )
                .font(.system(.headline, design: .rounded, weight: .black))
                .foregroundStyle(PulseDesign.sunlitChromeForeground)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var quietCheckInStatusContent: some View {
        if imprintRitualPhase == .saving, model.isSaving && showsSavingIndicator {
            ProgressView()
                .controlSize(.large)
                .tint(PulseDesign.quietOnGreen)
        } else {
            VStack(spacing: PulseDesign.spacing4) {
                PulseQuietCompanionFace(
                    isSmiling: model.todayRecord != nil,
                    lineWidth: PulseDesign.quietCompanionLineWidth + 1
                )
                .frame(width: 96, height: 60)
                .scaleEffect(imprintGlyphScale)

                Text(
                    completedCheckInText
                        ?? PulseLocalization.string("today.check_in", locale: locale)
                )
                .font(.system(.headline, design: .rounded, weight: .black))
                .foregroundStyle(PulseDesign.quietOnGreen)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            }
            .transition(.opacity)
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

        return PulseTodayPresentation.checkInAccessibilityLabel(
            state: state,
            commitmentName: model.habit?.name,
            locale: locale
        )
    }

    private var rhythmStatus: some View {
        Text(rhythmStatusText)
            .font(.system(.footnote, design: .rounded, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(PulseDesign.quietInk)
            .padding(.horizontal, PulseDesign.spacing16)
            .frame(minHeight: PulseDesign.spacing32)
            .background(PulseDesign.quietGreenSoft, in: Capsule())
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

    private var sunlitRhythmStatus: some View {
        Text(rhythmStatusText)
            .font(.system(.footnote, design: .rounded, weight: .black))
            .monospacedDigit()
            .foregroundStyle(PulseDesign.sunlitInk)
            .padding(.horizontal, PulseDesign.spacing16)
            .frame(minHeight: PulseDesign.spacing32)
            .background(PulseDesign.sunlitSurface, in: Capsule())
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
                isDisabled: model.isSaving,
                showsHeader: visualTheme != .sunlitDay
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
            .foregroundStyle(mediaActionForeground)
            .padding(.horizontal, PulseDesign.spacing12)
            .frame(minHeight: PulseDesign.minimumHitTarget)
            .background(mediaActionSurface, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(mediaActionBorder, lineWidth: PulseDesign.thinLineWidth)
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

    private var mediaActionForeground: Color {
        switch visualTheme {
        case .sunlitDay: PulseDesign.sunlitInk
        case .editorialJournal: PulseDesign.action
        case .quietField: PulseDesign.quietInk
        }
    }

    private var mediaActionSurface: Color {
        switch visualTheme {
        case .sunlitDay: PulseDesign.sunlitSurface
        case .editorialJournal: PulseDesign.surface
        case .quietField: PulseDesign.quietSurface
        }
    }

    private var mediaActionBorder: Color {
        switch visualTheme {
        case .sunlitDay: PulseDesign.sunlitAccent
        case .editorialJournal: PulseDesign.grass
        case .quietField: PulseDesign.quietGreen
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

    private var rhythmStatusText: String {
        PulseTodayPresentation.rhythmStatusText(
            currentStreak: model.statistics.currentStreak,
            locale: locale
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
        return PulseTodayPresentation.weekDayAccessibilityLabel(
            item,
            timeZone: timeZone,
            locale: locale
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
