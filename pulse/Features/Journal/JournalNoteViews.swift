import PulseCore
import SwiftUI

struct JournalNoteSummary: View {
    let record: CheckInRecordSnapshot
    let onEdit: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            HStack(alignment: .firstTextBaseline, spacing: PulseDesign.spacing12) {
                Label("journal.section.title", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseDesign.appInk(for: visualTheme))

                Spacer(minLength: PulseDesign.spacing8)

                Button(record.journalNote == nil ? "journal.action.add" : "journal.action.edit") {
                    onEdit()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulseDesign.appAccent(for: visualTheme))
                .accessibilityIdentifier("journal.edit.button")
            }

            Text(record.journalNote ?? PulseLocalization.string("journal.empty", locale: locale))
                .font(noteFont)
                .foregroundStyle(
                    record.journalNote == nil
                        ? PulseDesign.appMuted(for: visualTheme)
                        : PulseDesign.appInk(for: visualTheme)
                )
                .italic(record.journalNote == nil && visualTheme == .editorialJournal)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("journal.summary.text")
        }
        .padding(PulseDesign.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(noteBackground)
        .overlay(noteBorder)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.summary")
    }

    private var noteFont: Font {
        switch visualTheme {
        case .editorialJournal:
            .system(.body, design: .serif)
        case .quietField, .sunlitDay, .moonTide, .prismLedger:
            .system(.body, design: .rounded)
        }
    }

    @ViewBuilder
    private var noteBackground: some View {
        switch visualTheme {
        case .sunlitDay:
            PulseSunlitSurfaceFill()
        case .editorialJournal:
            Rectangle().fill(
                PulseDesign.surface.opacity(PulseDesign.editorialJournalSurfaceOpacity)
            )
        case .quietField:
            PulseQuietSpeechBubbleShape()
                .fill(PulseDesign.quietSurface.opacity(PulseDesign.quietJournalSurfaceOpacity))
        case .moonTide, .prismLedger:
            RoundedRectangle(cornerRadius: PulseDesign.spacing20, style: .continuous)
                .fill(PulseDesign.appSurface(for: visualTheme).opacity(0.90))
        }
    }

    @ViewBuilder
    private var noteBorder: some View {
        switch visualTheme {
        case .sunlitDay:
            Color.clear
        case .editorialJournal:
            Rectangle()
                .stroke(PulseDesign.editorialAccent, lineWidth: PulseDesign.thinLineWidth)
        case .quietField:
            PulseQuietSpeechBubbleShape()
                .stroke(PulseDesign.quietDivider, lineWidth: PulseDesign.thinLineWidth)
        case .moonTide, .prismLedger:
            RoundedRectangle(cornerRadius: PulseDesign.spacing20, style: .continuous)
                .stroke(
                    PulseDesign.appDivider(for: visualTheme),
                    lineWidth: PulseDesign.thinLineWidth
                )
        }
    }
}

