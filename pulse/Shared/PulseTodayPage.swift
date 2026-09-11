import PulseCore
import SwiftUI

/// Shared by Today and its read-only theme preview.
struct PulseTodayPage<CheckIn: View, Journal: View>: View {
    let today: LogicalDay?
    let timeZone: TimeZone?
    let habitName: String?
    let recentDays: [CalendarDayItem]
    let currentStreak: Int
    let checkIn: CheckIn
    let journal: Journal

    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 64) {
                    mainContent.frame(maxWidth: .infinity)
                    supportingContent.frame(maxWidth: .infinity).padding(.top, 20)
                }
            } else {
                VStack(spacing: 32) {
                    mainContent
                    supportingContent
                }
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            heading
            checkIn.frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var heading: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) { date; title }
        } else {
            switch theme {
            case .editorialJournal:
                VStack(alignment: .leading, spacing: 16) {
                    date
                    title
                    Rectangle().fill(PulseDesign.appInk(for: theme)).frame(width: 44, height: 2)
                }
            case .quietField:
                VStack(spacing: 12) {
                    date
                    title.multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity)
            case .sunlitDay:
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 16) {
                        dayNumber.font(.system(size: 58, weight: .bold, design: .rounded))
                        date.fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    title
                }
            case .moonTide:
                VStack(spacing: 16) {
                    date
                    title.multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity)
            case .prismLedger:
                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) { date; title }
                    Spacer(minLength: 0)
                    dayNumber.font(.system(size: 38, weight: .light, design: .monospaced))
                        .padding(.leading, 16)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(PulseDesign.appDivider(for: theme)).frame(width: 1)
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var date: some View {
        if let today, let timeZone {
            Text(!dynamicTypeSize.isAccessibilitySize && (theme == .sunlitDay || theme == .prismLedger)
                 ? String(format: PulseLocalization.string("today.kicker_with_weekday_format", locale: locale),
                          PulseFormatting.numericYearAndMonth(today, timeZone: timeZone),
                          PulseFormatting.fullWeekday(today, timeZone: timeZone, locale: locale))
                 : PulseFormatting.fullDate(today, timeZone: timeZone, locale: locale))
                .font(theme == .prismLedger ? .system(.caption, design: .monospaced) : .subheadline)
                .foregroundStyle(PulseDesign.appMuted(for: theme))
                .accessibilityLabel(PulseFormatting.fullDate(today, timeZone: timeZone, locale: locale))
                .accessibilityIdentifier("today.hero.kicker")
        }
    }

    @ViewBuilder
    private var dayNumber: some View {
        if let today {
            Text(today.day, format: .number).monospacedDigit()
                .foregroundStyle(PulseDesign.appAccent(for: theme))
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var title: some View {
        if let habitName {
            Text(habitName)
                .font(.system(theme == .sunlitDay ? .title : .largeTitle,
                              design: theme == .editorialJournal ? .serif : (theme == .quietField ? .rounded : .default),
                              weight: theme == .moonTide ? .regular : .semibold))
                .foregroundStyle(PulseDesign.appInk(for: theme))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("today.commitment.name")
        }
    }

    private var supportingContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 14) {
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
                Text(PulseTodayPresentation.rhythmStatusText(currentStreak: currentStreak, locale: locale))
                    .font(.footnote)
                    .foregroundStyle(PulseDesign.appMuted(for: theme))
                    .accessibilityIdentifier("today.rhythm.status")
            }
            journal
        }
    }

    private var weekDays: some View {
        ForEach(recentDays) { item in
            weekDay(item).frame(maxWidth: .infinity)
        }
    }

    private var weekCornerRadius: CGFloat {
        switch theme {
        case .editorialJournal: 2
        case .prismLedger: 4
        case .sunlitDay: 8
        case .quietField, .moonTide: 28
        }
    }

    private func weekDay(_ item: CalendarDayItem) -> some View {
        let checked = item.status == .checked
        return VStack(spacing: 8) {
            if let timeZone {
                Text(PulseFormatting.shortWeekday(item.day, timeZone: timeZone, locale: locale))
                    .font(.caption2)
                    .foregroundStyle(PulseDesign.appMuted(for: theme))
            }
            ZStack {
                RoundedRectangle(cornerRadius: weekCornerRadius)
                    .fill(checked ? PulseDesign.appAccent(for: theme) : .clear)
                if item.day == today && !checked {
                    RoundedRectangle(cornerRadius: weekCornerRadius)
                        .stroke(PulseDesign.appAccent(for: theme), lineWidth: 1.5)
                }
                if checked {
                    Image(systemName: "checkmark").font(.caption.weight(.semibold))
                } else if item.status == .missed {
                    Image(systemName: "minus").font(.caption)
                } else {
                    Text(item.day.day, format: .number).font(.caption)
                }
            }
            .foregroundStyle(checked ? PulseDesign.appAccentForeground(for: theme) : PulseDesign.appMuted(for: theme))
            .frame(width: dynamicTypeSize.isAccessibilitySize ? 56 : 28,
                   height: dynamicTypeSize.isAccessibilitySize ? 56 : 28)
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
    var isSaving = false
    var glyphScale: CGFloat = 1
    var rippleScale: CGFloat = 1
    var rippleVisible = false

    @Environment(\.pulseVisualTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var checked: Bool { completedText != nil }
    private var accent: Color { PulseDesign.appAccent(for: theme) }
    private var foreground: Color {
        checked ? PulseDesign.appAccentForeground(for: theme) : PulseDesign.appInk(for: theme)
    }
    private var fill: Color { checked ? accent : PulseDesign.appSurface(for: theme) }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) { glyph; status }
                    .padding(24).frame(maxWidth: .infinity)
                    .background(fill, in: RoundedRectangle(cornerRadius: 18))
            } else {
                artwork
            }
        }
        .foregroundStyle(foreground)
        .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.8), value: checked)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artwork: some View {
        switch theme {
        case .editorialJournal:
            VStack(spacing: 14) { glyph; status }
                .fontDesign(.serif)
                .frame(width: 210, height: 146)
                .background(PulseDesign.appSurface(for: theme))
                .foregroundStyle(accent)
                .overlay {
                    Rectangle().stroke(accent, style: StrokeStyle(lineWidth: checked ? 2 : 1, dash: checked ? [] : [3, 4]))
                        .padding(7)
                        .rotationEffect(.degrees(checked ? -3 : 0))
                        .scaleEffect(reduceMotion ? 1 : max(0.94, glyphScale))
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(accent.opacity(0.24)).frame(height: 1).padding(.horizontal, 24)
                }
        case .quietField:
            VStack(spacing: 12) { glyph; status }
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
        case .sunlitDay:
            HStack(spacing: 20) {
                status.frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    ForEach(0..<12) { index in
                        Capsule().fill(foreground.opacity(checked ? 0.72 : 0.30))
                            .frame(width: 2, height: checked ? 9 : 5)
                            .offset(y: -40)
                            .rotationEffect(.degrees(Double(index) * 30))
                    }
                    Circle().stroke(foreground.opacity(0.5), lineWidth: 1).frame(width: 60, height: 60)
                    glyph
                }.frame(width: 90, height: 90)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 338, minHeight: 148)
            .background(fill, in: RoundedRectangle(cornerRadius: 18))
            .overlay(alignment: .top) {
                HStack(spacing: 12) {
                    ForEach(0..<2) { _ in
                        Capsule().fill(accent.opacity(0.35)).frame(width: 26, height: 4)
                    }
                }.offset(y: -2)
            }
        case .moonTide:
            VStack(spacing: 14) { glyph; status }
                .frame(width: 180, height: 180)
                .background(PulseDesign.appSurface(for: theme), in: Circle())
                .foregroundStyle(PulseDesign.appInk(for: theme))
                .overlay {
                    Circle().trim(from: 0.08, to: checked ? 0.96 : 0.72)
                        .stroke(accent, style: StrokeStyle(lineWidth: checked ? 2 : 1, lineCap: .round))
                        .rotationEffect(.degrees(-105))
                        .padding(-10)
                    Circle().stroke(accent.opacity(0.15), lineWidth: 1).padding(-18)
                }
                .background {
                    Circle().stroke(accent.opacity(0.22), lineWidth: 1)
                        .scaleEffect(rippleScale).opacity(rippleVisible ? 1 : 0)
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
            .padding(24)
            .frame(maxWidth: 338, minHeight: 148)
            .background(fill, in: RoundedRectangle(cornerRadius: 4))
            .overlay { RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.5), lineWidth: 1) }
        }
    }

    @ViewBuilder
    private var glyph: some View {
        if isSaving {
            ProgressView().tint(foreground)
        } else {
            Image(systemName: checked ? "checkmark" : symbol)
                .font(.system(size: 28, weight: theme == .prismLedger ? .light : .regular))
                .scaleEffect(glyphScale)
        }
    }

    private var symbol: String {
        switch theme {
        case .editorialJournal: "circle.dotted"
        case .quietField: "leaf"
        case .sunlitDay: "sun.max"
        case .moonTide: "moon"
        case .prismLedger: "plus"
        }
    }

    @ViewBuilder
    private var status: some View {
        if let completedText {
            Text(completedText).font(.subheadline.weight(.medium))
                .multilineTextAlignment(theme == .sunlitDay || theme == .prismLedger ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("today.check_in_action")
                .font(.system(.title3, design: theme == .editorialJournal ? .serif : .default, weight: .semibold))
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
