import AppIntents
import PulseCore
import SwiftUI

enum PulseReminderActivitySurface {
    case island
    case lockScreen
}

struct PulseReminderActivityMark: View {
    let style: PulseReminderActivityStyle
    let phase: PulseReminderActivityPhase
    let size: CGFloat
    let surface: PulseReminderActivitySurface

    var body: some View {
        ZStack {
            switch style {
            case .dayRing:
                dayRing
            case .imprintPress:
                imprintPress
            case .splitField:
                splitField
            }
        }
        .frame(width: size, height: size)
        .contentTransition(.opacity)
        .accessibilityHidden(true)
    }

    private var dayRing: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: phase == .completed ? 1 : PulseWidgetDesign.openRingTrim)
                .stroke(
                    markColor,
                    style: StrokeStyle(
                        lineWidth: max(
                            PulseWidgetDesign.activityMarkMinimumStrokeWidth,
                            size * PulseWidgetDesign.activityDayRingStrokeRatio
                        ),
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(PulseWidgetDesign.openRingRotationDegrees))
            if phase == .completed {
                Image(systemName: "checkmark")
                    .font(.system(
                        size: size * PulseWidgetDesign.activityDayRingCheckRatio,
                        weight: .black
                    ))
                    .foregroundStyle(markColor)
            } else {
                Circle()
                    .fill(markColor)
                    .frame(
                        width: size * PulseWidgetDesign.activityDayRingEndpointRatio,
                        height: size * PulseWidgetDesign.activityDayRingEndpointRatio
                    )
            }
        }
    }

    private var imprintPress: some View {
        RoundedRectangle(
            cornerRadius: size * PulseWidgetDesign.activityPressCornerRatio,
            style: .continuous
        )
            .stroke(
                markColor,
                lineWidth: max(
                    PulseWidgetDesign.activityMarkMinimumStrokeWidth,
                    size * PulseWidgetDesign.activityPressStrokeRatio
                )
            )
            .overlay {
                if phase == .completed {
                    RoundedRectangle(
                        cornerRadius: size * PulseWidgetDesign.activityPressInnerCornerRatio,
                        style: .continuous
                    )
                        .fill(markColor)
                        .padding(size * PulseWidgetDesign.activityPressInnerInsetRatio)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.system(
                                    size: size * PulseWidgetDesign.activityPressCheckRatio,
                                    weight: .black
                                ))
                                .foregroundStyle(markForegroundColor)
                        }
                } else {
                    Capsule()
                        .fill(markColor)
                        .frame(
                            width: size * PulseWidgetDesign.activityPressBarWidthRatio,
                            height: max(
                                PulseWidgetDesign.activityMarkMinimumStrokeWidth,
                                size * PulseWidgetDesign.activityPressBarHeightRatio
                            )
                        )
                }
            }
    }

    private var splitField: some View {
        ZStack {
            Capsule()
                .fill(markColor.opacity(PulseWidgetDesign.activitySplitMutedOpacity))
                .frame(
                    width: size * PulseWidgetDesign.activitySplitTraceWidthRatio,
                    height: size * PulseWidgetDesign.activitySplitMutedHeightRatio
                )
                .rotationEffect(.degrees(PulseWidgetDesign.activitySplitLeftRotation))
                .offset(x: size * PulseWidgetDesign.activitySplitLeftOffsetRatio)
            Capsule()
                .fill(markColor)
                .frame(
                    width: size * PulseWidgetDesign.activitySplitTraceWidthRatio,
                    height: size * (phase == .completed
                        ? PulseWidgetDesign.activitySplitCompletedHeightRatio
                        : PulseWidgetDesign.activitySplitPendingHeightRatio)
                )
                .rotationEffect(.degrees(PulseWidgetDesign.activitySplitRightRotation))
                .offset(x: size * PulseWidgetDesign.activitySplitRightOffsetRatio)
            Circle()
                .fill(phase == .completed
                    ? markColor
                    : markColor.opacity(PulseWidgetDesign.activitySplitStrongOpacity))
                .frame(
                    width: size * PulseWidgetDesign.activitySplitDotRatio,
                    height: size * PulseWidgetDesign.activitySplitDotRatio
                )
                .offset(y: size * PulseWidgetDesign.activitySplitDotOffsetRatio)
        }
    }

    private var markColor: Color { PulseWidgetDesign.grass }

    private var markForegroundColor: Color {
        switch surface {
        case .island:
            PulseWidgetDesign.activityIslandBackground
        case .lockScreen:
            PulseWidgetDesign.grassForeground
        }
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
            .font(.headline.weight(.bold))
            .foregroundStyle(primaryColor)
            .lineLimit(1)
            .contentTransition(.opacity)
    }

    private var titleKey: String.LocalizationValue {
        switch phase {
        case .pending:
            "activity.reminder.title"
        case .completed:
            "activity.reminder.completed.title"
        }
    }

    private var primaryColor: Color {
        switch surface {
        case .island:
            PulseWidgetDesign.activityPrimary
        case .lockScreen:
            PulseWidgetDesign.ink
        }
    }
}

