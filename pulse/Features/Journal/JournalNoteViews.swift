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
                    .foregroundStyle(PulseDesign.ink)

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
                .foregroundStyle(record.journalNote == nil ? PulseDesign.secondary : PulseDesign.ink)
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
        visualTheme == .editorialJournal ? .system(.body, design: .serif) : .body
    }

    @ViewBuilder
    private var noteBackground: some View {
        switch visualTheme {
        case .tideArchive:
            RoundedRectangle(
                cornerRadius: PulseDesign.archiveHistoryPanelCornerRadius,
                style: .continuous
            )
            .fill(PulseDesign.archivePaper)
        case .editorialJournal:
            Rectangle().fill(
                PulseDesign.surface.opacity(PulseDesign.editorialJournalSurfaceOpacity)
            )
        case .quietField:
            RoundedRectangle(
                cornerRadius: PulseDesign.journalCardCornerRadius,
                style: .continuous
            )
            .fill(PulseDesign.surface.opacity(PulseDesign.quietJournalSurfaceOpacity))
        }
    }

    @ViewBuilder
    private var noteBorder: some View {
        switch visualTheme {
        case .tideArchive:
            RoundedRectangle(
                cornerRadius: PulseDesign.archiveHistoryPanelCornerRadius,
                style: .continuous
            )
            .stroke(
                PulseDesign.archiveCopper.opacity(PulseDesign.archiveHistorySurfaceBorderOpacity),
                lineWidth: PulseDesign.thinLineWidth
            )
        case .editorialJournal:
            Rectangle()
                .stroke(PulseDesign.editorialAccent, lineWidth: PulseDesign.thinLineWidth)
        case .quietField:
            RoundedRectangle(
                cornerRadius: PulseDesign.journalCardCornerRadius,
                style: .continuous
            )
            .stroke(PulseDesign.separator, lineWidth: PulseDesign.thinLineWidth)
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
                    .foregroundStyle(PulseDesign.ink)
            }

            TextField(
                "journal.draft.placeholder",
                text: $text,
                axis: .vertical
            )
            .lineLimit(draftLineLimit)
            .font(draftFont)
            .foregroundStyle(PulseDesign.ink)
            .disabled(isDisabled)
            .focused($isFocused)
            .accessibilityIdentifier("journal.draft.input")

            HStack(alignment: .firstTextBaseline, spacing: PulseDesign.spacing8) {
                if !isValid {
                    Text(validationMessage)
                        .foregroundStyle(PulseDesign.systemDestructive)
                        .accessibilityIdentifier("journal.draft.validation")
                }

                Spacer(minLength: 0)

                Text(characterCountText)
                    .foregroundStyle(
                        isValid ? PulseDesign.secondary : PulseDesign.systemDestructive
                    )
                    .accessibilityIdentifier("journal.draft.count")
            }
            .font(.caption2)
        }
        .padding(visualTheme == .editorialJournal ? 0 : PulseDesign.spacing16)
        .frame(
            maxWidth: .infinity,
            minHeight: visualTheme == .editorialJournal
                ? nil
                : PulseDesign.journalDraftMinimumHeight,
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
        visualTheme == .editorialJournal ? .system(.body, design: .serif) : .body
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
            RoundedRectangle(
                cornerRadius: PulseDesign.journalCardCornerRadius,
                style: .continuous
            )
            .fill(PulseDesign.surface.opacity(PulseDesign.quietJournalSurfaceOpacity))
        case .editorialJournal:
            Color.clear
        case .tideArchive:
            RoundedRectangle(
                cornerRadius: PulseDesign.archiveHistoryPanelCornerRadius,
                style: .continuous
            )
            .fill(PulseDesign.archivePaper)
        }
    }

    @ViewBuilder
    private var draftBorder: some View {
        switch visualTheme {
        case .quietField:
            RoundedRectangle(
                cornerRadius: PulseDesign.journalCardCornerRadius,
                style: .continuous
            )
            .stroke(PulseDesign.separator, lineWidth: PulseDesign.thinLineWidth)
        case .editorialJournal:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(PulseDesign.separator)
                    .frame(height: PulseDesign.thinLineWidth)
            }
        case .tideArchive:
            RoundedRectangle(
                cornerRadius: PulseDesign.archiveHistoryPanelCornerRadius,
                style: .continuous
            )
            .stroke(
                PulseDesign.archiveCopper.opacity(
                    PulseDesign.archiveHistorySurfaceBorderOpacity
                ),
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
                    .foregroundStyle(PulseDesign.ink)

                Text("journal.history.subtitle")
                    .font(.caption)
                    .foregroundStyle(PulseDesign.secondary)
            }
            .padding(.top, PulseDesign.spacing16)
            .padding(.bottom, PulseDesign.spacing20)

            if records.isEmpty {
                Text("journal.history.empty")
                    .font(bodyFont)
                    .foregroundStyle(PulseDesign.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, PulseDesign.spacing16)
                    .accessibilityIdentifier("history.journal.empty")
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
        case .quietField, .tideArchive:
            .title3.weight(.semibold)
        }
    }

    private var bodyFont: Font {
        visualTheme == .editorialJournal ? .system(.body, design: .serif) : .body
    }

    private var entrySpacing: CGFloat {
        visualTheme == .quietField ? PulseDesign.spacing12 : 0
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
                .foregroundStyle(PulseDesign.ink)
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
        visualTheme == .editorialJournal ? .system(.body, design: .serif) : .body
    }

    private var dateForeground: Color {
        switch visualTheme {
        case .quietField:
            PulseDesign.secondary
        case .editorialJournal:
            PulseDesign.editorialAccent
        case .tideArchive:
            PulseDesign.archiveCopper
        }
    }

    private var horizontalPadding: CGFloat {
        visualTheme == .quietField ? PulseDesign.spacing16 : 0
    }

    @ViewBuilder
    private var entryBackground: some View {
        if visualTheme == .quietField {
            RoundedRectangle(
                cornerRadius: PulseDesign.journalHistoryEntryCornerRadius,
                style: .continuous
            )
            .fill(PulseDesign.surface.opacity(PulseDesign.journalHistorySurfaceOpacity))
        }
    }

    @ViewBuilder
    private var entryBorder: some View {
        if visualTheme == .quietField {
            RoundedRectangle(
                cornerRadius: PulseDesign.journalHistoryEntryCornerRadius,
                style: .continuous
            )
            .stroke(PulseDesign.separator, lineWidth: PulseDesign.thinLineWidth)
        } else {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(
                        visualTheme == .tideArchive
                            ? PulseDesign.archiveCopper.opacity(
                                PulseDesign.archiveHistorySurfaceBorderOpacity
                            )
                            : PulseDesign.separator
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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme
    @FocusState private var isEditorFocused: Bool
    @State private var draftJournalNote: String
    @State private var showsDeleteConfirmation = false

    init(record: CheckInRecordSnapshot, model: PulseAppModel) {
        self.model = model
        recordID = record.id
        originalNote = record.journalNote
        _draftJournalNote = State(initialValue: record.journalNote ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "journal.editor.placeholder",
                        text: $draftJournalNote,
                        axis: .vertical
                    )
                    .lineLimit(4...8)
                    .focused($isEditorFocused)
                    .accessibilityIdentifier("journal.editor.input")
                } footer: {
                    VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                        Text(characterCountText)
                            .foregroundStyle(
                                isDraftValid
                                    ? PulseDesign.secondary
                                    : PulseDesign.systemDestructive
                            )
                            .accessibilityIdentifier("journal.editor.count")

                        if !isDraftValid {
                            Text(validationMessage)
                                .foregroundStyle(PulseDesign.systemDestructive)
                                .accessibilityIdentifier("journal.editor.validation")
                        }
                    }
                }

                Section {
                    Text("journal.privacy")
                        .font(.footnote)
                        .foregroundStyle(PulseDesign.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if originalNote != nil {
                        Button("journal.action.delete", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                        .accessibilityIdentifier("journal.delete.button")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PulseScreenBackground())
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
                        .disabled(!isDraftValid || !hasChanges)
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

    private var canonicalDraft: String? {
        try? JournalNote.canonicalText(userInput: draftJournalNote)
    }

    private var isDraftValid: Bool {
        JournalNote.accepts(userInput: draftJournalNote)
    }

    private var hasChanges: Bool {
        isDraftValid && canonicalDraft != originalNote
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
        guard isDraftValid, hasChanges else { return }
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
