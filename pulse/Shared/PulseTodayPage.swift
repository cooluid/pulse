import PulseCore
import SwiftUI

/// Today and its read-only theme specimen render the same page and facts.
struct PulseTodayPage<CheckIn: View, Journal: View, Media: View>: View {
    let today: LogicalDay?
    let timeZone: TimeZone?
    let habitName: String?
    let recentDays: [CalendarDayItem]
    let currentStreak: Int
    let isChecked: Bool
    let checkIn: CheckIn
    let journal: Journal
    let media: Media

    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var calendarDaySize = 136.0

    var body: some View {
        Group {
            if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 48) {
                    mainContent.frame(maxWidth: .infinity)
                    supportingContent.frame(maxWidth: .infinity).padding(.top, 20)
                }
            } else {
                VStack(spacing: 20) {
                    mainContent
                    supportingContent
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background {
            if theme == .sunlitDay {
                RoundedRectangle(cornerRadius: 3)
                    .fill(PulseDesign.appSurface(for: theme))
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(PulseDesign.appDivider(for: theme).opacity(0.4), lineWidth: 0.5)
                    }
                    .shadow(color: PulseDesign.shadow.opacity(0.08), radius: 10, y: 3)
                    .padding(.horizontal, -10)
                    .padding(.top, -6)
            }
        }
        .overlay(alignment: .topTrailing) {
            if theme == .sunlitDay && isChecked && !dynamicTypeSize.isAccessibilitySize {
                PulsePageFold().offset(x: 10, y: -6)
                    .transition(.scale(scale: 0.75, anchor: .topTrailing).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: isChecked)
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: theme == .moonTide ? 0 : 18) {
            heading
            checkIn
                .frame(maxWidth: .infinity)
                .padding(.top, theme == .moonTide ? 96 : 0)
                .padding(.bottom, theme == .moonTide ? 12 : 0)
                .offset(y: theme == .editorialJournal && isChecked && !dynamicTypeSize.isAccessibilitySize ? -78 : 0)
        }
        .background(alignment: .bottom) {
            if theme == .moonTide {
                PulseMoonSeascapeView()
                    .frame(height: 280)
                    .padding(.horizontal, -PulseDesign.horizontalPadding)
            }
        }
    }

    @ViewBuilder
    private var heading: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) { date; title }
        } else {
            switch theme {
            case .editorialJournal:
                VStack(alignment: .leading, spacing: 18) {
                    date
                    Rectangle().fill(PulseDesign.appDivider(for: theme)).frame(height: 1)
                    title
                        .padding(.trailing, isChecked ? 138 : 0)
                    Rectangle().fill(PulseDesign.appAccent(for: theme)).frame(width: 46, height: 3)
                }
            case .sunlitDay:
                VStack(alignment: .leading, spacing: 18) {
                    calendarDate
                    title
                }
            case .moonTide:
                VStack(alignment: .leading, spacing: 14) { date; title }
            case .quietField:
                VStack(spacing: 12) {
                    date
                    title.multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity)
            case .prismLedger:
                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) { date; title }
                    Spacer(minLength: 0)
                    dayNumber
                        .font(.system(size: 38, weight: .light, design: .monospaced))
                        .padding(.leading, 16)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(PulseDesign.appDivider(for: theme)).frame(width: 1)
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var calendarDate: some View {
        if let today, let timeZone {
            HStack(alignment: .center, spacing: 24) {
                dayNumber
                    .font(.system(size: calendarDaySize, weight: .regular, design: .serif))
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                VStack(alignment: .leading, spacing: 8) {
                    Text(PulseFormatting.year(today, timeZone: timeZone))
                        .font(.system(.title2, design: .serif))
                    Text(today.month, format: .number.precision(.integerLength(2)))
                        .font(.system(.title, design: .serif))
                    Rectangle().fill(PulseDesign.appAccent(for: theme)).frame(height: 1)
                    Text(PulseFormatting.fullWeekday(today, timeZone: timeZone, locale: locale))
                        .font(PulseDesign.editorialDisplayFont(size: 18, relativeTo: .headline))
                        .foregroundStyle(PulseDesign.sunlitWeekday)
                }
                .foregroundStyle(PulseDesign.appAccent(for: theme))
                .frame(maxWidth: 126, alignment: .leading)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(PulseFormatting.fullDate(today, timeZone: timeZone, locale: locale))
            .accessibilityIdentifier("today.hero.kicker")
        }
    }

    @ViewBuilder
    private var date: some View {
        if let today, let timeZone {
            Text(PulseFormatting.fullDate(today, timeZone: timeZone, locale: locale))
                .font(theme == .editorialJournal
                      ? PulseDesign.editorialDisplayFont(size: 15, relativeTo: .subheadline)
                      : .subheadline)
                .foregroundStyle(PulseDesign.appMuted(for: theme))
                .accessibilityIdentifier("today.hero.kicker")
        }
    }

    @ViewBuilder
    private var dayNumber: some View {
        if let today {
            Text(today.day, format: .number)
                .monospacedDigit()
                .foregroundStyle(PulseDesign.appAccent(for: theme))
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var title: some View {
        if let habitName {
            Text(habitName)
                .font(titleFont)
                .foregroundStyle(PulseDesign.appInk(for: theme))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("today.commitment.name")
        }
    }

    private var titleFont: Font {
        switch theme {
        case .editorialJournal, .sunlitDay:
            PulseDesign.editorialDisplayFont(size: 31, relativeTo: .largeTitle).weight(.bold)
        case .moonTide:
            .system(.largeTitle, weight: .medium)
        case .quietField:
            .system(.largeTitle, design: .rounded, weight: .semibold)
        case .prismLedger:
            .system(.largeTitle, weight: .semibold)
        }
    }

    private var supportingContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Rectangle().fill(PulseDesign.appDivider(for: theme)).frame(height: 1)
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 16) {
                            weekDays
                        }
                    } else {
                        HStack(spacing: 0) { weekDays }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("today.week.rail")
                Rectangle().fill(PulseDesign.appDivider(for: theme)).frame(height: 1)
                Text(PulseTodayPresentation.rhythmStatusText(currentStreak: currentStreak, locale: locale))
                    .font(theme == .editorialJournal
                          ? PulseDesign.editorialDisplayFont(size: 18, relativeTo: .headline)
                          : .headline.weight(.medium))
                    .foregroundStyle(PulseDesign.appInk(for: theme))
                    .accessibilityIdentifier("today.rhythm.status")
            }
            journal
            media
        }
    }

    private var weekDays: some View {
        ForEach(recentDays) { item in
            weekDay(item).frame(maxWidth: .infinity)
        }
    }

    private func weekDay(_ item: CalendarDayItem) -> some View {
        let checkedToday = item.day == today && item.status == .checked
        let isPending = item.status == .todayPending
        return VStack(spacing: 8) {
            if let timeZone {
                Text(PulseFormatting.shortWeekday(item.day, timeZone: timeZone, locale: locale))
                    .font(.caption)
                    .foregroundStyle(PulseDesign.appMuted(for: theme))
            }
            HStack(spacing: 2) {
                Text(item.day.day, format: .number)
                    .monospacedDigit()
                    .font(.caption)
                if item.status == .checked {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                } else if item.status == .missed {
                    Image(systemName: "minus").font(.system(size: 9, weight: .medium))
                } else if item.status == .beforeHabit {
                    Image(systemName: "circle.dotted").font(.system(size: 7))
                }
            }
            .foregroundStyle(checkedToday ? PulseDesign.appAccentForeground(for: theme) : PulseDesign.appInk(for: theme))
            .frame(minWidth: 36, minHeight: dynamicTypeSize.isAccessibilitySize ? 52 : 36)
            .background(checkedToday ? PulseDesign.appAccent(for: theme) : .clear, in: Capsule())
            .overlay {
                if isPending {
                    Capsule().stroke(PulseDesign.appAccent(for: theme), lineWidth: 1.2)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timeZone.map {
            PulseTodayPresentation.weekDayAccessibilityLabel(item, timeZone: $0, locale: locale)
        } ?? "")
        .accessibilityIdentifier("today.week.day.\(item.day.storageValue)")
    }
}

struct PulseCheckInFace: View {
    let completedText: String?
    var day: LogicalDay?
    var completedTime: String?
    var isSaving = false
    var glyphScale: CGFloat = 1

    @Environment(\.pulseVisualTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    private var checked: Bool { completedText != nil }
    private var accent: Color { PulseDesign.appAccent(for: theme) }
    private var foreground: Color {
        checked ? PulseDesign.appAccentForeground(for: theme) : PulseDesign.appInk(for: theme)
    }
    private var fill: Color { checked ? accent : PulseDesign.appSurface(for: theme) }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    if checked {
                        Image(systemName: "checkmark").foregroundStyle(accent)
                    } else if isSaving {
                        ProgressView().tint(PulseDesign.appAccentForeground(for: theme))
                    }
                    status
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(checked ? .clear : accent, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(checked ? PulseDesign.appInk(for: theme) : PulseDesign.appAccentForeground(for: theme))
            } else {
                artwork
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86), value: checked)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artwork: some View {
        switch theme {
        case .editorialJournal:
            Group {
                if checked {
                    VStack(spacing: 6) {
                        VStack(spacing: 5) {
                            Text("calendar.status.checked")
                                .font(PulseDesign.editorialDisplayFont(size: 22, relativeTo: .title2))
                            if let day {
                                Text(String(format: "%02d.%02d", day.month, day.day))
                                    .font(.system(size: 23, design: .serif))
                            }
                        }
                        .frame(width: 124, height: 94)
                        .background { PulseStampOutline() }
                        .rotationEffect(.degrees(-7))
                        .scaleEffect(reduceMotion ? 1 : max(0.86, glyphScale))
                        Text(completedTime ?? "")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(PulseDesign.appInk(for: theme))
                    }
                    .foregroundStyle(accent)
                    .padding(.trailing, 10)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    pendingButton(cornerRadius: 6)
                        .overlay { PulseStampOutline().foregroundStyle(PulseDesign.appAccentForeground(for: theme).opacity(0.62)).padding(4) }
                }
            }
            .frame(height: 138)
        case .sunlitDay:
            Group {
                if checked {
                    status.foregroundStyle(accent).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    pendingButton(cornerRadius: 8)
                }
            }
            .frame(minHeight: 62)
        case .moonTide:
            Group {
                if checked {
                    ZStack(alignment: .bottomTrailing) {
                        Image("PulseTideTrace").resizable().scaledToFit()
                            .frame(maxWidth: .infinity)
                            .opacity(0.9)
                            .scaleEffect(x: reduceMotion ? 1 : min(1.08, max(0.92, glyphScale)), y: 1, anchor: .leading)
                        HStack(spacing: 7) {
                            Circle().fill(accent).frame(width: 7, height: 7)
                            status
                        }
                        .foregroundStyle(accent)
                        .padding(.bottom, 4)
                    }
                    .frame(height: 76)
                } else {
                    pendingButton(cornerRadius: 32)
                        .shadow(color: accent.opacity(0.18), radius: 14)
                }
            }
            .frame(height: 82)
        case .quietField:
            VStack(spacing: 12) { glyph; status }
                .foregroundStyle(foreground)
                .frame(width: 190, height: 176)
                .background {
                    PulseSeedShape().fill(fill)
                    PulseSeedShape().stroke(accent.opacity(0.45), lineWidth: 1).padding(-7)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "leaf.fill").font(.system(size: 23, weight: .light))
                        .foregroundStyle(accent)
                        .rotationEffect(.degrees(checked ? -18 : 12))
                        .scaleEffect(checked ? 1.15 : 0.8)
                        .offset(x: 4, y: -8)
                }
        case .prismLedger:
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 4) {
                        ForEach(0..<9) { index in
                            Rectangle().fill(foreground.opacity(index.isMultiple(of: 3) ? 0.75 : 0.25))
                                .frame(width: 1, height: index.isMultiple(of: 3) ? 12 : 6)
                        }
                    }
                    status
                }.frame(maxWidth: .infinity, alignment: .leading)
                glyph.frame(width: 64, height: 64)
                    .overlay { Rectangle().stroke(foreground.opacity(0.35), lineWidth: 1) }
            }
            .foregroundStyle(foreground)
            .padding(24)
            .frame(maxWidth: 338, minHeight: 148)
            .background(fill, in: RoundedRectangle(cornerRadius: 4))
            .overlay { RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.5), lineWidth: 1) }
        }
    }

    private func pendingButton(cornerRadius: CGFloat) -> some View {
        Group {
            if isSaving {
                ProgressView().tint(PulseDesign.appAccentForeground(for: theme))
            } else {
                Text("today.check_in_action")
                    .font(theme == .editorialJournal || theme == .sunlitDay
                          ? PulseDesign.editorialDisplayFont(size: 25, relativeTo: .title2).weight(.semibold)
                          : .title3.weight(.semibold))
            }
        }
        .foregroundStyle(PulseDesign.appAccentForeground(for: theme))
        .frame(maxWidth: .infinity, minHeight: theme == .editorialJournal ? 92 : 62)
        .background(accent, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    private var glyph: some View {
        if isSaving {
            ProgressView().tint(foreground)
        } else {
            Image(systemName: checked ? "checkmark" : (theme == .quietField ? "leaf" : "plus"))
                .font(.system(size: 28, weight: theme == .prismLedger ? .light : .regular))
                .scaleEffect(glyphScale)
        }
    }

    @ViewBuilder
    private var status: some View {
        if let completedText {
            Text(completedText)
                .font(.headline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("today.check_in_action").font(.title3.weight(.semibold))
        }
    }
}
private struct PulseSeedShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.48, y: 0))
        path.addCurve(to: CGPoint(x: rect.width, y: rect.height * 0.48),
                      control1: CGPoint(x: rect.width * 0.92, y: -rect.height * 0.02),
                      control2: CGPoint(x: rect.width, y: rect.height * 0.12))
        path.addCurve(to: CGPoint(x: rect.width * 0.42, y: rect.height),
                      control1: CGPoint(x: rect.width, y: rect.height * 0.91),
                      control2: CGPoint(x: rect.width * 0.80, y: rect.height))
        path.addCurve(to: CGPoint(x: 0, y: rect.height * 0.52),
                      control1: CGPoint(x: rect.width * 0.12, y: rect.height),
                      control2: CGPoint(x: 0, y: rect.height * 0.9))
        path.addCurve(to: CGPoint(x: rect.width * 0.48, y: 0),
                      control1: CGPoint(x: 0, y: rect.height * 0.2),
                      control2: CGPoint(x: rect.width * 0.12, y: 0))
        path.closeSubpath()
        return path
    }
}
