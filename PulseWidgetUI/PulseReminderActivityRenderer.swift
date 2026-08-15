import AppIntents
import Foundation
import PulseCore
import SwiftUI

enum PulseReminderActivitySurface {
    case island
    case lockScreen
}

struct PulseReminderActivityMarkGeometry {
    static let arcStartFraction = 0.08
    static let arcEndFraction = 0.78
    static let arcRotationDegrees = -84.0

    static func fireflyOffset(ringDiameter: CGFloat) -> CGSize {
        let angle = (arcRotationDegrees + arcStartFraction * 360) * .pi / 180
        let radius = ringDiameter / 2
        return CGSize(
            width: cos(angle) * radius,
            height: sin(angle) * radius
        )
    }
}

struct PulseReminderActivityMark: View {
    let phase: PulseReminderActivityPhase
    let size: CGFloat
    let surface: PulseReminderActivitySurface

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        ZStack {
            if phase == .completed {
                completedRing
                Circle()
                    .fill(ringColor)
                    .frame(width: glyphSize * 0.28, height: glyphSize * 0.28)
            } else {
                pendingRing
                firefly
            }
        }
        .frame(width: glyphSize, height: glyphSize)
        .frame(width: size, height: size)
        .contentTransition(.opacity)
    }

    private var pendingRing: some View {
        Circle()
            .trim(
                from: PulseReminderActivityMarkGeometry.arcStartFraction,
                to: PulseReminderActivityMarkGeometry.arcEndFraction
            )
            .stroke(
                ringColor,
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round
                )
            )
            .rotationEffect(.degrees(PulseReminderActivityMarkGeometry.arcRotationDegrees))
            .frame(width: ringDiameter, height: ringDiameter)
    }

    private var completedRing: some View {
        Circle()
            .stroke(ringColor, lineWidth: lineWidth)
            .frame(width: ringDiameter, height: ringDiameter)
    }

    private var firefly: some View {
        Circle()
            .fill(PulseWidgetDesign.activityFirefly)
            .overlay {
                Circle()
                    .stroke(fireflyOutlineColor, lineWidth: max(1, lineWidth * 0.20))
            }
            .frame(width: fireflyDiameter, height: fireflyDiameter)
            .offset(x: fireflyOffset.width, y: fireflyOffset.height)
            .shadow(
                color: shouldGlow
                    ? PulseWidgetDesign.activityFirefly.opacity(0.72)
                    : .clear,
                radius: shouldGlow ? max(2, size * 0.11) : 0
            )
    }

    private var fireflyOffset: CGSize {
        PulseReminderActivityMarkGeometry.fireflyOffset(ringDiameter: ringDiameter)
    }

    private var glyphSize: CGFloat {
        surface == .island ? size * 0.82 : size
    }

    private var lineWidth: CGFloat {
        max(surface == .island ? 1.8 : 2.4, glyphSize * 0.11)
    }

    private var ringDiameter: CGFloat {
        glyphSize - lineWidth
    }

    private var fireflyDiameter: CGFloat {
        max(5.5, glyphSize * 0.18)
    }

    private var ringColor: Color {
        surface == .island
            ? PulseWidgetDesign.grass
            : PulseWidgetDesign.activityMark
    }

    private var fireflyOutlineColor: Color {
        surface == .island
            ? PulseWidgetDesign.activityIslandBackground
            : PulseWidgetDesign.background
    }

    private var shouldGlow: Bool {
        surface == .island && !isLuminanceReduced
    }
}

struct PulseReminderActivityHeadline: View {
    let phase: PulseReminderActivityPhase
    let locale: Locale
    let surface: PulseReminderActivitySurface

    var body: some View {
        Text(LocalizedStringResource(
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

    private var titleKey: String.LocalizationValue {
        phase == .pending
            ? "activity.reminder.title"
            : "activity.reminder.completed.title"
    }

    private var headlineFont: Font {
        surface == .island
            ? .headline.weight(.black)
            : .headline.weight(.bold)
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
                Text(LocalizedStringResource(
                    "activity.reminder.time.unavailable",
                    table: PulseLocalization.systemUITable,
                    locale: locale
                ))
            }
        }
        .font(.caption.weight(.bold).monospacedDigit())
        .foregroundStyle(foregroundColor)
        .lineLimit(1)
        .minimumScaleFactor(0.74)
    }

    private var foregroundColor: Color {
        surface == .island
            ? PulseWidgetDesign.activityFirefly
            : PulseWidgetDesign.activityMark
    }
}

struct PulseReminderActivityCompactTrailing: View {
    let phase: PulseReminderActivityPhase
    let reminderDate: Date
    let timeZoneIdentifier: String
    let locale: Locale

    var body: some View {
        Group {
            if phase == .pending {
                PulseReminderActivityTimeText(
                    reminderDate: reminderDate,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: locale,
                    surface: .island
                )
            } else {
                Text(LocalizedStringResource(
                    "activity.reminder.completed.compact",
                    table: PulseLocalization.systemUITable,
                    locale: locale
                ))
                .font(.caption2.weight(.heavy))
                .foregroundStyle(PulseWidgetDesign.grass)
            }
        }
        .contentTransition(.opacity)
    }
}

struct PulseReminderActivityActionButton: View {
    let locale: Locale
    let surface: PulseReminderActivitySurface

