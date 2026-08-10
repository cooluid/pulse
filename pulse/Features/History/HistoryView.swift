import SwiftUI

struct HistoryView: View {
    @Bindable var model: PulseAppModel
    @State private var selectedRecord: CheckInRecord?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        ZStack {
            PulseBackground()

            ScrollView {
                VStack(spacing: PulseDesign.contentSpacing) {
                    statisticsGrid
                    calendarCard
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, PulseDesign.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("history.navigation_title")
        .sheet(item: $selectedRecord) { record in
            RecordDetailView(record: record, model: model)
                .presentationDetents([.medium])
        }
    }

    private var statisticsGrid: some View {
        HStack(spacing: 12) {
            StatisticTile(
                value: model.statistics.currentStreak,
                labelKey: "history.current_streak",
                symbol: "flame.fill",
                color: PulseDesign.warning,
                accessibilityIdentifier: "history.stat.current"
            )
            StatisticTile(
                value: model.statistics.longestStreak,
                labelKey: "history.longest_streak",
                symbol: "trophy.fill",
                color: PulseDesign.brand,
                accessibilityIdentifier: "history.stat.longest"
            )
            StatisticTile(
                value: model.statistics.totalCount,
                labelKey: "history.total",
                symbol: "checkmark.seal.fill",
                color: PulseDesign.success,
                accessibilityIdentifier: "history.stat.total"
            )
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 18) {
            monthHeader

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(PulseFormatting.weekdayHeaders(weekStart: model.settings.weekStart), id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0..<leadingEmptyDays, id: \.self) { _ in
                    Color.clear
                        .frame(height: 44)
                        .accessibilityHidden(true)
                }

                ForEach(model.calendarItemsForSelectedMonth()) { item in
                    CalendarDayCell(item: item, isToday: item.day == model.today)
                        .onTapGesture {
                            guard item.status == .checked else { return }
                            selectedRecord = model.record(for: item.day)
                        }
                }
            }

            calendarLegend
        }
        .pulseCard()
    }

    private var monthHeader: some View {
        HStack {
            Button {
                model.moveSelectedMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("history.previous_month")

            Spacer()

            if let month = model.selectedMonth ?? model.today?.firstDayOfMonth(),
               let timeZone = model.timeZone {
                Text(PulseFormatting.monthAndYear(month, timeZone: timeZone))
                    .font(.headline)
            }

            Spacer()

            Button {
                model.moveSelectedMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .disabled((model.selectedMonth ?? model.today?.firstDayOfMonth()) == model.today?.firstDayOfMonth())
            .accessibilityLabel("history.next_month")
        }
    }

    private var leadingEmptyDays: Int {
        guard let month = model.selectedMonth ?? model.today?.firstDayOfMonth(),
              let timeZone = model.timeZone else { return 0 }
        let calendar = Calendar.pulseGregorian(timeZone: timeZone)
        let weekday = calendar.component(.weekday, from: month.date(timeZone: timeZone))
        return (weekday - model.settings.weekStart.rawValue + 7) % 7
    }

    private var calendarLegend: some View {
        HStack(spacing: 18) {
            Label("calendar.status.checked", systemImage: "checkmark.circle.fill")
                .foregroundStyle(PulseDesign.success)
            Label("calendar.status.missed", systemImage: "circle")
                .foregroundStyle(.secondary)
            Label("calendar.status.today", systemImage: "circle.dotted")
                .foregroundStyle(PulseDesign.brand)
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

private struct StatisticTile: View {
    let value: Int
    let labelKey: LocalizedStringKey
    let symbol: String
    let color: Color
    let accessibilityIdentifier: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(color)
            Text(value, format: .number)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(labelKey)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .pulseCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct CalendarDayCell: View {
    let item: CalendarDayItem
    let isToday: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)

            if item.status == .checked {
                VStack(spacing: 2) {
                    Text(item.day.day, format: .number)
                        .font(.subheadline.bold())
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                }
                .foregroundStyle(.white)
            } else {
                Text(item.day.day, format: .number)
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                    .foregroundStyle(foregroundColor)
            }
        }
        .frame(height: 44)
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(PulseDesign.brand, lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("calendar.day.\(item.day.storageValue)")
        .accessibilityAddTraits(item.status == .checked ? .isButton : [])
    }

    private var backgroundColor: Color {
        switch item.status {
        case .checked: PulseDesign.success
        case .missed: Color.secondary.opacity(0.08)
        case .todayPending: PulseDesign.brand.opacity(0.08)
        case .beforeHabit, .future: Color.clear
        }
    }

    private var foregroundColor: Color {
        switch item.status {
        case .beforeHabit, .future: .secondary.opacity(0.45)
        case .missed: .secondary
        case .todayPending: PulseDesign.brand
        case .checked: .white
        }
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
            VStack(spacing: 24) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(PulseDesign.success)

                VStack(spacing: 8) {
                    if let day = record.logicalDay, let timeZone = model.timeZone {
                        Text(PulseFormatting.fullDate(day, timeZone: timeZone))
                            .font(.title3.bold())
                    }
                    if let timeZone = model.timeZone {
                        Text(
                            String(
                                format: String(localized: "history.checked_at"),
                                PulseFormatting.time(record.checkedAt, timeZone: timeZone)
                            )
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                Button("history.delete_record", role: .destructive) {
                    showsDeleteConfirmation = true
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
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
    }
}
