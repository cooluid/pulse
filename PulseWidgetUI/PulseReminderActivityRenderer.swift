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

    var drawsHalo: Bool {
        self == .lockScreen
    }
}

struct PulseReminderActivityMarkGeometry {
    static let arcStartFraction = 0.08
    static let arcEndFraction = 0.78
    static let arcRotationDegrees = -84.0

    static let islandFireflyDiameterRatio: CGFloat = 0.48
    static let islandFireflyDiameterMinimum: CGFloat = 11
    static let islandCompletedCoreRatio: CGFloat = 0.68
    static let islandFireflyGlowDiameterRatio: CGFloat = 1.0
    static let islandFireflyGlowMinimumDiameter: CGFloat = 16

    static let haloLineWidthRatio: CGFloat = 0.10
    static let haloLineWidthMinimum: CGFloat = 2.4
    static let haloFireflyDiameterRatio: CGFloat = 0.18
    static let haloFireflyDiameterMinimum: CGFloat = 5.5
    static let haloFireflyOutlineRatio: CGFloat = 0.18
    static let haloFireflyOutlineMinimum: CGFloat = 0.9
    static let haloCompletedCoreRatio: CGFloat = 0.22

    struct Metrics {
        let glyphSize: CGFloat
        let lineWidth: CGFloat
        let ringDiameter: CGFloat
        let fireflyDiameter: CGFloat
        let fireflyOutlineWidth: CGFloat
        let fireflyGlowDiameter: CGFloat
        let completedCoreDiameter: CGFloat
    }

    static func metrics(layout: PulseReminderActivityMarkLayout) -> Metrics {
        let glyphSize = layout.size
        if layout.drawsHalo {
            return haloMetrics(glyphSize: glyphSize)
        }
        return islandMetrics(glyphSize: glyphSize)
    }

    private static func islandMetrics(glyphSize: CGFloat) -> Metrics {
        let fireflyDiameter = max(
            islandFireflyDiameterMinimum,
            glyphSize * islandFireflyDiameterRatio
        )
        let completedCoreDiameter = glyphSize * islandCompletedCoreRatio
        let fireflyGlowDiameter = min(
            glyphSize,
            max(
                islandFireflyGlowMinimumDiameter,
                glyphSize * islandFireflyGlowDiameterRatio
            )
        )
        return Metrics(
            glyphSize: glyphSize,
            lineWidth: 0,
            ringDiameter: 0,
            fireflyDiameter: fireflyDiameter,
            fireflyOutlineWidth: 0,
            fireflyGlowDiameter: fireflyGlowDiameter,
            completedCoreDiameter: completedCoreDiameter
        )
    }

