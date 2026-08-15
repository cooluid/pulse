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

    var usesCompactOpticalTreatment: Bool {
        switch self {
        case .islandCompact, .islandMinimal:
            true
        case .islandExpanded, .lockScreen:
            false
        }
    }
}

struct PulseReminderActivityMarkGeometry {
    static let arcStartFraction = 0.08
    static let regularArcEndFraction = 0.78
    static let compactArcEndFraction = 0.90
    static let arcRotationDegrees = -84.0

    struct Metrics {
        let glyphSize: CGFloat
        let lineWidth: CGFloat
        let ringDiameter: CGFloat
        let fireflyDiameter: CGFloat
        let fireflyOutlineWidth: CGFloat
        let fireflyGlowDiameter: CGFloat
        let ringGlowRadius: CGFloat
        let completedCoreDiameter: CGFloat
    }

    static func metrics(layout: PulseReminderActivityMarkLayout) -> Metrics {
        let glyphSize = layout.size
        let surface = layout.surface
        let lineWidth = max(
            surface == .island ? 1.6 : 2.4,
            glyphSize * 0.10
        )
        let fireflyScale = layout.usesCompactOpticalTreatment ? 0.16 : 0.18
        let fireflyDiameter = max(
            surface == .island ? 3.4 : 5.5,
            glyphSize * fireflyScale
        )
        let fireflyOutlineWidth = max(
            surface == .island ? 0.65 : 0.9,
            lineWidth * 0.18
        )
        let fireflyGlowDiameter: CGFloat
        if surface == .island {
            fireflyGlowDiameter = layout.usesCompactOpticalTreatment
                ? max(
                    PulseWidgetDesign.activityIslandCompactFireflyGlowMinimumDiameter,
                    glyphSize
                        * PulseWidgetDesign.activityIslandCompactFireflyGlowDiameterRatio
                )
                : max(
                    PulseWidgetDesign.activityIslandFireflyGlowMinimumDiameter,
                    glyphSize * PulseWidgetDesign.activityIslandFireflyGlowDiameterRatio
                )
        } else {
            fireflyGlowDiameter = fireflyDiameter
        }
        let fireflyGlowReservationDiameter = layout.usesCompactOpticalTreatment
            ? PulseWidgetDesign.activityIslandFireflyGlowMinimumDiameter
            : fireflyGlowDiameter
        let ringGlowRadius = layout.usesCompactOpticalTreatment
            ? glyphSize * PulseWidgetDesign.activityIslandRingGlowRadiusRatio
            : 0
        let ringDiameter = glyphSize - max(
            lineWidth,
            max(
                fireflyDiameter + fireflyOutlineWidth,
                fireflyGlowReservationDiameter
            )
        )

        return Metrics(
            glyphSize: glyphSize,
            lineWidth: lineWidth,
            ringDiameter: ringDiameter,
            fireflyDiameter: fireflyDiameter,
            fireflyOutlineWidth: fireflyOutlineWidth,
            fireflyGlowDiameter: fireflyGlowDiameter,
            ringGlowRadius: ringGlowRadius,
            completedCoreDiameter: ringDiameter * 0.22
        )
    }

    static func arcEndFraction(for layout: PulseReminderActivityMarkLayout) -> Double {
        layout.usesCompactOpticalTreatment
            ? compactArcEndFraction
            : regularArcEndFraction
    }

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
    let layout: PulseReminderActivityMarkLayout

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var metrics: PulseReminderActivityMarkGeometry.Metrics {
        PulseReminderActivityMarkGeometry.metrics(layout: layout)
    }

    var body: some View {
        ZStack {
            if phase == .completed {
                completedRing
                Circle()
                    .fill(ringColor)
                    .frame(
                        width: metrics.completedCoreDiameter,
                        height: metrics.completedCoreDiameter
                    )
            } else {
                pendingRing
                firefly
            }
        }
        .frame(width: metrics.glyphSize, height: metrics.glyphSize)
        .frame(width: layout.size, height: layout.size)
        .contentTransition(.opacity)
    }