struct PulseReminderActivityActionRow: View {
    let style: PulseReminderActivityStyle
    let phase: PulseReminderActivityPhase
    let locale: Locale
    let surface: PulseReminderActivitySurface

    @ViewBuilder
    var body: some View {
        switch style {
        case .dayRing:
            dayRingRow
        case .imprintPress:
            imprintColumn
        case .splitField:
            splitFieldRow
        }
    }

    private var dayRingRow: some View {
        HStack(spacing: PulseWidgetDesign.spacing8) {
            styleAccent
            message

            Spacer(minLength: PulseWidgetDesign.spacing8)

            action
        }
        .contentTransition(.opacity)
    }

    private var imprintColumn: some View {
        VStack(alignment: .leading, spacing: PulseWidgetDesign.spacing8) {
            message
            HStack(spacing: PulseWidgetDesign.spacing8) {
                styleAccent
                Spacer(minLength: PulseWidgetDesign.spacing8)
                action
            }
        }
        .contentTransition(.opacity)
    }

    private var splitFieldRow: some View {
        HStack(spacing: PulseWidgetDesign.activitySplitColumnSpacing) {
            message
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(secondaryColor.opacity(PulseWidgetDesign.activitySplitSeparatorOpacity))
                .frame(
                    width: PulseWidgetDesign.activitySplitSeparatorWidth,
                    height: PulseWidgetDesign.activitySplitSeparatorHeight
                )
                .accessibilityHidden(true)

            VStack(spacing: PulseWidgetDesign.spacing4) {
                styleAccent
                action
            }
        }
        .contentTransition(.opacity)
    }

