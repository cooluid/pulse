import SwiftUI
import PulseCore
import UniformTypeIdentifiers

struct HistoryView: View {
    @Bindable var model: PulseAppModel
    let primaryNavigationClearance: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @State private var selectedDay: LogicalDay?
    @State private var monthTransitionDirection = -1

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: PulseDesign.spacing4),
        count: 7
    )

    var body: some View {
        ZStack {
            PulseScreenBackground()
            PulseFieldBackground()

            VStack(spacing: 0) {
                PulseAppHeader(source: .history)

                GeometryReader { proxy in
                    ScrollView {
                        historyContent
                            .frame(
                                maxWidth: usesRegularWidthLayout
                                    ? PulseDesign.regularWidthContentMaxWidth
                                    : PulseDesign.historyMaxWidth
                            )
                            .frame(
                                minHeight: usesRegularWidthLayout ? proxy.size.height : nil,
                                alignment: .center
                            )
                            .padding(.horizontal, PulseDesign.horizontalPadding)
                            .padding(
                                .vertical,
                                usesRegularWidthLayout
                                    ? PulseDesign.regularWidthVerticalPadding
                                    : PulseDesign.spacing4
                            )
                            .padding(.bottom, scrollClearance)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedDay) { day in
            DayArchiveDetailView(day: day, model: model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        if usesRegularWidthLayout {
            HStack(alignment: .top, spacing: PulseDesign.regularWidthColumnGap) {
                VStack(spacing: 0) {
                    historyHeading
                    statisticsRow
                }
                .frame(maxWidth: .infinity)

                animatedCalendar
                    .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: 0) {
                historyHeading
                statisticsRow
                animatedCalendar
            }
            .padding(.bottom, PulseDesign.spacing24)
        }
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var scrollClearance: CGFloat {
        primaryNavigationClearance + PulseDesign.spacing16
    }

    private var historyHeading: some View {
        HStack(alignment: .bottom, spacing: PulseDesign.spacing16) {
            monthTitle

            Spacer(minLength: PulseDesign.spacing16)

            monthNavigationControls
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, PulseDesign.spacing16)
        .padding(.bottom, PulseDesign.spacing20)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PulseDesign.separator)
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
        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
            if let month = selectedMonth, let timeZone = model.timeZone {
                Text(
                    String(
                        format: PulseLocalization.string("history.archive_format", locale: locale),
                        PulseFormatting.year(month, timeZone: timeZone)
                    )
                )
                .font(.system(.caption2, design: .default, weight: .bold))
                .foregroundStyle(PulseDesign.secondary)

                Text(PulseFormatting.monthOnly(month, timeZone: timeZone, locale: locale))
                .font(.largeTitle.bold())
                .foregroundStyle(PulseDesign.ink)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.month.heading")
    }

    private var monthNavigationControls: some View {
        HStack(spacing: PulseDesign.spacing8) {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(
                        minWidth: PulseDesign.minimumHitTarget,
                        minHeight: PulseDesign.minimumHitTarget
                    )
            }
            .accessibilityLabel("history.previous_month")
            .accessibilityIdentifier("history.month.previous")

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(
                        minWidth: PulseDesign.minimumHitTarget,
                        minHeight: PulseDesign.minimumHitTarget
                    )
            }
            .disabled(isShowingCurrentMonth)
            .accessibilityLabel("history.next_month")
            .accessibilityIdentifier("history.month.next")
        }
        .font(.headline.weight(.semibold))
        .foregroundStyle(PulseDesign.ink)
        .buttonStyle(.plain)
    }

    private var statisticsRow: some View {
        HStack(spacing: 0) {
            StatisticTile(
                value: model.statistics.currentStreak,
                labelKey: "history.current_streak",
                accessibilityIdentifier: "history.stat.current"
            )

            Divider()

            StatisticTile(
                value: model.statistics.longestStreak,
                labelKey: "history.longest_streak",
                accessibilityIdentifier: "history.stat.longest"
            )

            Divider()

            StatisticTile(
                value: model.statistics.totalCount,
                labelKey: "history.total",
                accessibilityIdentifier: "history.stat.total"
            )
        }
        .padding(.vertical, PulseDesign.spacing20)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PulseDesign.separator)
                .frame(height: PulseDesign.thinLineWidth)
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
                    .font(.system(.caption2, design: .default, weight: .bold))
                    .foregroundStyle(PulseDesign.secondary)
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
    let value: Int
    let labelKey: LocalizedStringKey
    let accessibilityIdentifier: String

    var body: some View {
        VStack(spacing: PulseDesign.spacing4) {
            Text(value, format: .number)
                .font(.title2.bold())
                .monospacedDigit()
                .foregroundStyle(PulseDesign.ink)

            Text(labelKey)
                .font(.caption)
                .foregroundStyle(PulseDesign.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct CalendarDayCell: View {
    let item: CalendarDayItem
    let isToday: Bool
    let hasMedia: Bool
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            Circle()
                .fill(item.status == .checked ? PulseDesign.grass : Color.clear)
                .frame(
                    width: PulseDesign.calendarDayVisualSize,
                    height: PulseDesign.calendarDayVisualSize
                )

            if item.status == .checked {
                VStack(spacing: 0) {
                    Text(item.day.day, format: .number)
                        .font(.caption2.bold())
                        .monospacedDigit()
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                }
                .foregroundStyle(PulseDesign.grassForeground)
            } else if item.status == .missed {
                VStack(spacing: 0) {
                    Text(item.day.day, format: .number)
                        .font(.caption)
                        .monospacedDigit()
                    Image(systemName: "minus")
                        .font(.caption2.bold())
                        .accessibilityHidden(true)
                }
                .foregroundStyle(PulseDesign.secondary)
            } else {
                Text(item.day.day, format: .number)
                    .font(isToday ? .caption.bold() : .caption)
                    .monospacedDigit()
                    .foregroundStyle(PulseDesign.secondary)
                    .opacity(isDeemphasized ? PulseDesign.deemphasizedCalendarOpacity : 1)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: PulseDesign.calendarDayHitSize)
        .overlay {
            if isToday {
                Circle()
                    .stroke(PulseDesign.action, lineWidth: PulseDesign.emphasisLineWidth)
                    .frame(
                        width: PulseDesign.calendarDayVisualSize,
                        height: PulseDesign.calendarDayVisualSize
                    )
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if hasMedia {
                Image(systemName: "camera.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(PulseDesign.action)
                    .padding(PulseDesign.spacing4)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("calendar.day.\(item.day.storageValue)")
    }

    private var accessibilityLabel: String {
        let state: String
        switch item.status {
        case .checked:
            state = PulseLocalization.string("calendar.status.checked", locale: locale)
        case .missed:
            state = PulseLocalization.string("calendar.status.missed", locale: locale)
        case .todayPending:
            state = PulseLocalization.string("calendar.status.pending", locale: locale)
        case .future:
            state = PulseLocalization.string("calendar.status.future", locale: locale)
        case .beforeHabit:
            state = PulseLocalization.string("calendar.status.before_habit", locale: locale)
        }
        let base = String(
            format: PulseLocalization.string("accessibility.date_status_format", locale: locale),
            item.day.storageValue,
            state
        )
        guard hasMedia else { return base }
        return String(
            format: PulseLocalization.string("calendar.status.with_media_format", locale: locale),
            base
        )
    }

    private var isDeemphasized: Bool {
        item.status == .future || item.status == .beforeHabit
    }
}

private struct DayArchiveDetailView: View {
    let day: LogicalDay
    @Bindable var model: PulseAppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @State private var showsDeleteConfirmation = false
    @State private var showsMediaDeleteConfirmation = false
    @State private var photoDocument: ImprintPhotoDocument?
    @State private var showsPhotoExporter = false
    @State private var isPreparingPhotoExport = false

    private var record: CheckInRecordSnapshot? { model.record(for: day) }
    private var media: ImprintMediaSnapshot? { model.media(for: day) }

    var body: some View {
        ZStack {
            PulseScreenBackground()

            ScrollView {
                VStack(spacing: PulseDesign.spacing20) {
                    archiveHeader

                    if let media {
                        ImprintMediaPreview(media: media, load: model.thumbnailData)
                            .frame(maxWidth: .infinity)
                    }

                    archiveActionDock
                }
                .frame(maxWidth: PulseDesign.mediaCardMaxWidth)
                .padding(PulseDesign.spacing24)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tint(PulseDesign.tint)
        .fileExporter(
            isPresented: $showsPhotoExporter,
            document: photoDocument,
            contentType: .jpeg,
            defaultFilename: "pulse-\(day.storageValue).jpg"
        ) { _ in
            photoDocument = nil
        }
    }

    private var archiveHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: PulseDesign.spacing16) {
                PulseBrandMark(size: PulseDesign.recordDetailBrandMarkSize)
                archiveIdentity(alignment: .leading, textAlignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: PulseDesign.spacing12) {
                PulseBrandMark(size: PulseDesign.recordDetailBrandMarkSize)
                archiveIdentity(alignment: .center, textAlignment: .center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func archiveIdentity(
        alignment: HorizontalAlignment,
        textAlignment: TextAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: PulseDesign.spacing4) {
            Text(
                PulseFormatting.fullDate(
                    day,
                    timeZone: model.timeZone ?? .autoupdatingCurrent,
                    locale: locale
                )
            )
            .font(.title3.bold())
            .foregroundStyle(PulseDesign.ink)
            .multilineTextAlignment(textAlignment)

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
                .foregroundStyle(PulseDesign.secondary)
                .multilineTextAlignment(textAlignment)
            } else {
                Text("history.record_deleted_media_retained")
                    .foregroundStyle(PulseDesign.secondary)
                    .multilineTextAlignment(textAlignment)
            }
        }
        .frame(maxWidth: .infinity, alignment: textAlignment == .leading ? .leading : .center)
    }

    @ViewBuilder
    private var archiveActionDock: some View {
        if media != nil || record != nil {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    accessibilityActionGrid
                } else {
                    compactActionRow
                }
            }
            .padding(PulseDesign.spacing8)
            .background(
                PulseDesign.surface,
                in: RoundedRectangle(
                    cornerRadius: PulseDesign.mediaCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PulseDesign.mediaCornerRadius,
                    style: .continuous
                )
                .stroke(PulseDesign.separator, lineWidth: PulseDesign.thinLineWidth)
            }
        }
    }

    private var compactActionRow: some View {
        HStack(spacing: 0) {
            if let media {
                photoExportButton(media)
                actionDivider
                mediaDeleteButton(media)
            }

            if record != nil {
                if media != nil {
                    actionDivider
                }
                deleteButton
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var accessibilityActionGrid: some View {
        Grid(horizontalSpacing: PulseDesign.spacing8, verticalSpacing: PulseDesign.spacing8) {
            if let media {
                photoExportButton(media)
                    .gridCellColumns(2)

                if record != nil {
                    GridRow {
                        mediaDeleteButton(media)
                        deleteButton
                    }
                } else {
                    mediaDeleteButton(media)
                        .gridCellColumns(2)
                }
            } else if record != nil {
                deleteButton
                    .gridCellColumns(2)
            }
        }
    }

    private var actionDivider: some View {
        Divider()
            .frame(height: PulseDesign.minimumHitTarget)
            .padding(.horizontal, PulseDesign.spacing4)
    }

    private func photoExportButton(_ media: ImprintMediaSnapshot) -> some View {
        Button {
            guard !isPreparingPhotoExport else { return }
            isPreparingPhotoExport = true
            Task {
                defer { isPreparingPhotoExport = false }
                guard let data = await model.originalDataForExport(for: media) else { return }
                photoDocument = ImprintPhotoDocument(data: data)
                showsPhotoExporter = true
            }
        } label: {
            if isPreparingPhotoExport {
                archiveActionLabel(
                    "media.export_original",
                    systemImage: nil,
                    showsProgress: true
                )
            } else {
                archiveActionLabel(
                    "media.export_original",
                    systemImage: "square.and.arrow.up"
                )
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(PulseDesign.ink)
        .disabled(isPreparingPhotoExport)
        .accessibilityIdentifier("history.media.export.button")
    }

    private func mediaDeleteButton(_ media: ImprintMediaSnapshot) -> some View {
        Button(role: .destructive) {
            showsMediaDeleteConfirmation = true
        } label: {
            archiveActionLabel(
                "today.media.delete",
                systemImage: "photo.badge.minus"
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("history.media.delete.button")
        .confirmationDialog(
            "media.delete_confirmation.title",
            isPresented: $showsMediaDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("media.delete_confirmation.action", role: .destructive) {
                Task {
                    if await model.deleteMedia(id: media.id), record == nil {
                        dismiss()
                    }
                }
            }
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("media.delete_confirmation.message")
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showsDeleteConfirmation = true
        } label: {
            archiveActionLabel(
                "history.delete_record",
                systemImage: "calendar.badge.minus"
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("history.record.delete.button")
        .confirmationDialog(
            "history.delete_confirmation.title",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("history.delete_confirmation.action", role: .destructive) {
                Task {
                    if let record, await model.delete(recordID: record.id), media == nil {
                        dismiss()
                    }
                }
            }
            .accessibilityIdentifier("history.record.delete.confirm.button")
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("history.delete_confirmation.message")
        }
    }

    private func archiveActionLabel(
        _ title: LocalizedStringKey,
        systemImage: String?,
        showsProgress: Bool = false
    ) -> some View {
        VStack(spacing: PulseDesign.spacing4) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
            }

            Text(title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .frame(
            minHeight: dynamicTypeSize.isAccessibilitySize
                ? PulseDesign.accessibilityActionMinimumHeight
                : 60
        )
        .contentShape(Rectangle())
    }
}