struct JournalDraftComposer: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let isDisabled: Bool
    var showsHeader = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            if showsHeader {
                Label("journal.section.title", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseDesign.appInk(for: visualTheme))
            }

            TextField(
                "journal.draft.placeholder",
                text: $text,
                axis: .vertical
            )
            .lineLimit(draftLineLimit)
            .font(draftFont)
            .foregroundStyle(PulseDesign.appInk(for: visualTheme))
            .disabled(isDisabled)
            .focused($isFocused)
            .accessibilityIdentifier("journal.draft.input")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("action.done") {
                        isFocused = false
                    }
                    .accessibilityIdentifier("journal.keyboard.done")
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: PulseDesign.spacing8) {
                if !isValid {
                    Text(validationMessage)
                        .foregroundStyle(PulseDesign.systemDestructive)
                        .accessibilityIdentifier("journal.draft.validation")
                }

                Spacer(minLength: 0)

                Text(characterCountText)
                    .foregroundStyle(
                        isValid
                            ? PulseDesign.appMuted(for: visualTheme)
                            : PulseDesign.systemDestructive
                    )
                    .accessibilityIdentifier("journal.draft.count")
            }
            .font(.caption2)
        }
        .padding(visualTheme == .editorialJournal ? 0 : PulseDesign.spacing16)
        .frame(
            maxWidth: .infinity,
            minHeight: visualTheme == .quietField
                ? PulseDesign.journalDraftMinimumHeight
                : nil,
            alignment: .leading
        )
        .background(draftBackground)
        .overlay(draftBorder)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.draft")
    }

    var isValid: Bool {
        JournalNote.accepts(userInput: text)
    }

    private var draftLineLimit: ClosedRange<Int> {
        dynamicTypeSize.isAccessibilitySize ? 3...6 : 1...4
    }

    private var draftFont: Font {
        switch visualTheme {
        case .editorialJournal:
            .system(.body, design: .serif)
        case .quietField, .sunlitDay, .moonTide, .prismLedger:
            .system(.body, design: .rounded)
        }
    }

    private var characterCountText: String {
        String(
            format: PulseLocalization.string("journal.character_count_format", locale: locale),
            locale: locale,
            arguments: [
                Int64(text.count),
                Int64(JournalNote.maximumCharacterCount),
            ]
        )
    }

    private var validationMessage: String {
        String(
            format: PulseLocalization.string("journal.validation_format", locale: locale),
            locale: locale,
            arguments: [
                Int64(JournalNote.maximumCharacterCount),
                Int64(JournalNote.maximumLineCount),
            ]
        )
    }

    @ViewBuilder
    private var draftBackground: some View {
        switch visualTheme {
        case .quietField:
            PulseQuietSpeechBubbleShape()
                .fill(PulseDesign.quietSurface.opacity(PulseDesign.quietJournalSurfaceOpacity))
        case .editorialJournal:
            Color.clear
        case .sunlitDay:
            PulseSunlitSurfaceFill()
        case .moonTide, .prismLedger:
            RoundedRectangle(cornerRadius: PulseDesign.spacing20, style: .continuous)
                .fill(PulseDesign.appSurface(for: visualTheme).opacity(0.90))
        }
    }

    @ViewBuilder
    private var draftBorder: some View {
        switch visualTheme {
        case .quietField:
            PulseQuietSpeechBubbleShape()
                .stroke(PulseDesign.quietDivider, lineWidth: PulseDesign.thinLineWidth)
        case .editorialJournal:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(PulseDesign.separator)
                    .frame(height: PulseDesign.thinLineWidth)
            }
        case .sunlitDay:
            Color.clear
        case .moonTide, .prismLedger:
            RoundedRectangle(cornerRadius: PulseDesign.spacing20, style: .continuous)
                .stroke(
                    PulseDesign.appDivider(for: visualTheme),
                    lineWidth: PulseDesign.thinLineWidth
                )
        }
    }
}

struct JournalHistorySection: View {
    @Bindable var model: PulseAppModel
    @Binding var selectedDay: LogicalDay?

    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                Text("journal.history.title")
                    .font(titleFont)
                    .foregroundStyle(PulseDesign.appInk(for: visualTheme))

