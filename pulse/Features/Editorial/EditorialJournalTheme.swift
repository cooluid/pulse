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

struct EditorialTodayContent: View {
    @Bindable var model: PulseAppModel
    @Binding var draftJournalNote: String
    @FocusState.Binding var isJournalFocused: Bool
    let onCheckIn: () -> Void
    let onEditJournal: () -> Void
    let onCaptureMedia: () -> Void
    let onShowMedia: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
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

    private var editorialFooter: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            HStack(alignment: .center, spacing: PulseDesign.spacing16) {
                Button {
                    onCheckIn()
                } label: {
                    HStack(spacing: PulseDesign.spacing8) {
                        ZStack {
                            Circle()
                                .stroke(
                                    isChecked
                                        ? PulseDesign.ink
                                        : PulseDesign.secondary.opacity(
                                            PulseDesign.editorialPendingStrokeOpacity
                                        ),
                                    lineWidth: PulseDesign.emphasisLineWidth
                                )
                                .frame(
                                    width: PulseDesign.editorialCheckButtonSize,
                                    height: PulseDesign.editorialCheckButtonSize
                                )

                            if isChecked {
                                Circle()
                                    .fill(PulseDesign.ink)
                                    .frame(
                                        width: PulseDesign.editorialCheckButtonSize,
                                        height: PulseDesign.editorialCheckButtonSize
                                    )

                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PulseDesign.background)
                            } else if model.isSaving {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }

                        Text(isChecked ? "today.accessibility.checked" : "today.check_in")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(minHeight: PulseDesign.minimumHitTarget)
                }
                .buttonStyle(.plain)
                .disabled(
                    !model.canCheckInToday
                        || model.isSaving
                        || !isDraftValid
                )
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

            if isChecked,
               model.settings.mediaInvitationEnabled || model.todayMedia != nil {
                Button {
                    model.todayMedia == nil ? onCaptureMedia() : onShowMedia()
                } label: {
                    Label(
                        model.todayMedia == nil
                            ? "today.media.capture_compact"
                            : "today.media.view_compact",
                        systemImage: model.todayMedia == nil ? "camera" : "photo"
                    )
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: PulseDesign.minimumHitTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(PulseDesign.editorialAccent)
                .disabled(model.operation == .saveMedia)
                .accessibilityIdentifier(
                    model.todayMedia == nil
                        ? "today.media.capture.button"
                        : "today.media.preview.button"
                )
            }
        }
    }

    private var displayedTotalCount: Int {
        model.statistics.totalCount
    }

    private var isDraftValid: Bool {
        JournalNote.accepts(userInput: draftJournalNote)
    }

    private var checkInAccessibilityLabel: String {
        if isChecked {
            return PulseLocalization.string("today.accessibility.checked", locale: locale)
        }
        return PulseLocalization.string("today.accessibility.check_in", locale: locale)
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
        .accessibilityIdentifier("primary.navigation.\(section.rawValue)")
    }
}
