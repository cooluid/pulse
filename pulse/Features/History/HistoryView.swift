import SwiftUI

struct HistoryView: View {
    @Bindable var model: PulseAppModel
    let primaryNavigationClearance: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @State private var selectedRecord: CheckInRecordSnapshot?
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
                            .padding(.bottom, accessibilityScrollClearance)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedRecord) { record in
            RecordDetailView(record: record, model: model)
                .presentationDetents([.medium])
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

    private var accessibilityScrollClearance: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? primaryNavigationClearance : 0
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
                .textCase(.uppercase)
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
                if item.status == .checked {
                    Button {
                        selectedRecord = model.record(for: item.day)
                    } label: {
                        CalendarDayCell(item: item, isToday: item.day == model.today)
                    }
                    .buttonStyle(.plain)
                } else {
                    CalendarDayCell(item: item, isToday: item.day == model.today)
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
        return String(
            format: PulseLocalization.string("accessibility.date_status_format", locale: locale),
            item.day.storageValue,
            state
        )
    }

    private var isDeemphasized: Bool {
        item.status == .future || item.status == .beforeHabit
    }
}

private struct RecordDetailView: View {
    let record: CheckInRecordSnapshot
    @Bindable var model: PulseAppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var showsDeleteConfirmation = false

    var body: some View {
        ZStack {
            PulseScreenBackground()

            VStack(spacing: PulseDesign.spacing24) {
                PulseBrandMark(size: PulseDesign.recordDetailBrandMarkSize)

                VStack(spacing: PulseDesign.spacing8) {
                    if let day = record.logicalDay, let timeZone = record.timeZone {
                        Text(PulseFormatting.fullDate(day, timeZone: timeZone, locale: locale))
                            .font(.title3.bold())
                            .foregroundStyle(PulseDesign.ink)
                    }
                    if let timeZone = record.timeZone {
                        Text(
                            String(
                                format: PulseLocalization.string(
                                    "history.checked_at",
                                    locale: locale
                                ),
                                PulseFormatting.time(
                                    record.checkedAt,
                                    timeZone: timeZone,
                                    locale: locale
                                )
                            )
                        )
                        .foregroundStyle(PulseDesign.secondary)
                    }
                }

                deleteButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(PulseDesign.spacing24)
        }
        .tint(PulseDesign.tint)
    }

    private var deleteButton: some View {
        Button("history.delete_record", role: .destructive) {
            showsDeleteConfirmation = true
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("history.record.delete.button")
        .confirmationDialog(
            "history.delete_confirmation.title",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("history.delete_confirmation.action", role: .destructive) {
                Task {
                    if await model.delete(recordID: record.id) {
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
}
