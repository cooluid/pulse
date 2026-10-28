import PulseCore
import SwiftUI

/// One day in the month: kept days are small seals carrying their date.
struct CalendarDayCell: View {
    let item: CalendarDayItem
    let isToday: Bool
    let hasMedia: Bool
    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme
    @ScaledMetric(relativeTo: .body) private var markSide = PulseDesign.calendarMarkSide

    var body: some View {
        let palette = PulseDesign.palette(for: visualTheme)
        PulseDayMark(
            day: item.day.day,
            state: PulseDayMarkState(item.status),
            seed: PulseSealSeed.value(for: item.day),
            seal: palette.seal,
            ink: palette.ink,
            muted: palette.muted,
            emphasized: isToday
        )
        .frame(width: markSide, height: markSide)
        .frame(maxWidth: .infinity)
        .frame(minHeight: PulseDesign.calendarDayHitSize)
        .overlay(alignment: .bottom) {
            if isToday && item.status == .checked {
                Circle()
                    .fill(palette.seal)
                    .frame(width: 4, height: 4)
                    .offset(y: 2)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topTrailing) {
            if hasMedia {
                Image(systemName: "camera.fill")
                    .font(.system(size: PulseDesign.calendarAccessoryGlyphSize, weight: .bold))
                    .foregroundStyle(palette.ink)
                    .padding(3)
                    .background(palette.paper, in: Circle())
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("calendar.day.\(item.day.storageValue)")
    }

    private var accessibilityLabel: String {
        CalendarDayAccessibility.monthDayLabel(item, locale: locale, hasMedia: hasMedia)
    }
}
