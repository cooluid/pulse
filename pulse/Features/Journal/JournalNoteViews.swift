import PulseCore
import SwiftUI
import UIKit

struct JournalNoteSummary: View {
    let record: CheckInRecordSnapshot
    let onEdit: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
            HStack(alignment: .firstTextBaseline, spacing: PulseDesign.spacing12) {
                Text("journal.section.title")
                    .font(headingFont)
                    .foregroundStyle(PulseDesign.appInk(for: visualTheme))

                Spacer(minLength: PulseDesign.spacing8)

                Button(action: onEdit) {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                        .frame(minWidth: PulseDesign.minimumHitTarget,
                               minHeight: PulseDesign.minimumHitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(PulseDesign.appInk(for: visualTheme))
                .accessibilityLabel(record.journalNote == nil ? "journal.action.add" : "journal.action.edit")
                .accessibilityIdentifier("journal.edit.button")
            }

            Text(record.journalNote ?? PulseLocalization.string("journal.empty", locale: locale))
                .font(noteFont)
                .foregroundStyle(
                    record.journalNote == nil
                        ? PulseDesign.appMuted(for: visualTheme)
                        : PulseDesign.appInk(for: visualTheme)
                )
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(visualTheme == .moonTide ? PulseDesign.spacing16 : 0)
                .background {
                    if visualTheme == .moonTide {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(PulseDesign.appSurface(for: visualTheme).opacity(0.72))
                    }
                }
                .accessibilityIdentifier("journal.summary.text")
        }
        .padding(.horizontal, usesCard ? PulseDesign.spacing16 : 0)
        .padding(.vertical, PulseDesign.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PulseJournalPanel(theme: visualTheme))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.summary")
    }

    private var usesCard: Bool { visualTheme == .quietField || visualTheme == .prismLedger }

    private var headingFont: Font {
        visualTheme == .editorialJournal || visualTheme == .sunlitDay
            ? PulseDesign.editorialDisplayFont(size: 19, relativeTo: .headline).weight(.semibold)
            : .headline
    }

    private var noteFont: Font {
        visualTheme == .editorialJournal || visualTheme == .sunlitDay
            ? PulseDesign.editorialDisplayFont(size: 18, relativeTo: .body)
            : .body
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
    @ScaledMetric(relativeTo: .body) private var ruledLineHeight = 28.0

    var body: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
            if showsHeader {
                HStack(spacing: PulseDesign.spacing12) {
                    Text("journal.section.title")
                        .font(headingFont)
                        .foregroundStyle(PulseDesign.appInk(for: visualTheme))
                    Text("journal.optional")
                        .font(.caption)
                        .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                    Spacer(minLength: 0)
                    Button {
                        isFocused = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                            .frame(minWidth: PulseDesign.minimumHitTarget,
                                   minHeight: PulseDesign.minimumHitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PulseDesign.appInk(for: visualTheme))
                    .disabled(isDisabled)
                    .accessibilityLabel("journal.action.add")
                }
            }

            TextField("", text: $text, axis: .vertical)
                .lineLimit(draftLineLimit)
                .font(draftFont)
                .foregroundStyle(PulseDesign.appInk(for: visualTheme))
                .disabled(isDisabled)
                .focused($isFocused)
                .accessibilityLabel("journal.section.title")
                .accessibilityIdentifier("journal.draft.input")
                .padding(visualTheme == .editorialJournal || usesCard ? 0 : PulseDesign.spacing12)
                .frame(maxWidth: .infinity, minHeight: ruledLineHeight * 3, alignment: .topLeading)
                .background {
                    draftBackground
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded { isFocused = true },
                    including: isDisabled ? .none : .all
                )
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("action.done") { isFocused = false }
                            .accessibilityIdentifier("journal.keyboard.done")
                    }
                }

