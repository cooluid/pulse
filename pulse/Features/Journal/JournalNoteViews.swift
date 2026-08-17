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
