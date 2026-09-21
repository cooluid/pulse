import PulseCore
import SwiftUI

/// The facts every Today composition reads. How they are arranged is the theme's own business.
struct PulseTodayFacts {
    let today: LogicalDay?
    let timeZone: TimeZone?
    let habitName: String?
    let recentDays: [CalendarDayItem]
    let currentStreak: Int
    let isChecked: Bool
}

/// Today and its read-only theme specimen render the same facts.
///
/// A theme that has its own composition renders it here; the rest keep the shared
/// legacy arrangement. Moving a theme out of `legacyComposition` never touches another theme.
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

    var body: some View {
        switch theme {
        case .immersion:
            PulseImmersionTodayPage(
                facts: facts,
                checkIn: checkIn,
                journal: journal,
                media: media
            )
        case .prismLedger:
            PulsePrismLedgerTodayPage(
                facts: facts,
                checkIn: checkIn,
                journal: journal,
                media: media
            )
        case .quietField:
            PulseQuietFieldTodayPage(
                facts: facts,
                checkIn: checkIn,
                journal: journal,
                media: media
            )
        case .sunlitDay:
            PulseSunlitTodayPage(
                facts: facts,
                checkIn: checkIn,
                journal: journal,
                media: media
            )
        default:
            legacyComposition
        }
    }

    var facts: PulseTodayFacts {
        PulseTodayFacts(
            today: today,
            timeZone: timeZone,
            habitName: habitName,
            recentDays: recentDays,
            currentStreak: currentStreak,
            isChecked: isChecked
        )
    }

    /// The editorial journal arrangement. Themes with their own composition never land here.
    private var legacyComposition: some View {
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
        .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: isChecked)
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading
            checkIn
                .frame(maxWidth: .infinity)
                .offset(y: isChecked && !dynamicTypeSize.isAccessibilitySize ? -78 : 0)
        }
    }

    @ViewBuilder
    private var heading: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) { date; title }
        } else {
            VStack(alignment: .leading, spacing: 18) {
                date
                Rectangle().fill(PulseDesign.appDivider(for: theme)).frame(height: 1)
                title
                    .padding(.trailing, isChecked ? 138 : 0)
                Rectangle().fill(PulseDesign.appAccent(for: theme)).frame(width: 46, height: 3)
            }
        }
    }

    @ViewBuilder
    private var date: some View {
        if let today, let timeZone {
            Text(PulseFormatting.fullDate(today, timeZone: timeZone, locale: locale))
                .font(PulseDesign.editorialDisplayFont(size: 15, relativeTo: .subheadline))
                .foregroundStyle(PulseDesign.appMuted(for: theme))
                .accessibilityIdentifier("today.hero.kicker")
        }
    }

    @ViewBuilder
    private var title: some View {
        if let habitName {
            Text(habitName)
                .font(PulseDesign.editorialDisplayFont(size: 31, relativeTo: .largeTitle).weight(.bold))
                .foregroundStyle(PulseDesign.appInk(for: theme))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("today.commitment.name")
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
                    .font(PulseDesign.editorialDisplayFont(size: 18, relativeTo: .headline))
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
            sunlitFace
        case .quietField:
            quietFieldFace
        case .prismLedger:
            HStack(spacing: PulseDesign.spacing16) {
                if checked {
                    VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                        if let completedText {
                            Text(completedText)
                                .font(.system(size: 17, weight: .semibold))
                        }
                        if let completedTime {
                            Text(completedTime)
                                .font(.system(size: 13, design: .monospaced))
                                .opacity(0.7)
                        }
                    }
                    .foregroundStyle(PulseDesign.appInk(for: theme))
                } else if isSaving {
                    ProgressView()
                        .tint(PulseDesign.appAccentForeground(for: theme))
                } else {
                    Text("today.check_in_action")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PulseDesign.appAccentForeground(for: theme))
                }

                Spacer(minLength: 0)

                Rectangle()
                    .fill(checked ? accent : PulseDesign.appAccentForeground(for: theme))
                    .frame(width: 14, height: 14)
            }
            .padding(.horizontal, PulseDesign.spacing20)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(checked ? PulseDesign.appAccentSoft(for: theme) : accent)
        case .immersion:
            Group {
                if checked {
                    immersionCheckedFace
                } else {
                    immersionPendingFace
                }
            }
            .frame(height: 104)
        }
    }

    // MARK: - Quiet Field: the check-in is one brush stroke

    /// One stroke of ink under the stalk: press, and the stroke lands.
    private var quietFieldFace: some View {
        Group {
            if checked {
                HStack(spacing: PulseDesign.spacing12) {
                    Capsule()
                        .fill(accent)
                        .frame(width: 34, height: 4)
                    if let completedText {
                        Text(completedText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(PulseDesign.appInk(for: theme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .padding(.horizontal, PulseDesign.spacing4)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            } else if isSaving {
                ProgressView()
                    .tint(accent)
                    .frame(maxWidth: .infinity, minHeight: 58)
            } else {
                HStack(spacing: PulseDesign.spacing12) {
                    Circle()
                        .fill(PulseDesign.appAccentForeground(for: theme))
                        .frame(width: 8, height: 8)
                    Text("today.check_in_action")
                        .font(PulseDesign.editorialDisplayFont(size: 21, relativeTo: .title2).weight(.semibold))
                }
                .foregroundStyle(PulseDesign.appAccentForeground(for: theme))
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(accent, in: Capsule())
                .scaleEffect(reduceMotion ? 1 : max(0.9, glyphScale))
            }
        }
        .frame(height: 58)
    }

    // MARK: - Sunlit Day: the check-in is an exposure

    /// Pending: the day waits as a white outline on sensitized paper.
    /// Checked: the print develops — the sheet turns white where the sun struck it.
    private var sunlitFace: some View {
        Group {
            if checked {
                HStack(spacing: PulseDesign.spacing12) {
                    if let completedText {
                        Text(completedText)
                            .font(.system(size: 17, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .heavy))
                }
                .foregroundStyle(PulseDesign.appAccentForeground(for: theme))
                .padding(.horizontal, PulseDesign.spacing24)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(
                    accent,
                    in: RoundedRectangle(cornerRadius: 32, style: .continuous)
                )
            } else if isSaving {
                ProgressView()
                    .tint(accent)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .overlay {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(accent.opacity(0.4), lineWidth: 1.5)
                    }
            } else {
                HStack(spacing: PulseDesign.spacing12) {
                    Text("today.check_in_action")
                        .font(PulseDesign.editorialDisplayFont(size: 21, relativeTo: .title2).weight(.semibold))
                    Spacer(minLength: 0)
                    Circle()
                        .stroke(accent, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                        .overlay {
                            Circle().fill(accent).frame(width: 7, height: 7)
                        }
                }
                .foregroundStyle(accent)
                .padding(.horizontal, PulseDesign.spacing24)
                .frame(maxWidth: .infinity, minHeight: 64)
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(accent, lineWidth: 1.5)
                }
            }
        }
        .frame(minHeight: 64)
    }

    /// Immersion's control is a full-width surface, not a rectangle with a label sitting on it.
    private var immersionPendingFace: some View {
        HStack(spacing: 0) {
            if isSaving {
                ProgressView()
                    .tint(PulseDesign.appAccentForeground(for: theme))
                    .padding(.leading, PulseDesign.spacing32)
            } else {
                Text("today.check_in_action")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(PulseDesign.appAccentForeground(for: theme))
                    .padding(.leading, PulseDesign.spacing32)
            }

            Spacer(minLength: 0)

            Circle()
                .fill(PulseDesign.appAccentForeground(for: theme).opacity(0.55))
                .frame(width: 14, height: 14)
                .padding(.trailing, PulseDesign.spacing32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            accent,
            in: RoundedRectangle(cornerRadius: immersionSurfaceRadius, style: .continuous)
        )
        // The surface throws light onto the page instead of sitting flat on it.
        .shadow(color: accent.opacity(0.30), radius: 26, y: 10)
    }

    /// Once the day is kept the surface goes quiet instead of staying loud.
    private var immersionCheckedFace: some View {
        HStack(spacing: 0) {
            if let completedText {
                Text(completedText)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(.leading, PulseDesign.spacing32)
            }

            Spacer(minLength: 0)

            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(accent)
                .padding(.trailing, PulseDesign.spacing32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            PulseDesign.appAccentSoft(for: theme),
            in: RoundedRectangle(cornerRadius: immersionSurfaceRadius, style: .continuous)
        )
    }

    private var immersionSurfaceRadius: CGFloat { 38 }

    private func pendingButton(cornerRadius: CGFloat) -> some View {
        Group {
            if isSaving {
                ProgressView().tint(PulseDesign.appAccentForeground(for: theme))
            } else {
                Text("today.check_in_action")
                    .font(PulseDesign.editorialDisplayFont(size: 25, relativeTo: .title2).weight(.semibold))
            }
        }
        .foregroundStyle(PulseDesign.appAccentForeground(for: theme))
        .frame(maxWidth: .infinity, minHeight: 92)
        .background(accent, in: RoundedRectangle(cornerRadius: cornerRadius))
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
