import PulseCore
import SwiftUI

/// Immersion arranges Today as one continuous surface.
///
/// Where the shared arrangement stacks modules, this one builds a single field. The day's number
/// is the page's one loud event and sinks into it, the week is one stream instead of a row of
/// tiles, and the check-in control is a full-width surface rather than a labelled button.
struct PulseImmersionTodayPage<CheckIn: View, Journal: View, Media: View>: View {
    let facts: PulseTodayFacts
    let checkIn: CheckIn
    let journal: Journal
    let media: Media

    @Environment(\.locale) private var locale
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.pulseVisualTheme) private var theme

    private var accent: Color { PulseDesign.appAccent(for: theme) }
    private var showsHeroNumber: Bool { !dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            dateLine

            if showsHeroNumber {
                heroNumber
            }

            identity
                .padding(.top, showsHeroNumber ? 16 : 10)

            checkIn
                .frame(maxWidth: .infinity)
                .padding(.top, PulseDesign.spacing24)

            weekStream
                .padding(.top, PulseDesign.spacing24)

            VStack(alignment: .leading, spacing: PulseDesign.spacing20) {
                journal
                media
            }
            .padding(.top, PulseDesign.spacing24)
        }
        .frame(maxWidth: horizontalSizeClass == .regular ? 620 : .infinity, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.top, PulseDesign.spacing4)
        .padding(.bottom, PulseDesign.spacing12)
    }

    // MARK: - The day is the loudest thing on the page

    private var heroNumber: some View {
        Text(facts.today.map { String($0.day) } ?? "")
            .font(.system(size: 176, weight: .black))
            .kerning(-9)
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(accent.opacity(0.46))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .mask(sinkGradient)
            .accessibilityHidden(true)
    }

    /// Only the foot of the number dissolves, so the day reads as pressing into the surface.
    private var sinkGradient: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: 0.66),
                .init(color: .black.opacity(0.34), location: 0.86),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var dateLine: some View {
        if let today = facts.today, let timeZone = facts.timeZone {
            Text(PulseFormatting.fullDate(today, timeZone: timeZone, locale: locale))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PulseDesign.appMuted(for: theme))
                .accessibilityIdentifier("today.hero.kicker")
        }
    }

    // MARK: - Commitment and rhythm

    private var identity: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
            if let habitName = facts.habitName {
                Text(habitName)
                    .font(.system(size: 32, weight: .bold))
                    .kerning(-0.6)
                    .foregroundStyle(PulseDesign.appInk(for: theme))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("today.commitment.name")
            }

            Text(
                PulseTodayPresentation.rhythmStatusText(
                    currentStreak: facts.currentStreak,
                    locale: locale
                )
            )
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(accent)
            .accessibilityIdentifier("today.rhythm.status")
        }
    }

    // MARK: - The week as one stream

    private var weekStream: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
            Canvas { context, size in
                let items = facts.recentDays
                guard !items.isEmpty else { return }

                let gap: CGFloat = 4
                let count = CGFloat(items.count)
                let segmentWidth = max(0, (size.width - gap * (count - 1)) / count)

                for (index, item) in items.enumerated() {
                    let height = min(streamHeight(for: item), size.height)
                    let rect = CGRect(
                        x: CGFloat(index) * (segmentWidth + gap),
                        y: (size.height - height) / 2,
                        width: segmentWidth,
                        height: height
                    )
                    context.fill(
                        Path(
                            roundedRect: rect,
                            cornerRadius: min(segmentWidth, height) / 2
                        ),
                        with: .color(streamColor(for: item))
                    )
                }
            }
            .frame(height: 38)
            .accessibilityHidden(true)

            HStack(spacing: 4) {
                ForEach(facts.recentDays) { item in
                    streamLabel(item)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("today.week.rail")
        }
    }

    @ViewBuilder
    private func streamLabel(_ item: CalendarDayItem) -> some View {
        let isToday = item.day == facts.today && item.status == .todayPending
        VStack(spacing: 2) {
            if let timeZone = facts.timeZone {
                Text(PulseFormatting.shortWeekday(item.day, timeZone: timeZone, locale: locale))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PulseDesign.appMuted(for: theme))
            }
            Text(item.day.day, format: .number)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(
                    item.status == .checked
                        ? accent
                        : (isToday ? PulseDesign.appInk(for: theme) : PulseDesign.appMuted(for: theme))
                )
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            facts.timeZone.map {
                PulseTodayPresentation.weekDayAccessibilityLabel(item, timeZone: $0, locale: locale)
            } ?? ""
        )
        .accessibilityIdentifier("today.week.day.\(item.day.storageValue)")
    }

    /// A day that was kept rises, a day that was missed stays nearly flat. The band is the rhythm.
    private func streamHeight(for item: CalendarDayItem) -> CGFloat {
        switch item.status {
        case .checked: 24
        case .todayPending: 38
        case .missed: 14
        case .beforeHabit, .future: 9
        }
    }

    private func streamColor(for item: CalendarDayItem) -> Color {
        switch item.status {
        case .checked: accent
        case .todayPending: accent.opacity(0.55)
        case .missed: PulseDesign.appDivider(for: theme)
        case .beforeHabit, .future: PulseDesign.appInk(for: theme).opacity(0.18)
        }
    }
}
