import SwiftUI

struct TodayView: View {
    @Bindable var model: PulseAppModel
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var dayNumberSize = PulseDesign.dayNumberBaseSize

    var body: some View {
        ZStack {
            PulseScreenBackground()
            PulseFieldBackground(isActive: isActive)

            VStack(spacing: 0) {
                PulseAppHeader(source: .today)

                ScrollView {
                    VStack(spacing: 0) {
                        dayHero
                        checkInControl
                            .padding(
                                .top,
                                dynamicTypeSize.isAccessibilitySize
                                    ? PulseDesign.spacing12
                                    : PulseDesign.checkInHeroOverlap
                            )
                        if model.todayRecord == nil {
                            pendingCheckInStatus
                                .padding(.top, PulseDesign.spacing12)
                            weekRail
                                .padding(.top, PulseDesign.spacing20)
                        } else {
                            weekRail
                                .padding(.top, PulseDesign.checkInOuterHalo + PulseDesign.spacing12)
                        }
                        streakBand
                            .padding(.top, PulseDesign.spacing24)
                    }
                    .frame(maxWidth: PulseDesign.screenMaxWidth)
                    .padding(.horizontal, PulseDesign.horizontalPadding)
                    .padding(.top, PulseDesign.spacing4)
                    .padding(.bottom, PulseDesign.spacing24)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var dayHero: some View {
        VStack(spacing: 0) {
            if let today = model.today, let timeZone = model.timeZone {
                let weekday = PulseFormatting.fullWeekday(today, timeZone: timeZone)

                Text(
                    String(
                        format: String(localized: "today.kicker_with_weekday_format"),
                        PulseFormatting.numericYearAndMonth(today, timeZone: timeZone),
                        weekday
                    )
                )
                .font(.system(.caption2, design: .default, weight: .bold))
                .foregroundStyle(PulseDesign.ink)
                .accessibilityIdentifier("today.hero.kicker")

                dayNumber(today)
                    .padding(.top, PulseDesign.spacing12)
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
            .font(.system(size: dayNumberSize, weight: .regular))
            .monospacedDigit()
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(PulseDesign.ink)
            .accessibilityIdentifier("today.day.number")
    }

    private var weekRail: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(PulseDesign.separator)
                .frame(height: PulseDesign.thinLineWidth)
                .padding(.horizontal, PulseDesign.weekRailCurrentDot / 2)
                .padding(.bottom, PulseDesign.weekRailDot / 2)
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
                Text(PulseFormatting.shortWeekday(item.day, timeZone: timeZone))
                    .font(.system(.caption2, design: .default, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? PulseDesign.ink : PulseDesign.secondary)
            }

            Circle()
                .fill(dotFill(isChecked: isChecked, isToday: isToday))
                .frame(
                    width: isToday ? PulseDesign.weekRailCurrentDot : PulseDesign.weekRailDot,
                    height: isToday ? PulseDesign.weekRailCurrentDot : PulseDesign.weekRailDot
                )
                .overlay {
                    Circle()
                        .stroke(
                            isToday || isChecked ? PulseDesign.grass : PulseDesign.separator,
                            lineWidth: isToday
                                ? PulseDesign.weekRailCurrentBorder
                                : PulseDesign.emphasisLineWidth
                        )
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weekDayAccessibilityLabel(item))
    }

    private func dotFill(isChecked: Bool, isToday: Bool) -> Color {
        if isChecked { return PulseDesign.grass }
        if isToday { return PulseDesign.background }
        return PulseDesign.background
    }

    private var checkInControl: some View {
        let isChecked = model.todayRecord != nil

        return Button {
            Task { await model.checkIn() }
        } label: {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: PulseDesign.spacing12) {
                    checkInStatusContent
                }
                .padding(.horizontal, PulseDesign.spacing24)
                .frame(maxWidth: .infinity, minHeight: PulseDesign.accessibilityActionMinimumHeight)
                .background(PulseDesign.action, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(
                            PulseDesign.actionForeground.opacity(PulseDesign.actionBorderOpacity),
                            lineWidth: PulseDesign.thinLineWidth
                        )
                }
                .contentShape(Capsule())
            } else {
                ZStack {
                    Circle()
                        .fill(PulseDesign.action)
                        .overlay {
                            Circle()
                                .stroke(
                                    PulseDesign.actionForeground.opacity(PulseDesign.actionBorderOpacity),
                                    lineWidth: PulseDesign.thinLineWidth
                                )
                        }
                        .shadow(
                            color: PulseDesign.shadow.opacity(PulseDesign.actionShadowOpacity),
                            radius: PulseDesign.actionShadowRadius,
                            y: PulseDesign.actionShadowY
                        )

                    Circle()
                        .trim(from: isChecked ? 0 : 0.08, to: isChecked ? 1 : 0.94)
                        .stroke(
                            PulseDesign.actionForeground.opacity(PulseDesign.actionRingOpacity),
                            lineWidth: PulseDesign.thinLineWidth
                        )
                        .rotationEffect(.degrees(isChecked ? 378 : 18))
                        .padding(PulseDesign.checkInMarkInset)
                        .animation(
                            reduceMotion
                                ? nil
                                : .easeOut(duration: PulseDesign.completionAnimationDuration),
                            value: isChecked
                        )

                    checkInStatusContent
                }
                .frame(width: PulseDesign.checkInDiameter, height: PulseDesign.checkInDiameter)
                .background {
                    ZStack {
                        Circle()
                            .fill(PulseDesign.grass.opacity(PulseDesign.outerHaloOpacity))
                            .frame(
                                width: PulseDesign.checkInDiameter + PulseDesign.checkInOuterHalo * 2,
                                height: PulseDesign.checkInDiameter + PulseDesign.checkInOuterHalo * 2
                            )
                        Circle()
                            .fill(PulseDesign.grass.opacity(PulseDesign.innerHaloOpacity))
                            .frame(
                                width: PulseDesign.checkInDiameter + PulseDesign.checkInInnerHalo * 2,
                                height: PulseDesign.checkInDiameter + PulseDesign.checkInInnerHalo * 2
                            )
                    }
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
        .accessibilityLabel(checkInAccessibilityLabel)
        .accessibilityHint(isChecked ? "" : String(localized: "today.accessibility.hint"))
    }

    @ViewBuilder
    private var checkInStatusContent: some View {
        if model.isSaving {
            ProgressView()
                .controlSize(.large)
                .tint(PulseDesign.actionForeground)
        } else if let completedCheckInText {
            VStack(spacing: PulseDesign.spacing4) {
                Image(systemName: "checkmark")
                    .font(.system(.title, design: .default, weight: .medium))

                Text(completedCheckInText)
                    .font(.headline.bold())
            }
            .foregroundStyle(PulseDesign.actionForeground)
            .multilineTextAlignment(.center)
        } else {
            Text("today.check_in")
                .font(.headline.bold())
                .foregroundStyle(PulseDesign.actionForeground)
        }
    }

    private var pendingCheckInStatus: some View {
        Text(pendingStatusKey)
        .font(.footnote)
        .foregroundStyle(PulseDesign.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var pendingStatusKey: LocalizedStringKey {
        if let today = model.today,
           let habitStartDay = model.habitStartDay,
           today < habitStartDay {
            return "today.before_start_status"
        }
        return "today.pending_status"
    }

    private var completedCheckInText: String? {
        guard let record = model.todayRecord, let timeZone = record.timeZone else {
            return nil
        }
        return String(
            format: String(localized: "today.checked_with_time"),
            PulseFormatting.time(record.checkedAt, timeZone: timeZone)
        )
    }

    private var checkInAccessibilityLabel: Text {
        if let completedCheckInText {
            return Text(completedCheckInText)
        }
        if model.todayRecord != nil {
            return Text("today.accessibility.checked")
        }
        return Text("today.accessibility.check_in")
    }

    private var streakBand: some View {
        HStack(alignment: .bottom, spacing: PulseDesign.spacing16) {
            VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                Text("today.rhythm_label")
                    .font(.system(.caption2, design: .default, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(PulseDesign.ink)

                Text("today.streak_encouragement")
                    .font(.footnote)
                    .foregroundStyle(PulseDesign.secondary)
            }

            Spacer(minLength: PulseDesign.spacing16)

            HStack(alignment: .firstTextBaseline, spacing: PulseDesign.spacing4) {
                Text(model.statistics.currentStreak, format: .number)
                    .font(.title.bold())
                    .monospacedDigit()
                    .foregroundStyle(PulseDesign.ink)

                Text("unit.days")
                    .font(.footnote.bold())
                    .foregroundStyle(PulseDesign.ink)
            }
        }
        .padding(.horizontal, PulseDesign.spacing16)
        .padding(.vertical, PulseDesign.spacing16)
        .overlay {
            Capsule()
                .stroke(PulseDesign.separator, lineWidth: PulseDesign.thinLineWidth)
        }
        .accessibilityElement(children: .combine)
    }

    private func weekDayAccessibilityLabel(_ item: CalendarDayItem) -> String {
        guard let timeZone = model.timeZone else { return "" }
        let date = PulseFormatting.fullDate(item.day, timeZone: timeZone)
        let state: String
        switch item.status {
        case .beforeHabit: state = String(localized: "calendar.status.before_habit")
        case .checked: state = String(localized: "calendar.status.checked")
        case .missed: state = String(localized: "calendar.status.missed")
        case .todayPending: state = String(localized: "calendar.status.pending")
        case .future: state = String(localized: "calendar.status.future")
        }
        return "\(date)，\(state)"
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
