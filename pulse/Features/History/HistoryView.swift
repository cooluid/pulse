import PulseCore
import SwiftUI
import UniformTypeIdentifiers

private enum HistoryContentMode: String {
    case calendar
    case journal

    var titleKey: LocalizedStringKey {
        switch self {
        case .calendar: "history.mode.calendar"
        case .journal: "history.mode.journal"
        }
    }
}

struct HistoryView: View {
    @Bindable var model: PulseAppModel
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme
    @State private var selectedDay: LogicalDay?
    @State private var monthTransitionDirection = -1
    @State private var contentMode: HistoryContentMode = .calendar

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: PulseDesign.spacing4),
        count: 7
    )

    var body: some View {
        ScrollView {
            historyContent
                .frame(maxWidth: PulseDesign.historyMaxWidth)
                .padding(.horizontal, PulseDesign.horizontalPadding)
                .padding(.top, usesRegularWidthLayout ? PulseDesign.regularWidthVerticalPadding : 0)
                .padding(.bottom, PulseDesign.spacing16)
                .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(PulseScreenBackground())
        .pulsePrimaryToolbar(source: .history)
        .sheet(item: $selectedDay) { day in
            DayArchiveDetailView(day: day, model: model)
        }
    }

    private var palette: PulseThemePalette { PulseDesign.palette(for: visualTheme) }

    private var historyContent: some View {
        VStack(spacing: 0) {
            historyHeading
            statisticsRow
                .padding(.top, PulseDesign.spacing20)
            historyModePicker
                .padding(.top, PulseDesign.spacing24)
            Group {
                switch contentMode {
                case .calendar: animatedCalendar
                case .journal: JournalHistorySection(model: model, selectedDay: $selectedDay)
                }
            }
        }
        .padding(.bottom, PulseDesign.spacing24)
    }

    private var historyModePicker: some View {
        HStack(spacing: 0) {
            historyModeButton(.calendar)
            historyModeButton(.journal)
        }
        .padding(PulseDesign.spacing4)
        .background(palette.paperRaised, in: Capsule())
    }

    private func historyModeButton(_ mode: HistoryContentMode) -> some View {
        let selected = contentMode == mode
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { contentMode = mode }
        } label: {
            Text(mode.titleKey)
                .font(.subheadline.weight(selected ? .semibold : .medium))
                .foregroundStyle(selected ? palette.seal : palette.muted)
                .padding(.vertical, PulseDesign.spacing8)
                .frame(maxWidth: .infinity, minHeight: PulseDesign.minimumHitTarget - PulseDesign.spacing8)
                .background {
                    if selected {
                        Capsule().fill(palette.sealWash)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("history.mode.\(mode.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var historyHeading: some View {
        HStack(spacing: PulseDesign.spacing8) {
            monthTitle
            Spacer(minLength: PulseDesign.spacing8)
            monthNavigationButton(offset: -1)
            monthNavigationButton(offset: 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, PulseDesign.spacing4)
        .contentShape(Rectangle())
        .simultaneousGesture(monthSwipeGesture)
        .accessibilityAction(named: Text("history.previous_month")) {
            moveMonth(by: -1)
        }
        .accessibilityAction(named: Text("history.next_month")) {
            moveMonth(by: 1)
        }
    }

    private var monthTitle: some View {
        Group {
            if let month = selectedMonth, let timeZone = model.timeZone {
                Text(monthHeading(month, timeZone: timeZone))
                    .font(PulseDesign.displayFont(size: 30, relativeTo: .largeTitle).weight(.bold))
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.month.heading")
    }

    private func monthHeading(_ month: LogicalDay, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = .pulseGregorian(timeZone: timeZone)
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: month.date(timeZone: timeZone))
    }

    private func monthNavigationButton(offset: Int) -> some View {
        let isDisabled = offset > 0 && isShowingCurrentMonth
        return Button {
            moveMonth(by: offset)
        } label: {
            Image(systemName: offset < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isDisabled ? palette.muted.opacity(0.45) : palette.ink)
                .frame(width: 38, height: 38)
                .background(palette.paperRaised, in: Circle())
                .frame(minWidth: PulseDesign.minimumHitTarget, minHeight: PulseDesign.minimumHitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(offset < 0 ? "history.previous_month" : "history.next_month")
        .accessibilityIdentifier(offset < 0 ? "history.month.previous" : "history.month.next")
    }

    /// Three tiles side by side; at accessibility sizes they stack so no label breaks into single characters.
    private var statisticsRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: PulseDesign.spacing12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: PulseDesign.spacing12))
        return layout {
            StatisticTile(
                value: model.statistics.currentStreak,
                labelKey: "history.current_streak",
                isLeading: true,
                accessibilityIdentifier: "history.stat.current"
            )
            StatisticTile(
                value: model.statistics.longestStreak,
                labelKey: "history.longest_streak",
                isLeading: false,
                accessibilityIdentifier: "history.stat.longest"
            )
            StatisticTile(
                value: model.statistics.totalCount,
                labelKey: "history.total",
                isLeading: false,
                accessibilityIdentifier: "history.stat.total"
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var calendar: some View {
        LazyVGrid(columns: columns, spacing: PulseDesign.spacing8) {
            ForEach(
                Array(
                    PulseFormatting.weekdayHeaders(
                        weekStart: model.settings.weekStart,
                        locale: locale
                    ).enumerated()
                ),
                id: \.offset
            ) { index, weekday in
                Text(weekday)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.muted)
                    .frame(maxWidth: .infinity, minHeight: PulseDesign.spacing24)
                    .accessibilityIdentifier("calendar.weekday.\(index)")
            }

            ForEach(leadingPlaceholderIDs, id: \.self) { _ in
                Color.clear
                    .frame(height: PulseDesign.calendarDayHitSize)
                    .accessibilityHidden(true)
            }

            ForEach(model.calendarItemsForSelectedMonth()) { item in
                let hasMedia = model.hasMedia(for: item.day)
                if item.status == .checked || hasMedia {
                    Button {
                        selectedDay = item.day
                    } label: {
                        CalendarDayCell(
                            item: item,
                            isToday: item.day == model.today,
                            hasMedia: hasMedia
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    CalendarDayCell(
                        item: item,
                        isToday: item.day == model.today,
                        hasMedia: false
                    )
                }
            }
        }
        .padding(.top, PulseDesign.spacing20)
    }

    private var animatedCalendar: some View {
        calendar
            .id(selectedMonth)
            .transition(monthTransition)
    }

    private var selectedMonth: LogicalDay? {
        model.selectedMonth ?? model.today?.firstDayOfMonth()
    }

    private var leadingEmptyDays: Int {
        guard let month = selectedMonth, let timeZone = model.timeZone else { return 0 }
        let calendar = Calendar.pulseGregorian(timeZone: timeZone)
        let weekday = calendar.component(.weekday, from: month.date(timeZone: timeZone))
        return (weekday - model.settings.weekStart.rawValue + 7) % 7
    }

    private var leadingPlaceholderIDs: [String] {
        (0..<leadingEmptyDays).map { "calendar.leading.\($0)" }
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: PulseDesign.minimumHitTarget)
            .onEnded { value in
                if value.translation.width > PulseDesign.minimumHitTarget {
                    moveMonth(by: -1)
                } else if value.translation.width < -PulseDesign.minimumHitTarget {
                    moveMonth(by: 1)
                }
            }
    }

    private var isShowingCurrentMonth: Bool {
        selectedMonth == model.today?.firstDayOfMonth()
    }

    private var monthTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        if monthTransitionDirection > 0 {
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        }
        return .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }

    private func moveMonth(by offset: Int) {
        guard offset != 0 else { return }
        guard offset < 0 || !isShowingCurrentMonth else { return }
        monthTransitionDirection = offset

        guard !reduceMotion else {
            model.moveSelectedMonth(by: offset)
            return
        }
        withAnimation(.easeInOut(duration: PulseDesign.monthTransitionDuration)) {
            model.moveSelectedMonth(by: offset)
        }
    }
}

private struct StatisticTile: View {
    @Environment(\.pulseVisualTheme) private var visualTheme
    let value: Int
    let labelKey: LocalizedStringKey
    let isLeading: Bool
    let accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
            Text(value, format: .number)
                .font(PulseDesign.displayFont(size: 32, relativeTo: .title).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(
                    isLeading ? PulseDesign.appAccent(for: visualTheme) : PulseDesign.appInk(for: visualTheme)
                )
            Text(labelKey)
                .font(.caption.weight(.medium))
                .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, PulseDesign.spacing16)
        .padding(.vertical, PulseDesign.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PulseDesign.appSurface(for: visualTheme),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct DayArchiveDetailView: View {
    let day: LogicalDay
    @Bindable var model: PulseAppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var pendingDestructiveAction: DestructiveAction?
    @State private var photoDocument: ImprintPhotoDocument?
    @State private var showsPhotoExporter = false
    @State private var isPreparingPhotoExport = false
    @State private var showsJournalEditor = false
    @State private var showsOriginal = false

    private enum DestructiveAction {
        case media(UUID)
        case record(UUID)
    }

    private var record: CheckInRecordSnapshot? { model.record(for: day) }
    private var media: ImprintMediaSnapshot? { model.media(for: day) }

    var body: some View {
        PulseDetailSheetScaffold(
            title: "history.detail.title",
            detents: archivePresentationDetents
        ) {
            archiveIdentity

            if let record {
                JournalNoteSummary(record: record) {
                    showsJournalEditor = true
                }
            }

            if let media {
                ImprintMediaPreviewButton(
                    media: media,
                    load: model.thumbnailData,
                    accessibilityIdentifier: "history.media.preview",
                    onOpen: { showsOriginal = true }
                )
                    .frame(maxWidth: .infinity)
            }
        } actions: {
            archiveActionsMenu
        }
        .fileExporter(
            isPresented: $showsPhotoExporter,
            document: photoDocument,
            contentType: .jpeg,
            defaultFilename: "pulse-\(day.storageValue).jpg"
        ) { result in
            if case .failure(let error) = result {
                model.errorMessage = error.localizedDescription
            }
            photoDocument = nil
        }
        .sheet(isPresented: $showsJournalEditor) {
            if let record {
                JournalNoteEditorSheet(record: record, model: model)
            }
        }
        .fullScreenCover(isPresented: $showsOriginal) {
            if let media {
                ImprintMediaFullscreenViewer(media: media, load: model.originalData)
            }
        }
    }

    private var archivePresentationDetents: Set<PresentationDetent> {
        if media != nil || dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact {
            return [.large]
        }
        return [.fraction(PulseDesign.journalDetailDetentFraction + 0.08), .large]
    }

    /// The day's own impression: the same tilt and grain it has everywhere else.
    private var archiveIdentity: some View {
        let palette = PulseDesign.palette(for: visualTheme)
        let timeZone = model.timeZone ?? .autoupdatingCurrent
        return HStack(alignment: .center, spacing: PulseDesign.spacing20) {
            Group {
                if record != nil {
                    PulseSealImpression(
                        inscription: .name(model.habit?.name ?? ""),
                        ink: palette.seal,
                        seed: PulseSealSeed.value(for: day)
                    )
                    .rotationEffect(PulseSealSeed.tilt(for: PulseSealSeed.value(for: day)))
                } else {
                    PulseSealSlot(inscription: .name(model.habit?.name ?? ""), tint: palette.muted)
                }
            }
            .frame(width: dynamicTypeSize.isAccessibilitySize ? 72 : 96, height: dynamicTypeSize.isAccessibilitySize ? 72 : 96)

            VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
                Text(PulseFormatting.fullDate(day, timeZone: timeZone, locale: locale))
                    .font(PulseDesign.displayFont(size: 22, relativeTo: .title2).weight(.bold))
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Group {
                    if let record {
                        Text(
                            String(
                                format: PulseLocalization.string("history.checked_at", locale: locale),
                                PulseFormatting.time(record.checkedAt, timeZone: record.timeZone, locale: locale)
                            )
                        )
                        .monospacedDigit()
                    } else {
                        Text("history.record_deleted_media_retained")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, PulseDesign.spacing8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.record.detail.identity")
    }

    private var archiveActionsMenu: some View {
        PulseDetailActionsMenu(
            accessibilityLabel: "history.record_actions",
            accessibilityHint: "history.record_actions_hint",
            accessibilityIdentifier: "history.record.actions.menu",
            isBusy: isPreparingPhotoExport
        ) {
            if let media {
                Button {
                    preparePhotoExport(media)
                } label: {
                    Label("media.export_original", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("history.media.export.action")

                Divider()

                Button(role: .destructive) {
                    pendingDestructiveAction = .media(media.id)
                } label: {
                    Label("today.media.delete", systemImage: "trash")
                }
                .tint(PulseDesign.systemDestructive)
                .accessibilityIdentifier("history.media.delete.action")
            }

            if let record {
                Button(role: .destructive) {
                    pendingDestructiveAction = .record(record.id)
                } label: {
                    Label("history.delete_record", systemImage: "calendar.badge.minus")
                }
                .tint(PulseDesign.systemDestructive)
                .accessibilityIdentifier("history.record.delete.action")
            }
        }
        .disabled(isPreparingPhotoExport)
        .confirmationDialog(
            destructiveConfirmationTitle,
            isPresented: showsDestructiveConfirmation,
            titleVisibility: .visible
        ) {
            switch pendingDestructiveAction {
            case .media(let id):
                Button("media.delete_confirmation.action", role: .destructive) {
                    confirmDestructiveAction(.media(id))
                }
                .accessibilityIdentifier("history.media.delete.confirmation.action")
            case .record(let id):
                Button("history.delete_confirmation.action", role: .destructive) {
                    confirmDestructiveAction(.record(id))
                }
                .accessibilityIdentifier("history.record.delete.confirmation.action")
            case nil:
                EmptyView()
            }
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text(destructiveConfirmationMessage)
        }
    }

    private var showsDestructiveConfirmation: Binding<Bool> {
        Binding {
            pendingDestructiveAction != nil
        } set: { isPresented in
            if !isPresented {
                pendingDestructiveAction = nil
            }
        }
    }

    private var destructiveConfirmationTitle: LocalizedStringKey {
        switch pendingDestructiveAction {
        case .media:
            "media.delete_confirmation.title"
        case .record:
            "history.delete_confirmation.title"
        case nil:
            "history.record_actions"
        }
    }

    private var destructiveConfirmationMessage: LocalizedStringKey {
        switch pendingDestructiveAction {
        case .media:
            "media.delete_confirmation.message"
        case .record:
            record?.journalNote == nil
                ? "history.delete_confirmation.message"
                : "history.delete_confirmation.message_with_journal"
        case nil:
            "history.record_actions_hint"
        }
    }

    private func preparePhotoExport(_ media: ImprintMediaSnapshot) {
        guard !isPreparingPhotoExport else { return }
        isPreparingPhotoExport = true
        Task {
            defer { isPreparingPhotoExport = false }
            guard let data = await model.originalDataForExport(for: media) else { return }
            photoDocument = ImprintPhotoDocument(data: data)
            showsPhotoExporter = true
        }
    }

    private func confirmDestructiveAction(_ action: DestructiveAction) {
        pendingDestructiveAction = nil
        let dismissAfterMediaDelete = record == nil
        let dismissAfterRecordDelete = media == nil

        Task {
            switch action {
            case .media(let id):
                if await model.deleteMedia(id: id), dismissAfterMediaDelete {
                    dismiss()
                }
            case .record(let id):
                if await model.delete(recordID: id), dismissAfterRecordDelete {
                    dismiss()
                }
            }
        }
    }
}
