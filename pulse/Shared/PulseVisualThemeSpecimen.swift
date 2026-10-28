import PulseCore
import SwiftUI

/// A read-only Today page drawn in another theme, from the same facts.
struct PulseVisualThemeSpecimen: View {
    let theme: PulseVisualTheme
    let model: PulseAppModel
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var inheritedColorScheme

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / 360
            VStack(spacing: 0) {
                PulseSpecimenBar()
                PulseTodayPage(
                    today: model.today,
                    timeZone: model.timeZone,
                    habitName: model.habit?.name,
                    recentDays: model.recentDays,
                    currentStreak: model.statistics.currentStreak,
                    isChecked: model.todayRecord != nil,
                    checkIn: previewCheckIn,
                    journal: previewJournal,
                    media: EmptyView()
                )
                .padding(.horizontal, PulseDesign.horizontalPadding)
                Spacer(minLength: 0)
                PulsePrimaryNavigation(
                    selection: .constant(.today),
                    todayDayNumber: model.today?.day,
                    isTodayChecked: model.todayRecord != nil
                )
            }
            .padding(.top, 12)
            .frame(width: 360, height: 740)
            .background(PulseScreenBackground())
            .environment(\.pulseVisualTheme, theme)
            .environment(\.colorScheme, previewColorScheme)
            .environment(\.horizontalSizeClass, .compact)
            .environment(\.dynamicTypeSize, .medium)
            .scaleEffect(scale, anchor: .topLeading)
        }
        .aspectRatio(360.0 / 740.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var previewColorScheme: ColorScheme {
        PulseThemeAppearance.previewColorScheme(theme: theme, appearance: model.settings.theme,
                                              inherited: inheritedColorScheme)
    }

    private var previewCheckIn: some View {
        PulseCheckInFace(
            habitName: model.habit?.name,
            day: model.today,
            completedText: model.todayRecord.map { record in
                String(format: PulseLocalization.string("today.checked_with_time", locale: locale),
                       PulseFormatting.time(record.checkedAt, timeZone: record.timeZone, locale: locale))
            }
        )
    }

    @ViewBuilder
    private var previewJournal: some View {
        if let record = model.todayRecord {
            JournalNoteSummary(record: record, onEdit: {})
        } else {
            PulseThemeDraftPreview()
        }
    }
}

/// The smaller face of a theme: its paper, today's impression, and the week.
struct PulseVisualThemeSwatch: View {
    let theme: PulseVisualTheme
    let habitName: String?
    let today: LogicalDay?
    let recentDays: [CalendarDayItem]

    var body: some View {
        let palette = PulseDesign.palette(for: theme)
        let seed = today.map(PulseSealSeed.value(for:)) ?? 0
        HStack(spacing: PulseDesign.spacing20) {
            PulseSealImpression(inscription: .name(habitName ?? ""), ink: palette.seal, seed: seed)
                .rotationEffect(PulseSealSeed.tilt(for: seed))
                .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                if let habitName {
                    Text(habitName)
                        .font(PulseDesign.displayFont(size: 19, relativeTo: .headline).weight(.bold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                HStack(spacing: 5) {
                    ForEach(recentDays) { item in
                        PulseDayMark(
                            day: item.day.day,
                            state: PulseDayMarkState(item.status),
                            seed: PulseSealSeed.value(for: item.day),
                            seal: palette.seal,
                            ink: palette.ink,
                            muted: palette.muted,
                            emphasized: item.day == today
                        )
                        .frame(width: 22, height: 22)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PulseDesign.spacing20)
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .background(palette.paper)
        .environment(\.pulseVisualTheme, theme)
        .accessibilityHidden(true)
    }
}

/// The Today bar as it sits on the page, without being a way anywhere.
private struct PulseSpecimenBar: View {
    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        HStack {
            Spacer()
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(PulseDesign.appInk(for: visualTheme))
                .frame(width: PulseDesign.minimumHitTarget, height: PulseDesign.minimumHitTarget)
                .pulseGlass(in: Circle())
        }
        .padding(.horizontal, PulseDesign.spacing16)
        .frame(height: 52)
    }
}

private struct PulseThemeDraftPreview: View {
    @FocusState private var isFocused: Bool
    var body: some View {
        JournalDraftComposer(text: .constant(""), isFocused: $isFocused, isDisabled: true)
    }
}