                Text("journal.history.subtitle")
                    .font(.caption)
                    .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
            }
            .padding(.top, PulseDesign.spacing16)
            .padding(.bottom, PulseDesign.spacing20)

            if records.isEmpty {
                if visualTheme == .quietField {
                    VStack(spacing: PulseDesign.spacing16) {
                        PulseBrandMark(size: 88)

                        Text("journal.history.empty")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(PulseDesign.quietMuted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, PulseDesign.spacing24)
                    .padding(.top, PulseDesign.spacing20)
                    .padding(.bottom, PulseDesign.spacing32)
                    .frame(maxWidth: .infinity)
                    .background {
                        PulseQuietSpeechBubbleShape()
                            .fill(PulseDesign.quietSurface)
                    }
                    .overlay {
                        PulseQuietSpeechBubbleShape()
                            .stroke(
                                PulseDesign.quietDivider,
                                lineWidth: PulseDesign.thinLineWidth
                            )
                    }
                    .accessibilityIdentifier("history.journal.empty")
                } else if visualTheme == .sunlitDay {
                    VStack(spacing: PulseDesign.spacing16) {
                        PulseBrandMark(size: 76)

                        Text("journal.history.empty")
                            .font(.system(.headline, design: .rounded, weight: .black))
                            .foregroundStyle(PulseDesign.sunlitMuted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(PulseDesign.spacing24)
                    .frame(maxWidth: .infinity)
                    .background {
                        PulseSunlitSurfaceFill()
                    }
                    .accessibilityIdentifier("history.journal.empty")
                } else {
                    Text("journal.history.empty")
                        .font(bodyFont)
                        .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, PulseDesign.spacing16)
                        .accessibilityIdentifier("history.journal.empty")
                }
            } else {
                LazyVStack(spacing: entrySpacing) {
                    ForEach(records) { record in
                        Button {
                            selectedDay = record.logicalDay
                        } label: {
                            JournalHistoryEntryRow(
                                record: record,
                                timeZone: model.timeZone
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("history.journal.section")
    }

    private var records: [CheckInRecordSnapshot] {
        let month = model.selectedMonth ?? model.today?.firstDayOfMonth()
        return model.records
            .filter { record in
                record.journalNote != nil
                    && record.logicalDay.year == month?.year
                    && record.logicalDay.month == month?.month
            }
            .sorted { $0.checkedAt > $1.checkedAt }
    }

    private var titleFont: Font {
        switch visualTheme {
        case .editorialJournal:
            .system(.title2, design: .serif).weight(.bold)
        case .quietField, .sunlitDay, .moonTide, .prismLedger:
            visualTheme == .quietField
                ? .system(.title3, design: .rounded, weight: .black)
                : .system(.title3, design: .rounded, weight: .black)
        }
    }

    private var bodyFont: Font {
        switch visualTheme {
        case .editorialJournal: .system(.body, design: .serif)
        case .quietField, .sunlitDay, .moonTide, .prismLedger:
            .system(.body, design: .rounded)
        }
    }

    private var entrySpacing: CGFloat {
        visualTheme == .editorialJournal ? 0 : PulseDesign.spacing12
    }
}

private struct JournalHistoryEntryRow: View {
    let record: CheckInRecordSnapshot
    let timeZone: TimeZone?

    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme

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
                .foregroundStyle(dateForeground)
                .textCase(.uppercase)
                .tracking(visualTheme == .editorialJournal ? PulseDesign.editorialKickerTracking : 0)
            }

            Text(record.journalNote ?? "")
                .font(noteFont)
                .foregroundStyle(PulseDesign.appInk(for: visualTheme))
                .lineLimit(PulseDesign.journalHistoryExcerptLineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, PulseDesign.spacing16)
        .background(entryBackground)
        .overlay(entryBorder)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.journal.entry.\(record.logicalDay.storageValue)")
    }

    private var noteFont: Font {
        switch visualTheme {
        case .editorialJournal: .system(.body, design: .serif)
        case .quietField, .sunlitDay, .moonTide, .prismLedger:
            .system(.body, design: .rounded)
        }
    }

    private var dateForeground: Color {
        switch visualTheme {
        case .quietField:
            PulseDesign.quietMuted
        case .editorialJournal:
            PulseDesign.editorialAccent
        case .sunlitDay:
            PulseDesign.sunlitMuted
        case .moonTide, .prismLedger:
            PulseDesign.appAccent(for: visualTheme)
        }
    }

    private var horizontalPadding: CGFloat {
        visualTheme == .editorialJournal ? 0 : PulseDesign.spacing16
    }

    @ViewBuilder
    private var entryBackground: some View {
        if visualTheme == .quietField {
            PulseQuietSpeechBubbleShape()
                .fill(PulseDesign.quietSurface.opacity(PulseDesign.journalHistorySurfaceOpacity))
        } else if visualTheme == .sunlitDay {
            PulseSunlitSurfaceFill(cornerRadius: PulseDesign.spacing20)
        } else if visualTheme == .moonTide || visualTheme == .prismLedger {
            RoundedRectangle(cornerRadius: PulseDesign.spacing16, style: .continuous)
                .fill(PulseDesign.appSurface(for: visualTheme).opacity(0.90))
        }
    }

    @ViewBuilder
    private var entryBorder: some View {
        if visualTheme == .quietField {
            PulseQuietSpeechBubbleShape()
                .stroke(PulseDesign.quietDivider, lineWidth: PulseDesign.thinLineWidth)
        } else if visualTheme == .sunlitDay {
            Color.clear
        } else if visualTheme == .moonTide || visualTheme == .prismLedger {
            RoundedRectangle(cornerRadius: PulseDesign.spacing16, style: .continuous)
                .stroke(
                    PulseDesign.appDivider(for: visualTheme),
                    lineWidth: PulseDesign.thinLineWidth
                )
        } else {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(
                        PulseDesign.separator
                    )
                    .frame(height: PulseDesign.thinLineWidth)
            }
        }
    }
}

struct JournalNoteEditorSheet: View {
    @Bindable var model: PulseAppModel
    let recordID: UUID
    let originalNote: String?
    let logicalDay: LogicalDay
    let recordTimeZone: TimeZone

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme
    @FocusState private var isEditorFocused: Bool
    @State private var draftJournalNote: String
    @State private var showsDeleteConfirmation = false

    init(record: CheckInRecordSnapshot, model: PulseAppModel) {
        self.model = model
        recordID = record.id
        originalNote = record.journalNote
        logicalDay = record.logicalDay
        recordTimeZone = record.timeZone
        _draftJournalNote = State(initialValue: record.journalNote ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PulseDesign.spacing20) {
                    Text(
                        PulseFormatting.fullDate(
                            logicalDay,
                            timeZone: recordTimeZone,
                            locale: locale
                        )
                    )
                    .font(dateFont)
                    .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("journal.editor.date")

                    editorSurface

                    if originalNote != nil {
                        Button(role: .destructive) {
                            showsDeleteConfirmation = true
                        } label: {
                            Label("journal.action.delete", systemImage: "trash")
                                .frame(minHeight: PulseDesign.minimumHitTarget)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(PulseDesign.systemDestructive)
                        .accessibilityIdentifier("journal.delete.button")
                    }
                }
                .frame(maxWidth: PulseDesign.mediaCardMaxWidth, alignment: .leading)
                .padding(.horizontal, PulseDesign.spacing20)
                .padding(.top, PulseDesign.spacing16)
                .padding(.bottom, PulseDesign.spacing32)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
            .background(PulseScreenBackground())
            .foregroundStyle(PulseDesign.appInk(for: visualTheme))
            .navigationTitle("journal.editor.title")
            .navigationBarTitleDisplayMode(.inline)
            .tint(PulseDesign.appAccent(for: visualTheme))
            .disabled(model.operation != nil)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                        .accessibilityIdentifier("journal.editor.cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save") { save() }
                        .foregroundStyle(
                            canSave
                                ? PulseDesign.appAccent(for: visualTheme)
                                : PulseDesign.appMuted(for: visualTheme)
                        )
                        .disabled(!canSave)
                        .accessibilityIdentifier("journal.editor.save")
                }

            }
            .confirmationDialog(
                "journal.delete_confirmation.title",
                isPresented: $showsDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("journal.delete_confirmation.action", role: .destructive) {
                    deleteNote()
                }
                .accessibilityIdentifier("journal.delete.confirmation.action")
                Button("action.cancel", role: .cancel) {}
            } message: {
                Text("journal.delete_confirmation.message")
            }
            .onAppear { isEditorFocused = true }
        }
    }

    private var editorSurface: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            TextField(
                "journal.editor.placeholder",
                text: $draftJournalNote,
                axis: .vertical
            )
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4...10 : 4...8)
            .font(editorFont)
            .foregroundStyle(PulseDesign.appInk(for: visualTheme))
            .focused($isEditorFocused)
            .accessibilityLabel("journal.section.title")
            .accessibilityHint(validationMessage)
            .accessibilityIdentifier("journal.editor.input")

            if showsEditorFooter {
                Spacer(minLength: PulseDesign.spacing12)

                HStack(alignment: .firstTextBaseline, spacing: PulseDesign.spacing8) {
                    if !isDraftValid {
                        Text(validationMessage)
                            .foregroundStyle(PulseDesign.systemDestructive)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("journal.editor.validation")
                    }

                    Spacer(minLength: 0)

                    Text(characterCountText)
                        .foregroundStyle(
                            isDraftValid
                                ? PulseDesign.appMuted(for: visualTheme)
                                : PulseDesign.systemDestructive
                        )
                        .accessibilityIdentifier("journal.editor.count")
                }
                .font(.caption)
            }
        }
        .padding(PulseDesign.spacing16)
        .frame(
            maxWidth: .infinity,
            minHeight: dynamicTypeSize.isAccessibilitySize ? 260 : 220,
            alignment: .topLeading
        )
        .background {
            RoundedRectangle(
                cornerRadius: PulseDesign.spacing20,
                style: .continuous
            )
            .fill(PulseDesign.appSurface(for: visualTheme))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: PulseDesign.spacing20,
                style: .continuous
            )
            .stroke(
                PulseDesign.appDivider(for: visualTheme),
                lineWidth: PulseDesign.thinLineWidth
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.editor.surface")
    }

    private var dateFont: Font {
        switch visualTheme {
        case .editorialJournal:
            .system(.headline, design: .serif).weight(.semibold)
        case .quietField, .sunlitDay, .moonTide, .prismLedger:
            .system(.headline, design: .rounded).weight(.semibold)
        }
    }

    private var editorFont: Font {
        switch visualTheme {
        case .editorialJournal:
            .system(.body, design: .serif)
        case .quietField, .sunlitDay, .moonTide, .prismLedger:
            .system(.body, design: .rounded)
        }
    }

    private var showsEditorFooter: Bool {
        !draftJournalNote.isEmpty || !isDraftValid
    }

    private var canonicalDraft: String? {
        try? JournalNote.canonicalText(userInput: draftJournalNote)
    }

    private var isDraftValid: Bool {
        JournalNote.accepts(userInput: draftJournalNote)
    }

    private var hasChanges: Bool {
        canonicalDraft != originalNote
    }

    private var canSave: Bool {
        isDraftValid && hasChanges
    }

    private var characterCountText: String {
        String(
            format: PulseLocalization.string("journal.character_count_format", locale: locale),
            locale: locale,
            arguments: [
                Int64(draftJournalNote.count),
                Int64(JournalNote.maximumCharacterCount),
            ]
        )
    }

    private var validationMessage: String {
        String(
            format: PulseLocalization.string("journal.validation_format", locale: locale),
            locale: locale,
            arguments: [
                Int64(JournalNote.maximumCharacterCount),
                Int64(JournalNote.maximumLineCount),
            ]
        )
    }

    private func save() {
        guard canSave else { return }
        Task {
            if await model.updateJournalNote(
                recordID: recordID,
                journalNote: draftJournalNote
            ) {
                dismiss()
            }
        }
    }

    private func deleteNote() {
        Task {
            if await model.updateJournalNote(recordID: recordID, journalNote: nil) {
                dismiss()
            }
        }
    }
}
