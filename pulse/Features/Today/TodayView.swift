import SwiftUI

struct TodayView: View {
    @Bindable var model: PulseAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            PulseBackground()

            ScrollView {
                VStack(spacing: PulseDesign.contentSpacing) {
                    header
                    checkInHero
                    streakCard
                    recentDaysCard
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, PulseDesign.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("today.navigation_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView(model: model)
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("settings.navigation_title")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            if let today = model.today, let timeZone = model.timeZone {
                Text(PulseFormatting.fullDate(today, timeZone: timeZone))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(model.todayRecord == nil ? "today.prompt" : "today.completed_prompt")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var checkInHero: some View {
        let isChecked = model.todayRecord != nil

        return VStack(spacing: 16) {
            Button {
                Task { await model.checkIn() }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isChecked
                                    ? [PulseDesign.success, PulseDesign.success.opacity(0.78)]
                                    : [PulseDesign.brand, PulseDesign.brandDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: (isChecked ? PulseDesign.success : PulseDesign.brand).opacity(0.28),
                            radius: 24,
                            y: 14
                        )

                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                        .padding(10)

                    if model.isSaving {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: isChecked ? "checkmark" : "hand.tap.fill")
                                .font(.system(size: 42, weight: .semibold))
                                .symbolRenderingMode(.monochrome)
                            Text(isChecked ? "today.checked" : "today.check_in")
                                .font(.title3.bold())
                        }
                        .foregroundStyle(.white)
                    }
                }
                .frame(width: 218, height: 218)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isChecked || model.isSaving)
            .accessibilityIdentifier("today.checkin.button")
            .scaleEffect(model.isSaving && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.isSaving)
            .accessibilityLabel(isChecked ? "today.accessibility.checked" : "today.accessibility.check_in")
            .accessibilityHint(isChecked ? "" : String(localized: "today.accessibility.hint"))

            if let record = model.todayRecord, let timeZone = model.timeZone {
                Text(
                    String(
                        format: String(localized: "today.checked_at"),
                        PulseFormatting.time(record.checkedAt, timeZone: timeZone)
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("today.checked.time")
            } else {
                Text("today.offline_note")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var streakCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(PulseDesign.warning.opacity(0.14))
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(PulseDesign.warning)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("today.current_streak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(model.statistics.currentStreak, format: .number)
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("unit.days")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("today.streak_encouragement")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .pulseCard()
        .accessibilityElement(children: .combine)
    }

    private var recentDaysCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("today.recent_days")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(model.recentDays) { item in
                    recentDay(item)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .pulseCard()
    }

    private func recentDay(_ item: CalendarDayItem) -> some View {
        let isChecked = item.status == .checked
        let isToday = item.day == model.today

        return VStack(spacing: 8) {
            if let timeZone = model.timeZone {
                Text(PulseFormatting.weekday(item.day, timeZone: timeZone))
                    .font(.caption2.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .primary : .secondary)
            }

            ZStack {
                Circle()
                    .fill(isChecked ? PulseDesign.success : Color.secondary.opacity(0.1))
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Text(item.day.day, format: .number)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 34, height: 34)
            .overlay {
                if isToday {
                    Circle().stroke(PulseDesign.brand, lineWidth: 2)
                        .padding(-3)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(recentDayAccessibilityLabel(item))
    }

    private func recentDayAccessibilityLabel(_ item: CalendarDayItem) -> String {
        guard let timeZone = model.timeZone else { return "" }
        let date = PulseFormatting.fullDate(item.day, timeZone: timeZone)
        let state = item.status == .checked
            ? String(localized: "calendar.status.checked")
            : String(localized: "calendar.status.not_checked")
        return "\(date)，\(state)"
    }
}
