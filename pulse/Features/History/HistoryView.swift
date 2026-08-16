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
    @Environment(\.pulseVisualTheme) private var visualTheme
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
            .accessibilityIdentifier(
                visualTheme == .tidalBreath
                    ? "history.theme.tidal-breath"
                    : "history.theme.quiet-field"
            )
    }

    @ViewBuilder
    private var historyContent: some View {
        if visualTheme == .tidalBreath {
            tidalHistoryContent
        } else {
            quietHistoryContent
        }
    }

    @ViewBuilder
    private var quietHistoryContent: some View {
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

    @ViewBuilder
    private var tidalHistoryContent: some View {
        if usesRegularWidthLayout {
            HStack(alignment: .top, spacing: PulseDesign.regularWidthColumnGap) {
                VStack(spacing: PulseDesign.spacing20) {
                    tidalMonthHero
                    tidalStatisticsBand
                }
                .frame(maxWidth: .infinity)

                tidalCalendarPanel
                    .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: PulseDesign.spacing20) {
                tidalMonthHero
                tidalStatisticsBand
                tidalCalendarPanel
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

    private var tidalMonthHero: some View {
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
                    .foregroundStyle(PulseDesign.tidalBlueDeep.opacity(0.72))
                    .accessibilityHidden(true)
                }

                Spacer(minLength: PulseDesign.spacing12)

                tidalMonthNavigationControls
            }

            if let month = selectedMonth, let timeZone = model.timeZone {
                HStack(alignment: .lastTextBaseline, spacing: PulseDesign.spacing16) {
                    Text(String(format: "%02d", month.month))
                        .font(.system(size: PulseDesign.tidalHistoryMonthSize, weight: .medium))
                        .monospacedDigit()
                        .tracking(-4)
                        .foregroundStyle(PulseDesign.ink)

                    VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                        Text(PulseFormatting.monthOnly(month, timeZone: timeZone, locale: locale))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(PulseDesign.ink)

                        Rectangle()
                            .fill(PulseDesign.tidalBlueMid)
                            .frame(width: 52, height: PulseDesign.emphasisLineWidth)
                            .accessibilityHidden(true)
                    }
                    .padding(.bottom, PulseDesign.spacing12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, PulseDesign.spacing12)
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

    private var tidalMonthNavigationControls: some View {
        HStack(spacing: PulseDesign.spacing8) {
            tidalMonthNavigationButton(
                systemName: "chevron.left",
                accessibilityLabel: "history.previous_month",
                accessibilityIdentifier: "history.month.previous"
            ) {
                moveMonth(by: -1)
            }

            tidalMonthNavigationButton(
                systemName: "chevron.right",
                accessibilityLabel: "history.next_month",
                accessibilityIdentifier: "history.month.next",
                isDisabled: isShowingCurrentMonth
            ) {
                moveMonth(by: 1)
            }
        }
    }

    private func tidalMonthNavigationButton(
        systemName: String,
        accessibilityLabel: LocalizedStringKey,
        accessibilityIdentifier: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulseDesign.tidalBlueDeep)
                .frame(
                    width: PulseDesign.minimumHitTarget,
                    height: PulseDesign.minimumHitTarget
                )
                .background(PulseDesign.tidalForeground, in: Circle())
                .overlay {
                    Circle()
                        .stroke(
                            PulseDesign.tidalBlueMid.opacity(0.42),
                            lineWidth: PulseDesign.thinLineWidth
                        )
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.38 : 1)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var tidalStatisticsBand: some View {
        HStack(spacing: 0) {
            TidalStatisticTile(
                value: model.statistics.currentStreak,
                labelKey: "history.current_streak",
                accessibilityIdentifier: "history.stat.current"
            )

            tidalStatisticDivider

            TidalStatisticTile(
                value: model.statistics.longestStreak,
                labelKey: "history.longest_streak",
                accessibilityIdentifier: "history.stat.longest"
            )

            tidalStatisticDivider

            TidalStatisticTile(
                value: model.statistics.totalCount,
                labelKey: "history.total",
                accessibilityIdentifier: "history.stat.total"
            )
        }
        .padding(.vertical, PulseDesign.spacing20)
        .background {
            ZStack {
                LinearGradient(
                    colors: [PulseDesign.tidalBlueMid, PulseDesign.tidalBlueDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                HistoryTidalContourShape(verticalBias: 0.66)
                    .stroke(
                        PulseDesign.tidalForeground.opacity(0.16),
                        lineWidth: PulseDesign.thinLineWidth
                    )
            }
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: PulseDesign.tidalHistoryPanelCornerRadius,
                style: .continuous
            )
        )
    }

    private var tidalStatisticDivider: some View {
        Rectangle()
            .fill(PulseDesign.tidalForeground.opacity(0.20))
            .frame(width: PulseDesign.thinLineWidth, height: 42)
            .accessibilityHidden(true)
    }

    private var tidalCalendarPanel: some View {
        ZStack {
            LinearGradient(
                colors: [PulseDesign.tidalBlueDeep, PulseDesign.tidalBlueDepth],
                startPoint: .top,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                HistoryTidalContourShape(verticalBias: 0.12)
                    .stroke(
                        PulseDesign.tidalBluePale.opacity(0.24),
                        lineWidth: PulseDesign.thinLineWidth
                    )
                    .frame(height: 42)
                    .accessibilityHidden(true)

                Spacer(minLength: 0)
            }

            animatedCalendar
                .padding(.horizontal, PulseDesign.spacing12)
                .padding(.bottom, PulseDesign.spacing20)
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: PulseDesign.tidalHistoryPanelCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PulseDesign.tidalHistoryPanelCornerRadius,
                style: .continuous
            )
            .stroke(
                PulseDesign.tidalForeground.opacity(0.18),
                lineWidth: PulseDesign.thinLineWidth
            )
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
                    .foregroundStyle(
                        visualTheme == .tidalBreath
                            ? PulseDesign.tidalForeground.opacity(0.68)
                            : PulseDesign.secondary
                    )
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
        .padding(.top, visualTheme == .tidalBreath ? PulseDesign.spacing16 : PulseDesign.spacing20)
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

private struct TidalStatisticTile: View {
    let value: Int
    let labelKey: LocalizedStringKey
    let accessibilityIdentifier: String

    var body: some View {
        VStack(spacing: PulseDesign.spacing4) {
            Text(value, format: .number)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(PulseDesign.tidalForeground)

            Text(labelKey)
                .font(.caption2.weight(.medium))
                .foregroundStyle(PulseDesign.tidalForeground.opacity(0.70))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct HistoryTidalContourShape: Shape {
    let verticalBias: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 32
        for step in 0...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(
                x: rect.width * progress,
                y: rect.height * (
                    verticalBias + sin(progress * 2.4 * .pi) * 0.16
                )
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
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
        if visualTheme == .tidalBreath {
            tidalCell
        } else {
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

    private var tidalCell: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: PulseDesign.tidalCalendarDayCornerRadius,
                style: .continuous
            )
            .fill(tidalCellFill)
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
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(PulseDesign.tidalBlueDeep)
            } else if item.status == .missed {
                VStack(spacing: 0) {
                    Text(item.day.day, format: .number)
                        .font(.caption)
                        .monospacedDigit()

                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .bold))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(PulseDesign.tidalForeground.opacity(0.72))
            } else {
                Text(item.day.day, format: .number)
                    .font(isToday ? .caption.bold() : .caption)
                    .monospacedDigit()
                    .foregroundStyle(PulseDesign.tidalForeground.opacity(tidalDayOpacity))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: PulseDesign.calendarDayHitSize)
        .overlay {
            if isToday {
                RoundedRectangle(
                    cornerRadius: PulseDesign.tidalCalendarDayCornerRadius,
                    style: .continuous
                )
                .stroke(
                    PulseDesign.tidalForeground,
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
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(PulseDesign.tidalBluePale)
                    .padding(PulseDesign.spacing4)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("calendar.day.\(item.day.storageValue)")
    }

    private var tidalCellFill: Color {
        switch item.status {
        case .checked:
            PulseDesign.tidalForeground
        case .todayPending:
            PulseDesign.tidalForeground.opacity(0.14)
        case .missed:
            PulseDesign.tidalForeground.opacity(0.08)
        case .future, .beforeHabit:
            .clear
        }
    }

    private var tidalDayOpacity: Double {
        isDeemphasized ? 0.34 : 0.78
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
    @Environment(\.pulseVisualTheme) private var visualTheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var pendingDestructiveAction: DestructiveAction?
    @State private var photoDocument: ImprintPhotoDocument?
    @State private var showsPhotoExporter = false
    @State private var isPreparingPhotoExport = false

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
    }

    private var archivePresentationDetents: Set<PresentationDetent> {
        if media != nil || dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact {
            return [.large]
        }
        return [.fraction(PulseDesign.compactDetailDetentFraction), .large]
    }

    @ViewBuilder
    private var archiveIdentity: some View {
        if visualTheme == .tidalBreath {
            tidalArchiveIdentity
        } else {
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

    private var tidalArchiveIdentity: some View {
        HStack(alignment: .top, spacing: PulseDesign.spacing16) {
            Image(systemName: record == nil ? "photo.fill" : "checkmark")
                .font(.headline.weight(.bold))
                .foregroundStyle(PulseDesign.tidalBlueDeep)
                .frame(
                    width: PulseDesign.minimumHitTarget,
                    height: PulseDesign.minimumHitTarget
                )
                .background(PulseDesign.tidalForeground, in: Circle())
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
                .foregroundStyle(PulseDesign.tidalForeground)
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
                    .foregroundStyle(PulseDesign.tidalForeground.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("history.record_deleted_media_retained")
                        .foregroundStyle(PulseDesign.tidalForeground.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PulseDesign.spacing20)
        .background(
            LinearGradient(
                colors: [PulseDesign.tidalBlueMid, PulseDesign.tidalBlueDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(
                cornerRadius: PulseDesign.tidalHistoryPanelCornerRadius,
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
            "history.delete_confirmation.message"
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