    private var pendingRing: some View {
        Circle()
            .trim(
                from: PulseReminderActivityMarkGeometry.arcStartFraction,
                to: PulseReminderActivityMarkGeometry.arcEndFraction(for: layout)
            )
            .stroke(
                ringColor,
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round
                )
            )
            .rotationEffect(.degrees(PulseReminderActivityMarkGeometry.arcRotationDegrees))
            .frame(width: metrics.ringDiameter, height: metrics.ringDiameter)
            .shadow(
                color: ringGlowColor,
                radius: shouldGlowRing ? metrics.ringGlowRadius : 0
            )
    }

    private var completedRing: some View {
        Circle()
            .stroke(ringColor, lineWidth: metrics.lineWidth)
            .frame(width: metrics.ringDiameter, height: metrics.ringDiameter)
            .shadow(
                color: ringGlowColor,
                radius: shouldGlowRing ? metrics.ringGlowRadius : 0
            )
    }

    private var firefly: some View {
        ZStack {
            if shouldGlow {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                fireflyColor.opacity(
                                    fireflyGlowCoreOpacity
                                ),
                                fireflyColor.opacity(
                                    fireflyGlowMiddleOpacity
                                ),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: metrics.fireflyGlowDiameter / 2
                        )
                    )
                    .frame(
                        width: metrics.fireflyGlowDiameter,
                        height: metrics.fireflyGlowDiameter
                    )
            }

            Circle()
                .fill(fireflyColor)
                .overlay {
                    Circle()
                        .stroke(
                            fireflyOutlineColor,
                            lineWidth: metrics.fireflyOutlineWidth
                        )
                }
                .frame(width: metrics.fireflyDiameter, height: metrics.fireflyDiameter)
        }
        .frame(
            width: metrics.fireflyGlowDiameter,
            height: metrics.fireflyGlowDiameter
        )
        .offset(x: fireflyOffset.width, y: fireflyOffset.height)
    }

    private var fireflyOffset: CGSize {
        PulseReminderActivityMarkGeometry.fireflyOffset(
            ringDiameter: metrics.ringDiameter
        )
    }

    private var lineWidth: CGFloat {
        metrics.lineWidth
    }

    private var ringColor: Color {
        layout.surface == .island
            ? PulseWidgetDesign.grass
            : PulseWidgetDesign.activityMark
    }

    private var ringGlowColor: Color {
        ringColor.opacity(
            shouldGlowRing
                ? PulseWidgetDesign.activityIslandRingGlowOpacity
                : 0
        )
    }

    private var fireflyOutlineColor: Color {
        layout.surface == .island
            ? PulseWidgetDesign.activityIslandFirefly
            : PulseWidgetDesign.activityLockScreenBackground
    }

    private var fireflyColor: Color {
        layout.surface == .island
            ? PulseWidgetDesign.activityIslandFirefly
            : PulseWidgetDesign.activityLockScreenFirefly
    }

    private var fireflyGlowCoreOpacity: Double {
        layout.usesCompactOpticalTreatment
            ? PulseWidgetDesign.activityIslandCompactFireflyGlowCoreOpacity
            : PulseWidgetDesign.activityIslandFireflyGlowCoreOpacity
    }

    private var fireflyGlowMiddleOpacity: Double {
        layout.usesCompactOpticalTreatment
            ? PulseWidgetDesign.activityIslandCompactFireflyGlowMiddleOpacity
            : PulseWidgetDesign.activityIslandFireflyGlowMiddleOpacity
    }

    private var shouldGlow: Bool {
        layout.surface == .island && !isLuminanceReduced
    }

    private var shouldGlowRing: Bool {
        layout.usesCompactOpticalTreatment && !isLuminanceReduced
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
                Text(verbatim: PulseLocalization.string(
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
            ? PulseWidgetDesign.activityIslandTime
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
                Text(verbatim: PulseLocalization.string(
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
            Text(verbatim: actionTitle)
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
        .accessibilityLabel(Text(verbatim: actionTitle))
    }

    private var actionTitle: String {
        PulseLocalization.string(
            "activity.reminder.check_in",
            table: PulseLocalization.systemUITable,
            locale: locale
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
        HStack(spacing: 12) {
            PulseReminderActivityHeadline(
                phase: phase,
                locale: locale,
                surface: .island
            )

            Spacer(minLength: 8)

            if phase == .pending {
                PulseReminderActivityActionButton(locale: locale, surface: .island)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: PulseWidgetDesign.activityExpandedBottomHeight)
        .padding(.horizontal, PulseWidgetDesign.activityHorizontalInset)
        .animation(completionAnimation, value: phase)
        .accessibilityElement(children: .contain)
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

                if phase == .pending {
                    PulseReminderActivityActionButton(
                        locale: locale,
                        surface: .lockScreen
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
            layout: .lockScreen
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: PulseLocalization.string(
            phase == .completed
                ? "activity.reminder.completed.title"
                : "activity.reminder.title",
            table: PulseLocalization.systemUITable,
            locale: locale
        )))
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
                    layout: .islandExpanded
                )
                .accessibilityHidden(true)

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
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
