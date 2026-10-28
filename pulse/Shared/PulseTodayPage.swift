import PulseCore
import SwiftUI

/// The facts every Today arrangement reads.
struct PulseTodayFacts {
    let today: LogicalDay?
    let timeZone: TimeZone?
    let habitName: String?
    let recentDays: [CalendarDayItem]
    let currentStreak: Int
    let isChecked: Bool
}

/// Today is one page in every theme: who you are keeping a day for, today's seal, the last week.
/// Themes change the paper and the ink; nothing here branches on them.
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

    private var palette: PulseThemePalette { PulseDesign.palette(for: theme) }
    private var usesTwoColumns: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        Group {
            if usesTwoColumns {
                HStack(alignment: .center, spacing: PulseDesign.regularWidthColumnGap) {
                    VStack(alignment: .leading, spacing: PulseDesign.spacing32) {
                        identity
                        checkIn.frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: PulseDesign.spacing32) {
                        week
                        afterword
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    identity
                    checkIn
                        .frame(maxWidth: .infinity)
                        .padding(.top, PulseDesign.spacing32)
                    week
                        .padding(.top, PulseDesign.spacing32)
                    afterword
                        .padding(.top, PulseDesign.spacing24)
                }
            }
        }
        .padding(.top, PulseDesign.spacing8)
        .padding(.bottom, PulseDesign.spacing16)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
            if let today, let timeZone {
                Text(PulseFormatting.fullDate(today, timeZone: timeZone, locale: locale))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.muted)
                    .accessibilityIdentifier("today.hero.kicker")
            }
            if let habitName {
                Text(habitName)
                    .font(PulseDesign.displayFont(size: usesTwoColumns ? 44 : 34, relativeTo: .largeTitle).weight(.bold))
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("today.commitment.name")
            }
            Text(PulseTodayPresentation.rhythmStatusText(currentStreak: currentStreak, locale: locale))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.seal)
                .accessibilityIdentifier("today.rhythm.status")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var week: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: PulseDesign.spacing12)],
                          spacing: PulseDesign.spacing16) {
                    weekDays
                }
            } else {
                HStack(spacing: 0) { weekDays }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.week.rail")
    }

    private var weekDays: some View {
        ForEach(recentDays) { item in
            weekDay(item).frame(maxWidth: .infinity)
        }
    }

    private func weekDay(_ item: CalendarDayItem) -> some View {
        let isToday = item.day == today
        return VStack(spacing: PulseDesign.spacing8) {
            if let timeZone {
                Text(PulseFormatting.shortWeekday(item.day, timeZone: timeZone, locale: locale))
                    .font(.caption.weight(isToday ? .semibold : .regular))
                    .foregroundStyle(isToday ? palette.ink : palette.muted)
            }
            PulseDayMark(
                day: item.day.day,
                state: PulseDayMarkState(item.status),
                seed: PulseSealSeed.value(for: item.day),
                seal: palette.seal,
                ink: palette.ink,
                muted: palette.muted,
                emphasized: isToday
            )
            .frame(width: weekMarkSide, height: weekMarkSide)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timeZone.map {
            PulseTodayPresentation.weekDayAccessibilityLabel(item, timeZone: $0, locale: locale)
        } ?? "")
        .accessibilityIdentifier("today.week.day.\(item.day.storageValue)")
    }

    private var weekMarkSide: CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return PulseDesign.weekMarkSide * 1.5 }
        return usesTwoColumns ? PulseDesign.regularWeekMarkSide : PulseDesign.weekMarkSide
    }

    private var afterword: some View {
        HStack(alignment: .center, spacing: PulseDesign.spacing12) {
            journal
            media
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension PulseDayMarkState {
    init(_ status: CalendarDayStatus) {
        switch status {
        case .checked: self = .kept
        case .todayPending: self = .awaiting
        case .missed: self = .missed
        case .beforeHabit, .future: self = .quiet
        }
    }
}

/// Today's seal: an empty place before, an impression after, and one line saying which.
struct PulseCheckInFace: View {
    let habitName: String?
    let day: LogicalDay?
    let completedText: String?
    var isEnabled = true
    var isSaving = false
    var isPressed = false
    var inkProgress: CGFloat = 1
    var impressionScale: CGFloat = 1

    @Environment(\.pulseVisualTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var palette: PulseThemePalette { PulseDesign.palette(for: theme) }
    private var isChecked: Bool { completedText != nil }
    private var seed: UInt64 { day.map(PulseSealSeed.value(for:)) ?? 0 }
    private var inscription: PulseSealInscription { .name(habitName ?? "") }

    var body: some View {
        VStack(spacing: PulseDesign.spacing16) {
            seal
                .frame(maxWidth: sealSide, maxHeight: sealSide)
                .frame(maxWidth: .infinity)
            status
        }
        .padding(.vertical, PulseDesign.spacing8)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var seal: some View {
        ZStack {
            PulseSealSlot(inscription: inscription, tint: palette.seal, isPressed: isPressed)
                .opacity(isChecked ? 1 - Double(inkProgress) : 1)

            if isChecked {
                PulseSealImpression(inscription: inscription, ink: palette.seal, seed: seed)
                    .mask { PulseInkSpreadShape(progress: inkProgress, seed: seed) }
                    .scaleEffect(impressionScale)
                    .rotationEffect(PulseSealSeed.tilt(for: seed))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private var status: some View {
        if let completedText {
            Text(completedText)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: PulseDesign.checkInActionHeight)
        } else {
            Text("today.check_in_action")
                .font(.headline)
                .foregroundStyle(palette.onSeal)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(isSaving ? 0 : 1)
                .overlay {
                    if isSaving {
                        ProgressView().tint(palette.onSeal)
                    }
                }
                .padding(.horizontal, PulseDesign.spacing32)
                .padding(.vertical, PulseDesign.spacing8)
                .frame(minWidth: PulseDesign.checkInActionMinimumWidth, minHeight: PulseDesign.checkInActionHeight)
                .background(palette.seal, in: Capsule())
                .opacity(isEnabled ? 1 : PulseDesign.disabledControlOpacity)
        }
    }

    private var sealSide: CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return PulseDesign.accessibilitySealSide }
        return horizontalSizeClass == .regular ? PulseDesign.regularTodaySealSide : PulseDesign.todaySealMaximumSide
    }
}
