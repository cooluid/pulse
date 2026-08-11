import SwiftUI
import PulseCore

struct TodayView: View {
    @Bindable var model: PulseAppModel
    let isActive: Bool
    let primaryNavigationClearance: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .largeTitle) private var dayNumberSize = PulseDesign.dayNumberBaseSize
    @State private var showsSavingIndicator = false
    @State private var imprintRitualPhase: ImprintRitualPhase = .ready
    @State private var completionAnimationSequence = 0
    @State private var imprintGlyphScale: CGFloat = 1
    @State private var completionRippleVisible = false
    @State private var completionRippleExpanded = false

    var body: some View {
        ZStack {
            PulseScreenBackground()
            PulseFieldBackground()

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
                            .padding(.bottom, accessibilityScrollClearance)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var todayContent: some View {
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

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var accessibilityScrollClearance: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? primaryNavigationClearance : 0
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

    private var weekRail: some View {
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
                .fill(dotFill(isChecked: isChecked))
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

    private func dotFill(isChecked: Bool) -> Color {
        if isChecked { return PulseDesign.grass }
        return PulseDesign.background
    }

    private var checkInControl: some View {
        let isChecked = model.todayRecord != nil
        let controlFill = isChecked ? PulseDesign.grass : PulseDesign.action
        let controlForeground = isChecked
            ? PulseDesign.grassForeground
            : PulseDesign.actionForeground

        return Button {
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
            }
        } label: {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: PulseDesign.spacing12) {
                    checkInStatusContent(foreground: controlForeground)
                }
                .padding(.horizontal, PulseDesign.spacing24)
                .frame(maxWidth: .infinity, minHeight: PulseDesign.accessibilityActionMinimumHeight)
                .background(controlFill, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(
                            controlForeground.opacity(PulseDesign.actionBorderOpacity),
                            lineWidth: PulseDesign.thinLineWidth
                        )
                }
                .contentShape(Capsule())
            } else {
                ZStack {
                    Circle()
                        .fill(controlFill)
                        .overlay {
                            Circle()
                                .stroke(
                                    controlForeground.opacity(PulseDesign.actionBorderOpacity),
                                    lineWidth: PulseDesign.thinLineWidth
                                )
                        }
                        .shadow(
                            color: PulseDesign.shadow.opacity(PulseDesign.actionShadowOpacity),
                            radius: PulseDesign.actionShadowRadius,
                            y: PulseDesign.actionShadowY
                        )

                    checkInStatusContent(foreground: controlForeground)
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
        .buttonStyle(PulseCheckInButtonStyle())
        .disabled(isChecked || !model.canCheckInToday)
        .accessibilityIdentifier("today.checkin.button")
        .scaleEffect(model.isSaving && !reduceMotion ? 0.97 : 1)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: PulseDesign.savingAnimationDuration),
            value: model.isSaving
        )
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
        .accessibilityLabel(checkInAccessibilityLabel)
        .accessibilityHint(
            isChecked
                ? ""
                : PulseLocalization.string("today.accessibility.hint", locale: locale)
        )
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
        guard let record = model.todayRecord else {
            return nil
        }
        return String(
            format: PulseLocalization.string("today.checked_with_time", locale: locale),
            PulseFormatting.time(record.checkedAt, timeZone: record.timeZone, locale: locale)
        )
    }

    private var checkInAccessibilityLabel: Text {
        let state: String
        if let completedCheckInText {
            state = completedCheckInText
        } else if model.todayRecord != nil {
            state = PulseLocalization.string("today.accessibility.checked", locale: locale)
        } else {
            state = PulseLocalization.string("today.accessibility.check_in", locale: locale)
        }

        guard let commitmentName = model.habit?.name else {
            return Text(state)
        }

        return Text(
            String(
                format: PulseLocalization.string(
                    "today.accessibility.commitment_state_format",
                    locale: locale
                ),
                commitmentName,
                state
            )
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
            .contentTransition(
                .numericText(value: Double(model.statistics.currentStreak))
            )
            .animation(
                completionSecondaryAnimation,
                value: model.statistics.currentStreak
            )
            .accessibilityIdentifier("today.rhythm.status")
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

private struct PulseCheckInButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: PulseDesign.savingAnimationDuration),
                value: configuration.isPressed
            )
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
