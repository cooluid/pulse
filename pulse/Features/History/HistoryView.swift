import SwiftUI

struct HistoryView: View {
    @Bindable var model: PulseAppModel
    let isActive: Bool

    @State private var selectedRecord: CheckInRecord?

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: PulseDesign.spacing4),
        count: 7
    )

    var body: some View {
        ZStack {
            PulseScreenBackground()
            PulseFieldBackground(isActive: isActive)

            VStack(spacing: 0) {
                PulseAppHeader {
                    SettingsView(model: model)
                }

                ScrollView {
                    VStack(spacing: 0) {
                        historyHeading
                        statisticsRow
                        calendar
                    }
                    .frame(maxWidth: PulseDesign.historyMaxWidth)
                    .padding(.horizontal, PulseDesign.horizontalPadding)
                    .padding(.top, 2)
                    .padding(.bottom, PulseDesign.spacing24)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedRecord) { record in
            RecordDetailView(record: record, model: model)
                .presentationDetents([.medium])
        }
    }

    private var historyHeading: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
            if let month = selectedMonth, let timeZone = model.timeZone {
                Text(
                    String(
                        format: String(localized: "history.archive_format"),
                        PulseFormatting.year(month, timeZone: timeZone)
                    )
                )
                .font(.system(size: 11, weight: .bold))
                .tracking(1.43)
                .textCase(.uppercase)
                .foregroundStyle(PulseDesign.secondary)

                Text(
                    String(
                        format: String(localized: "history.month_records_format"),
                        PulseFormatting.monthOnly(month, timeZone: timeZone)
                    )
                )
                .font(.system(size: 40, weight: .bold))
                .tracking(-2.4)
                .foregroundStyle(PulseDesign.ink)
            }
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
        .gesture(monthSwipeGesture)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text("history.previous_month")) {
            model.moveSelectedMonth(by: -1)
        }
        .accessibilityAction(named: Text("history.next_month")) {
            moveToNextMonthIfAvailable()
        }
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
    }

    private var calendar: some View {
        LazyVGrid(columns: columns, spacing: PulseDesign.spacing8) {
            ForEach(
                Array(PulseFormatting.weekdayHeaders(weekStart: model.settings.weekStart).enumerated()),
                id: \.offset
            ) { index, weekday in
                Text(weekday)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PulseDesign.secondary)
                    .frame(maxWidth: .infinity, minHeight: 24)
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
                    model.moveSelectedMonth(by: -1)
                } else if value.translation.width < -PulseDesign.minimumHitTarget {
                    moveToNextMonthIfAvailable()
                }
            }
    }

    private func moveToNextMonthIfAvailable() {
        guard selectedMonth != model.today?.firstDayOfMonth() else { return }
        model.moveSelectedMonth(by: 1)
    }
}

private struct StatisticTile: View {
    let value: Int
    let labelKey: LocalizedStringKey
    let accessibilityIdentifier: String

    var body: some View {
        VStack(spacing: PulseDesign.spacing4) {
            Text(value, format: .number)
                .font(.system(size: 28, weight: .bold))
                .tracking(-1.12)
                .monospacedDigit()
                .foregroundStyle(PulseDesign.ink)

            Text(labelKey)
                .font(.system(size: 10))
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

    var body: some View {
        ZStack {
            Circle()
                .fill(item.status == .checked ? PulseDesign.grass : Color.clear)
                .frame(
                    width: PulseDesign.calendarDayVisualSize,
                    height: PulseDesign.calendarDayVisualSize
                )

            Text(item.day.day, format: .number)
                .font(.system(size: 11, weight: item.status == .checked || isToday ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(item.status == .checked ? PulseDesign.grassForeground : PulseDesign.secondary)
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
        case .checked: state = String(localized: "calendar.status.checked")
        case .missed: state = String(localized: "calendar.status.missed")
        case .todayPending: state = String(localized: "calendar.status.pending")
        case .future: state = String(localized: "calendar.status.future")
        case .beforeHabit: state = String(localized: "calendar.status.before_habit")
        }
        return "\(item.day.storageValue)，\(state)"
    }
}

private struct RecordDetailView: View {
    let record: CheckInRecord
    @Bindable var model: PulseAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                PulseScreenBackground()

                VStack(spacing: PulseDesign.spacing24) {
                    PulseBrandMark(size: 64)

                    VStack(spacing: PulseDesign.spacing8) {
                        if let day = record.logicalDay, let timeZone = model.timeZone {
                            Text(PulseFormatting.fullDate(day, timeZone: timeZone))
                                .font(.title3.bold())
                                .foregroundStyle(PulseDesign.ink)
                        }
                        if let timeZone = model.timeZone {
                            Text(
                                String(
                                    format: String(localized: "history.checked_at"),
                                    PulseFormatting.time(record.checkedAt, timeZone: timeZone)
                                )
                            )
                            .foregroundStyle(PulseDesign.secondary)
                        }
                    }

                    Button("history.delete_record", role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(PulseDesign.spacing24)
            }
            .navigationTitle("history.record_detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }
                }
            }
            .confirmationDialog(
                "history.delete_confirmation.title",
                isPresented: $showsDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("history.delete_confirmation.action", role: .destructive) {
                    Task {
                        await model.delete(recordID: record.id)
                        dismiss()
                    }
                }
                Button("action.cancel", role: .cancel) {}
            } message: {
                Text("history.delete_confirmation.message")
            }
        }
        .tint(PulseDesign.tint)
    }
}
