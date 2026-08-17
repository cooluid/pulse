import PulseCore
import SwiftUI

enum EditorialJournalDesign {
    static let accent = PulseDesign.editorialAccent
    static let lineHeight: CGFloat = 3
    static let lineInitialWidth: CGFloat = 36
    static let checkButtonSize: CGFloat = 44
    static let titleTracking: CGFloat = -0.02
    static let kickerTracking: CGFloat = 0.06

    static func promptKey(for day: LogicalDay) -> LocalizedStringKey {
        let index = abs(day.storageValue.hashValue) % 4
        switch index {
        case 0: return "editorial.prompt.feel"
        case 1: return "editorial.prompt.mind"
        case 2: return "editorial.prompt.body"
        default: return "editorial.prompt.word"
        }
    }
}

struct EditorialTodayContent: View {
    @Bindable var model: PulseAppModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @FocusState private var isJournalFocused: Bool
    @State private var draftJournalNote = ""
    @State private var isCheckingIn = false
    @State private var lineExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            editorialHeader
                .padding(.top, PulseDesign.spacing24)

            editorialPromptBlock
                .padding(.top, PulseDesign.spacing24)

            Spacer(minLength: PulseDesign.spacing24)

            editorialFooter
                .padding(.bottom, PulseDesign.spacing8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: syncDraftJournalNote)
        .onChange(of: model.todayRecord?.id) { _, _ in
            syncDraftJournalNote()
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
                    .tracking(EditorialJournalDesign.kickerTracking)
                    .accessibilityIdentifier("today.hero.kicker")
            }

            if let habitName = model.habit?.name {
                Text(habitName)
                    .font(.system(.largeTitle, design: .serif).weight(.bold))
                    .foregroundStyle(PulseDesign.ink)
                    .tracking(EditorialJournalDesign.titleTracking)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("today.commitment.name")
            }

            EditorialAccentLine(isExpanded: lineExpanded || isChecked)
        }
    }

    private var editorialPromptBlock: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            if let today = model.today {
                Text(EditorialJournalDesign.promptKey(for: today))
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .foregroundStyle(PulseDesign.secondary)
            }

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    TextField(
                        "editorial.journal.placeholder",
                        text: $draftJournalNote,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                } else {
                    TextField(
                        "editorial.journal.placeholder",
                        text: $draftJournalNote,
                        axis: .vertical
                    )
                    .lineLimit(1...4)
                }
            }
            .font(.body)
            .foregroundStyle(PulseDesign.ink)
            .disabled(isChecked || model.isSaving)
            .focused($isJournalFocused)
            .onChange(of: draftJournalNote) { _, newValue in
                draftJournalNote = String(newValue.prefix(JournalNote.maxCharacterCount))
            }
            .accessibilityIdentifier("editorial.journal.input")

            Rectangle()
                .fill(isChecked ? EditorialJournalDesign.accent : PulseDesign.separator)
                .frame(height: PulseDesign.thinLineWidth)
        }
    }

    private var editorialFooter: some View {
        HStack(alignment: .center, spacing: PulseDesign.spacing16) {
            Button {
                performCheckIn()
            } label: {
                ZStack {
                    Circle()
                        .stroke(
                            isChecked ? PulseDesign.ink : PulseDesign.secondary.opacity(0.45),
                            lineWidth: PulseDesign.emphasisLineWidth
                        )
                        .frame(
                            width: EditorialJournalDesign.checkButtonSize,
                            height: EditorialJournalDesign.checkButtonSize
                        )

                    if isChecked {
                        Circle()
                            .fill(PulseDesign.ink)
                            .frame(
                                width: EditorialJournalDesign.checkButtonSize,
                                height: EditorialJournalDesign.checkButtonSize
                            )

                        Image(systemName: "checkmark")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Color.white)
                    } else if model.isSaving || isCheckingIn {
                        ProgressView()
                            .controlSize(.regular)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!model.canCheckInToday || model.isSaving || isCheckingIn)
            .accessibilityLabel(checkInAccessibilityLabel)
            .accessibilityIdentifier("today.checkin.button")

            Spacer(minLength: PulseDesign.spacing12)

            VStack(alignment: .trailing, spacing: PulseDesign.spacing4) {
                Text(
                    String(
                        format: PulseLocalization.string(
                            "editorial.record.total_format",
                            locale: locale
                        ),
                        locale: locale,
                        arguments: [Int64(displayedTotalCount)]
                    )
                )
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(PulseDesign.ink)
                .accessibilityIdentifier("today.rhythm.status")

                Text("editorial.record.cumulative_hint")
                    .font(.caption2)
                    .foregroundStyle(PulseDesign.secondary)
            }
        }
    }

    private var displayedTotalCount: Int {
        model.statistics.totalCount
    }

    private var checkInAccessibilityLabel: String {
        if isChecked {
            return PulseLocalization.string("today.accessibility.checked", locale: locale)
        }
        return PulseLocalization.string("today.accessibility.check_in", locale: locale)
    }

    private func editorialDateKicker(today: LogicalDay, timeZone: TimeZone) -> String {
        let weekday = PulseFormatting.fullWeekday(today, timeZone: timeZone, locale: locale)
        let date = EditorialDateFormatting.numericYearMonthDay(today, timeZone: timeZone)
        return String(
            format: PulseLocalization.string("editorial.date_kicker_format", locale: locale),
            date,
            weekday
        )
    }

    private func syncDraftJournalNote() {
        draftJournalNote = model.todayRecord?.journalNote ?? ""
        lineExpanded = model.todayRecord != nil
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

    private func performCheckIn() {
        guard model.canCheckInToday else { return }
        isCheckingIn = true
        isJournalFocused = false

        Task {
            let note = JournalNote.normalized(draftJournalNote)
            guard await model.checkIn(journalNote: note) != nil else {
                isCheckingIn = false
                return
            }
            isCheckingIn = false
            updateLineState(animated: !reduceMotion)
        }
    }
}

struct EditorialAccentLine: View {
    let isExpanded: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(isExpanded ? EditorialJournalDesign.accent : PulseDesign.separator)
                .frame(
                    width: isExpanded ? proxy.size.width : EditorialJournalDesign.lineInitialWidth,
                    height: EditorialJournalDesign.lineHeight,
                    alignment: .leading
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.55),
                    value: isExpanded
                )
        }
        .frame(height: EditorialJournalDesign.lineHeight)
        .accessibilityHidden(true)
    }
}

