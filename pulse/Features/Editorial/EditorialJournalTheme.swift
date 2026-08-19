import PulseCore
import SwiftUI

enum EditorialJournalPrompt {
    static func promptKey(for day: LogicalDay) -> LocalizedStringKey {
        let index = ((day.year * 12 + day.month) * 31 + day.day) % 4
        switch index {
        case 0: return "editorial.prompt.feel"
        case 1: return "editorial.prompt.mind"
        case 2: return "editorial.prompt.body"
        default: return "editorial.prompt.word"
        }
    }
}

struct EditorialTodayContent<CheckInControl: View>: View {
    @Bindable var model: PulseAppModel
    @Binding var draftJournalNote: String
    @FocusState.Binding var isJournalFocused: Bool
    let onEditJournal: () -> Void
    let checkInControl: CheckInControl

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var lineExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            editorialHeader
                .padding(.top, PulseDesign.spacing24)

            editorialPromptBlock
                .padding(.top, PulseDesign.spacing24)

            checkInControl
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, PulseDesign.spacing24)

            editorialWeekRail
                .padding(.top, PulseDesign.spacing24)

            editorialRhythmStatus
                .padding(.top, PulseDesign.spacing20)

            Spacer(minLength: PulseDesign.spacing16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { lineExpanded = isChecked }
        .onChange(of: model.todayRecord?.id) { _, _ in
            updateLineState(animated: !reduceMotion)
        }
    }

    private var isChecked: Bool {
        model.todayRecord != nil
    }

    private var editorialHeader: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            if let today = model.today, let timeZone = model.timeZone {
                Text(editorialDateKicker(today: today, timeZone: timeZone))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PulseDesign.secondary)
                    .textCase(.uppercase)
                    .tracking(PulseDesign.editorialKickerTracking)
                    .accessibilityIdentifier("today.hero.kicker")
            }

            if let habitName = model.habit?.name {
                Text(habitName)
                    .font(.system(.largeTitle, design: .serif).weight(.bold))
                    .foregroundStyle(PulseDesign.ink)
                    .tracking(PulseDesign.editorialTitleTracking)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("today.commitment.name")
            }

            EditorialAccentLine(isExpanded: lineExpanded || isChecked)
        }
    }

    private var editorialPromptBlock: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            if let today = model.today {
                Text(EditorialJournalPrompt.promptKey(for: today))
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .foregroundStyle(PulseDesign.secondary)
            }

            if let record = model.todayRecord {
                JournalNoteSummary(record: record, onEdit: onEditJournal)
            } else {
                JournalDraftComposer(
                    text: $draftJournalNote,
                    isFocused: $isJournalFocused,
                    isDisabled: model.isSaving,
                    showsHeader: false
                )
            }
        }
    }

    private var editorialRhythmStatus: some View {
        Text(
            PulseTodayPresentation.rhythmStatusText(
                currentStreak: model.statistics.currentStreak,
                locale: locale
            )
        )
        .font(.subheadline.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(PulseDesign.ink)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .contentTransition(
            .numericText(value: Double(model.statistics.currentStreak))
        )
        .accessibilityIdentifier("today.rhythm.status")
    }

    private var editorialWeekRail: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(model.recentDays) { item in
                editorialWeekRailDay(item)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, PulseDesign.spacing12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PulseDesign.separator)
                .frame(height: PulseDesign.thinLineWidth)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.week.rail")
    }

    private func editorialWeekRailDay(_ item: CalendarDayItem) -> some View {
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
                .font(.caption2.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? PulseDesign.ink : PulseDesign.secondary)
            }

            ZStack {
                Circle()
                    .fill(isChecked ? PulseDesign.ink : .clear)
                Circle()
                    .stroke(
                        isToday ? PulseDesign.editorialAccent : PulseDesign.separator,
                        lineWidth: isToday
                            ? PulseDesign.emphasisLineWidth
                            : PulseDesign.thinLineWidth
                    )

                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: PulseDesign.spacing8, weight: .bold))
                        .foregroundStyle(PulseDesign.background)
                } else if isToday {
                    Text(item.day.day, format: .number)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PulseDesign.ink)
                } else if item.status == .missed {
                    Image(systemName: "minus")
                        .font(.system(size: PulseDesign.spacing8, weight: .medium))
                        .foregroundStyle(PulseDesign.secondary)
                }
            }
            .frame(width: PulseDesign.spacing24, height: PulseDesign.spacing24)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(editorialWeekDayAccessibilityLabel(item))
        .accessibilityIdentifier("today.week.day.\(item.day.storageValue)")
    }

    private func editorialWeekDayAccessibilityLabel(_ item: CalendarDayItem) -> String {
        guard let timeZone = model.timeZone else { return "" }
        return PulseTodayPresentation.weekDayAccessibilityLabel(
            item,
            timeZone: timeZone,
            locale: locale
        )
    }

    private func editorialDateKicker(today: LogicalDay, timeZone: TimeZone) -> String {
        let weekday = PulseFormatting.fullWeekday(today, timeZone: timeZone, locale: locale)
        let date = PulseFormatting.numericDate(today, timeZone: timeZone, locale: locale)
        return String(
            format: PulseLocalization.string("editorial.date_kicker_format", locale: locale),
            date,
            weekday
        )
    }

    private func updateLineState(animated: Bool) {
        let shouldExpand = model.todayRecord != nil
        guard animated else {
            lineExpanded = shouldExpand
            return
        }
        withAnimation(.easeOut(duration: PulseDesign.completionSecondaryDuration)) {
            lineExpanded = shouldExpand
        }
    }

}