            HStack(alignment: .firstTextBaseline, spacing: PulseDesign.spacing8) {
                if !isValid {
                    Text(validationMessage)
                        .foregroundStyle(PulseDesign.systemDestructive)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("journal.draft.validation")
                }

                Spacer(minLength: 0)

                Text(characterCountText)
                    .foregroundStyle(isValid ? PulseDesign.appMuted(for: visualTheme) : PulseDesign.systemDestructive)
                    .accessibilityIdentifier("journal.draft.count")
            }
            .font(.caption2)
        }
        .padding(.horizontal, usesCard ? PulseDesign.spacing16 : 0)
        .padding(.vertical, PulseDesign.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PulseJournalPanel(theme: visualTheme))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.draft")
    }

    var isValid: Bool { JournalNote.accepts(userInput: text) }

    private var usesCard: Bool { visualTheme == .quietField || visualTheme == .prismLedger }

    private var draftLineLimit: ClosedRange<Int> {
        dynamicTypeSize.isAccessibilitySize ? 3...6 : 3...4
    }

    private var headingFont: Font {
        visualTheme == .editorialJournal || visualTheme == .sunlitDay
            ? PulseDesign.editorialDisplayFont(size: 19, relativeTo: .headline).weight(.semibold)
            : .headline
    }

    private var draftFont: Font {
        visualTheme == .editorialJournal || visualTheme == .sunlitDay
            ? PulseDesign.editorialDisplayFont(size: 18, relativeTo: .body)
            : .body
    }

    @ViewBuilder
    private var draftBackground: some View {
        if visualTheme == .editorialJournal {
            VStack(spacing: 0) {
                ForEach(0..<3) { _ in
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(PulseDesign.appDivider(for: visualTheme))
                        .frame(height: PulseDesign.thinLineWidth)
                }
            }
            .accessibilityHidden(true)
        } else if visualTheme == .moonTide || visualTheme == .sunlitDay {
            RoundedRectangle(cornerRadius: visualTheme == .moonTide ? 14 : 8)
                .fill(PulseDesign.appSurface(for: visualTheme).opacity(0.75))
                .overlay {
                    RoundedRectangle(cornerRadius: visualTheme == .moonTide ? 14 : 8)
                        .stroke(PulseDesign.appDivider(for: visualTheme), lineWidth: PulseDesign.thinLineWidth)
                }
        }
    }

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

private struct PulseJournalPanel: ViewModifier {
    let theme: PulseVisualTheme

    func body(content: Content) -> some View {
        content
            .background {
                if theme == .quietField || theme == .prismLedger {
                    RoundedRectangle(cornerRadius: theme == .quietField ? 24 : 4)
                        .fill(PulseDesign.appSurface(for: theme))
                }
            }
            .overlay {
                if theme == .quietField || theme == .prismLedger {
                    RoundedRectangle(cornerRadius: theme == .quietField ? 24 : 4)
                        .stroke(PulseDesign.appDivider(for: theme), lineWidth: PulseDesign.thinLineWidth)
                }
            }
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
                LazyVStack(spacing: usesCards ? PulseDesign.spacing12 : 0) {
                    ForEach(records) { record in
                        Button {
                            selectedDay = record.logicalDay
                        } label: {
                            JournalHistoryEntryRow(
                                record: record,
                                media: model.media(for: record.logicalDay),
                                loadThumbnail: model.thumbnailData
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

    private var usesCards: Bool { visualTheme == .quietField || visualTheme == .prismLedger }

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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibleEntry
            } else {
                regularEntry
            }
        }
        .padding(.horizontal, usesCards ? PulseDesign.spacing16 : 0)
        .padding(.vertical, PulseDesign.spacing20)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .background(entryBackground)
        .overlay(alignment: .bottom) {
            if !usesCards {
                Rectangle()
                    .fill(PulseDesign.appDivider(for: visualTheme))
                    .frame(height: PulseDesign.thinLineWidth)
                    .padding(.leading, visualTheme == .moonTide && !dynamicTypeSize.isAccessibilitySize ? 44 : 0)
            }
        }
        .overlay(alignment: .leading) {
            if visualTheme == .moonTide && !dynamicTypeSize.isAccessibilitySize {
                Rectangle()
                    .fill(PulseDesign.appAccent(for: visualTheme).opacity(0.36))
                    .frame(width: 1)
                    .padding(.leading, 15)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.journal.entry.\(record.logicalDay.storageValue)")
    }

    private var regularEntry: some View {
        HStack(alignment: .top, spacing: PulseDesign.spacing12) {
            if visualTheme == .editorialJournal {
                stampedDate
            } else if visualTheme == .sunlitDay {
                calendarDate
            } else if visualTheme == .moonTide {
                Image("PulseTideTick")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 16)
                    .padding(.top, 14)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
                if visualTheme != .editorialJournal && visualTheme != .sunlitDay {
                    dateHeading
                }
                checkedAt
                noteText
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let media {
                JournalHistoryThumbnail(media: media, load: loadThumbnail)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.medium))
                .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)
        }
    }

    private var accessibleEntry: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            dateHeading
            checkedAt
            noteText
            if let media {
                JournalHistoryThumbnail(media: media, load: loadThumbnail)
            }
        }
    }

