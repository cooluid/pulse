import PulseCore
import SwiftUI
import UIKit

/// A short card that keeps the day's note close to its seal.
struct PulseNoteCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        content
            .padding(.horizontal, PulseDesign.spacing16)
            .padding(.vertical, PulseDesign.spacing12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PulseDesign.appSurface(for: visualTheme),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
    }
}

struct JournalNoteSummary: View {
    let record: CheckInRecordSnapshot
    let onEdit: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        PulseNoteCard {
            HStack(alignment: .top, spacing: PulseDesign.spacing12) {
                VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                    Text("journal.section.title")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                    Text(record.journalNote ?? PulseLocalization.string("journal.empty", locale: locale))
                        .font(
                            record.journalNote == nil
                                ? .body
                                : PulseDesign.displayFont(size: 18, relativeTo: .body)
                        )
                        .foregroundStyle(
                            record.journalNote == nil
                                ? PulseDesign.appMuted(for: visualTheme)
                                : PulseDesign.appInk(for: visualTheme)
                        )
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("journal.summary.text")
                }

                Button(action: onEdit) {
                    Image(systemName: record.journalNote == nil ? "plus" : "pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PulseDesign.appInk(for: visualTheme))
                        .frame(width: 36, height: 36)
                        .background(PulseDesign.appChromeBackground(for: visualTheme), in: Circle())
                        .frame(minWidth: PulseDesign.minimumHitTarget, minHeight: PulseDesign.minimumHitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(record.journalNote == nil ? "journal.action.add" : "journal.action.edit")
                .accessibilityIdentifier("journal.edit.button")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.summary")
    }
}

struct JournalDraftComposer: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let isDisabled: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        PulseNoteCard {
            VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
                HStack(alignment: .firstTextBaseline, spacing: PulseDesign.spacing8) {
                    TextField(
                        "",
                        text: $text,
                        prompt: Text("journal.section.title")
                            .foregroundStyle(PulseDesign.appMuted(for: visualTheme)),
                        axis: .vertical
                    )
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 1...6 : 1...4)
                    .font(PulseDesign.displayFont(size: 18, relativeTo: .body))
                    .foregroundStyle(PulseDesign.appInk(for: visualTheme))
                    .disabled(isDisabled)
                    .focused($isFocused)
                    .accessibilityLabel("journal.section.title")
                    .accessibilityIdentifier("journal.draft.input")
                    .frame(maxWidth: .infinity, minHeight: PulseDesign.journalDraftMinimumHeight - PulseDesign.spacing12,
                           alignment: .leading)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("action.done") { isFocused = false }
                                .accessibilityIdentifier("journal.keyboard.done")
                        }
                    }

                    if text.isEmpty && !isFocused {
                        Text("journal.optional")
                            .font(.caption)
                            .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                            .accessibilityHidden(true)
                    }
                }

                if isFocused || !text.isEmpty || !isValid {
                    HStack(alignment: .firstTextBaseline, spacing: PulseDesign.spacing8) {
                        if !isValid {
                            Text(validationMessage)
                                .foregroundStyle(PulseDesign.systemDestructive)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("journal.draft.validation")
                        }
                        Spacer(minLength: 0)
                        Text(characterCountText)
                            .monospacedDigit()
                            .foregroundStyle(isValid ? PulseDesign.appMuted(for: visualTheme) : PulseDesign.systemDestructive)
                            .accessibilityIdentifier("journal.draft.count")
                    }
                    .font(.caption2)
                }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded { isFocused = true },
            including: isDisabled ? .none : .all
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.draft")
    }

    var isValid: Bool { JournalNote.accepts(userInput: text) }

    private var characterCountText: String {
        String(
            format: PulseLocalization.string("journal.character_count_format", locale: locale),
            locale: locale,
            arguments: [Int64(text.count), Int64(JournalNote.maximumCharacterCount)]
        )
    }

    private var validationMessage: String {
        String(
            format: PulseLocalization.string("journal.validation_format", locale: locale),
            locale: locale,
            arguments: [Int64(JournalNote.maximumCharacterCount), Int64(JournalNote.maximumLineCount)]
        )
    }
}

