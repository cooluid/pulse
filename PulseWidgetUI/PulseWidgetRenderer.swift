import PulseCore
import SwiftUI
import WidgetKit

enum PulseWidgetStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case breathingOrbit
    case numberSilhouette
    case depthRhythm
    case quietOrder
    case rhythmBoard

    var id: String { rawValue }
}

enum PulseWidgetStyleAccessPolicy {
    static let freeStyle = PulseWidgetStyle.breathingOrbit

    static func requiresEnhancement(_ style: PulseWidgetStyle) -> Bool {
        style != freeStyle
    }

    static func isAvailable(
        _ style: PulseWidgetStyle,
        hasEnhancementEntitlement: Bool
    ) -> Bool {
        !requiresEnhancement(style) || hasEnhancementEntitlement
    }

    static func resolvedStyle(
        preferredStyle: PulseWidgetStyle,
        hasEnhancementEntitlement: Bool
    ) -> PulseWidgetStyle {
        isAvailable(
            preferredStyle,
            hasEnhancementEntitlement: hasEnhancementEntitlement
        ) ? preferredStyle : freeStyle
    }
}

struct PulseWidgetHomeRenderer: View {
    let snapshot: PulseWidgetSnapshot
    let style: PulseWidgetStyle
    let usesMediumMetrics: Bool
    let usesFullColorPalette: Bool
    let statusText: String
    let actionText: String

    @Environment(\.locale) private var locale