    private var stampedDate: some View {
        VStack(spacing: PulseDesign.spacing8) {
            Text(numericDate)
                .font(PulseDesign.editorialDisplayFont(size: 19, relativeTo: .headline))
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(PulseDesign.appAccent(for: visualTheme), lineWidth: 1.2)
                }
                .rotationEffect(.degrees(-7))
            Text(weekday)
                .font(PulseDesign.editorialDisplayFont(size: 12, relativeTo: .caption))
        }
        .foregroundStyle(PulseDesign.appAccent(for: visualTheme))
        .frame(width: 72)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(fullDate)
    }

    private var calendarDate: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.logicalDay.day, format: .number)
                .font(PulseDesign.editorialDisplayFont(size: 44, relativeTo: .largeTitle))
                .foregroundStyle(PulseDesign.appAccent(for: visualTheme))
            Text(weekday)
                .font(.caption2)
                .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
        }
        .frame(width: 66, alignment: .leading)
        .overlay(alignment: .topLeading) {
            JournalCalendarFold()
                .fill(PulseDesign.appAccent(for: visualTheme))
                .frame(width: 14, height: 14)
                .offset(x: -4, y: -12)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(fullDate)
    }

    private var dateHeading: some View {
        Text(dynamicTypeSize.isAccessibilitySize ? fullDate : "\(numericDate)  \(weekday)")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(PulseDesign.appInk(for: visualTheme))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var checkedAt: some View {
        Text(String(
            format: PulseLocalization.string("today.checked_with_time", locale: locale),
            PulseFormatting.time(record.checkedAt, timeZone: record.timeZone, locale: locale)
        ))
        .font(.caption)
        .foregroundStyle(visualTheme == .sunlitDay ? PulseDesign.appAccent(for: visualTheme) : PulseDesign.appMuted(for: visualTheme))
        .fixedSize(horizontal: false, vertical: true)
    }

    private var noteText: some View {
        Text(record.journalNote ?? "")
            .font(noteFont)
            .foregroundStyle(PulseDesign.appInk(for: visualTheme))
            .lineSpacing(4)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : PulseDesign.journalHistoryExcerptLineLimit)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var noteFont: Font {
        visualTheme == .editorialJournal || visualTheme == .sunlitDay
            ? PulseDesign.editorialDisplayFont(size: 17, relativeTo: .body)
            : .body
    }

    private var numericDate: String {
        String(format: "%02d.%02d", record.logicalDay.month, record.logicalDay.day)
    }

    private var weekday: String {
        PulseFormatting.fullWeekday(record.logicalDay, timeZone: record.timeZone, locale: locale)
    }

    private var fullDate: String {
        PulseFormatting.fullDate(record.logicalDay, timeZone: record.timeZone, locale: locale)
    }

    private var usesCards: Bool { visualTheme == .quietField || visualTheme == .prismLedger }

    @ViewBuilder
    private var entryBackground: some View {
        if visualTheme == .quietField {
            PulseQuietSpeechBubbleShape()
                .fill(PulseDesign.quietSurface.opacity(PulseDesign.journalHistorySurfaceOpacity))
                .overlay {
                    PulseQuietSpeechBubbleShape()
                        .stroke(PulseDesign.quietDivider, lineWidth: PulseDesign.thinLineWidth)
                }
        } else if visualTheme == .prismLedger {
            RoundedRectangle(cornerRadius: PulseDesign.spacing16)
                .fill(PulseDesign.appSurface(for: visualTheme).opacity(0.9))
                .overlay {
                    RoundedRectangle(cornerRadius: PulseDesign.spacing16)
                        .stroke(PulseDesign.appDivider(for: visualTheme), lineWidth: PulseDesign.thinLineWidth)
                }
        }
    }
}

private struct JournalCalendarFold: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
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
                    .scaledToFit()
            } else if failed {
                Image(systemName: "photo.badge.exclamationmark")
                    .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
        .background(PulseDesign.appSurface(for: visualTheme))
        .clipShape(RoundedRectangle(cornerRadius: 4))
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

    private var thumbnailSize: CGSize {
        let ratio = CGFloat(media.pixelWidth) / CGFloat(media.pixelHeight)
        return CGSize(width: min(64, 84 * ratio), height: min(84, 64 / ratio))
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
        case .immersion:
            .system(.headline, weight: .semibold)
        }
    }

    private var editorFont: Font {
        switch visualTheme {
        case .editorialJournal:
            .system(.body, design: .serif)
        case .quietField, .sunlitDay, .moonTide, .prismLedger:
            .system(.body, design: .rounded)
        case .immersion:
            .system(.body)
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
