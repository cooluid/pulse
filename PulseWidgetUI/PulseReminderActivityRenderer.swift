import AppIntents
import Foundation
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

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        Group {
            switch style {
            case .dayRing:
                fireflyMark
            case .imprintPress:
                gravityMark
            case .splitField:
                pulseMark
            }
        }
        .frame(width: glyphSize, height: glyphSize)
        .shadow(
            color: shouldGlow ? accentColor.opacity(0.48) : .clear,
            radius: shouldGlow ? islandGlowRadius : 0
        )
        .frame(width: size, height: size)
        .contentTransition(.opacity)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var fireflyMark: some View {
        if surface == .island {
            ZStack {
                Circle()
                    .strokeBorder(primaryColor, lineWidth: markLineWidth)

                fireflyState
            }
        } else {
            ZStack {
                lockScreenFireflyRing

                fireflyState
            }
        }
    }

    @ViewBuilder
    private var fireflyState: some View {
        if phase == .pending {
            Circle()
                .fill(PulseWidgetDesign.activityPrimary)
                .frame(width: glyphSize * 0.22, height: glyphSize * 0.22)
                .offset(x: fireflyOffsetX, y: fireflyOffsetY)
                .shadow(
                    color: shouldGlow
                        ? PulseWidgetDesign.activityPrimary.opacity(0.84)
                        : .clear,
                    radius: shouldGlow ? islandFireflyGlowRadius : 0
                )
        } else {
            if surface == .island {
                Circle()
                    .fill(primaryColor)
                    .frame(width: glyphSize * 0.32, height: glyphSize * 0.32)
            } else {
                Circle()
                    .fill(primaryColor)
                    .padding(size * 0.33)
            }
        }
    }

    private var gravityMark: some View {
        ZStack {
            gravityOutline

            RoundedRectangle(cornerRadius: glyphSize * 0.08, style: .continuous)
                .fill(phase == .completed ? primaryColor : primaryColor.opacity(0.28))
                .frame(
                    width: glyphSize * 0.52,
                    height: phase == .completed ? glyphSize * 0.52 : glyphSize * 0.16
                )
        }
    }

    private var pulseMark: some View {
        PulseActivityPulseWave(amplitude: phase == .completed ? 0.52 : 1)
            .stroke(
                primaryColor,
                style: StrokeStyle(
                    lineWidth: markLineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .padding(pulseInset)
    }

    private var primaryColor: Color {
        PulseWidgetDesign.grass
    }

    private var accentColor: Color {
        style == .dayRing
            ? PulseWidgetDesign.activityPrimary
            : PulseWidgetDesign.grass
    }

    private var shouldGlow: Bool {
        surface == .island && !isLuminanceReduced
    }

    private var glyphSize: CGFloat {
        surface == .island ? size * 0.78 : size
    }

    private var markLineWidth: CGFloat {
        if surface == .island {
            return max(1.6, glyphSize * 0.12)
        }

        switch style {
        case .dayRing:
            return max(2, size * 0.11)
        case .imprintPress:
            return max(2, size * 0.09)
        case .splitField:
            return max(2, size * 0.10)
        }
    }

    private var islandGlowRadius: CGFloat {
        max(1.1, size * 0.07)
    }

    private var islandFireflyGlowRadius: CGFloat {
        max(1.5, size * 0.09)
    }

    private var fireflyOffsetX: CGFloat {
        surface == .island ? glyphSize * 0.28 : size * 0.34
    }

    private var fireflyOffsetY: CGFloat {
        surface == .island ? -glyphSize * 0.28 : -size * 0.18
    }

    private var pulseInset: CGFloat {
        surface == .island ? glyphSize * 0.12 : size * 0.08
    }

    private var lockScreenFireflyRing: some View {
        Circle()
            .trim(from: 0.08, to: phase == .completed ? 0.99 : 0.78)
            .stroke(
                primaryColor,
                style: StrokeStyle(
                    lineWidth: markLineWidth,
                    lineCap: .round
                )
            )
            .rotationEffect(.degrees(-84))
    }

    @ViewBuilder
    private var gravityOutline: some View {
        if surface == .island {
            RoundedRectangle(cornerRadius: glyphSize * 0.18, style: .continuous)
                .strokeBorder(primaryColor, lineWidth: markLineWidth)
        } else {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .stroke(primaryColor, lineWidth: markLineWidth)
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
        .font(headlineFont)
        .foregroundStyle(primaryColor)
        .lineLimit(1)
        .minimumScaleFactor(0.70)
        .contentTransition(.opacity)
    }

    private var titleKey: String.LocalizationValue {
        phase == .pending
            ? "activity.reminder.title"
            : "activity.reminder.completed.title"
    }

    private var headlineFont: Font {
        switch surface {
        case .island:
            .headline.weight(.black)
        case .lockScreen:
            .headline.weight(.bold)
        }
    }

    private var primaryColor: Color {
        surface == .island
            ? PulseWidgetDesign.activityPrimary
            : PulseWidgetDesign.ink
    }
}

struct PulseReminderActivityActionButton: View {
    let style: PulseReminderActivityStyle
    let locale: Locale

    var body: some View {
        Button(intent: PulseCheckInIntent()) {
            Text(LocalizedStringResource(
                "activity.reminder.check_in",
                table: PulseLocalization.systemUITable,
                locale: locale
            ))
            .font(.subheadline.weight(.black))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(PulseWidgetDesign.activityActionForeground)
            .padding(.horizontal, 14)
            .frame(minWidth: 64, minHeight: 44)
            .background { actionChrome }
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

    @ViewBuilder
    private var actionChrome: some View {
        switch style {
        case .dayRing:
            Capsule()
                .fill(PulseWidgetDesign.activitySoftWhite)
                .shadow(
                    color: PulseWidgetDesign.activityFirefly.opacity(0.26),
                    radius: 5,
                    y: 1
                )

        case .imprintPress:
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PulseWidgetDesign.activityPressShadow)
                    .offset(y: 3)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PulseWidgetDesign.grass)
            }

        case .splitField:
            Capsule()
                .fill(PulseWidgetDesign.activityPulseLight)
        }
    }
}

struct PulseReminderDynamicIslandExpandedView: View {
    let style: PulseReminderActivityStyle
    let phase: PulseReminderActivityPhase
    let locale: Locale

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        Group {
            switch style {
            case .dayRing:
                fireflyHaloComposition
            case .imprintPress:
                gravitySealComposition
            case .splitField:
                livingPulseComposition
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: PulseWidgetDesign.activityHeroHeight)
        .animation(completionAnimation, value: phase)
        .accessibilityElement(children: .contain)
    }

    private var fireflyHaloComposition: some View {
        HStack(spacing: 12) {
            PulseFireflyHaloGraphic(
                phase: phase,
                glows: !isLuminanceReduced
            )
            .frame(width: 58, height: 58)

            PulseReminderActivityHeadline(
                phase: phase,
                locale: locale,
                surface: .island
            )

            Spacer(minLength: 6)

            trailingAction
        }
        .padding(.horizontal, PulseWidgetDesign.activityHeroHorizontalInset)
    }

    private var gravitySealComposition: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                PulseReminderActivityHeadline(
                    phase: phase,
                    locale: locale,
                    surface: .island
                )

                HStack(spacing: 4) {
                    Capsule()
                        .fill(PulseWidgetDesign.grass)
                        .frame(width: phase == .completed ? 68 : 42, height: 4)
                    Capsule()
                        .fill(PulseWidgetDesign.activitySoftWhite.opacity(0.32))
                        .frame(width: phase == .completed ? 18 : 44, height: 4)
                }
            }

            Spacer(minLength: 4)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(PulseWidgetDesign.grass.opacity(0.12))
                    .frame(width: 82, height: 62)

                trailingAction
            }
        }
        .padding(.leading, PulseWidgetDesign.activityHeroHorizontalInset + 2)
        .padding(.trailing, PulseWidgetDesign.activityHeroHorizontalInset - 2)
    }

    private var livingPulseComposition: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                PulseReminderActivityHeadline(
                    phase: phase,
                    locale: locale,
                    surface: .island
                )

                Spacer(minLength: 6)

                trailingAction
            }

            PulseActivityPulseWave(amplitude: phase == .completed ? 0.42 : 1)
                .stroke(
                    LinearGradient(
                        colors: [
                            PulseWidgetDesign.activityPulseLight.opacity(0.22),
                            PulseWidgetDesign.activityPulseLight,
                            PulseWidgetDesign.activitySoftWhite,
                            PulseWidgetDesign.activityPulseLight.opacity(0.22),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
                .frame(height: 20)
                .shadow(
                    color: isLuminanceReduced
                        ? .clear
                        : PulseWidgetDesign.activityPulseLight.opacity(0.34),
                    radius: 4
                )
                .accessibilityHidden(true)
        }
        .padding(.horizontal, PulseWidgetDesign.activityHeroHorizontalInset + 2)
    }

    @ViewBuilder
    private var trailingAction: some View {
        if phase == .pending {
            PulseReminderActivityActionButton(style: style, locale: locale)
        } else {
            PulseReminderActivityCompletionGlyph(style: style)
                .transition(.scale(scale: 0.72).combined(with: .opacity))
        }
    }

    private var completionAnimation: Animation? {
        guard !reduceMotion, !isLuminanceReduced else { return nil }
        return .easeInOut(duration: PulseWidgetDesign.activityCompletionAnimationDuration)
    }
}

