import PulseCore
import SwiftUI

struct CalendarDayCell: View {
    let item: CalendarDayItem
    let isToday: Bool
    let hasMedia: Bool
    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        let style = PulseDesign.CalendarDayStyle.resolve(
            theme: visualTheme,
            status: item.status
        )

        ZStack {
            tile(style)
            dayContent(style)
        }
        .frame(maxWidth: .infinity)
        .frame(height: PulseDesign.calendarDayHitSize)
        .overlay {
            if isToday {
                todayStroke(style)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if hasMedia {
                Image(systemName: "camera.fill")
                    .font(
                        .system(
                            size: PulseDesign.calendarAccessoryGlyphSize,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(style.mediaForeground)
                    .padding(PulseDesign.spacing4)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("calendar.day.\(item.day.storageValue)")
    }

    private func tile(_ style: PulseDesign.CalendarDayStyle) -> some View {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
            .fill(style.fill).frame(width: style.tileSize, height: style.tileSize)
    }

    private func todayStroke(_ style: PulseDesign.CalendarDayStyle) -> some View {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
            .stroke(style.todayStroke, lineWidth: 1.5)
            .frame(width: style.tileSize, height: style.tileSize)
    }

    @ViewBuilder
    private func dayContent(_ style: PulseDesign.CalendarDayStyle) -> some View {
        let numberFont = dayNumberFont(style)
        switch style.mark {
        case .checked:
            VStack(spacing: 0) {
                Text(item.day.day, format: .number)
                    .font(numberFont)
                    .monospacedDigit()
                Image(systemName: "checkmark")
                    .font(statusGlyphFont(style))
            }
            .foregroundStyle(style.foreground)
        case .missed:
            VStack(spacing: 0) {
                Text(item.day.day, format: .number)
                    .font(numberFont)
                    .monospacedDigit()
                Image(systemName: "minus")
                    .font(statusGlyphFont(style))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(style.foreground)
        case .beforeHabit:
            VStack(spacing: 0) {
                Text(item.day.day, format: .number)
                    .font(numberFont)
                    .monospacedDigit()
                Image(systemName: "circle.dotted")
                    .font(beforeHabitGlyphFont)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(style.foreground)
        case .none:
            Text(item.day.day, format: .number)
                .font(numberFont)
                .monospacedDigit()
                .foregroundStyle(style.foreground)
        }
    }

    private func dayNumberFont(_ style: PulseDesign.CalendarDayStyle) -> Font {
        let weight: Font.Weight = (style.mark == .checked || isToday) ? .bold : .regular
        let textStyle: Font.TextStyle = style.mark == .checked ? .caption2 : .caption
        return .system(textStyle, design: .default, weight: weight)
    }

    private func statusGlyphFont(_ style: PulseDesign.CalendarDayStyle) -> Font {
        .system(size: PulseDesign.calendarAccessoryGlyphSize, weight: .semibold)
    }

    private var beforeHabitGlyphFont: Font {
        .system(size: PulseDesign.calendarAccessoryGlyphSize, weight: .semibold)
    }

    private var accessibilityLabel: String {
        CalendarDayAccessibility.monthDayLabel(item, locale: locale, hasMedia: hasMedia)
    }
}
