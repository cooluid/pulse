import PulseCore
import SwiftUI

struct PulseVisualThemeSpecimen: View {
    let theme: PulseVisualTheme
    let model: PulseAppModel
    @Environment(\.locale) private var locale

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
                        checkIn: previewCheckIn,
                        journal: previewJournal
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
            }
            .environment(\.pulseVisualTheme, theme)
            .environment(\.horizontalSizeClass, .compact)
            .environment(\.dynamicTypeSize, .medium)
            .scaleEffect(scale, anchor: .topLeading)
        }
        .aspectRatio(360.0 / 740.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var previewCheckIn: some View {
        VStack(spacing: 18) {
            PulseCheckInFace(completedText: model.todayRecord.map { record in
                String(format: PulseLocalization.string("today.checked_with_time", locale: locale),
                       PulseFormatting.time(record.checkedAt, timeZone: record.timeZone, locale: locale))
            })
            Group {
                if model.todayRecord == nil {
                    Text("today.check_in_hint_visible")
                        .font(.caption)
                        .foregroundStyle(PulseDesign.appMuted(for: theme))
                } else if model.settings.mediaInvitationEnabled || model.todayMedia != nil {
                    Label(model.todayMedia == nil ? "today.media.capture_compact" : "today.media.view_compact", systemImage: "camera.fill")
                        .font(.caption.bold())
                        .foregroundStyle(PulseDesign.appInk(for: theme))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(PulseDesign.appSurface(for: theme), in: Capsule())
                        .overlay { Capsule().stroke(PulseDesign.appDivider(for: theme), lineWidth: 1) }
                }
            }
            .frame(minHeight: 44)
        }
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

private struct PulseThemeDraftPreview: View {
    @FocusState private var isFocused: Bool
    var body: some View {
        JournalDraftComposer(text: .constant(""), isFocused: $isFocused, isDisabled: true)
    }
}