struct JournalHistorySection: View {
    @Bindable var model: PulseAppModel
    @Binding var selectedDay: LogicalDay?

    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if records.isEmpty {
                Text("journal.history.empty")
                    .font(.body)
                    .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, PulseDesign.spacing24)
                    .accessibilityIdentifier("history.journal.empty")
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(records) { record in
                        Button {
                            selectedDay = record.logicalDay
                        } label: {
                            JournalHistoryEntryRow(
                                record: record,
                                media: model.media(for: record.logicalDay),
                                loadThumbnail: model.thumbnailData,
                                showsDivider: record.id != records.last?.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, PulseDesign.spacing16)
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
            .sorted { $0.logicalDay > $1.logicalDay }
    }
}

private struct JournalHistoryEntryRow: View {
    let record: CheckInRecordSnapshot
    let media: ImprintMediaSnapshot?
    let loadThumbnail: (ImprintMediaSnapshot) async throws -> Data
    let showsDivider: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                    dateMark
                    details
                    if let media {
                        JournalHistoryThumbnail(media: media, load: loadThumbnail)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: PulseDesign.spacing16) {
                    dateMark
                    details
                    if let media {
                        JournalHistoryThumbnail(media: media, load: loadThumbnail)
                    }
                }
            }
        }
        .padding(.vertical, PulseDesign.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(PulseDesign.appDivider(for: visualTheme))
                    .frame(height: PulseDesign.thinLineWidth)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.journal.entry.\(record.logicalDay.storageValue)")
    }

    private var dateMark: some View {
        PulseDayMark(
            day: record.logicalDay.day,
            state: .kept,
            seed: PulseSealSeed.value(for: record.logicalDay),
            seal: PulseDesign.appAccent(for: visualTheme),
            ink: PulseDesign.appInk(for: visualTheme),
            muted: PulseDesign.appMuted(for: visualTheme)
        )
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
            HStack(alignment: .firstTextBaseline, spacing: PulseDesign.spacing8) {
                Text(weekday)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseDesign.appInk(for: visualTheme))
                Text(checkedAtText)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(fullDate) \(checkedAtText)")

            Text(record.journalNote ?? "")
                .font(PulseDesign.displayFont(size: 17, relativeTo: .body))
                .foregroundStyle(PulseDesign.appInk(for: visualTheme))
                .lineSpacing(4)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : PulseDesign.journalHistoryExcerptLineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var checkedAtText: String {
        String(
            format: PulseLocalization.string("today.checked_with_time", locale: locale),
            PulseFormatting.time(record.checkedAt, timeZone: record.timeZone, locale: locale)
        )
    }

    private var weekday: String {
        PulseFormatting.fullWeekday(record.logicalDay, timeZone: record.timeZone, locale: locale)
    }

    private var fullDate: String {
        PulseFormatting.fullDate(record.logicalDay, timeZone: record.timeZone, locale: locale)
    }
}

private struct JournalHistoryThumbnail: View {
    let media: ImprintMediaSnapshot
    let load: (ImprintMediaSnapshot) async throws -> Data

    @Environment(\.pulseVisualTheme) private var visualTheme
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if failed {
                Image(systemName: "photo.badge.exclamationmark")
                    .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(width: 56, height: 56)
        .background(PulseDesign.appSurface(for: visualTheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: media.thumbnailRelativePath) {
            image = nil
            failed = false
            do {
                let data = try await load(media)
                try Task.checkCancellation()
                image = UIImage(data: data)
                failed = image == nil
            } catch is CancellationError {
                return
            } catch {
                failed = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(failed ? "media.preview.unavailable" : "media.preview.accessibility")
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
        .subheadline.weight(.medium)
    }

    private var editorFont: Font {
        PulseDesign.displayFont(size: 18, relativeTo: .body)
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