struct EditorialAccentLine: View {
    let isExpanded: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(isExpanded ? PulseDesign.editorialAccent : PulseDesign.separator)
                .frame(
                    width: isExpanded ? proxy.size.width : PulseDesign.editorialLineInitialWidth,
                    height: PulseDesign.editorialLineHeight,
                    alignment: .leading
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(
                    reduceMotion
                        ? nil
                        : .easeOut(duration: PulseDesign.editorialAccentExpansionDuration),
                    value: isExpanded
                )
        }
        .frame(height: PulseDesign.editorialLineHeight)
        .accessibilityHidden(true)
    }
}

struct EditorialRecordDetailIdentity: View {
    let day: LogicalDay
    let record: CheckInRecordSnapshot?
    let habitName: String?
    let timeZone: TimeZone

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            Text(
                PulseFormatting.fullDate(day, timeZone: timeZone, locale: locale)
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(PulseDesign.secondary)
            .textCase(.uppercase)
            .tracking(PulseDesign.editorialKickerTracking)

            if let habitName {
                Text(habitName)
                    .font(.system(.title, design: .serif).weight(.bold))
                    .foregroundStyle(PulseDesign.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle()
                .fill(PulseDesign.editorialAccent)
                .frame(height: PulseDesign.editorialLineHeight)

            if let record {
                Text(
                    String(
                        format: PulseLocalization.string(
                            "history.checked_at",
                            locale: locale
                        ),
                        PulseFormatting.time(
                            record.checkedAt,
                            timeZone: record.timeZone,
                            locale: locale
                        )
                    )
                )
                .font(.caption)
                .foregroundStyle(PulseDesign.secondary)
                .padding(.top, PulseDesign.spacing8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.record.detail.identity")
    }

}

struct EditorialPrimaryNavigation: View {
    @Binding var selection: PulsePrimarySection

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { proxy in
            let itemWidth = proxy.size.width / CGFloat(PulsePrimarySection.allCases.count)
            HStack(spacing: 0) {
                editorialTab(
                    .today,
                    title: "editorial.tab.today",
                    width: itemWidth
                )
                editorialTab(
                    .history,
                    title: "editorial.tab.records",
                    width: itemWidth
                )
            }
        }
        .frame(
            height: dynamicTypeSize.isAccessibilitySize
                ? PulseDesign.accessibilityNavigationMinimumHeight
                : PulseDesign.primaryNavigationHeight
        )
        .padding(.horizontal, PulseDesign.horizontalPadding)
        .padding(.top, PulseDesign.spacing8)
        .padding(.bottom, PulseDesign.spacing24)
        .background(PulseDesign.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PulseDesign.separator)
                .frame(height: PulseDesign.thinLineWidth)
        }
    }

    private func editorialTab(
        _ section: PulsePrimarySection,
        title: LocalizedStringKey,
        width: CGFloat
    ) -> some View {
        Button {
            guard selection != section else { return }
            if reduceMotion {
                selection = section
            } else {
                withAnimation(.easeInOut(duration: PulseDesign.primaryContentTransitionDuration)) {
                    selection = section
                }
            }
        } label: {
            VStack(spacing: PulseDesign.spacing8) {
                Text(title)
                    .font(.caption.weight(selection == section ? .semibold : .regular))
                    .foregroundStyle(
                        selection == section ? PulseDesign.ink : PulseDesign.secondary
                    )

                Rectangle()
                    .fill(selection == section ? PulseDesign.ink : PulseDesign.separator)
                    .frame(height: PulseDesign.emphasisLineWidth)
            }
            .frame(width: width)
            .frame(minHeight: PulseDesign.minimumHitTarget)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("primary.navigation.\(section.rawValue)")
    }
}
