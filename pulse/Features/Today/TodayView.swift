import SwiftUI

struct TodayView: View {
    @Bindable var model: PulseAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                .foregroundStyle(PulseDesign.ink)
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
                    .foregroundStyle(PulseDesign.secondary)
            }

            Text(model.todayRecord == nil ? "today.prompt" : "today.completed_prompt")
                .font(.system(.title2, design: .serif, weight: .semibold))
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
                        .fill(isChecked ? PulseDesign.success : PulseDesign.brand)

                    Circle()
                        .stroke(PulseDesign.actionForeground.opacity(0.42), lineWidth: 1)
                        .padding(12)

                    if model.isSaving {
                        ProgressView()
                            .controlSize(.large)
                            .tint(PulseDesign.actionForeground)
                    } else {
                        VStack(spacing: 12) {
                            if isChecked {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 34, weight: .medium))
                            }
                            Text(isChecked ? "today.checked" : "today.check_in")
                                .font(.system(.headline, design: .serif, weight: .semibold))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(PulseDesign.actionForeground)
                        .padding(20)
                    }
                }
                .frame(width: checkInDiameter, height: checkInDiameter)
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
                .foregroundStyle(PulseDesign.secondary)
                .accessibilityIdentifier("today.checked.time")
            } else {
                Text("today.offline_note")
                    .font(.subheadline)
                    .foregroundStyle(PulseDesign.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var checkInDiameter: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 236 : 196
    }

    private var streakCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(model.statistics.currentStreak, format: .number)
                    .font(.system(.largeTitle, design: .serif, weight: .regular))
                    .foregroundStyle(PulseDesign.brand)

                VStack(alignment: .leading, spacing: 2) {
                    Text("unit.days")
                        .font(.subheadline.weight(.medium))
                    Text("today.current_streak")
                        .font(.caption)
                        .foregroundStyle(PulseDesign.secondary)
                }

                Spacer(minLength: 12)
            }

            Text("today.streak_encouragement")
                .font(.subheadline)
                .foregroundStyle(PulseDesign.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 20)
        .overlay(alignment: .top) { Divider().overlay(PulseDesign.separator) }
        .overlay(alignment: .bottom) { Divider().overlay(PulseDesign.separator) }
        .accessibilityElement(children: .combine)
    }

    private var recentDaysCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("today.recent_days")
                .font(.system(.headline, design: .serif, weight: .semibold))

            HStack(spacing: 8) {
                ForEach(model.recentDays) { item in
                    recentDay(item)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .pulseSurface()
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
                    .fill(isChecked ? PulseDesign.success : PulseDesign.background)
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(PulseDesign.actionForeground)
                } else {
                    Text(item.day.day, format: .number)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseDesign.secondary)
                }
            }
            .frame(width: 34, height: 34)
            .overlay {
                Circle()
                    .stroke(isToday ? PulseDesign.brand : PulseDesign.separator, lineWidth: isToday ? 2 : 1)
                    .padding(isToday ? -3 : 0)
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
