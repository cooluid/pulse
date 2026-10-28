import AppIntents
import Foundation
import PulseCore
import SwiftUI

enum PulseReminderActivitySurface {
    case island
    case lockScreen
}

enum PulseReminderActivityMarkLayout: CaseIterable {
    case islandExpanded
    case islandCompact
    case islandMinimal
    case lockScreen

    var size: CGFloat {
        switch self {
        case .islandExpanded:
            PulseWidgetDesign.activityExpandedMarkSize
        case .islandCompact:
            PulseWidgetDesign.activityCompactMarkSize
        case .islandMinimal:
            PulseWidgetDesign.activityMinimalMarkSize
        case .lockScreen:
            PulseWidgetDesign.activityLockScreenMarkSize
        }
    }

    var surface: PulseReminderActivitySurface {
        switch self {
        case .islandExpanded, .islandCompact, .islandMinimal:
            .island
        case .lockScreen:
            .lockScreen
        }
    }
}

enum PulseReminderActivityDay {
    /// The calendar day the reminder belongs to, in the commitment's own time zone.
    static func number(reminderDate: Date, timeZoneIdentifier: String) -> Int? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return nil }
        return Calendar.pulseGregorian(timeZone: timeZone).component(.day, from: reminderDate)
    }
}

/// Today's date seal: a dashed place while the reminder waits, the impression once the day is kept.
struct PulseReminderActivityMark: View {
    let phase: PulseReminderActivityPhase
    let layout: PulseReminderActivityMarkLayout
    var day: Int?
    var locale: Locale?
    var animatesAppearance = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var hasAppeared = false

    var body: some View {
        mark
            .frame(width: layout.size, height: layout.size)
            .scaleEffect(appearanceScale)
            .opacity(appearanceOpacity)
            .animation(completionAnimation, value: phase)
            .onAppear(perform: animateAppearanceIfNeeded)
            .accessibilityElement(children: .ignore)
            .accessibilityHidden(locale == nil)
            .accessibilityLabel(Text(verbatim: accessibilityTitle))
    }

    @ViewBuilder
    private var mark: some View {
        if let day {
            PulseDayMark(
                day: day,
                state: phase == .completed ? .kept : .awaiting,
                seed: seed,
                seal: sealColor,
                ink: inkColor,
                muted: inkColor
            )
            .id(phase)
            .transition(phase == .completed ? stampTransition : .opacity)
        } else {
            ZStack {
                if phase == .completed {
                    PulseSealImpression(
                        inscription: .glyph("印"),
                        ink: sealColor,
                        seed: seed,
                        texture: isLuminanceReduced ? 0 : 0.6,
                        typeface: .systemSerif,
                        cornerFraction: PulseWidgetDesign.sealCornerFraction
                    )
                    .transition(stampTransition)
                } else {
                    PulseSealSlot(
                        inscription: .glyph("印"),
                        tint: sealColor,
                        typeface: .systemSerif,
                        cornerFraction: PulseWidgetDesign.sealCornerFraction,
                        ghostOpacity: 0.5
                    )
                    .transition(.opacity)
                }
            }
        }
    }

    private var stampTransition: AnyTransition {
        .asymmetric(insertion: .scale(scale: 1.16).combined(with: .opacity), removal: .opacity)
    }

    private var seed: UInt64 {
        PulseSealSeed.value(for: "reminder-\(day ?? 0)")
    }

    private var sealColor: Color {
        layout.surface == .island
            ? PulseWidgetDesign.activityIslandSeal
            : PulseWidgetDesign.activityLockScreenSeal
    }

    private var inkColor: Color {
        layout.surface == .island
            ? PulseWidgetDesign.activityIslandForeground
            : PulseWidgetDesign.ink
    }

    private var accessibilityTitle: String {
        guard let locale else { return "" }
        return PulseLocalization.string(
            phase == .completed
                ? "activity.reminder.completed.title"
                : "activity.reminder.title",
            table: PulseLocalization.systemUITable,
            locale: locale
        )
    }

    private var animatesIn: Bool {
        phase == .pending && animatesAppearance && !reduceMotion && !isLuminanceReduced
    }

    private var appearanceScale: CGFloat {
        animatesIn && !hasAppeared ? 0.86 : 1
    }