struct PulseReminderActivityCompletionGlyph: View {
    let style: PulseReminderActivityStyle

    var body: some View {
        Group {
            switch style {
            case .dayRing:
                ZStack {
                    Circle()
                        .stroke(PulseWidgetDesign.activitySoftWhite, lineWidth: 2.5)
                    Circle()
                        .fill(PulseWidgetDesign.activityFirefly)
                        .padding(12)
                }

            case .imprintPress:
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PulseWidgetDesign.grass)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(PulseWidgetDesign.activityIslandBackground)
                        .padding(11)
                }

            case .splitField:
                ZStack {
                    Circle()
                        .fill(PulseWidgetDesign.activityPulseLight.opacity(0.18))
                    PulseActivityPulseWave(amplitude: 0.46)
                        .stroke(
                            PulseWidgetDesign.activityPulseLight,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )
                        .padding(8)
                }
            }
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}

struct PulseReminderLockScreenView: View {
    let style: PulseReminderActivityStyle
    let phase: PulseReminderActivityPhase
    let locale: Locale

    var body: some View {
        HStack(spacing: 12) {
            PulseReminderActivityMark(
                style: style,
                phase: phase,
                size: 42,
                surface: .lockScreen
            )

            VStack(alignment: .leading, spacing: 4) {
                PulseReminderActivityHeadline(
                    phase: phase,
                    locale: locale,
                    surface: .lockScreen
                )

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
            }

            Spacer(minLength: 8)

            if phase == .pending {
                PulseReminderActivityActionButton(style: style, locale: locale)
            } else {
                PulseReminderActivityCompletionGlyph(style: style)
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
        VStack(spacing: 0) {
            Color.clear
                .frame(height: PulseWidgetDesign.activityPreviewCameraClearance)

            PulseReminderDynamicIslandExpandedView(
                style: style,
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
    }
}

private struct PulseFireflyHaloGraphic: View {
    let phase: PulseReminderActivityPhase
    let glows: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(PulseWidgetDesign.activitySoftWhite.opacity(0.08), lineWidth: 1)
                .padding(2)

            Circle()
                .trim(from: 0.07, to: phase == .completed ? 0.99 : 0.76)
                .stroke(
                    AngularGradient(
                        colors: [
                            PulseWidgetDesign.grass.opacity(0.16),
                            PulseWidgetDesign.grass,
                            PulseWidgetDesign.activityFirefly,
                            PulseWidgetDesign.activitySoftWhite,
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-82))
                .padding(4)

            Circle()
                .fill(PulseWidgetDesign.grass.opacity(phase == .completed ? 0.18 : 0.07))
                .padding(15)

            if phase == .pending {
                ZStack {
                    Circle()
                        .fill(PulseWidgetDesign.activityPrimary.opacity(glows ? 0.24 : 0))
                        .frame(width: 22, height: 22)
                        .blur(radius: glows ? 5 : 0)

                    Circle()
                        .fill(PulseWidgetDesign.activityPrimary)
                        .frame(width: 8, height: 8)
                        .shadow(
                            color: glows
                                ? PulseWidgetDesign.activityPrimary.opacity(0.92)
                                : .clear,
                            radius: glows ? 6 : 0
                        )
                }
                .offset(x: 21, y: -12)
            } else {
                Circle()
                    .fill(PulseWidgetDesign.activityFirefly)
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PulseActivityPulseWave: Shape {
    var amplitude: CGFloat

    var animatableData: CGFloat {
        get { amplitude }
        set { amplitude = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let midY = rect.midY
        let unit = rect.width / 12
        let rise = rect.height * 0.42 * amplitude
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addLine(to: CGPoint(x: rect.minX + unit * 2.2, y: midY))
        path.addLine(to: CGPoint(x: rect.minX + unit * 3.0, y: midY - rise * 0.38))
        path.addLine(to: CGPoint(x: rect.minX + unit * 3.8, y: midY + rise * 0.44))
        path.addLine(to: CGPoint(x: rect.minX + unit * 5.0, y: midY - rise))
        path.addLine(to: CGPoint(x: rect.minX + unit * 6.2, y: midY + rise * 0.72))
        path.addLine(to: CGPoint(x: rect.minX + unit * 7.2, y: midY - rise * 0.24))
        path.addLine(to: CGPoint(x: rect.minX + unit * 8.0, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))

        return path
    }
}