    var body: some View {
        Button(intent: PulseCheckInIntent()) {
            Text(LocalizedStringResource(
                "activity.reminder.check_in",
                table: PulseLocalization.systemUITable,
                locale: locale
            ))
            .font(.subheadline.weight(.black))
            .lineLimit(1)
            .minimumScaleFactor(0.76)
            .foregroundStyle(actionForeground)
            .padding(.horizontal, 15)
            .frame(minWidth: 72, minHeight: 44)
            .background {
                Capsule()
                    .fill(actionSurface)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            LocalizedStringResource(
                "activity.reminder.check_in",
                table: PulseLocalization.systemUITable,
                locale: locale
            )
        )
    }

    private var actionSurface: Color {
        surface == .island
            ? PulseWidgetDesign.activityActionSurface
            : PulseWidgetDesign.action
    }

    private var actionForeground: Color {
        surface == .island
            ? PulseWidgetDesign.activityActionForeground
            : PulseWidgetDesign.actionForeground
    }
}

struct PulseReminderDynamicIslandBottomView: View {
    let phase: PulseReminderActivityPhase
    let locale: Locale

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        Group {
            if phase == .pending {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        bodyText
                        Spacer(minLength: 8)
                        PulseReminderActivityActionButton(locale: locale, surface: .island)
                    }

                    HStack {
                        Spacer(minLength: 0)
                        PulseReminderActivityActionButton(locale: locale, surface: .island)
                        Spacer(minLength: 0)
                    }
                }
            } else {
                HStack {
                    bodyText
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: PulseWidgetDesign.activityExpandedBottomHeight)
        .padding(.horizontal, PulseWidgetDesign.activityHorizontalInset)
        .animation(completionAnimation, value: phase)
        .accessibilityElement(children: .contain)
    }

    private var bodyText: some View {
        Text(LocalizedStringResource(
            phase == .completed
                ? "activity.reminder.completed.body"
                : "activity.reminder.body",
            table: PulseLocalization.systemUITable,
            locale: locale
        ))
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(PulseWidgetDesign.activityIslandForeground.opacity(0.76))
        .lineLimit(1)
        .minimumScaleFactor(0.76)
    }

    private var completionAnimation: Animation? {
        guard !reduceMotion, !isLuminanceReduced else { return nil }
        return .easeInOut(duration: PulseWidgetDesign.activityCompletionAnimationDuration)
    }
}

struct PulseReminderLockScreenView: View {
    let phase: PulseReminderActivityPhase
    let reminderDate: Date
    let timeZoneIdentifier: String
    let locale: Locale

    var body: some View {
        ViewThatFits(in: .horizontal) {
            regularLayout
            accessibilityLayout
        }
        .padding(PulseWidgetDesign.activityLockScreenInset)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .accessibilityElement(children: .contain)
    }

    private var regularLayout: some View {
        HStack(spacing: 14) {
            mark

            VStack(alignment: .leading, spacing: 8) {
                headlineRow

                HStack(spacing: 10) {
                    bodyText
                    Spacer(minLength: 4)
                    if phase == .pending {
                        PulseReminderActivityActionButton(
                            locale: locale,
                            surface: .lockScreen
                        )
                    }
                }
            }
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                mark
                VStack(alignment: .leading, spacing: 4) {
                    PulseReminderActivityHeadline(
                        phase: phase,
                        locale: locale,
                        surface: .lockScreen
                    )
                    timeText
                }
            }

            if phase == .pending {
                PulseReminderActivityActionButton(locale: locale, surface: .lockScreen)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var headlineRow: some View {
        HStack(spacing: 8) {
            PulseReminderActivityHeadline(
                phase: phase,
                locale: locale,
                surface: .lockScreen
            )

            Spacer(minLength: 4)

            timeText
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    PulseWidgetDesign.activityMark.opacity(0.12),
                    in: Capsule()
                )
        }
    }

    private var timeText: some View {
        PulseReminderActivityTimeText(
            reminderDate: reminderDate,
            timeZoneIdentifier: timeZoneIdentifier,
            locale: locale,
            surface: .lockScreen
        )
    }

    private var mark: some View {
        PulseReminderActivityMark(
            phase: phase,
            size: 54,
            surface: .lockScreen
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            LocalizedStringResource(
                phase == .completed
                    ? "activity.reminder.completed.title"
                    : "activity.reminder.title",
                table: PulseLocalization.systemUITable,
                locale: locale
            )
        )
    }

    private var bodyText: some View {
        Text(LocalizedStringResource(
            phase == .completed
                ? "activity.reminder.completed.body"
                : "activity.reminder.body",
            table: PulseLocalization.systemUITable,
            locale: locale
        ))
        .font(.subheadline.weight(.medium))
        .foregroundStyle(PulseWidgetDesign.secondary)
        .lineLimit(2)
        .minimumScaleFactor(0.80)
    }

}

struct PulseReminderActivityPreview: View {
    let phase: PulseReminderActivityPhase
    let reminderDate: Date
    let timeZoneIdentifier: String
    let locale: Locale

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                PulseReminderActivityMark(
                    phase: phase,
                    size: 32,
                    surface: .island
                )
                .accessibilityHidden(true)

                PulseReminderActivityHeadline(
                    phase: phase,
                    locale: locale,
                    surface: .island
                )

                Spacer(minLength: 6)

                PulseReminderActivityTimeText(
                    reminderDate: reminderDate,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: locale,
                    surface: .island
                )
            }

            PulseReminderDynamicIslandBottomView(
                phase: phase,
                locale: locale
            )
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
    }
}