    private var appearanceOpacity: Double {
        animatesIn && !hasAppeared ? 0 : 1
    }

    private var completionAnimation: Animation? {
        reduceMotion || isLuminanceReduced
            ? nil
            : .spring(duration: PulseWidgetDesign.activityCompletionAnimationDuration, bounce: 0.22)
    }

    private func animateAppearanceIfNeeded() {
        guard animatesIn else {
            hasAppeared = true
            return
        }
        withAnimation(.easeOut(duration: PulseWidgetDesign.activityAppearanceAnimationDuration)) {
            hasAppeared = true
        }
    }
}

struct PulseReminderActivityHeadline: View {
    let phase: PulseReminderActivityPhase
    let locale: Locale
    let surface: PulseReminderActivitySurface

    var body: some View {
        Text(verbatim: PulseLocalization.string(
            titleKey,
            table: PulseLocalization.systemUITable,
            locale: locale
        ))
        .font(headlineFont)
        .foregroundStyle(foregroundColor)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .contentTransition(.opacity)
    }

    private var titleKey: String {
        phase == .pending
            ? "activity.reminder.title"
            : "activity.reminder.completed.title"
    }

    private var headlineFont: Font {
        surface == .island
            ? .system(.headline, weight: .semibold)
            : .system(.headline, weight: .bold)
    }

    private var foregroundColor: Color {
        surface == .island
            ? PulseWidgetDesign.activityIslandForeground
            : PulseWidgetDesign.ink
    }
}

enum PulseReminderActivityTimeFormatter {
    static func string(
        reminderDate: Date,
        timeZoneIdentifier: String,
        locale: Locale
    ) -> String? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }
        return reminderDate.formatted(Date.FormatStyle(
            date: .omitted,
            time: .shortened,
            locale: locale,
            timeZone: timeZone
        ))
    }
}

struct PulseReminderActivityTimeText: View {
    let reminderDate: Date
    let timeZoneIdentifier: String
    let locale: Locale
    let surface: PulseReminderActivitySurface

    var body: some View {
        Group {
            if let time = PulseReminderActivityTimeFormatter.string(
                reminderDate: reminderDate,
                timeZoneIdentifier: timeZoneIdentifier,
                locale: locale
            ) {
                Text(verbatim: time)
            } else {
                Text(verbatim: PulseLocalization.string(
                    "activity.reminder.time.unavailable",
                    table: PulseLocalization.systemUITable,
                    locale: locale
                ))
            }
        }
        .font(.caption.weight(.semibold).monospacedDigit())
        .foregroundStyle(foregroundColor)
        .lineLimit(1)
        .minimumScaleFactor(0.74)
    }

    private var foregroundColor: Color {
        surface == .island
            ? PulseWidgetDesign.activityIslandForeground.opacity(
                PulseWidgetDesign.activityIslandSecondaryOpacity
            )
            : PulseWidgetDesign.muted
    }
}

struct PulseReminderActivityActionButton: View {
    let locale: Locale
    let surface: PulseReminderActivitySurface

