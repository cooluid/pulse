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
        ZStack {
            PulseScreenBackground()
            PulseFieldBackground(allowsMotion: isActive)

            VStack(spacing: 0) {
                PulseAppHeader(source: .history)

                GeometryReader { proxy in
                    ScrollView {
                        historyContent
                            .frame(maxWidth: PulseDesign.historyMaxWidth)
                            .frame(
                                minHeight: usesRegularWidthLayout ? proxy.size.height : nil,
                                alignment: .top
                            )
                            .padding(.horizontal, PulseDesign.horizontalPadding)
                            .padding(
                                .vertical,
                                usesRegularWidthLayout
                                    ? PulseDesign.regularWidthVerticalPadding
                                    : PulseDesign.spacing4
                            )
                            .padding(.bottom, PulseDesign.spacing16)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                }
            }

        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedDay) { day in
            DayArchiveDetailView(day: day, model: model)
        }
    }

    private var historyContent: some View {
        VStack(spacing: 0) {
            historyHeading
            statisticsRow
            historyModePicker
                .padding(.top, PulseDesign.spacing16)
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
        .background(PulseDesign.appSurface(for: visualTheme), in: RoundedRectangle(cornerRadius: modeCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: modeCornerRadius)
                .stroke(PulseDesign.appDivider(for: visualTheme), lineWidth: PulseDesign.thinLineWidth)
        }
    }

    private func historyModeButton(_ mode: HistoryContentMode) -> some View {
        let selected = contentMode == mode
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { contentMode = mode }
        } label: {
            Text(mode.titleKey)
                .font(modeFont)
                .foregroundStyle(modeForeground(selected: selected))
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: PulseDesign.minimumHitTarget)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: modeCornerRadius)
                            .fill(selectedModeBackground)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("history.mode.\(mode.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var modeCornerRadius: CGFloat {
        switch visualTheme {
        case .editorialJournal, .sunlitDay: 8
        case .quietField: 6
        case .prismLedger: 4
        case .immersion: 26
        }
    }

    private var modeFont: Font {
        visualTheme == .editorialJournal || visualTheme == .sunlitDay
            ? PulseDesign.editorialDisplayFont(size: 17, relativeTo: .subheadline)
            : .subheadline
    }

    private var selectedModeBackground: Color {
        visualTheme == .editorialJournal || visualTheme == .sunlitDay
            ? PulseDesign.appAccent(for: visualTheme)
            : PulseDesign.appAccentSoft(for: visualTheme)
    }

    private func modeForeground(selected: Bool) -> Color {
        if !selected { return PulseDesign.appMuted(for: visualTheme) }
        return visualTheme == .editorialJournal || visualTheme == .sunlitDay
            ? PulseDesign.appAccentForeground(for: visualTheme)
            : PulseDesign.appInk(for: visualTheme)
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var historyHeading: some View {
        HStack(spacing: PulseDesign.spacing8) {
            monthNavigationButton(offset: -1)
            Spacer(minLength: 0)
            monthTitle
            Spacer(minLength: 0)
            monthNavigationButton(offset: 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, PulseDesign.spacing12)
        .padding(.bottom, PulseDesign.spacing12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PulseDesign.appDivider(for: visualTheme))
                .frame(height: PulseDesign.thinLineWidth)
        }
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
                    .font(monthFont)
                    .foregroundStyle(visualTheme == .sunlitDay ? PulseDesign.appAccent(for: visualTheme) : PulseDesign.appInk(for: visualTheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.month.heading")
    }

    private var monthFont: Font {
        switch visualTheme {
        case .editorialJournal, .sunlitDay, .quietField:
            PulseDesign.editorialDisplayFont(size: 23, relativeTo: .title2)
        case .prismLedger: .system(.title3, design: .monospaced, weight: .medium)
        case .immersion: .system(.title3, weight: .bold)
        }
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
        Button {
            moveMonth(by: offset)
        } label: {
            Image(systemName: offset < 0 ? "chevron.left" : "chevron.right")
                .font(.body.weight(.medium))
                .foregroundStyle(
                    offset > 0 && isShowingCurrentMonth
                        ? PulseDesign.appMuted(for: visualTheme).opacity(0.5)
                        : visualTheme == .sunlitDay
                            ? PulseDesign.appAccent(for: visualTheme)
                            : PulseDesign.appInk(for: visualTheme)
                )
                .frame(minWidth: PulseDesign.minimumHitTarget,
                       minHeight: PulseDesign.minimumHitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(offset > 0 && isShowingCurrentMonth)
        .accessibilityLabel(offset < 0 ? "history.previous_month" : "history.next_month")
        .accessibilityIdentifier(offset < 0 ? "history.month.previous" : "history.month.next")
    }

    private var statisticsRow: some View {
        HStack(spacing: 0) {
            StatisticTile(
                value: model.statistics.currentStreak,
                labelKey: "history.current_streak",
                accessibilityIdentifier: "history.stat.current"
            )
            statisticDivider
            StatisticTile(
                value: model.statistics.longestStreak,
                labelKey: "history.longest_streak",
                accessibilityIdentifier: "history.stat.longest"
            )
            statisticDivider
            StatisticTile(
                value: model.statistics.totalCount,
                labelKey: "history.total",
                accessibilityIdentifier: "history.stat.total"
            )
        }
        .padding(.vertical, PulseDesign.spacing20)
        .overlay(alignment: .bottom) {
            if visualTheme == .sunlitDay {
                Rectangle()
                    .fill(PulseDesign.appDivider(for: visualTheme))
                    .frame(height: PulseDesign.thinLineWidth)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statisticDivider: some View {
        Rectangle()
            .fill(PulseDesign.appDivider(for: visualTheme))
            .frame(width: PulseDesign.thinLineWidth)
            .padding(.vertical, 4)
            .accessibilityHidden(true)
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
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
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
    let accessibilityIdentifier: String

    var body: some View {
        VStack(spacing: PulseDesign.spacing8) {
            Text(labelKey)
                .font(labelFont)
                .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(value, format: .number)
                .font(valueFont)
                .monospacedDigit()
                .foregroundStyle(
                    visualTheme == .editorialJournal || visualTheme == .sunlitDay
                        ? PulseDesign.appAccent(for: visualTheme)
                        : PulseDesign.appInk(for: visualTheme)
                )
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var labelFont: Font {
        visualTheme == .editorialJournal || visualTheme == .sunlitDay || visualTheme == .quietField
            ? PulseDesign.editorialDisplayFont(size: 14, relativeTo: .caption)
            : .caption
    }

    private var valueFont: Font {
        visualTheme == .editorialJournal || visualTheme == .sunlitDay || visualTheme == .quietField
            ? PulseDesign.editorialDisplayFont(size: 31, relativeTo: .title)
            : .system(.title)
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
        if record != nil {
            return [.fraction(PulseDesign.journalDetailDetentFraction), .large]
        }
        return [.fraction(PulseDesign.compactDetailDetentFraction), .large]
    }

    @ViewBuilder
    private var archiveIdentity: some View {
        switch visualTheme {
        case .editorialJournal:
            EditorialRecordDetailIdentity(
                day: day,
                record: record,
                habitName: model.habit?.name,
                timeZone: model.timeZone ?? .autoupdatingCurrent
            )
        case .sunlitDay:
            sunlitDetailIdentity
        case .quietField:
            quietArchiveIdentity
        case .prismLedger, .immersion:
            chromaticArchiveIdentity
        }
    }

    private var chromaticArchiveIdentity: some View {
        HStack(alignment: .top, spacing: PulseDesign.spacing16) {
            PulseBrandMark(size: PulseDesign.minimumHitTarget)

            VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                Text(
                    PulseFormatting.fullDate(
                        day,
                        timeZone: model.timeZone ?? .autoupdatingCurrent,
                        locale: locale
                    )
                )
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PulseDesign.appInk(for: visualTheme))
                .fixedSize(horizontal: false, vertical: true)

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
                    .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(PulseDesign.spacing16)
        .background(
            PulseDesign.appSurface(for: visualTheme).opacity(0.90),
            in: RoundedRectangle(
                cornerRadius: PulseDesign.spacing16,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PulseDesign.spacing16,
                style: .continuous
            )
            .stroke(
                PulseDesign.appDivider(for: visualTheme),
                lineWidth: PulseDesign.thinLineWidth
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.archive.identity")
    }

    private var quietArchiveIdentity: some View {
        HStack(alignment: .top, spacing: PulseDesign.spacing16) {
            PulseBrandMark(size: PulseDesign.minimumHitTarget)

            VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                Text(
                    PulseFormatting.fullDate(
                        day,
                        timeZone: model.timeZone ?? .autoupdatingCurrent,
                        locale: locale
                    )
                )
                .font(PulseDesign.editorialDisplayFont(size: 20, relativeTo: .title3).weight(.semibold))
                .foregroundStyle(PulseDesign.quietInk)
                .fixedSize(horizontal: false, vertical: true)

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
                    .foregroundStyle(PulseDesign.quietMuted)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("history.record_deleted_media_retained")
                        .foregroundStyle(PulseDesign.quietMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PulseDesign.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PulseDesign.quietGreenSoft,
            in: RoundedRectangle(
                cornerRadius: PulseDesign.spacing20,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.record.detail.identity")
    }

    private var sunlitDetailIdentity: some View {
        HStack(alignment: .top, spacing: PulseDesign.spacing16) {
            Image(systemName: record == nil ? "photo.fill" : "checkmark")
                .font(.headline.weight(.black))
                .foregroundStyle(PulseDesign.sunlitOnAccent)
                .frame(
                    width: PulseDesign.minimumHitTarget,
                    height: PulseDesign.minimumHitTarget
                )
                .background(
                    PulseDesign.sunlitAccent,
                    in: RoundedRectangle(
                        cornerRadius: PulseDesign.spacing12,
                        style: .continuous
                    )
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
                Text(
                    PulseFormatting.fullDate(
                        day,
                        timeZone: model.timeZone ?? .autoupdatingCurrent,
                        locale: locale
                    )
                )
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(PulseDesign.sunlitInk)
                .fixedSize(horizontal: false, vertical: true)

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
                    .foregroundStyle(PulseDesign.sunlitMuted)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("history.record_deleted_media_retained")
                        .foregroundStyle(PulseDesign.sunlitMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PulseDesign.spacing16)
        .background(
            PulseDesign.sunlitSurface,
            in: RoundedRectangle(
                cornerRadius: PulseDesign.sunlitPrintCornerRadius,
                style: .continuous
            )
        )
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
