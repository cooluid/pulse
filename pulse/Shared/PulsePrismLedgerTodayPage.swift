import PulseCore
import SwiftUI

/// Prism Ledger reads like a readout.
///
/// Where Immersion is one loud number and Moon Tide is centred air, this one is compact and
/// gridded: today's facts sit side by side as labelled cells, the week is a numbered strip, and
/// the check-in is a squared bar rather than a pill or a full-width surface.
struct PulsePrismLedgerTodayPage<CheckIn: View, Journal: View, Media: View>: View {
    let facts: PulseTodayFacts
    let checkIn: CheckIn
    let journal: Journal
    let media: Media

    @Environment(\.locale) private var locale
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.pulseVisualTheme) private var theme

    private var accent: Color { PulseDesign.appAccent(for: theme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            readouts

            commitment
                .padding(.top, PulseDesign.spacing20)

            checkIn
                .padding(.top, PulseDesign.spacing20)

            weekStrip
                .padding(.top, PulseDesign.spacing24)

            VStack(alignment: .leading, spacing: PulseDesign.spacing20) {
                journal
                media
            }
            .padding(.top, PulseDesign.spacing24)
        }
        .frame(maxWidth: horizontalSizeClass == .regular ? 620 : .infinity, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.top, PulseDesign.spacing8)
        .padding(.bottom, PulseDesign.spacing12)
    }

    // MARK: - Today as two readouts

    private var readouts: some View {
        HStack(alignment: .top, spacing: PulseDesign.spacing8) {
            readoutCell {
                if let today = facts.today, let timeZone = facts.timeZone {
                    Text(PulseFormatting.fullDate(today, timeZone: timeZone, locale: locale))
                        .accessibilityIdentifier("today.hero.kicker")
                }
            }
            .accessibilityElement(children: .combine)

            readoutCell {
                Text(
                    PulseTodayPresentation.rhythmStatusText(
                        currentStreak: facts.currentStreak,
                        locale: locale
                    )
                )
            }
            .accessibilityIdentifier("today.rhythm.status")
        }
    }

    private func readoutCell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.system(size: 15, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(PulseDesign.appInk(for: theme))
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
            .padding(PulseDesign.spacing12)
            .background(
                PulseDesign.appSurface(for: theme),
                in: RoundedRectangle(cornerRadius: 4)
            )
    }

    // MARK: - Commitment

    @ViewBuilder
    private var commitment: some View {
        if let habitName = facts.habitName {
            Text(habitName)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(PulseDesign.appInk(for: theme))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("today.commitment.name")
        }
    }

    // MARK: - The week as a numbered strip

    private var weekStrip: some View {
        HStack(alignment: .bottom, spacing: PulseDesign.spacing4) {
            ForEach(facts.recentDays) { item in
                weekColumn(item)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.week.rail")
    }

    @ViewBuilder
    private func weekColumn(_ item: CalendarDayItem) -> some View {
        let isToday = item.day == facts.today && item.status == .todayPending
        VStack(spacing: PulseDesign.spacing8) {
            Rectangle()
                .fill(markFill(for: item))
                .overlay {
                    if isToday {
                        Rectangle().stroke(accent, lineWidth: 1)
                    }
                }
                .frame(height: 18)

            Text(item.day.day, format: .number)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(
                    item.status == .checked
                        ? PulseDesign.appInk(for: theme)
                        : PulseDesign.appMuted(for: theme)
                )

            if let timeZone = facts.timeZone {
                Text(PulseFormatting.shortWeekday(item.day, timeZone: timeZone, locale: locale))
                    .font(.system(size: 10))
                    .foregroundStyle(PulseDesign.appMuted(for: theme).opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            if isToday {
                RoundedRectangle(cornerRadius: 3)
                    .fill(PulseDesign.appAccentSoft(for: theme).opacity(0.55))
                    .padding(.horizontal, -3)
                    .padding(.vertical, -4)
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

    /// Every day gets the same square; the fill carries the state.
    private func markFill(for item: CalendarDayItem) -> Color {
        switch item.status {
        case .checked: accent
        case .todayPending: accent.opacity(0.16)
        case .missed: PulseDesign.appDivider(for: theme)
        case .beforeHabit, .future: PulseDesign.appInk(for: theme).opacity(0.08)
        }
    }
}
