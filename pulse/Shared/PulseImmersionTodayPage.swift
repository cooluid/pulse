import PulseCore
import SwiftUI

/// Immersion arranges Today as one continuous surface.
///
/// The date and the day's number hold still behind this content (see `PulseThemeBackdrop`), so
/// scrolling moves the day's work across the page instead of dragging the number off a hard cut.
/// Everything below stays inside the page's language: no cards, no rules, no boxed sections.
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
            // Room for the date and day number the backdrop draws. The date itself stays readable
            // to VoiceOver there; this only reserves the space.
            Color.clear
                .frame(height: heroReservedHeight)
                .accessibilityHidden(true)

            identity

            checkIn
                .frame(maxWidth: .infinity)
                .padding(.top, PulseDesign.spacing24)

            weekStream
                .padding(.top, PulseDesign.spacing24)

            VStack(alignment: .leading, spacing: PulseDesign.spacing20) {
                journal
                    .padding(.leading, PulseDesign.spacing12)
                    .overlay(alignment: .topLeading) {
                        // One short mark keeps the note in the page's language without boxing it.
                        Capsule()
                            .fill(accent)
                            .frame(width: 3, height: 18)
                            .padding(.top, PulseDesign.spacing12)
                    }
                media
            }
            .padding(.top, PulseDesign.spacing24)
        }
        .frame(maxWidth: horizontalSizeClass == .regular ? 620 : .infinity, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.top, PulseDesign.spacing4)
        .padding(.bottom, PulseDesign.spacing12)
    }

    /// The backdrop's date line plus the day number, measured from the top of this content.
    private var heroReservedHeight: CGFloat {
        showsHeroNumber ? 243 : 26
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