    var body: some View {
        Button(intent: PulseLiveActivityCheckInIntent()) {
            Text(verbatim: actionTitle)
                .font(.system(.subheadline, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .foregroundStyle(actionForeground)
                .padding(.horizontal, PulseWidgetDesign.activityActionHorizontalPadding)
                .frame(
                    minWidth: PulseWidgetDesign.activityActionMinimumWidth,
                    minHeight: visibleActionHeight
                )
                .background {
                    Capsule()
                        .fill(actionSurface)
                }
                .padding(.vertical, islandHitTargetInset)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: actionTitle))
    }

    private var actionTitle: String {
        PulseLocalization.string(
            "activity.reminder.check_in",
            table: PulseLocalization.systemUITable,
            locale: locale
        )
    }

    private var visibleActionHeight: CGFloat {
        surface == .island
            ? PulseWidgetDesign.activityIslandActionVisibleHeight
            : PulseWidgetDesign.activityActionMinimumHeight
    }

    private var islandHitTargetInset: CGFloat {
        surface == .island
            ? (PulseWidgetDesign.activityActionMinimumHeight - visibleActionHeight) / 2
            : 0
    }

    private var actionSurface: Color {
        surface == .island
            ? PulseWidgetDesign.activityIslandSeal
            : PulseWidgetDesign.seal
    }

    private var actionForeground: Color {
        surface == .island
            ? PulseWidgetDesign.activityIslandForeground
            : PulseWidgetDesign.onSeal
    }
}

struct PulseReminderActivityStatusCopy: View {
    let phase: PulseReminderActivityPhase
    let reminderDate: Date
    let timeZoneIdentifier: String
    let locale: Locale
    let surface: PulseReminderActivitySurface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        VStack(alignment: .leading, spacing: copySpacing) {
            PulseReminderActivityHeadline(
                phase: phase,
                locale: locale,
                surface: surface
            )
            if phase == .pending {
                PulseReminderActivityTimeText(
                    reminderDate: reminderDate,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: locale,
                    surface: surface
                )
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(copyAnimation, value: phase)
        .accessibilityElement(children: .combine)
    }

    private var copySpacing: CGFloat {
        surface == .island
            ? PulseWidgetDesign.activityIslandCenterSpacing
            : PulseWidgetDesign.activityLockScreenCopySpacing
    }

    private var copyAnimation: Animation? {
        reduceMotion || isLuminanceReduced
            ? nil
            : .easeInOut(duration: PulseWidgetDesign.activityCopyTransitionDuration)
    }
}

struct PulseReminderLockScreenView: View {
    let phase: PulseReminderActivityPhase
    let reminderDate: Date
    let timeZoneIdentifier: String
    let locale: Locale
    var animatesAppearance = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                regularLayout
            }
        }
        .padding(PulseWidgetDesign.activityLockScreenInset)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .animation(copyAnimation, value: phase)
        .accessibilityElement(children: .contain)
    }

    private var regularLayout: some View {
        HStack(alignment: .center, spacing: PulseWidgetDesign.activityLockScreenItemSpacing) {
            mark
            statusCopy

            if phase == .pending {
                PulseReminderActivityActionButton(
                    locale: locale,
                    surface: .lockScreen
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: PulseWidgetDesign.activityLockScreenStackSpacing) {
            HStack(alignment: .center, spacing: PulseWidgetDesign.activityLockScreenItemSpacing) {
                mark
                statusCopy
            }

            if phase == .pending {
                PulseReminderActivityActionButton(locale: locale, surface: .lockScreen)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    private var statusCopy: some View {
        PulseReminderActivityStatusCopy(
            phase: phase,
            reminderDate: reminderDate,
            timeZoneIdentifier: timeZoneIdentifier,
            locale: locale,
            surface: .lockScreen
        )
    }

    private var mark: some View {
        PulseReminderActivityMark(
            phase: phase,
            layout: .lockScreen,
            day: PulseReminderActivityDay.number(
                reminderDate: reminderDate,
                timeZoneIdentifier: timeZoneIdentifier
            ),
            locale: locale,
            animatesAppearance: animatesAppearance
        )
    }

    private var copyAnimation: Animation? {
        reduceMotion || isLuminanceReduced
            ? nil
            : .easeInOut(duration: PulseWidgetDesign.activityCopyTransitionDuration)
    }
}

struct PulseReminderActivityPreview: View {
    let phase: PulseReminderActivityPhase
    let reminderDate: Date
    let timeZoneIdentifier: String
    let locale: Locale

    var body: some View {
        HStack(alignment: .center, spacing: PulseWidgetDesign.activityPreviewItemSpacing) {
            PulseReminderActivityMark(
                phase: phase,
                layout: .islandExpanded,
                day: PulseReminderActivityDay.number(
                    reminderDate: reminderDate,
                    timeZoneIdentifier: timeZoneIdentifier
                )
            )

            PulseReminderActivityStatusCopy(
                phase: phase,
                reminderDate: reminderDate,
                timeZoneIdentifier: timeZoneIdentifier,
                locale: locale,
                surface: .island
            )

            if phase == .pending {
                PulseReminderActivityActionButton(locale: locale, surface: .island)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PulseWidgetDesign.activityPreviewHorizontalInset)
        .padding(.vertical, PulseWidgetDesign.activityPreviewVerticalInset)
        .background(
            PulseWidgetDesign.activityIslandBackground,
            in: RoundedRectangle(
                cornerRadius: PulseWidgetDesign.activityPreviewCornerRadius,
                style: .continuous
            )
        )
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
