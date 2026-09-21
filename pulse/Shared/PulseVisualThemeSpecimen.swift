import PulseCore
import SwiftUI

struct PulseVisualThemeSpecimen: View {
    let theme: PulseVisualTheme
    let model: PulseAppModel
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var inheritedColorScheme

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / 360
            VStack(spacing: 0) {
                PulseAppHeader(source: .today)
                ScrollView {
                    PulseTodayPage(
                        today: model.today,
                        timeZone: model.timeZone,
                        habitName: model.habit?.name,
                        recentDays: model.recentDays,
                        currentStreak: model.statistics.currentStreak,
                        isChecked: model.todayRecord != nil,
                        checkIn: previewCheckIn,
                        journal: previewJournal,
                        media: previewMedia
                    )
                    .padding(.horizontal, PulseDesign.horizontalPadding)
                }
                .scrollDisabled(true)
                .scrollIndicators(.hidden)
                PulsePrimaryNavigation(selection: .constant(.today), todayDayNumber: model.today?.day,
                                       isTodayChecked: model.todayRecord != nil)
            }
            .padding(.top, 12)
            .frame(width: 360, height: 740)
            .background {
                PulseScreenBackground()
                PulseFieldBackground(presentation: .today, allowsMotion: false)
                PulseThemeBackdrop(facts: facts)
                    .padding(.top, 12)
            }
            .environment(\.pulseVisualTheme, theme)
            .environment(\.colorScheme, previewColorScheme)
            .environment(\.horizontalSizeClass, .compact)
            .environment(\.dynamicTypeSize, .medium)
            .scaleEffect(scale, anchor: .topLeading)
        }
        .aspectRatio(360.0 / 740.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var facts: PulseTodayFacts {
        PulseTodayFacts(
            today: model.today,
            timeZone: model.timeZone,
            habitName: model.habit?.name,
            recentDays: model.recentDays,
            currentStreak: model.statistics.currentStreak,
            isChecked: model.todayRecord != nil
        )
    }

    private var previewColorScheme: ColorScheme {
        PulseThemeAppearance.previewColorScheme(theme: theme, appearance: model.settings.theme,
                                              inherited: inheritedColorScheme)
    }

    private var previewCheckIn: some View {
        PulseCheckInFace(
            completedText: model.todayRecord.map { record in
                String(format: PulseLocalization.string("today.checked_with_time", locale: locale),
                       PulseFormatting.time(record.checkedAt, timeZone: record.timeZone, locale: locale))
            },
            day: model.today,
            completedTime: model.todayRecord.map {
                PulseFormatting.time($0.checkedAt, timeZone: $0.timeZone, locale: locale)
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

    @ViewBuilder
    private var previewMedia: some View {
        if model.todayRecord != nil && (model.settings.mediaInvitationEnabled || model.todayMedia != nil) {
            Label(model.todayMedia == nil ? "today.media.capture_compact" : "today.media.view_compact", systemImage: "camera")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PulseDesign.appInk(for: theme))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: theme == .editorialJournal ? .leading : .center)
        }
    }
}

private struct PulseThemeDraftPreview: View {
    @FocusState private var isFocused: Bool
    var body: some View {
        JournalDraftComposer(text: .constant(""), isFocused: $isFocused, isDisabled: true)
    }
}
