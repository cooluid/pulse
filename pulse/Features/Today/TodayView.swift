import AVFoundation
import PulseCore
import SwiftUI
import UIKit

struct TodayView: View {
    @Bindable var model: PulseAppModel
    let isActive: Bool
    let primaryNavigationClearance: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @Environment(\.pulseVisualTheme) private var visualTheme
    @ScaledMetric(relativeTo: .largeTitle) private var dayNumberSize = PulseDesign.dayNumberBaseSize
    @ScaledMetric(relativeTo: .largeTitle) private var faultDayNumberSize =
        PulseDesign.faultDayNumberBaseSize
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

    var body: some View {
        ZStack {
            PulseScreenBackground()
            PulseFieldBackground(presentation: .today)

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
                                    : PulseDesign.spacing4
                            )
                            .padding(.bottom, scrollClearance)
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
        if visualTheme == .faultAlmanac && !dynamicTypeSize.isAccessibilitySize {
            ZStack {
                faultAlmanacContent
                visualThemeMarker
            }
        } else {
            ZStack {
                quietFieldContent
                visualThemeMarker
            }
        }
    }

    private var visualThemeMarker: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(visualTheme.localizedName(locale: locale))
            .accessibilityIdentifier(
                visualTheme == .faultAlmanac
                    ? "today.theme.fault-almanac"
                    : "today.theme.quiet-field"
            )
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
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: 0) {
                dayHero
                checkInControl
                    .padding(.top, PulseDesign.checkInHeroSpacing)
                weekRail
                    .padding(.top, PulseDesign.checkInOuterHalo + PulseDesign.spacing12)
                rhythmStatus
                    .padding(.top, PulseDesign.spacing24)
            }
            .padding(.bottom, PulseDesign.spacing24)
        }
    }

    @ViewBuilder
    private var faultAlmanacContent: some View {
        if usesRegularWidthLayout {
            HStack(alignment: .center, spacing: PulseDesign.regularWidthColumnGap) {
                VStack(spacing: PulseDesign.spacing24) {
                    faultDayHero
                    weekRail
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: PulseDesign.spacing24) {
                    checkInControl
                    faultRhythmStatus
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: 0) {
                faultDayHero

                HStack(alignment: .bottom, spacing: PulseDesign.spacing16) {
                    checkInControl

                    faultRhythmStatus
                        .padding(.bottom, PulseDesign.spacing20)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, -PulseDesign.spacing12)

                weekRail
                    .padding(.top, PulseDesign.spacing32)
            }
            .padding(.bottom, PulseDesign.spacing24)
        }
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var scrollClearance: CGFloat {
        primaryNavigationClearance + PulseDesign.spacing16
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

    private var faultDayHero: some View {
        ZStack(alignment: .topLeading) {
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
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PulseDesign.ink)
                .padding(.top, PulseDesign.spacing12)
                .accessibilityIdentifier("today.hero.kicker")

                Text(today.day, format: .number)
                    .font(.system(size: faultDayNumberSize, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .tracking(-8)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(PulseDesign.ink)
                    .offset(x: -PulseDesign.spacing8, y: PulseDesign.spacing32)
                    .accessibilityIdentifier("today.day.number")

                PulseFaultCutShape()
                    .stroke(
                        PulseDesign.faultAccent,
                        style: StrokeStyle(
                            lineWidth: 18,
                            lineCap: .square,
                            lineJoin: .bevel
                        )
                    )
                    .frame(height: PulseDesign.faultTodayHeroMinimumHeight * 0.72)
                    .offset(y: PulseDesign.spacing16)
                    .accessibilityHidden(true)

                if let commitmentName = model.habit?.name {
                    VStack(alignment: .trailing, spacing: PulseDesign.spacing4) {
                        Text("today.commitment.cue")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PulseDesign.faultAccent)

                        Text(commitmentName)
                            .font(.title3.weight(.black))
                            .foregroundStyle(PulseDesign.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 184, alignment: .trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 194)
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
        .frame(minHeight: PulseDesign.faultTodayHeroMinimumHeight, alignment: .top)
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

    @ViewBuilder
    private var weekRail: some View {
        if visualTheme == .faultAlmanac && !dynamicTypeSize.isAccessibilitySize {
            faultWeekRail
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

    private var faultWeekRail: some View {
        VStack(spacing: PulseDesign.spacing8) {
            Rectangle()
                .fill(PulseDesign.ink)
                .frame(height: PulseDesign.emphasisLineWidth)
                .accessibilityHidden(true)

            HStack(alignment: .top, spacing: 0) {
                ForEach(model.recentDays) { item in
                    faultWeekRailDay(item)
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
                            isToday || isChecked ? PulseDesign.grass : PulseDesign.separator,
                            lineWidth: PulseDesign.emphasisLineWidth
                        )
                }
        }
        .animation(completionSecondaryAnimation, value: item.status)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weekDayAccessibilityLabel(item))
        .accessibilityIdentifier("today.week.day.\(item.day.storageValue)")
    }

    private func faultWeekRailDay(_ item: CalendarDayItem) -> some View {
        let isChecked = item.status == .checked
        let isToday = item.day == model.today
        let markColor: Color = if isToday && !isChecked {
            PulseDesign.faultAccent
        } else if isChecked {
            PulseDesign.grass
        } else {
            PulseDesign.separator
        }

        return VStack(spacing: PulseDesign.spacing8) {
            Rectangle()
                .fill(markColor)
                .frame(
                    width: isToday ? 7 : (isChecked ? 5 : 2),
                    height: isToday ? 27 : (isChecked ? 19 : 12)
                )
                .rotationEffect(.degrees(isToday ? -8 : 0))

            if let timeZone = model.timeZone {
                Text(
                    PulseFormatting.shortWeekday(
                        item.day,
                        timeZone: timeZone,
                        locale: locale
                    )
                )
                .font(.system(.caption2, design: .monospaced, weight: isToday ? .black : .medium))
                .foregroundStyle(isToday ? PulseDesign.ink : PulseDesign.secondary)
            }
        }
        .animation(completionSecondaryAnimation, value: item.status)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weekDayAccessibilityLabel(item))
        .accessibilityIdentifier("today.week.day.\(item.day.storageValue)")
    }

    private var checkInControl: some View {
        let isChecked = model.todayRecord != nil
        let controlFill = isChecked
            ? PulseDesign.grass
            : (visualTheme == .faultAlmanac ? PulseDesign.faultAccent : PulseDesign.action)
        let controlForeground = isChecked
            ? PulseDesign.grassForeground
            : (
                visualTheme == .faultAlmanac
                    ? PulseDesign.faultAccentForeground
                    : PulseDesign.actionForeground
            )

        return VStack(spacing: PulseDesign.spacing12) {
            checkInVisual(
                isChecked: isChecked,
                fill: controlFill,
                foreground: controlForeground
            )
            .overlay {
                PulseCombinedPressControl(
                    isEnabled: !isChecked && model.canCheckInToday,
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
                    .foregroundStyle(PulseDesign.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .overlay(alignment: .topLeading) {
            if imprintRitualPhase == .imprinted {
                Color.clear
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        PulseLocalization.string("today.accessibility.checked", locale: locale)
                    )
                    .accessibilityIdentifier("today.checkin.presentation.imprinted")
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
        } else if visualTheme == .faultAlmanac {
            ZStack {
                PulseFaultSealShape()
                    .fill(fill)
                    .overlay {
                        PulseFaultSealShape()
                            .stroke(
                                foreground.opacity(PulseDesign.actionBorderOpacity),
                                lineWidth: PulseDesign.emphasisLineWidth
                            )
                    }
                    .shadow(
                        color: PulseDesign.shadow.opacity(PulseDesign.actionShadowOpacity),
                        radius: PulseDesign.actionShadowRadius,
                        y: PulseDesign.actionShadowY
                    )

                checkInStatusContent(foreground: foreground)
                    .rotationEffect(.degrees(isChecked ? -2 : 5))
            }
            .frame(
                width: PulseDesign.faultCheckInDiameter,
                height: PulseDesign.faultCheckInDiameter
            )
            .rotationEffect(.degrees(isChecked ? 2 : -5))
            .background {
                ZStack {
                    if isActive && !isChecked && model.canCheckInToday {
                        PulseFaultSealShape()
                            .stroke(
                                PulseDesign.faultAccent.opacity(0.16),
                                lineWidth: PulseDesign.emphasisLineWidth
                            )
                            .scaleEffect(1.14)
                            .rotationEffect(.degrees(8))
                    }

                    PulseFaultSealShape()
                        .stroke(
                            PulseDesign.grass.opacity(PulseDesign.completionRippleOpacity),
                            lineWidth: PulseDesign.emphasisLineWidth
                        )
                        .frame(
                            width: PulseDesign.faultCheckInDiameter,
                            height: PulseDesign.faultCheckInDiameter
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
            .contentShape(PulseFaultSealShape())
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

    private var faultRhythmStatus: some View {
        VStack(alignment: .trailing, spacing: PulseDesign.spacing8) {
            Rectangle()
                .fill(PulseDesign.faultAccent)
                .frame(width: 44, height: PulseDesign.emphasisLineWidth)
                .accessibilityHidden(true)

            Text(rhythmStatusText)
                .font(.system(.footnote, design: .monospaced, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(PulseDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.trailing)
                .contentTransition(.numericText(value: Double(model.statistics.currentStreak)))
                .animation(
                    completionSecondaryAnimation,
                    value: model.statistics.currentStreak
                )
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today.rhythm.status")
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
            .foregroundStyle(PulseDesign.action)
            .padding(.horizontal, PulseDesign.spacing12)
            .frame(minHeight: PulseDesign.minimumHitTarget)
            .background(PulseDesign.surface, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(PulseDesign.grass, lineWidth: PulseDesign.thinLineWidth)
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
        guard model.canCheckInToday else { return }
        imprintRitualPhase = .saving

        Task {
            guard let receipt = await model.checkIn() else {
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