    private static func haloMetrics(glyphSize: CGFloat) -> Metrics {
        let lineWidth = max(haloLineWidthMinimum, glyphSize * haloLineWidthRatio)
        let fireflyDiameter = max(
            haloFireflyDiameterMinimum,
            glyphSize * haloFireflyDiameterRatio
        )
        let fireflyOutlineWidth = max(
            haloFireflyOutlineMinimum,
            lineWidth * haloFireflyOutlineRatio
        )
        let ringDiameter = glyphSize - max(
            lineWidth,
            fireflyDiameter + fireflyOutlineWidth
        )
        return Metrics(
            glyphSize: glyphSize,
            lineWidth: lineWidth,
            ringDiameter: ringDiameter,
            fireflyDiameter: fireflyDiameter,
            fireflyOutlineWidth: fireflyOutlineWidth,
            fireflyGlowDiameter: fireflyDiameter,
            completedCoreDiameter: ringDiameter * haloCompletedCoreRatio
        )
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
    var locale: Locale? = nil

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var metrics: PulseReminderActivityMarkGeometry.Metrics {
        PulseReminderActivityMarkGeometry.metrics(layout: layout)
    }

    var body: some View {
        ZStack {
            if layout.drawsHalo {
                haloMark
            } else {
                islandMark
            }
        }
        .frame(width: metrics.glyphSize, height: metrics.glyphSize)
        .frame(width: layout.size, height: layout.size)
        .contentTransition(.opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(locale == nil)
        .accessibilityLabel(Text(verbatim: accessibilityTitle))
    }

    private var accessibilityTitle: String {
        guard let locale else {
            return ""
        }
        return PulseLocalization.string(
            phase == .completed
                ? "activity.reminder.completed.title"
                : "activity.reminder.title",
            table: PulseLocalization.systemUITable,
            locale: locale
        )
    }

    @ViewBuilder
    private var islandMark: some View {
        if phase == .completed {
            Circle()
                .fill(fireflyColor)
                .frame(
                    width: metrics.completedCoreDiameter,
                    height: metrics.completedCoreDiameter
                )
        } else {
            firefly(offset: .zero)
        }
    }

    @ViewBuilder
    private var haloMark: some View {
        if phase == .completed {
            Circle()
                .stroke(ringColor, lineWidth: metrics.lineWidth)
                .frame(width: metrics.ringDiameter, height: metrics.ringDiameter)
            Circle()
                .fill(ringColor)
                .frame(
                    width: metrics.completedCoreDiameter,
                    height: metrics.completedCoreDiameter
                )
        } else {
            Circle()
                .trim(
                    from: PulseReminderActivityMarkGeometry.arcStartFraction,
                    to: PulseReminderActivityMarkGeometry.arcEndFraction
                )
                .stroke(
                    ringColor,
                    style: StrokeStyle(
                        lineWidth: metrics.lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(
                    .degrees(PulseReminderActivityMarkGeometry.arcRotationDegrees)
                )
                .frame(width: metrics.ringDiameter, height: metrics.ringDiameter)
            firefly(offset: haloFireflyOffset)
        }
    }

    private func firefly(offset: CGSize) -> some View {
        ZStack {
            if shouldGlow {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                fireflyColor.opacity(
                                    PulseWidgetDesign.activityIslandFireflyGlowCoreOpacity
                                ),
                                fireflyColor.opacity(
                                    PulseWidgetDesign.activityIslandFireflyGlowMiddleOpacity
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
                    if metrics.fireflyOutlineWidth > 0 {
                        Circle()
                            .stroke(
                                fireflyOutlineColor,
                                lineWidth: metrics.fireflyOutlineWidth
                            )
                    }
                }
                .frame(width: metrics.fireflyDiameter, height: metrics.fireflyDiameter)
        }
        .frame(
            width: max(metrics.fireflyGlowDiameter, metrics.fireflyDiameter),
            height: max(metrics.fireflyGlowDiameter, metrics.fireflyDiameter)
        )
        .offset(x: offset.width, y: offset.height)
    }

    private var haloFireflyOffset: CGSize {
        PulseReminderActivityMarkGeometry.fireflyOffset(
            ringDiameter: metrics.ringDiameter
        )
    }

    private var ringColor: Color {
        PulseWidgetDesign.activityMark
    }

    private var fireflyOutlineColor: Color {
        layout.drawsHalo
            ? PulseWidgetDesign.activityLockScreenBackground
            : fireflyColor
    }

    private var fireflyColor: Color {
        layout.drawsHalo
            ? PulseWidgetDesign.activityLockScreenFirefly
            : PulseWidgetDesign.activityIslandFirefly
    }

    private var shouldGlow: Bool {
        layout.surface == .island && phase == .pending && !isLuminanceReduced
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
            : PulseWidgetDesign.activityMark
    }
}

struct PulseReminderActivityActionButton: View {
    let locale: Locale
    let surface: PulseReminderActivitySurface

    var body: some View {
        Button(intent: PulseCheckInIntent()) {
            Text(verbatim: actionTitle)
            .font(.system(.subheadline, weight: actionWeight))
            .lineLimit(1)
            .minimumScaleFactor(0.76)
            .foregroundStyle(actionForeground)
            .padding(.horizontal, PulseWidgetDesign.activityActionHorizontalPadding)
            .frame(
                minWidth: PulseWidgetDesign.activityActionMinimumWidth,
                minHeight: PulseWidgetDesign.activityActionMinimumHeight
            )
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

    private var actionWeight: Font.Weight {
        surface == .island ? .semibold : .black
    }

    private var actionSurface: Color {
        surface == .island
            ? PulseWidgetDesign.activityIslandForeground.opacity(
                PulseWidgetDesign.activityIslandActionFillOpacity
            )
            : PulseWidgetDesign.action
    }

    private var actionForeground: Color {
        surface == .island
            ? PulseWidgetDesign.activityIslandForeground
            : PulseWidgetDesign.actionForeground
    }
}

struct PulseReminderActivityStatusCopy: View {
    let phase: PulseReminderActivityPhase
    let reminderDate: Date
    let timeZoneIdentifier: String
    let locale: Locale
    let surface: PulseReminderActivitySurface

    var body: some View {
        VStack(alignment: .leading, spacing: copySpacing) {
            PulseReminderActivityHeadline(
                phase: phase,
                locale: locale,
                surface: surface
            )
            PulseReminderActivityTimeText(
                reminderDate: reminderDate,
                timeZoneIdentifier: timeZoneIdentifier,
                locale: locale,
                surface: surface
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var copySpacing: CGFloat {
        surface == .island
            ? PulseWidgetDesign.activityIslandCenterSpacing
            : PulseWidgetDesign.activityLockScreenCopySpacing
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
        HStack(alignment: .center, spacing: PulseWidgetDesign.activityLockScreenItemSpacing) {
            mark
            statusCopy

            if phase == .pending {
                PulseReminderActivityActionButton(
                    locale: locale,
                    surface: .lockScreen
                )
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
            locale: locale
        )
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
                layout: .islandExpanded
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