    private var message: some View {
        Text(LocalizedStringResource(
            bodyKey,
            table: PulseLocalization.systemUITable,
            locale: locale
        ))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(secondaryColor)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var action: some View {
        switch phase {
        case .pending:
            Button(intent: PulseCheckInIntent()) {
                Text(LocalizedStringResource(
                    "activity.reminder.check_in",
                    table: PulseLocalization.systemUITable,
                    locale: locale
                ))
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .foregroundStyle(PulseWidgetDesign.activityActionForeground)
                    .padding(.horizontal, PulseWidgetDesign.activityActionHorizontalInset)
                    .frame(minHeight: PulseWidgetDesign.activityActionMinimumHeight)
                    .background(PulseWidgetDesign.grass, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                LocalizedStringResource(
                    "activity.reminder.check_in",
                    table: PulseLocalization.systemUITable,
                    locale: locale
                )
            )
        case .completed:
            Label {
                Text(LocalizedStringResource(
                    "activity.reminder.completed.compact",
                    table: PulseLocalization.systemUITable,
                    locale: locale
                ))
            } icon: {
                Image(systemName: "checkmark")
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(PulseWidgetDesign.grass)
        }
    }

    @ViewBuilder
    private var styleAccent: some View {
        switch style {
        case .dayRing:
            Capsule()
                .fill(PulseWidgetDesign.grass.opacity(PulseWidgetDesign.activityAccentOpacity))
                .frame(
                    width: PulseWidgetDesign.activityAccentLineWidth,
                    height: PulseWidgetDesign.activityAccentLineHeight
                )
        case .imprintPress:
            RoundedRectangle(
                cornerRadius: PulseWidgetDesign.activityAccentCornerRadius,
                style: .continuous
            )
                .fill(PulseWidgetDesign.grass.opacity(PulseWidgetDesign.activityAccentOpacity))
                .frame(
                    width: PulseWidgetDesign.activityAccentSquareSide,
                    height: PulseWidgetDesign.activityAccentSquareSide
                )
        case .splitField:
            HStack(spacing: PulseWidgetDesign.activityAccentSplitSpacing) {
                Capsule()
                    .frame(
                        width: PulseWidgetDesign.activityAccentSplitWidth,
                        height: PulseWidgetDesign.activityAccentSplitHeight
                    )
                    .rotationEffect(.degrees(-PulseWidgetDesign.activityAccentSplitRotation))
                Capsule()
                    .frame(
                        width: PulseWidgetDesign.activityAccentSplitWidth,
                        height: PulseWidgetDesign.activityAccentSplitHeight
                    )
                    .rotationEffect(.degrees(PulseWidgetDesign.activityAccentSplitRotation))
            }
            .foregroundStyle(
                PulseWidgetDesign.grass.opacity(PulseWidgetDesign.activityAccentOpacity)
            )
        }
    }

    private var bodyKey: String.LocalizationValue {
        switch phase {
        case .pending:
            "activity.reminder.body"
        case .completed:
            "activity.reminder.completed.body"
        }
    }

    private var secondaryColor: Color {
        switch surface {
        case .island:
            PulseWidgetDesign.activitySecondary
        case .lockScreen:
            PulseWidgetDesign.secondary
        }
    }
}

struct PulseReminderLockScreenView: View {
    let style: PulseReminderActivityStyle
    let phase: PulseReminderActivityPhase
    let locale: Locale

    var body: some View {
        HStack(spacing: PulseWidgetDesign.activityLockScreenSpacing) {
            PulseReminderActivityMark(
                style: style,
                phase: phase,
                size: PulseWidgetDesign.activityLockScreenMarkSize,
                surface: .lockScreen
            )

            VStack(alignment: .leading, spacing: PulseWidgetDesign.spacing8) {
                PulseReminderActivityHeadline(
                    phase: phase,
                    locale: locale,
                    surface: .lockScreen
                )
                PulseReminderActivityActionRow(
                    style: style,
                    phase: phase,
                    locale: locale,
                    surface: .lockScreen
                )
            }
        }
        .padding(PulseWidgetDesign.homeSafeInset)
        .accessibilityElement(children: .contain)
    }
}

struct PulseReminderActivityPreview: View {
    let style: PulseReminderActivityStyle
    let phase: PulseReminderActivityPhase
    let locale: Locale

    var body: some View {
        VStack(spacing: PulseWidgetDesign.activityPreviewSpacing) {
            HStack(spacing: PulseWidgetDesign.activityPreviewSpacing) {
                PulseReminderActivityMark(
                    style: style,
                    phase: phase,
                    size: PulseWidgetDesign.activityPreviewMarkSize,
                    surface: .island
                )
                PulseReminderActivityHeadline(
                    phase: phase,
                    locale: locale,
                    surface: .island
                )
                Spacer(minLength: 0)
            }
            PulseReminderActivityActionRow(
                style: style,
                phase: phase,
                locale: locale,
                surface: .island
            )
        }
        .padding(.horizontal, PulseWidgetDesign.activityPreviewHorizontalInset)
        .padding(.vertical, PulseWidgetDesign.activityPreviewVerticalInset)
        .background(
            PulseWidgetDesign.activityIslandBackground,
            in: RoundedRectangle(
                cornerRadius: PulseWidgetDesign.activityPreviewCornerRadius,
                style: .continuous
            )
        )
    }
}
