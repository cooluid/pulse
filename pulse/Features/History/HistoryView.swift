import SwiftUI
import PulseCore
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

    var systemImage: String {
        switch self {
        case .calendar: "calendar"
        case .journal: "square.and.pencil"
        }
    }
}

struct HistoryView: View {
    @Bindable var model: PulseAppModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme
    @State private var selectedDay: LogicalDay?
    @State private var monthTransitionDirection = -1
    @State private var contentMode: HistoryContentMode = .calendar
    @Namespace private var contentModeNamespace

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

            historyThemeMarker
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedDay) { day in
            DayArchiveDetailView(day: day, model: model)
        }
    }

    private var historyThemeMarker: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(visualTheme.localizedName(locale: locale))
            .accessibilityIdentifier(themeMarkerIdentifier)
    }

    private var themeMarkerIdentifier: String {
        switch visualTheme {
        case .quietField:
            "history.theme.quiet-field"
        case .editorialJournal:
            "history.theme.editorial-journal"
        case .tideArchive:
            "history.theme.tide-archive"
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        switch visualTheme {
        case .tideArchive:
            archiveHistoryContent
        case .editorialJournal, .quietField:
            standardHistoryContent
        }
    }

    private var standardHistoryContent: some View {
        VStack(spacing: 0) {
            historyHeading
            statisticsRow
            historyModePicker
                .padding(.top, PulseDesign.spacing16)
            Group {
                switch contentMode {
                case .calendar:
                    animatedCalendar
                case .journal:
                    JournalHistorySection(model: model, selectedDay: $selectedDay)
                }
            }
            .id(contentMode)
            .transition(.opacity)
        }
        .padding(.bottom, PulseDesign.spacing24)
    }

    private var archiveHistoryContent: some View {
        VStack(spacing: 0) {
            archiveMonthHero
            archiveStatisticsBand
            historyModePicker
                .padding(.top, PulseDesign.spacing16)
            Group {
                switch contentMode {
                case .calendar:
                    animatedCalendar
                case .journal:
                    JournalHistorySection(model: model, selectedDay: $selectedDay)
                }
            }
            .id(contentMode)
            .transition(.opacity)
        }
        .padding(PulseDesign.spacing20)
        .background {
            RoundedRectangle(
                cornerRadius: PulseDesign.archiveHistoryLedgerCornerRadius,
                style: .continuous
            )
            .fill(
                PulseDesign.archivePaper.opacity(
                    PulseDesign.archiveHistoryLedgerOpacity
                )
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: PulseDesign.archiveHistoryLedgerCornerRadius,
                style: .continuous
            )
            .stroke(
                PulseDesign.archiveCopper.opacity(
                    PulseDesign.archiveHistoryLedgerBorderOpacity
                ),
                lineWidth: PulseDesign.thinLineWidth
            )
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(PulseDesign.archiveCopper)
                .frame(width: PulseDesign.emphasisLineWidth)
                .padding(.vertical, PulseDesign.spacing24)
        }
        .padding(.bottom, PulseDesign.spacing24)
    }

    private var historyModePicker: some View {
        HStack(spacing: PulseDesign.spacing4) {
            historyModeButton(.calendar)
            historyModeButton(.journal)
        }
        .padding(PulseDesign.historyModePickerInset)
        .frame(height: PulseDesign.historyModePickerHeight)
        .background {
            RoundedRectangle(
                cornerRadius: PulseDesign.historyModePickerCornerRadius,
                style: .continuous
            )
            .fill(historyModePickerSurface)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: PulseDesign.historyModePickerCornerRadius,
                style: .continuous
            )
            .stroke(PulseDesign.separator, lineWidth: PulseDesign.thinLineWidth)
        }
    }

    private func historyModeButton(_ mode: HistoryContentMode) -> some View {
        let isSelected = contentMode == mode

        return Button {
            guard contentMode != mode else { return }
            if reduceMotion {
                contentMode = mode
            } else {
                withAnimation(
                    .easeInOut(duration: PulseDesign.primaryContentTransitionDuration)
                ) {
                    contentMode = mode
                }
            }
        } label: {
            Label(mode.titleKey, systemImage: mode.systemImage)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(
                    isSelected ? historyModeSelectedForeground : PulseDesign.secondary
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if isSelected {
                        RoundedRectangle(
                            cornerRadius: PulseDesign.historyModePickerItemCornerRadius,
                            style: .continuous
                        )
                        .fill(PulseDesign.appSuccess(for: visualTheme))
                        .matchedGeometryEffect(
                            id: "history.mode.selection",
                            in: contentModeNamespace
                        )
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("history.mode.\(mode.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var historyModePickerSurface: Color {
        PulseDesign.appSurface(for: visualTheme).opacity(
            PulseDesign.historyModePickerSurfaceOpacity
        )
    }

    private var historyModeSelectedForeground: Color {
        switch visualTheme {
        case .quietField:
            PulseDesign.grassForeground
        case .editorialJournal:
            PulseDesign.background
        case .tideArchive:
            PulseDesign.archiveNight
        }
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
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

    private var archiveMonthHero: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            HStack(alignment: .center, spacing: PulseDesign.spacing16) {
                if let month = selectedMonth, let timeZone = model.timeZone {
                    Text(
                        String(
                            format: PulseLocalization.string(
                                "history.archive_format",
                                locale: locale
                            ),
                            PulseFormatting.year(month, timeZone: timeZone)
                        )
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseDesign.secondary)
                    .accessibilityHidden(true)
                }

                Spacer(minLength: PulseDesign.spacing12)

                archiveMonthNavigationControls
            }

            if let month = selectedMonth, let timeZone = model.timeZone {
                HStack(alignment: .lastTextBaseline, spacing: PulseDesign.spacing16) {
                    Text(String(format: "%02d", month.month))
                        .font(.system(size: PulseDesign.archiveHistoryMonthSize, weight: .medium))
                        .monospacedDigit()
                        .tracking(PulseDesign.archiveHistoryMonthTracking)
                        .foregroundStyle(PulseDesign.ink)

                    VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                        Text(PulseFormatting.monthOnly(month, timeZone: timeZone, locale: locale))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(PulseDesign.ink)

                        Rectangle()
                            .fill(PulseDesign.archiveCopper)
                            .frame(
                                width: PulseDesign.archiveHistoryAccentWidth,
                                height: PulseDesign.emphasisLineWidth
                            )
                            .accessibilityHidden(true)
                    }
                    .padding(.bottom, PulseDesign.spacing12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, PulseDesign.spacing8)
        .contentShape(Rectangle())
        .simultaneousGesture(monthSwipeGesture)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.month.heading")
        .accessibilityAction(named: Text("history.previous_month")) {
            moveMonth(by: -1)
        }
        .accessibilityAction(named: Text("history.next_month")) {
            moveMonth(by: 1)
        }
    }

    private var archiveMonthNavigationControls: some View {
        HStack(spacing: PulseDesign.spacing8) {
            archiveMonthNavigationButton(
                systemName: "chevron.left",
                accessibilityLabel: "history.previous_month",
                accessibilityIdentifier: "history.month.previous"
            ) {
                moveMonth(by: -1)
            }

            archiveMonthNavigationButton(
                systemName: "chevron.right",
                accessibilityLabel: "history.next_month",
                accessibilityIdentifier: "history.month.next",
                isDisabled: isShowingCurrentMonth
            ) {
                moveMonth(by: 1)
            }
        }
    }

    private func archiveMonthNavigationButton(
        systemName: String,
        accessibilityLabel: LocalizedStringKey,
        accessibilityIdentifier: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulseDesign.ink)
                .frame(
                    width: PulseDesign.minimumHitTarget,
                    height: PulseDesign.minimumHitTarget
                )
                .background(
                    PulseDesign.archivePaper,
                    in: RoundedRectangle(
                        cornerRadius: PulseDesign.archiveCalendarDayCornerRadius,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: PulseDesign.archiveCalendarDayCornerRadius,
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
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? PulseDesign.disabledControlOpacity : 1)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var archiveStatisticsBand: some View {
        HStack(spacing: 0) {
            ArchiveStatisticTile(
                value: model.statistics.currentStreak,
                labelKey: "history.current_streak",
                accessibilityIdentifier: "history.stat.current"
            )

            archiveStatisticDivider

            ArchiveStatisticTile(
                value: model.statistics.longestStreak,
                labelKey: "history.longest_streak",
                accessibilityIdentifier: "history.stat.longest"
            )

            archiveStatisticDivider

            ArchiveStatisticTile(
                value: model.statistics.totalCount,
                labelKey: "history.total",
                accessibilityIdentifier: "history.stat.total"
            )
        }
        .padding(.vertical, PulseDesign.spacing16)
        .overlay(alignment: .top) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(PulseDesign.archiveCopper)
                    .frame(width: PulseDesign.archiveHistoryAccentWidth)
                Rectangle()
                    .fill(PulseDesign.separator)
            }
            .frame(height: PulseDesign.thinLineWidth)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PulseDesign.separator)
                .frame(height: PulseDesign.thinLineWidth)
        }
    }

    private var archiveStatisticDivider: some View {
        Rectangle()
            .fill(PulseDesign.separator)
            .frame(
                width: PulseDesign.thinLineWidth,
                height: PulseDesign.archiveHistoryStatisticDividerHeight
            )
            .accessibilityHidden(true)
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
        .padding(.top, visualTheme == .tideArchive ? PulseDesign.spacing16 : PulseDesign.spacing20)
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

private struct ArchiveStatisticTile: View {
    let value: Int
    let labelKey: LocalizedStringKey
    let accessibilityIdentifier: String

    var body: some View {
        VStack(spacing: PulseDesign.spacing4) {
            Text(value, format: .number)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(PulseDesign.ink)

            Text(labelKey)
                .font(.caption2.weight(.medium))
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
    @Environment(\.pulseVisualTheme) private var visualTheme

    @ViewBuilder
    var body: some View {
        switch visualTheme {
        case .tideArchive:
            archiveCell
        case .editorialJournal:
            editorialCell
        case .quietField:
            quietCell
        }
    }

    private var quietCell: some View {
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
            } else if item.status == .beforeHabit {
                VStack(spacing: 0) {
                    Text(item.day.day, format: .number)
                        .font(.caption)
                        .monospacedDigit()

                    Image(systemName: "circle.dotted")
                        .font(
                            .system(
                                size: PulseDesign.calendarAccessoryGlyphSize,
                                weight: .semibold
                            )
                        )
                        .accessibilityHidden(true)
                }
                .foregroundStyle(quietPassiveForeground)
            } else {
                Text(item.day.day, format: .number)
                    .font(isToday ? .caption.bold() : .caption)
                    .monospacedDigit()
                    .foregroundStyle(quietPassiveForeground)
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
                    .font(
                        .system(
                            size: PulseDesign.calendarAccessoryGlyphSize,
                            weight: .bold
                        )
                    )
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

    private var archiveCell: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: PulseDesign.archiveCalendarDayCornerRadius,
                style: .continuous
            )
            .fill(archiveCellFill)
            .frame(
                width: PulseDesign.calendarDayVisualSize + PulseDesign.spacing4,
                height: PulseDesign.calendarDayVisualSize + PulseDesign.spacing4
            )

            if item.status == .checked {
                VStack(spacing: 0) {
                    Text(item.day.day, format: .number)
                        .font(.caption2.bold())
                        .monospacedDigit()

                    Image(systemName: "checkmark")
                        .font(
                            .system(
                                size: PulseDesign.calendarAccessoryGlyphSize,
                                weight: .bold
                            )
                        )
                }
                .foregroundStyle(PulseDesign.archiveNight)
            } else if item.status == .missed {
                VStack(spacing: 0) {
                    Text(item.day.day, format: .number)
                        .font(.caption)
                        .monospacedDigit()

                    Image(systemName: "minus")
                        .font(
                            .system(
                                size: PulseDesign.calendarAccessoryGlyphSize,
                                weight: .bold
                            )
                        )
                        .accessibilityHidden(true)
                }
                .foregroundStyle(PulseDesign.secondary)
            } else if item.status == .beforeHabit {
                VStack(spacing: 0) {
                    Text(item.day.day, format: .number)
                        .font(.caption)
                        .monospacedDigit()

                    Image(systemName: "circle.dotted")
                        .font(
                            .system(
                                size: PulseDesign.calendarAccessoryGlyphSize,
                                weight: .semibold
                            )
                        )
                        .accessibilityHidden(true)
                }
                .foregroundStyle(archivePassiveForeground)
            } else {
                Text(item.day.day, format: .number)
                    .font(isToday ? .caption.bold() : .caption)
                    .monospacedDigit()
                    .foregroundStyle(archivePassiveForeground)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: PulseDesign.calendarDayHitSize)
        .overlay {
            if isToday {
                RoundedRectangle(
                    cornerRadius: PulseDesign.archiveCalendarDayCornerRadius,
                    style: .continuous
                )
                .stroke(
                    PulseDesign.archiveCopper,
                    lineWidth: PulseDesign.emphasisLineWidth
                )
                .frame(
                    width: PulseDesign.calendarDayVisualSize + PulseDesign.spacing4,
                    height: PulseDesign.calendarDayVisualSize + PulseDesign.spacing4
                )
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if hasMedia {
                Image(systemName: "camera.fill")
                    .font(
                        .system(
                            size: PulseDesign.calendarAccessoryGlyphSize,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(PulseDesign.archiveCopper)
                    .padding(PulseDesign.spacing4)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("calendar.day.\(item.day.storageValue)")
    }

    private var editorialCell: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: PulseDesign.editorialCalendarDayCornerRadius,
                style: .continuous
            )
            .fill(
                item.status == .checked
                    ? PulseDesign.editorialAccent.opacity(
                        PulseDesign.editorialCalendarCheckedOpacity
                    )
                    : Color.clear
            )
            .frame(
                width: PulseDesign.calendarDayVisualSize,
                height: PulseDesign.calendarDayVisualSize
            )

            if item.status == .checked {
                VStack(spacing: 0) {
                    Text(item.day.day, format: .number)
                        .font(.system(.caption2, design: .serif, weight: .bold))
                        .monospacedDigit()
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                }
                .foregroundStyle(PulseDesign.editorialAccent)
            } else if item.status == .missed {
                VStack(spacing: 0) {
                    Text(item.day.day, format: .number)
                        .font(.system(.caption, design: .serif))
                        .monospacedDigit()
                    Image(systemName: "minus")
                        .font(.caption2.bold())
                        .accessibilityHidden(true)
                }
                .foregroundStyle(PulseDesign.secondary)
            } else if item.status == .beforeHabit {
                VStack(spacing: 0) {
                    Text(item.day.day, format: .number)
                        .font(.system(.caption, design: .serif))
                        .monospacedDigit()
                    Image(systemName: "circle.dotted")
                        .font(
                            .system(
                                size: PulseDesign.calendarAccessoryGlyphSize,
                                weight: .semibold
                            )
                        )
                        .accessibilityHidden(true)
                }
                .foregroundStyle(quietPassiveForeground)
            } else {
                Text(item.day.day, format: .number)
                    .font(
                        .system(
                            .caption,
                            design: .serif,
                            weight: isToday ? .bold : .regular
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(quietPassiveForeground)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: PulseDesign.calendarDayHitSize)
        .overlay {
            if isToday {
                RoundedRectangle(
                    cornerRadius: PulseDesign.editorialCalendarDayCornerRadius,
                    style: .continuous
                )
                .stroke(
                    PulseDesign.editorialAccent,
                    lineWidth: PulseDesign.emphasisLineWidth
                )
                .frame(
                    width: PulseDesign.calendarDayVisualSize,
                    height: PulseDesign.calendarDayVisualSize
                )
            }
        }
        .overlay(alignment: .bottom) {
            if item.status == .checked {
                Rectangle()
                    .fill(PulseDesign.editorialAccent)
                    .frame(
                        width: PulseDesign.calendarDayVisualSize,
                        height: PulseDesign.thinLineWidth
                    )
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if hasMedia {
                Image(systemName: "camera.fill")
                    .font(
                        .system(
                            size: PulseDesign.calendarAccessoryGlyphSize,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(PulseDesign.editorialAccent)
                    .padding(PulseDesign.spacing4)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("calendar.day.\(item.day.storageValue)")
    }

    private var archiveCellFill: Color {
        switch item.status {
        case .checked:
            PulseDesign.archiveCopper
        case .todayPending:
            PulseDesign.archiveMist.opacity(PulseDesign.archiveHistoryTodayFillOpacity)
        case .missed:
            PulseDesign.archiveNight.opacity(PulseDesign.archiveHistoryMissedFillOpacity)
        case .future, .beforeHabit:
            .clear
        }
    }

    private var quietPassiveForeground: Color {
        switch item.status {
        case .beforeHabit:
            PulseDesign.secondary.opacity(PulseDesign.calendarBeforeHabitOpacity)
        case .todayPending, .future:
            PulseDesign.secondary
        case .checked, .missed:
            PulseDesign.ink
        }
    }

    private var archivePassiveForeground: Color {
        switch item.status {
        case .todayPending:
            PulseDesign.ink
        case .future:
            PulseDesign.secondary
        case .beforeHabit:
            PulseDesign.secondary.opacity(PulseDesign.calendarBeforeHabitOpacity)
        case .checked, .missed:
            PulseDesign.ink
        }
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
}

private struct DayArchiveDetailView: View {
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
                ImprintMediaPreview(media: media, load: model.thumbnailData)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("history.media.preview")
            }
        } actions: {
            archiveActionsMenu
        }
        .fileExporter(
            isPresented: $showsPhotoExporter,
            document: photoDocument,
            contentType: .jpeg,
            defaultFilename: "pulse-\(day.storageValue).jpg"
        ) { _ in
            photoDocument = nil
        }
        .sheet(isPresented: $showsJournalEditor) {
            if let record {
                JournalNoteEditorSheet(record: record, model: model)
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
        case .tideArchive:
            archiveDetailIdentity
        case .quietField:
            quietArchiveIdentity
        }
    }

    private var quietArchiveIdentity: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
            Text(
                PulseFormatting.fullDate(
                    day,
                    timeZone: model.timeZone ?? .autoupdatingCurrent,
                    locale: locale
                )
            )
            .font(.title3.bold())
            .foregroundStyle(PulseDesign.ink)
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
                .foregroundStyle(PulseDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("history.record_deleted_media_retained")
                    .foregroundStyle(PulseDesign.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.record.detail.identity")
    }

    private var archiveDetailIdentity: some View {
        HStack(alignment: .top, spacing: PulseDesign.spacing16) {
            Image(systemName: record == nil ? "photo.fill" : "checkmark")
                .font(.headline.weight(.bold))
                .foregroundStyle(PulseDesign.archiveNight)
                .frame(
                    width: PulseDesign.minimumHitTarget,
                    height: PulseDesign.minimumHitTarget
                )
                .background(PulseDesign.archiveCopper, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
                Text(
                    PulseFormatting.fullDate(
                        day,
                        timeZone: model.timeZone ?? .autoupdatingCurrent,
                        locale: locale
                    )
                )
                .font(.title3.bold())
                .foregroundStyle(PulseDesign.ink)
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
                    .foregroundStyle(PulseDesign.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("history.record_deleted_media_retained")
                        .foregroundStyle(PulseDesign.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PulseDesign.spacing20)
        .background {
            RoundedRectangle(
                cornerRadius: PulseDesign.archiveHistoryPanelCornerRadius,
                style: .continuous
            )
            .fill(PulseDesign.archivePaper)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(PulseDesign.archiveCopper)
                .frame(width: PulseDesign.emphasisLineWidth)
                .padding(.vertical, PulseDesign.spacing16)
        }
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