struct EditorialHistoryContent: View {
    @Bindable var model: PulseAppModel
    @Binding var selectedDay: LogicalDay?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                Text("editorial.history.title")
                    .font(.system(.title2, design: .serif).weight(.bold))
                    .foregroundStyle(PulseDesign.ink)

                Text("editorial.history.subtitle")
                    .font(.caption)
                    .foregroundStyle(PulseDesign.secondary)
            }
            .padding(.top, PulseDesign.spacing16)
            .padding(.bottom, PulseDesign.spacing20)

            LazyVStack(spacing: 0) {
                ForEach(sortedRecords) { record in
                    Button {
                        selectedDay = record.logicalDay
                    } label: {
                        EditorialHistoryEntryRow(
                            record: record,
                            habitName: model.habit?.name,
                            timeZone: model.timeZone
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var sortedRecords: [CheckInRecordSnapshot] {
        model.records.sorted { $0.checkedAt > $1.checkedAt }
    }
}

private struct EditorialHistoryEntryRow: View {
    let record: CheckInRecordSnapshot
    let habitName: String?
    let timeZone: TimeZone?

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
            if let timeZone {
                Text(
                    PulseFormatting.fullDate(
                        record.logicalDay,
                        timeZone: timeZone,
                        locale: locale
                    )
                )
                .font(.caption2.weight(.medium))
                .foregroundStyle(PulseDesign.secondary)
                .textCase(.uppercase)
                .tracking(EditorialJournalDesign.kickerTracking)
            }

            Text(displayNote)
                .font(.system(.body, design: .serif))
                .foregroundStyle(record.journalNote == nil ? PulseDesign.secondary : PulseDesign.ink)
                .italic(record.journalNote == nil)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let habitName {
                Text(habitName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(EditorialJournalDesign.accent)
            }
        }
        .padding(.vertical, PulseDesign.spacing16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PulseDesign.separator)
                .frame(height: PulseDesign.thinLineWidth)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.entry.\(record.logicalDay.storageValue)")
    }

    private var displayNote: String {
        if let note = record.journalNote, !note.isEmpty {
            return note
        }
        return PulseLocalization.string("editorial.journal.blank", locale: locale)
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
            .tracking(EditorialJournalDesign.kickerTracking)

            if let habitName {
                Text(habitName)
                    .font(.system(.title, design: .serif).weight(.bold))
                    .foregroundStyle(PulseDesign.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle()
                .fill(EditorialJournalDesign.accent)
                .frame(height: EditorialJournalDesign.lineHeight)

            Text(quoteText)
                .font(.system(.title3, design: .serif))
                .italic(record?.journalNote == nil)
                .foregroundStyle(record?.journalNote == nil ? PulseDesign.secondary : PulseDesign.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, PulseDesign.spacing8)

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

    private var quoteText: String {
        if let note = record?.journalNote, !note.isEmpty {
            return note
        }
        return PulseLocalization.string("editorial.journal.detail_blank", locale: locale)
    }
}

struct EditorialPrimaryNavigation: View {
    @Binding var selection: PulsePrimarySection

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            editorialTab(.today, title: "editorial.tab.today")
            editorialTab(.history, title: "editorial.tab.records")
        }
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
        title: LocalizedStringKey
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
                    .fill(selection == section ? PulseDesign.ink : Color.clear)
                    .frame(height: PulseDesign.emphasisLineWidth)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: PulseDesign.minimumHitTarget)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("navigation.section.\(section.rawValue)")
    }
}

private enum EditorialDateFormatting {
    static func numericYearMonthDay(_ day: LogicalDay, timeZone: TimeZone) -> String {
        let calendar = Calendar.pulseGregorian(timeZone: timeZone)
        let date = day.date(timeZone: timeZone)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let dayValue = components.day else {
            return day.storageValue
        }
        return String(format: "%d/%d/%d", year, month, dayValue)
    }
}
