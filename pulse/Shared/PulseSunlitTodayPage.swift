import PulseCore
import SwiftUI

/// Sunlit Day arranges Today as a cyanotype print.
///
/// The whole page is one sheet of sensitized paper: Prussian blue and white line only.
/// The day's number waits as an unexposed outline; keeping the day develops it solid.
/// Photos belong here naturally — a cyanotype is a sun print, so today's photo is the print.
struct PulseSunlitTodayPage<CheckIn: View, Journal: View, Media: View>: View {
    let facts: PulseTodayFacts
    let checkIn: CheckIn
    let journal: Journal
    let media: Media

    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var accent: Color { PulseDesign.appAccent(for: theme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            identity

            exposureNumber
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, PulseDesign.spacing8)

            checkIn
                .frame(maxWidth: .infinity)
                .padding(.top, PulseDesign.spacing20)

            printRail
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

    // MARK: - Commitment and rhythm

    private var identity: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
            HStack(alignment: .firstTextBaseline) {
                if let today = facts.today, let timeZone = facts.timeZone {
                    Text(PulseFormatting.fullDate(today, timeZone: timeZone, locale: locale))
                        .font(PulseDesign.editorialDisplayFont(size: 15, relativeTo: .subheadline))
                        .foregroundStyle(PulseDesign.appMuted(for: theme))
                        .accessibilityIdentifier("today.hero.kicker")
                }
                Spacer(minLength: PulseDesign.spacing12)
                sunMark
            }
            if let habitName = facts.habitName {
                Text(habitName)
                    .font(PulseDesign.editorialDisplayFont(size: 30, relativeTo: .largeTitle).weight(.bold))
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
            .font(.subheadline.weight(.medium))
            .foregroundStyle(PulseDesign.sunlitWeekday)
            .accessibilityIdentifier("today.rhythm.status")
        }
    }

    /// The sun is the printer; one small mark is enough to say so.
    private var sunMark: some View {
        ZStack {
            Circle()
                .stroke(PulseDesign.sunlitWeekday, lineWidth: 1.5)
                .frame(width: 18, height: 18)
            Circle()
                .fill(PulseDesign.sunlitWeekday)
                .frame(width: 6, height: 6)
        }
        .accessibilityHidden(true)
    }

    // MARK: - The day's number as an exposure

    /// Decorative only: the date line above carries the same fact to VoiceOver.
    private var exposureNumber: some View {
        Group {
            if let today = facts.today, !dynamicTypeSize.isAccessibilitySize {
                // Unexposed, the number is a faint ghost on the paper; keeping the day
                // develops it to full density. One fact, two densities, no extra chrome.
                Text(String(today.day))
                    .font(.system(size: PulseDesign.sunlitExposureNumberSize, weight: .semibold, design: .serif))
                    .kerning(PulseDesign.sunlitExposureNumberTracking)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(facts.isChecked ? accent : accent.opacity(0.30))
                    .animation(.easeOut(duration: 0.4), value: facts.isChecked)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - The week as developing prints

    private var printRail: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: PulseDesign.spacing16) {
                    ForEach(facts.recentDays) { item in
                        printLabel(item).frame(maxWidth: .infinity)
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(facts.recentDays) { item in
                        printLabel(item).frame(maxWidth: .infinity)
                    }
                }
                .frame(minHeight: PulseDesign.minimumHitTarget)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.week.rail")
    }

    @ViewBuilder
    private func printLabel(_ item: CalendarDayItem) -> some View {
        let isToday = item.day == facts.today && item.status == .todayPending
        VStack(spacing: PulseDesign.spacing8) {
            Circle()
                .strokeBorder(printStroke(item), lineWidth: 1.5)
                .background(Circle().fill(printFill(item)))
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            VStack(spacing: 2) {
                if let timeZone = facts.timeZone {
                    Text(PulseFormatting.shortWeekday(item.day, timeZone: timeZone, locale: locale))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PulseDesign.appMuted(for: theme))
                }
                Text(item.day.day, format: .number)
                    .font(.system(size: 12, weight: isToday ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(
                        item.status == .checked
                            ? accent
                            : (isToday ? PulseDesign.appInk(for: theme) : PulseDesign.appMuted(for: theme))
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            facts.timeZone.map {
                PulseTodayPresentation.weekDayAccessibilityLabel(item, timeZone: $0, locale: locale)
            } ?? ""
        )
        .accessibilityIdentifier("today.week.day.\(item.day.storageValue)")
    }

    /// A kept day is fully developed — solid. The ring shape doubles the color cue,
    /// so the rail never leans on color alone.
    private func printFill(_ item: CalendarDayItem) -> Color {
        switch item.status {
        case .checked: accent
        default: .clear
        }
    }

    private func printStroke(_ item: CalendarDayItem) -> Color {
        switch item.status {
        case .checked: accent
        case .todayPending: accent
        case .missed: PulseDesign.appDivider(for: theme)
        case .beforeHabit, .future: PulseDesign.appDivider(for: theme)
        }
    }
}