    var body: some View {
        GeometryReader { proxy in
            Group {
                switch style {
                case .breathingOrbit:
                    breathingOrbit(size: proxy.size)
                case .numberSilhouette:
                    numberSilhouette(size: proxy.size)
                case .depthRhythm:
                    depthRhythm(size: proxy.size)
                case .quietOrder:
                    quietOrder(size: proxy.size)
                case .rhythmBoard:
                    rhythmBoard(size: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    private func breathingOrbit(size: CGSize) -> some View {
        let inset = horizontalInset(in: size)
        let imprintSide = size.width * (usesMediumMetrics ? 0.19 : 0.25)

        return ZStack {
            baseBackground

            contourField(
                size: size,
                anchor: CGPoint(x: usesMediumMetrics ? 0.78 : 0.80, y: 0.57),
                widthRatio: usesMediumMetrics ? 0.56 : 0.94,
                heightRatio: 1.06
            )

            statusLabel(size: css(14, in: size))
                .padding(.leading, inset)
                .padding(.top, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(verbatim: monthAndDay)
                .font(.system(size: css(17, in: size), weight: .medium, design: .rounded))
                .foregroundStyle(actionColor)
                .monospacedDigit()
                .padding(.trailing, inset)
                .padding(.top, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            habitName(
                size: css(usesMediumMetrics ? 47 : 39, in: size),
                width: size.width * (usesMediumMetrics ? 0.60 : 0.70),
                alignment: .leading
            )
            .padding(.leading, inset)
            .padding(.top, size.height * 0.28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            weekRail(snapshot.recentDays, gap: css(7, in: size), size: size)
                .padding(.leading, inset)
                .padding(.bottom, size.height * 0.10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            imprint(side: imprintSide, hasHalo: true)
                .padding(.trailing, inset)
                .padding(.bottom, size.height * 0.065)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    private func numberSilhouette(size: CGSize) -> some View {
        let panelWidth = size.width * (usesMediumMetrics ? 0.40 : 0.54)
        let inset = horizontalInset(in: size)
        let imprintSide = min(
            size.height * (usesMediumMetrics ? 0.43 : 0.27),
            size.width * (usesMediumMetrics ? 0.18 : 0.23)
        )

        return ZStack {
            baseBackground

            RoundedRectangle(cornerRadius: 0)
                .fill(fieldColor.opacity(usesFullColorPalette ? 0.82 : 0.48))
                .frame(width: panelWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            VStack(spacing: css(2, in: size)) {
                Text(snapshot.today.day, format: .number)
                    .font(.system(
                        size: css(usesMediumMetrics ? 118 : 96, in: size),
                        weight: .ultraLight,
                        design: .rounded
                    ))
                    .foregroundStyle(actionColor.opacity(0.24))
                    .monospacedDigit()
                    .minimumScaleFactor(0.62)
                    .lineLimit(1)
                    .frame(maxWidth: panelWidth - inset)

                Text(verbatim: monthName.uppercased(with: locale))
                    .font(.system(
                        size: css(usesMediumMetrics ? 12 : 10, in: size),
                        weight: .semibold,
                        design: .rounded
                    ))
                    .foregroundStyle(secondaryColor)
                    .tracking(css(1.4, in: size))
                    .lineLimit(1)
            }
            .frame(width: panelWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Rectangle()
                .fill(actionColor.opacity(0.18))
                .frame(width: css(1, in: size))
                .padding(.vertical, size.height * 0.11)
                .offset(x: panelWidth / 2)

            VStack(alignment: .leading, spacing: css(8, in: size)) {
                statusLabel(size: css(usesMediumMetrics ? 14 : 12, in: size))

                habitName(
                    size: css(usesMediumMetrics ? 40 : 31, in: size),
                    width: size.width - panelWidth - inset * 2,
                    alignment: .leading
                )

                Spacer(minLength: 0)

                imprint(side: imprintSide, hasHalo: false)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.leading, panelWidth + inset)
            .padding(.trailing, inset)
            .padding(.vertical, size.height * 0.10)
        }
    }

    private func depthRhythm(size: CGSize) -> some View {
        let inset = horizontalInset(in: size)
        let imprintSide = min(
            size.height * (usesMediumMetrics ? 0.48 : 0.31),
            size.width * (usesMediumMetrics ? 0.20 : 0.27)
        )

        return ZStack {
            baseBackground

            contourField(
                size: size,
                anchor: CGPoint(x: 0.86, y: 0.70),
                widthRatio: usesMediumMetrics ? 0.62 : 0.96,
                heightRatio: 1.08
            )
            .opacity(0.62)

            statusLabel(size: css(14, in: size))
                .padding(.leading, inset)
                .padding(.top, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(verbatim: monthAndDay)
                .font(.system(size: css(16, in: size), weight: .medium, design: .rounded))
                .foregroundStyle(secondaryColor)
                .monospacedDigit()
                .padding(.trailing, inset)
                .padding(.top, size.height * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            habitName(
                size: css(usesMediumMetrics ? 40 : 33, in: size),
                width: size.width * (usesMediumMetrics ? 0.54 : 0.70),
                alignment: .leading
            )
            .padding(.leading, inset)
            .padding(.top, size.height * 0.27)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            depthTrail(days: Array(snapshot.recentDays.dropLast()), size: size)
                .padding(.horizontal, inset)
                .padding(.bottom, size.height * 0.09)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            imprint(side: imprintSide, hasHalo: true)
                .padding(.trailing, inset)
                .padding(.bottom, size.height * 0.055)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    private func quietOrder(size: CGSize) -> some View {
        let inset = horizontalInset(in: size)
        let imprintSide = min(
            size.height * (usesMediumMetrics ? 0.38 : 0.24),
            size.width * (usesMediumMetrics ? 0.16 : 0.22)
        )

        return ZStack {
            baseBackground

            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    statusLabel(size: css(14, in: size))
                    Spacer()
                    Text(verbatim: monthAndDay)
                        .font(.system(
                            size: css(17, in: size),
                            weight: .medium,
                            design: .rounded
                        ))
                        .foregroundStyle(actionColor)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                habitName(
                    size: css(usesMediumMetrics ? 48 : 38, in: size),
                    width: size.width * (usesMediumMetrics ? 0.72 : 0.80),
                    alignment: .center
                )

                Spacer(minLength: 0)

                HStack {
                    Capsule()
                        .fill(fieldColor.opacity(0.68))
                        .frame(height: css(1, in: size))
                    imprint(side: imprintSide, hasHalo: false)
                }
            }
            .padding(.horizontal, inset)
            .padding(.top, size.height * 0.08)
            .padding(.bottom, size.height * 0.065)
        }
    }

    private func rhythmBoard(size: CGSize) -> some View {
        let inset = horizontalInset(in: size)

        return ZStack {
            baseBackground

            VStack(alignment: .leading, spacing: css(10, in: size)) {
                HStack(alignment: .firstTextBaseline, spacing: css(8, in: size)) {
                    habitName(
                        size: css(usesMediumMetrics ? 38 : 30, in: size),
                        width: size.width * (usesMediumMetrics ? 0.62 : 0.60),
                        alignment: .leading
                    )
                    Spacer(minLength: css(8, in: size))
                    Text(verbatim: monthName)
                        .font(.system(
                            size: css(usesMediumMetrics ? 15 : 12, in: size),
                            weight: .medium,
                            design: .rounded
                        ))
                        .foregroundStyle(secondaryColor)
                        .lineLimit(1)
                }

                statusLabel(size: css(usesMediumMetrics ? 14 : 12, in: size))

                Spacer(minLength: 0)

                weekDateScore(snapshot.recentDays, size: size)
            }
            .padding(.horizontal, inset)
            .padding(.top, size.height * 0.075)
            .padding(.bottom, size.height * 0.07)
        }
    }

    private func depthTrail(
        days: [PulseWidgetDaySnapshot],
        size: CGSize
    ) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width * (usesMediumMetrics ? 0.66 : 0.62)
            let baseline = proxy.size.height * 0.72
            let step = width / CGFloat(max(days.count - 1, 1))
            let centers = days.indices.map { index in
                CGPoint(
                    x: CGFloat(index) * step,
                    y: baseline - CGFloat(index) * proxy.size.height * 0.075
                )
            }

            ZStack(alignment: .topLeading) {
                Path { path in
                    guard let first = centers.first else { return }
                    path.move(to: first)
                    for center in centers.dropFirst() {
                        path.addLine(to: center)
                    }
                    if let last = centers.last {
                        path.addCurve(
                            to: CGPoint(x: proxy.size.width * 0.92, y: proxy.size.height * 0.24),
                            control1: CGPoint(
                                x: last.x + proxy.size.width * 0.12,
                                y: last.y
                            ),
                            control2: CGPoint(
                                x: proxy.size.width * 0.80,
                                y: proxy.size.height * 0.24
                            )
                        )
                    }
                }
                .stroke(
                    actionColor.opacity(0.22),
                    style: StrokeStyle(
                        lineWidth: css(1.2, in: size),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                ForEach(Array(days.enumerated()), id: \.element.id) { index, item in
                    let scale = 0.48 + CGFloat(index) * 0.08
                    Circle()
                        .fill(railFill(item.state))
                        .overlay {
                            if let stroke = railStroke(item.state) {
                                Circle().stroke(stroke, lineWidth: css(1.2, in: size))
                            }
                        }
                        .frame(
                            width: css(13, in: size) * scale,
                            height: css(13, in: size) * scale
                        )
                        .position(centers[index])
                }
            }
        }
        .frame(
            width: size.width - horizontalInset(in: size) * 2,
            height: size.height * 0.36
        )
    }

    private func contourField(
        size: CGSize,
        anchor: CGPoint,
        widthRatio: CGFloat,
        heightRatio: CGFloat
    ) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Ellipse()
                    .stroke(
                        grassColor.opacity(0.28 - Double(index) * 0.045),
                        lineWidth: css(index == 0 ? 2.0 : 1.25, in: size)
                    )
                    .frame(
                        width: size.width * max(0.18, widthRatio - CGFloat(index) * 0.11),
                        height: size.height * max(0.22, heightRatio - CGFloat(index) * 0.13)
                    )
            }
        }
        .position(x: size.width * anchor.x, y: size.height * anchor.y)
    }

    private func habitName(
        size: CGFloat,
        width: CGFloat,
        alignment: TextAlignment
    ) -> some View {
        Text(verbatim: snapshot.habitName)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(primaryColor)
            .multilineTextAlignment(alignment)
            .lineLimit(2)
            .minimumScaleFactor(0.62)
            .allowsTightening(true)
            .frame(width: max(width, 1), alignment: alignment == .center ? .center : .leading)
    }

    private func statusLabel(size: CGFloat) -> some View {
        Text(verbatim: statusText)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(secondaryColor)
            .lineLimit(1)
    }

    private func imprint(side: CGFloat, hasHalo: Bool) -> some View {
        ZStack {
            if hasHalo {
                Circle()
                    .fill(usesFullColorPalette
                        ? PulseWidgetDesign.surface
                        : Color.primary.opacity(0.12))
            }
            PulseWidgetImprintMark(
                isChecked: snapshot.isCheckedToday,
                usesFullColorPalette: usesFullColorPalette,
                usesSystemPalette: false,
                isOnCompletedSurface: false,
                coreScale: 0.42,
                ringInsetRatio: 0.08,
                showsPendingCore: true,
                pendingLabel: actionText,
                pendingLabelScale: 0.14,
                glyphScale: 0.25,
                centerLabel: nil,
                centerLabelScale: 0,
                ringRotationDegrees: 0,
                coreRotationDegrees: 0
            )
        }
        .frame(width: side, height: side)
    }

    private func weekRail(
        _ days: [PulseWidgetDaySnapshot],
        gap: CGFloat,
        size: CGSize
    ) -> some View {
        HStack(spacing: gap) {
            ForEach(days) { item in
                let emphasized = item.state == .checked || item.state == .todayPending
                Circle()
                    .fill(railFill(item.state))
                    .overlay {
                        if let stroke = railStroke(item.state) {
                            Circle().stroke(stroke, lineWidth: css(1.4, in: size))
                        }
                    }
                    .frame(
                        width: emphasized ? css(14, in: size) : css(9, in: size),
                        height: emphasized ? css(14, in: size) : css(9, in: size)
                    )
            }
        }
        .frame(height: css(15, in: size))
        .fixedSize()
    }

    private func weekDateScore(
        _ days: [PulseWidgetDaySnapshot],
        size: CGSize
    ) -> some View {
        HStack(spacing: css(usesMediumMetrics ? 8 : 2, in: size)) {
            ForEach(days) { item in
                let emphasized = item.state == .checked || item.state == .todayPending
                let slotSide = css(usesMediumMetrics ? 40 : 27, in: size)
                let markSide = emphasized ? slotSide : slotSide * 0.64

                VStack(spacing: css(4, in: size)) {
                    Text(verbatim: PulseLocalizedDateFormatting.dayNumber(
                        item.day,
                        locale: locale
                    ))
                    .font(.system(
                        size: css(usesMediumMetrics ? 14 : 11, in: size),
                        weight: item.state == .todayPending ? .semibold : .medium,
                        design: .rounded
                    ))
                    .foregroundStyle(
                        item.state == .todayPending ? actionColor : secondaryColor
                    )
                    .monospacedDigit()
                    .lineLimit(1)

                    ZStack {
                        Circle()
                            .fill(railFill(item.state))
                            .overlay {
                                if let stroke = railStroke(item.state) {
                                    Circle().stroke(stroke, lineWidth: css(1.4, in: size))
                                }
                            }

                        if item.state == .checked {
                            Image(systemName: "checkmark")
                                .font(.system(
                                    size: css(usesMediumMetrics ? 12 : 9, in: size),
                                    weight: .bold
                                ))
                                .foregroundStyle(checkedDotForeground)
                        }
                    }
                    .frame(width: markSide, height: markSide)
                    .frame(width: slotSide, height: slotSide)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func railFill(_ state: PulseWidgetDayState) -> Color {
        if usesFullColorPalette {
            return switch state {
            case .checked: PulseWidgetDesign.grass
            case .missed: PulseWidgetDesign.secondary.opacity(0.34)
            case .beforeHabit, .todayPending: .clear
            }
        }
        return switch state {
        case .checked: .primary
        case .missed: .primary.opacity(PulseWidgetDesign.homeMissedOpacity)
        case .beforeHabit, .todayPending: .clear
        }
    }

    private func railStroke(_ state: PulseWidgetDayState) -> Color? {
        if usesFullColorPalette {
            return switch state {
            case .beforeHabit: PulseWidgetDesign.secondary.opacity(0.50)
            case .todayPending: PulseWidgetDesign.action
            case .checked, .missed: nil
            }
        }
        return switch state {
        case .beforeHabit: Color.primary.opacity(PulseWidgetDesign.homeBeforeHabitOpacity)
        case .todayPending: Color.primary
        case .checked, .missed: nil
        }
    }

    private var baseBackground: Color {
        usesFullColorPalette ? PulseWidgetDesign.background : .clear
    }

    private var primaryColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.ink : .primary
    }

    private var secondaryColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.secondary : .secondary
    }

    private var actionColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.action : .primary
    }

    private var grassColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.grass : .primary
    }

    private var fieldColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.field : .primary.opacity(0.12)
    }

    private var checkedDotForeground: Color {
        usesFullColorPalette ? PulseWidgetDesign.grassForeground : .white
    }

    private var monthAndDay: String {
        PulseLocalizedDateFormatting.monthAndDay(snapshot.today, locale: locale)
    }

    private var monthName: String {
        PulseLocalizedDateFormatting.monthName(snapshot.today, locale: locale)
    }

    private func horizontalInset(in size: CGSize) -> CGFloat {
        size.width * (usesMediumMetrics ? 0.055 : 0.075)
    }

    private func css(_ value: CGFloat, in size: CGSize) -> CGFloat {
        let prototypeHeight: CGFloat = usesMediumMetrics ? (680 / 2.05) : 340
        return value * size.height / prototypeHeight
    }
}

struct PulseWidgetImprintMark: View {
    let isChecked: Bool
    let usesFullColorPalette: Bool
    let usesSystemPalette: Bool
    let isOnCompletedSurface: Bool
    let coreScale: CGFloat
    let ringInsetRatio: CGFloat
    let showsPendingCore: Bool
    let pendingLabel: String?
    let pendingLabelScale: CGFloat
    let glyphScale: CGFloat
    let centerLabel: String?
    let centerLabelScale: CGFloat
    let ringRotationDegrees: Double
    let coreRotationDegrees: Double

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                PulsePrototypeRing(color: isChecked ? completedColor : pendingColor)
                    .padding(side * ringInsetRatio)
                    .rotationEffect(.degrees(ringRotationDegrees))

                if isChecked {
                    completedCore(side: side)
                } else if let centerLabel {
                    Text(verbatim: centerLabel)
                        .font(.system(size: side * centerLabelScale, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(pendingColor)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                        .frame(width: side * coreScale, height: side * coreScale)
                } else if showsPendingCore {
                    ZStack {
                        Circle().fill(pendingColor)
                        if let pendingLabel {
                            Text(verbatim: pendingLabel)
                                .font(.system(
                                    size: side * pendingLabelScale,
                                    weight: .medium
                                ))
                                .foregroundStyle(pendingCoreForeground)
                                .minimumScaleFactor(0.54)
                                .lineLimit(1)
                                .padding(.horizontal, side * 0.03)
                        }
                    }
                    .frame(width: side * coreScale, height: side * coreScale)
                    .rotationEffect(.degrees(coreRotationDegrees))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    private func completedCore(side: CGFloat) -> some View {
        ZStack {
            Circle().fill(completedColor)
            if let centerLabel {
                Text(verbatim: centerLabel)
                    .font(.system(size: side * centerLabelScale, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(usesCutoutGlyph ? Color.black : completedCoreForeground)
                    .blendMode(usesCutoutGlyph ? .destinationOut : .normal)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
            } else if usesCutoutGlyph {
                Image(systemName: "checkmark")
                    .font(.system(size: side * glyphScale, weight: .medium))
                    .foregroundStyle(.black)
                    .blendMode(.destinationOut)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: side * glyphScale, weight: .medium))
                    .foregroundStyle(completedCoreForeground)
            }
        }
        .compositingGroup()
        .frame(width: side * coreScale, height: side * coreScale)
        .rotationEffect(.degrees(coreRotationDegrees))
    }

    private var completedColor: Color {
        guard usesFullColorPalette, !usesSystemPalette else { return .primary }
        return isOnCompletedSurface
            ? PulseWidgetDesign.grassForeground
            : PulseWidgetDesign.grass
    }

    private var pendingColor: Color {
        usesFullColorPalette && !usesSystemPalette
            ? PulseWidgetDesign.action
            : .primary
    }

    private var completedCoreForeground: Color {
        PulseWidgetDesign.grassForeground
    }

    private var pendingCoreForeground: Color {
        usesFullColorPalette && !usesSystemPalette
            ? PulseWidgetDesign.actionForeground
            : .white
    }

    private var usesCutoutGlyph: Bool {
        usesSystemPalette || !usesFullColorPalette
    }
}

private struct PulsePrototypeRing: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            Circle()
                .trim(from: 0, to: 312 / 360)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: side * 0.09,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .rotationEffect(.degrees(-114))
                .padding(side * PulseWidgetDesign.prototypeRingInsetRatio)
                .frame(width: side, height: side)
        }
        .accessibilityHidden(true)
    }
}

enum PulseWidgetDesign {
    static let background = Color("PulseBackground")
    static let surface = Color("PulseSurface")
    static let grass = Color("PulseGrass")
    static let grassForeground = Color("PulseGrassForeground")
    static let action = Color("PulseAction")
    static let actionForeground = Color("PulseActionForeground")
    static let ink = Color("PulseInk")
    static let secondary = Color("PulseSecondary")
    static let field = Color("PulseField")

    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let homeSafeInset: CGFloat = 12
    static let imprintRingInsetRatio: CGFloat = 0.08
    static let prototypeRingInsetRatio: CGFloat = 0.07
    static let imprintCoreScale: CGFloat = 0.46
    static let imprintGlyphScale: CGFloat = 0.18
    static let homeContentInsets = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
    static let accessoryRailLargeSide: CGFloat = 8
    static let accessoryRailSmallSide: CGFloat = 5
    static let accessoryBlockCornerRadius: CGFloat = 1.5
    static let accessoryRailStrokeWidth: CGFloat = 1.5
    static let accessoryConnectorWidth: CGFloat = 1
    static let accessoryConnectorOpacity = 0.28
    static let accessoryDateFontSize: CGFloat = 8
    static let accessoryDateLabelWidth: CGFloat = 14
    static let accessoryDateLabelHeight: CGFloat = 10
    static let accessoryDateRailGap: CGFloat = 2
    static let accessoryDateOpacity = 0.62
    static let accessoryTodayDateScale: CGFloat = 0.24
    static let accessoryImprintHeightRatio: CGFloat = 0.82
    static let accessoryImprintWidthRatio: CGFloat = 0.26
    static let accessoryRailYRatio: CGFloat = 0.73
    static let accessoryRailTerminalGap: CGFloat = 14
    static let homeMissedOpacity = 0.38
    static let homeBeforeHabitOpacity = 0.58
    static let accessoryMissedOpacity = 0.42
    static let accessoryBeforeHabitOpacity = 0.56
}
