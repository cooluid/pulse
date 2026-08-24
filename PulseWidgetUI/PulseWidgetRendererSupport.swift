import PulseCore
import SwiftUI
import WidgetKit

struct PulseBleedSplitShape: Shape {
    var topFraction: CGFloat
    var bottomFraction: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topFraction, bottomFraction) }
        set {
            topFraction = newValue.first
            bottomFraction = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * topFraction, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * bottomFraction, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct PulseAwaitingPlaceWell: View {
    let isChecked: Bool
    let usesFullColorPalette: Bool
    let emptyText: String

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                Circle()
                    .stroke(fieldColor.opacity(isChecked ? 0.40 : 0.28), lineWidth: side * 0.03)

                Circle()
                    .stroke(fieldColor.opacity(isChecked ? 0.09 : 0.07), lineWidth: side * 0.18)
                    .padding(side * 0.09)

                ZStack {
                    Circle()
                        .fill(isChecked ? completedColor : surfaceColor.opacity(0.82))

                    Text(verbatim: emptyText)
                        .font(.system(size: side * 0.22, weight: .bold))
                        .foregroundStyle(actionColor)
                        .minimumScaleFactor(0.70)
                        .lineLimit(1)
                        .frame(width: side * 0.52)
                        .opacity(isChecked ? 0 : 1)

                    Image(systemName: "checkmark")
                        .font(.system(size: side * 0.31, weight: .semibold))
                        .foregroundStyle(usesFullColorPalette
                            ? PulseWidgetDesign.grassForeground
                            : Color.black)
                        .blendMode(usesFullColorPalette ? .normal : .destinationOut)
                        .opacity(isChecked ? 1 : 0)
                }
                .compositingGroup()
                .frame(
                    width: side * (isChecked ? 0.70 : 0.58),
                    height: side * (isChecked ? 0.70 : 0.58)
                )
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    private var fieldColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.field : .primary
    }

    private var actionColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.action : .primary
    }

    private var surfaceColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.surface : .clear
    }

    private var completedColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.grass : .primary
    }
}

struct PulseStarRingArtwork: View {
    let isChecked: Bool
    let usesFullColorPalette: Bool
    let ambientPeriod: PulseWidgetAmbientPeriod

    var body: some View {
        GeometryReader { proxy in
            let geometry = PulseStarRingGeometry(
                size: proxy.size,
                period: ambientPeriod,
                isChecked: isChecked
            )

            ZStack {
                Circle()
                    .fill(ringColor.opacity(isChecked ? 0.32 : 0.20))
                    .frame(
                        width: geometry.innerWellDiameter,
                        height: geometry.innerWellDiameter
                    )
                    .position(geometry.ringCenter)

                Circle()
                    .trim(from: 0, to: isChecked ? 1 : PulseWidgetDesign.openRingTrim)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(
                            lineWidth: geometry.ringLineWidth,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(PulseWidgetDesign.openRingRotationDegrees))
                    .frame(
                        width: geometry.ringPathDiameter,
                        height: geometry.ringPathDiameter
                    )
                    .position(geometry.ringCenter)

                todayStar(diameter: geometry.starDiameter)
                    .position(geometry.starPosition)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }

    private func todayStar(diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(ringColor.opacity(isChecked ? 0.28 : 0))
                .frame(width: diameter * 1.90, height: diameter * 1.90)

            Circle()
                .fill(isChecked ? litStarColor : backgroundColor)
                .overlay {
                    Circle()
                        .stroke(
                            ringColor,
                            lineWidth: max(1.6, diameter * 0.11)
                        )
                }
                .overlay {
                    Circle()
                        .fill(isChecked ? ringColor.opacity(0.22) : ringColor.opacity(0.90))
                        .frame(
                            width: diameter * (isChecked ? 0.34 : 0.26),
                            height: diameter * (isChecked ? 0.34 : 0.26)
                        )
                        .offset(
                            x: isChecked ? -diameter * 0.14 : 0,
                            y: isChecked ? -diameter * 0.12 : 0
                        )
                }
                .clipShape(Circle())
                .frame(width: diameter, height: diameter)
        }
        .frame(width: diameter * 1.90, height: diameter * 1.90)
    }

    private var backgroundColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.background : .clear
    }

    private var ringColor: Color {
        usesFullColorPalette
            ? (isChecked ? PulseWidgetDesign.grass : PulseWidgetDesign.action)
            : .primary
    }

    private var litStarColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.actionForeground : .white
    }
}

struct PulseStarRingGeometry {
    let safeFrame: CGRect
    let ringCenter: CGPoint
    let ringDiameter: CGFloat
    let ringPathDiameter: CGFloat
    let ringLineWidth: CGFloat
    let midlineRadius: CGFloat
    let innerWellDiameter: CGFloat
    let starDiameter: CGFloat
    let starPosition: CGPoint
    let starAngleDegrees: CGFloat

    static let periodAngleSpan: CGFloat = 14
    static let completionAngleSpan: CGFloat = 4
    static let ringLineRatio: CGFloat = 0.09
    static var midlineRatio: CGFloat { (1 - ringLineRatio) / 2 }
    static var worldGapMidpointDegrees: CGFloat {
        336 + PulseWidgetDesign.openRingRotationDegrees
    }

    init(
        size: CGSize,
        period: PulseWidgetAmbientPeriod,
        isChecked: Bool
    ) {
        let usesMediumMetrics = size.width > size.height * 1.5
        let safeInset = max(8, size.height * 0.05)
        let safeFrame = CGRect(origin: .zero, size: size).insetBy(dx: safeInset, dy: safeInset)
        let starDiameter = max(16, size.height * 0.125)
        let starRadius = starDiameter / 2
        let center = CGPoint(
            x: size.width * (usesMediumMetrics ? 0.70 : 0.58),
            y: size.height * (usesMediumMetrics ? 0.56 : 0.62)
        )

        let periodOffset: CGFloat
        switch period {
        case .morning: periodOffset = -Self.periodAngleSpan
        case .daylight: periodOffset = 0
        case .evening: periodOffset = Self.periodAngleSpan
        }
        let starAngle = Self.worldGapMidpointDegrees
            + periodOffset
            + (isChecked ? Self.completionAngleSpan : 0)

        let desiredOuter = min(
            size.height * (usesMediumMetrics ? 0.82 : 0.76),
            size.width * (usesMediumMetrics ? 0.40 : 0.76)
        )
        let extremeAngles: [CGFloat] = [
            Self.worldGapMidpointDegrees - Self.periodAngleSpan,
            Self.worldGapMidpointDegrees,
            Self.worldGapMidpointDegrees + Self.periodAngleSpan + Self.completionAngleSpan,
        ]
        let allowedMidline = extremeAngles
            .map { angle in
                Self.maximumMidline(
                    center: center,
                    angleDegrees: angle,
                    starRadius: starRadius,
                    safeFrame: safeFrame
                )
            }
            .min() ?? 1
        let outerDiameter = min(desiredOuter, allowedMidline / Self.midlineRatio)
        let lineWidth = max(8, outerDiameter * Self.ringLineRatio)
        let pathDiameter = max(1, outerDiameter - lineWidth)
        let midlineRadius = pathDiameter / 2
        let gutter = max(4.8, outerDiameter * 0.042)
        let innerWellDiameter = max(1, outerDiameter - (lineWidth * 2) - (gutter * 2))
        let radians = starAngle * .pi / 180

        self.safeFrame = safeFrame
        self.ringCenter = center
        self.ringDiameter = outerDiameter
        self.ringPathDiameter = pathDiameter
        self.ringLineWidth = lineWidth
        self.midlineRadius = midlineRadius
        self.innerWellDiameter = innerWellDiameter
        self.starDiameter = starDiameter
        self.starPosition = CGPoint(
            x: center.x + midlineRadius * cos(radians),
            y: center.y + midlineRadius * sin(radians)
        )
        self.starAngleDegrees = starAngle
    }

    var starFrame: CGRect {
        CGRect(
            x: starPosition.x - starDiameter / 2,
            y: starPosition.y - starDiameter / 2,
            width: starDiameter,
            height: starDiameter
        )
    }

    private static func maximumMidline(
        center: CGPoint,
        angleDegrees: CGFloat,
        starRadius: CGFloat,
        safeFrame: CGRect
    ) -> CGFloat {
        let radians = angleDegrees * .pi / 180
        let direction = CGVector(dx: cos(radians), dy: sin(radians))
        var limit = CGFloat.greatestFiniteMagnitude

        if direction.dx > 0.001 {
            limit = min(limit, (safeFrame.maxX - starRadius - center.x) / direction.dx)
        } else if direction.dx < -0.001 {
            limit = min(limit, (safeFrame.minX + starRadius - center.x) / direction.dx)
        }

        if direction.dy > 0.001 {
            limit = min(limit, (safeFrame.maxY - starRadius - center.y) / direction.dy)
        } else if direction.dy < -0.001 {
            limit = min(limit, (safeFrame.minY + starRadius - center.y) / direction.dy)
        }

        return max(1, limit - 1)
    }
}

struct PulseStackPaperGeometry {
    let topPaperFrame: CGRect
    let stackBounds: CGRect
    let pressSize: CGSize
    let pressFrame: CGRect
    let foldSize: CGSize
    let foldClearance: CGFloat
    let paperInset: CGFloat
    let layerStep: CGFloat
    let paperCornerRadius: CGFloat
    let deskCornerRadius: CGFloat
    let rotationPerLayer: Double

    static var sheetCount: Int { PulseWidgetDesign.stackPhysicalSheetCount }

    init(
        size: CGSize,
        usesMediumMetrics: Bool,
        isChecked: Bool
    ) {
        let scale = min(size.width, size.height) / 158
        let pendingStep = (usesMediumMetrics
            ? PulseWidgetDesign.stackPendingLayerStepMedium
            : PulseWidgetDesign.stackPendingLayerStepSmall) * scale
        let checkedStep = (usesMediumMetrics
            ? PulseWidgetDesign.stackCheckedLayerStepMedium
            : PulseWidgetDesign.stackCheckedLayerStepSmall) * scale
        let margin = (usesMediumMetrics
            ? PulseWidgetDesign.stackCanvasMarginMedium
            : PulseWidgetDesign.stackCanvasMarginSmall) * scale
        let cascade = CGFloat(Self.sheetCount - 1) * pendingStep
        let paperInset = (usesMediumMetrics ? 10 : 8) * scale
        let width = max(1, size.width - margin * 2 - cascade)
        let height = max(1, size.height - margin * 2 - cascade)
        let origin = CGPoint(x: margin + cascade, y: margin)
        let topPaper = CGRect(origin: origin, size: CGSize(width: width, height: height))
        // Formal canvas geometry: small 158² press 54×46 at right 28 / bottom 46;
        // medium 338×158 press 86×70 at right 48 / bottom 36.
        let pressWidth: CGFloat
        let pressHeight: CGFloat
        let pressOrigin: CGPoint
        if usesMediumMetrics {
            let sx = size.width / 338
            let sy = size.height / 158
            pressWidth = 86 * sx
            pressHeight = 70 * sy
            pressOrigin = CGPoint(
                x: size.width - 48 * sx - pressWidth,
                y: size.height - 36 * sy - pressHeight
            )
        } else {
            let sx = size.width / 158
            let sy = size.height / 158
            pressWidth = 54 * sx
            pressHeight = 46 * sy
            pressOrigin = CGPoint(
                x: size.width - 28 * sx - pressWidth,
                y: size.height - 46 * sy - pressHeight
            )
        }
        let foldSide = min(width, height) * 0.30
        let foldClearance = foldSide * 0.86

        self.topPaperFrame = topPaper
        self.stackBounds = CGRect(
            x: topPaper.minX - cascade,
            y: topPaper.minY,
            width: topPaper.width + cascade,
            height: topPaper.height + cascade
        )
        self.pressSize = CGSize(width: pressWidth, height: pressHeight)
        self.pressFrame = CGRect(origin: pressOrigin, size: CGSize(width: pressWidth, height: pressHeight))
        self.foldSize = CGSize(width: foldSide, height: foldSide)
        self.foldClearance = foldClearance
        self.paperInset = paperInset
        self.layerStep = isChecked ? checkedStep : pendingStep
        self.paperCornerRadius = (usesMediumMetrics ? 19 : 17) * scale
        self.deskCornerRadius = (usesMediumMetrics ? 26 : 22) * scale
        self.rotationPerLayer = usesMediumMetrics ? -0.95 : -1.35
    }
}

struct PulseOrganicInkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [
            CGPoint(x: 0.47, y: 0.01), CGPoint(x: 0.72, y: 0.07),
            CGPoint(x: 0.94, y: 0.20), CGPoint(x: 0.98, y: 0.43),
            CGPoint(x: 0.87, y: 0.66), CGPoint(x: 0.75, y: 0.83),
            CGPoint(x: 0.55, y: 0.96), CGPoint(x: 0.31, y: 0.92),
            CGPoint(x: 0.12, y: 0.77), CGPoint(x: 0.02, y: 0.55),
            CGPoint(x: 0.10, y: 0.30), CGPoint(x: 0.27, y: 0.16),
        ].map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }

        var path = Path()
        path.move(to: midpoint(points.last!, points[0]))
        for index in points.indices {
            let point = points[index]
            let next = points[(index + 1) % points.count]
            path.addQuadCurve(to: midpoint(point, next), control: point)
        }
        path.closeSubpath()
        return path
    }

    private func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: (lhs.x + rhs.x) / 2, y: (lhs.y + rhs.y) / 2)
    }
}

struct PulsePaperPressMark: View {
    let isChecked: Bool
    let usesFullColorPalette: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let radius = hypot(width, height) * 0.52

            ZStack {
                // A single soft oval forms the press plate; keep side soaks very faint.
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [markColor.opacity(0.14), markColor.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: radius * 0.70
                        )
                    )
                    .frame(width: width * 0.70, height: height * 0.60)
                    .offset(x: width * 0.14, y: height * 0.16)
                    .opacity(isChecked ? 1 : 0)

                Ellipse()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: markColor.opacity(0.48), location: 0),
                                .init(color: markColor.opacity(0.28), location: 0.55),
                                .init(color: markColor.opacity(0.12), location: 0.88),
                                .init(color: markColor.opacity(0), location: 1),
                            ],
                            center: UnitPoint(x: 0.42, y: 0.48),
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                    .rotationEffect(.degrees(-9))
                    .opacity(isChecked ? 1 : 0)

                Ellipse()
                    .fill(markColor.opacity(0.06))
                    .overlay {
                        Ellipse()
                            .stroke(markColor.opacity(0.38), lineWidth: max(1.2, min(width, height) * 0.035))
                    }
                    .padding(min(width, height) * 0.06)
                    .rotationEffect(.degrees(-11))
                    .opacity(isChecked ? 0 : 1)
            }
            .frame(width: width, height: height)
        }
        .accessibilityHidden(true)
    }

    private var markColor: Color {
        guard usesFullColorPalette else { return .primary }
        return isChecked ? PulseWidgetDesign.grass : PulseWidgetDesign.action
    }
}

struct PulseLetterPressedInkMark: View {
    let markColor: Color

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                PulseOrganicInkShape()
                    .fill(markColor.opacity(0.14))
                    .frame(width: side * 0.94, height: side * 0.84)
                    .rotationEffect(.degrees(-11))

                PulseLetterPressRidges()
                    .stroke(
                        markColor.opacity(0.66),
                        style: StrokeStyle(
                            lineWidth: max(1, side * 0.095),
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .frame(width: side * 0.88, height: side * 0.82)
                    .rotationEffect(.degrees(-11))

                PulseOrganicInkShape()
                    .fill(markColor.opacity(0.46))
                    .frame(width: side * 0.25, height: side * 0.16)
                    .rotationEffect(.degrees(13))
                    .offset(x: side * -0.16, y: side * 0.10)

                PulseOrganicInkShape()
                    .fill(markColor.opacity(0.34))
                    .frame(width: side * 0.24, height: side * 0.14)
                    .rotationEffect(.degrees(-19))
                    .offset(x: side * 0.25, y: side * 0.28)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

struct PulseLetterHandUnderline: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()
        path.move(to: point(0.02, 0.60))
        path.addCurve(
            to: point(0.98, 0.42),
            control1: point(0.22, 0.76),
            control2: point(0.70, 0.18)
        )
        path.move(to: point(0.10, 0.82))
        path.addCurve(
            to: point(0.78, 0.66),
            control1: point(0.30, 0.94),
            control2: point(0.58, 0.48)
        )
        return path
    }
}

struct PulseLetterPencilRules: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()
        path.move(to: point(0.00, 0.18))
        path.addCurve(
            to: point(1.00, 0.24),
            control1: point(0.26, 0.10),
            control2: point(0.69, 0.33)
        )
        path.move(to: point(0.02, 0.82))
        path.addCurve(
            to: point(0.73, 0.76),
            control1: point(0.24, 0.91),
            control2: point(0.53, 0.66)
        )
        return path
    }
}

struct PulseLetterPressRidges: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()
        path.move(to: point(0.08, 0.65))
        path.addCurve(
            to: point(0.78, 0.14),
            control1: point(-0.04, 0.22),
            control2: point(0.52, -0.07)
        )

        path.move(to: point(0.87, 0.24))
        path.addCurve(
            to: point(0.88, 0.47),
            control1: point(0.94, 0.29),
            control2: point(0.94, 0.41)
        )

        path.move(to: point(0.19, 0.82))
        path.addCurve(
            to: point(0.68, 0.31),
            control1: point(0.07, 0.51),
            control2: point(0.38, 0.18)
        )

        path.move(to: point(0.43, 0.76))
        path.addCurve(
            to: point(0.61, 0.43),
            control1: point(0.32, 0.59),
            control2: point(0.44, 0.39)
        )
        return path
    }
}

struct PulseStackedSheetShape: Shape {
    var cornerRadius: CGFloat
    var foldSide: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(cornerRadius, foldSide) }
        set {
            cornerRadius = newValue.first
            foldSide = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, min(rect.width, rect.height) / 2)
        let fold = min(max(0, foldSide), min(rect.width, rect.height) * 0.45)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )

        if fold > radius {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - fold))
            path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.maxY))
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addArc(
                center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                radius: radius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
        }

        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

struct PulseFoldedPaperFlap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct PulseLetterDateSeal: View {
    let isChecked: Bool
    let dayNumber: String
    let usesFullColorPalette: Bool

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let sealDiameter = height * 0.86
            let cancellationWidth = max(0, proxy.size.width - sealDiameter)

            HStack(spacing: 0) {
                VStack(alignment: .trailing, spacing: height * 0.10) {
                    RoundedRectangle(cornerRadius: height * 0.02, style: .continuous)
                        .frame(width: cancellationWidth * 0.82, height: max(1, height * 0.035))
                    RoundedRectangle(cornerRadius: height * 0.02, style: .continuous)
                        .frame(width: cancellationWidth, height: max(1, height * 0.035))
                }
                .foregroundStyle(markColor.opacity(isChecked ? 0.58 : 0.30))
                .offset(y: height * (isChecked ? 0.05 : -0.03))
                .frame(width: cancellationWidth, alignment: .trailing)

                ZStack {
                    Circle()
                        .fill(surfaceColor)
                        .shadow(
                            color: shadowColor.opacity(usesFullColorPalette ? 0.10 : 0),
                            radius: height * 0.08,
                            y: height * 0.04
                        )

                    Circle()
                        .trim(from: 0, to: isChecked ? 1 : 0.867)
                        .stroke(
                            markColor,
                            style: StrokeStyle(
                                lineWidth: max(1, height * 0.055),
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-18))

                    Circle()
                        .fill(isChecked ? markColor : markColor.opacity(0.10))
                        .frame(width: sealDiameter * 0.58, height: sealDiameter * 0.58)

                    Text(verbatim: dayNumber)
                        .font(.system(size: sealDiameter * 0.31, weight: .semibold))
                        .foregroundStyle(isChecked ? completedForeground : pendingForeground)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .frame(width: sealDiameter, height: sealDiameter)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .rotationEffect(.degrees(isChecked ? 0 : 2.5))
        }
        .accessibilityHidden(true)
    }

    private var markColor: Color {
        guard usesFullColorPalette else { return .primary }
        return isChecked ? PulseWidgetDesign.grass : PulseWidgetDesign.action
    }

    private var surfaceColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.surface.opacity(0.96) : .clear
    }

    private var shadowColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.shadow : .clear
    }

    private var pendingForeground: Color {
        usesFullColorPalette ? PulseWidgetDesign.action : .primary
    }

    private var completedForeground: Color {
        usesFullColorPalette ? PulseWidgetDesign.grassForeground : .black
    }
}

struct PulseEchoCompletionMark: View {
    let isChecked: Bool
    let usesFullColorPalette: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .trim(from: 0, to: isChecked ? 1 : 0.58 + CGFloat(index) * 0.10)
                        .stroke(
                            markColor.opacity(0.82 - Double(index) * 0.20),
                            style: StrokeStyle(lineWidth: max(1, side * 0.045), lineCap: .round)
                        )
                        .padding(side * (0.08 + CGFloat(index) * 0.13))
                        .rotationEffect(.degrees(isChecked ? 0 : Double(index) * 32 - 48))
                }

                RoundedRectangle(cornerRadius: side * 0.06, style: .continuous)
                    .fill(markColor)
                    .frame(width: side * (isChecked ? 0.24 : 0.12), height: side * (isChecked ? 0.24 : 0.12))
                    .rotationEffect(.degrees(45))
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: side * 0.11, weight: .bold))
                            .foregroundStyle(completedForeground)
                            .opacity(isChecked ? 1 : 0)
                    }
            }
        }
        .accessibilityHidden(true)
    }

    private var markColor: Color {
        guard usesFullColorPalette else { return .primary }
        return isChecked ? PulseWidgetDesign.grass : PulseWidgetDesign.field
    }

    private var completedForeground: Color {
        usesFullColorPalette ? PulseWidgetDesign.grassForeground : .black
    }
}

struct PulseTideSkyGeometry: Equatable {
    let diameter: CGFloat
    let center: CGPoint
    let opacity: Double

    init(
        size: CGSize,
        usesMediumMetrics: Bool,
        period: PulseWidgetAmbientPeriod
    ) {
        let scale = size.height / 158
        diameter = (usesMediumMetrics ? 48 : 34) * scale

        switch period {
        case .morning:
            center = CGPoint(
                x: size.width - diameter * 0.42,
                y: size.height * 0.42
            )
            opacity = 0.18
        case .daylight:
            center = CGPoint(
                x: size.width - diameter * 0.24,
                y: size.height * 0.17
            )
            opacity = 0.12
        case .evening:
            center = CGPoint(
                x: size.width - diameter * 0.04,
                y: size.height * 0.62
            )
            opacity = 0.17
        }
    }
}

struct PulseTideStaffMark: View {
    let isChecked: Bool
    let usesFullColorPalette: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            HStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: side * 0.06, style: .continuous)
                        .fill(markColor.opacity(0.11))
                        .frame(width: side * 0.18, height: side * 0.90)

                    RoundedRectangle(cornerRadius: side * 0.025, style: .continuous)
                        .fill(markColor.opacity(0.72))
                        .frame(width: max(1, side * 0.055), height: side * 0.84)
                }
                .frame(width: side * 0.18)

                VStack(spacing: side * 0.075) {
                    ForEach(0..<4, id: \.self) { index in
                        let isWaterLevel = index == (isChecked ? 0 : 3)
                        Rectangle()
                            .fill(markColor.opacity(isWaterLevel ? 0.96 : 0.38))
                            .frame(
                                width: side * (isWaterLevel ? 0.36 : (index.isMultiple(of: 2) ? 0.24 : 0.18)),
                                height: max(1, side * (isWaterLevel ? 0.055 : 0.028))
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(width: side * 0.36)
            }
            .frame(width: side * 0.54, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    private var markColor: Color {
        guard usesFullColorPalette else { return .primary }
        return isChecked ? PulseWidgetDesign.grass : PulseWidgetDesign.field
    }

}

struct PulseTideCurve: Shape {
    enum Kind {
        case water
        case lip
        case trace
    }

    let kind: Kind
    let usesMediumMetrics: Bool

    func path(in rect: CGRect) -> Path {
        let referenceWidth: CGFloat = usesMediumMetrics ? 340 : 160
        let referenceHeight: CGFloat = usesMediumMetrics ? 100 : 90
        let points: [CGPoint]

        if usesMediumMetrics {
            points = kind == .trace
                ? [
                    CGPoint(x: -8, y: 50), CGPoint(x: 52, y: 36),
                    CGPoint(x: 108, y: 58), CGPoint(x: 170, y: 46),
                    CGPoint(x: 230, y: 34), CGPoint(x: 286, y: 60),
                    CGPoint(x: 348, y: 44),
                ]
                : [
                    CGPoint(x: -8, y: 38), CGPoint(x: 48, y: 22),
                    CGPoint(x: 96, y: 50), CGPoint(x: 160, y: 38),
                    CGPoint(x: 220, y: 26), CGPoint(x: 278, y: 52),
                    CGPoint(x: 348, y: 34),
                ]
        } else {
            points = kind == .trace
                ? [
                    CGPoint(x: -4, y: 44), CGPoint(x: 30, y: 34),
                    CGPoint(x: 58, y: 50), CGPoint(x: 86, y: 42),
                    CGPoint(x: 114, y: 34), CGPoint(x: 138, y: 52),
                    CGPoint(x: 164, y: 40),
                ]
                : [
                    CGPoint(x: -4, y: 34), CGPoint(x: 28, y: 22),
                    CGPoint(x: 52, y: 42), CGPoint(x: 80, y: 34),
                    CGPoint(x: 108, y: 26), CGPoint(x: 132, y: 44),
                    CGPoint(x: 164, y: 30),
                ]
        }

        func scaled(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: point.x / referenceWidth * rect.width,
                y: point.y / referenceHeight * rect.height
            )
        }

        var path = Path()
        path.move(to: scaled(points[0]))
        path.addCurve(
            to: scaled(points[3]),
            control1: scaled(points[1]),
            control2: scaled(points[2])
        )
        path.addCurve(
            to: scaled(points[6]),
            control1: scaled(points[4]),
            control2: scaled(points[5])
        )

        if kind == .water {
            path.addLine(to: CGPoint(x: rect.maxX + rect.width * 0.05, y: rect.maxY + rect.height * 0.05))
            path.addLine(to: CGPoint(x: rect.minX - rect.width * 0.05, y: rect.maxY + rect.height * 0.05))
            path.closeSubpath()
        }

        return path
    }
}

struct PulsePathTrailGeometry {
    struct NodePoint {
        let center: CGPoint
        let diameter: CGFloat
    }

    let size: CGSize
    let usesMediumMetrics: Bool

    /// A quiet two-bend route: history approaches today instead of reading as a chart.
    private var nodeFractions: [(x: CGFloat, y: CGFloat, side: CGFloat)] {
        if usesMediumMetrics {
            return [
                (0.06, 0.70, 5.0),
                (0.20, 0.66, 5.8),
                (0.34, 0.69, 6.7),
                (0.49, 0.63, 7.7),
                (0.63, 0.65, 8.8),
                (0.75, 0.59, 10.0),
            ]
        }
        return [
            (0.04, 0.74, 4.4),
            (0.17, 0.70, 5.0),
            (0.30, 0.72, 5.7),
            (0.43, 0.66, 6.5),
            (0.56, 0.68, 7.4),
            (0.68, 0.62, 8.4),
        ]
    }

    var todayCenter: CGPoint {
        CGPoint(
            x: size.width * (usesMediumMetrics ? 0.87 : 0.80),
            y: size.height * (usesMediumMetrics ? 0.72 : 0.77)
        )
    }

    var nodePoints: [NodePoint] {
        nodeFractions.map { fraction in
            NodePoint(
                center: CGPoint(
                    x: size.width * fraction.x,
                    y: size.height * fraction.y
                ),
                diameter: fraction.side * size.height / 158
            )
        }
    }

    /// The far end enters from beyond the card; the near end terminates at today's seal.
    var spinePoints: [CGPoint] {
        let nodes = nodePoints.map(\.center)
        guard nodes.count >= 2 else { return nodes }

        let first = nodes[0]
        let second = nodes[1]

        let start = CGPoint(
            x: first.x - (second.x - first.x) * 0.78,
            y: first.y + size.height * 0.025
        )
        return [start] + nodes + [todayCenter]
    }
}

struct PulsePathHillContours: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()
        path.move(to: point(-0.08, 0.67))
        path.addCurve(
            to: point(0.68, 0.63),
            control1: point(0.13, 0.54),
            control2: point(0.33, 0.50)
        )
        path.addCurve(
            to: point(1.07, 0.70),
            control1: point(0.83, 0.68),
            control2: point(0.94, 0.73)
        )

        path.move(to: point(-0.08, 0.78))
        path.addCurve(
            to: point(0.55, 0.72),
            control1: point(0.10, 0.65),
            control2: point(0.31, 0.63)
        )
        path.addCurve(
            to: point(1.07, 0.77),
            control1: point(0.72, 0.76),
            control2: point(0.91, 0.81)
        )
        return path
    }
}

struct PulsePathInkSpineShape: Shape {
    var points: [CGPoint]

    func path(in _: CGRect) -> Path {
        Self.smoothPath(through: points)
    }

    static func smoothPath(through points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }

        path.move(to: points[0])
        guard points.count > 2 else {
            path.addLine(to: points[1])
            return path
        }

        for index in 0..<(points.count - 1) {
            let p0 = points[max(index - 1, 0)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(index + 2, points.count - 1)]
            let control1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: p1.y + (p2.y - p0.y) / 6
            )
            let control2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6,
                y: p2.y - (p3.y - p1.y) / 6
            )
            path.addCurve(to: p2, control1: control1, control2: control2)
        }
        return path
    }
}

struct PulsePathTodaySeal: View {
    let isChecked: Bool
    let dayNumber: String
    let usesFullColorPalette: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(
                        usesFullColorPalette
                            ? PulseWidgetDesign.grass.opacity(isChecked ? 0.10 : 0)
                            : Color.primary.opacity(isChecked ? 0.06 : 0)
                    )
                    .scaleEffect(isChecked ? 1.18 : 0.82)

                Circle()
                    .fill(fillColor)

                PulseStateRing(
                    isChecked: isChecked,
                    color: strokeColor,
                    lineWidth: max(2, side * 0.055)
                )

                Text(verbatim: dayNumber)
                    .font(.system(size: side * 0.40, weight: .bold))
                    .foregroundStyle(dayColor)
                    .monospacedDigit()
                    .minimumScaleFactor(0.74)
                    .lineLimit(1)
                    .scaleEffect(isChecked ? 1 : 0.94)
            }
        }
        .accessibilityHidden(true)
    }

    private var strokeColor: Color {
        guard usesFullColorPalette else { return .primary }
        return isChecked ? PulseWidgetDesign.grass : PulseWidgetDesign.action
    }

    private var fillColor: Color {
        usesFullColorPalette
            ? PulseWidgetDesign.surface.opacity(isChecked ? 0.94 : 0.88)
            : Color.clear
    }

    private var dayColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.ink : .primary
    }
}

struct PulseStateRing: View {
    let isChecked: Bool
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        Circle()
            .trim(from: 0, to: isChecked ? 1 : PulseWidgetDesign.openRingTrim)
            .stroke(
                color,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(
                isChecked ? 0 : PulseWidgetDesign.openRingRotationDegrees
            ))
            .padding(lineWidth / 2)
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
                PulseWidgetRingLayer(
                    color: isChecked ? completedColor : pendingColor,
                    isClosed: isChecked
                )
                    .padding(side * ringInsetRatio)
                    .rotationEffect(.degrees(ringRotationDegrees))

                completedCore(side: side)
                    .opacity(isChecked ? 1 : 0)

                if let centerLabel {
                    Text(verbatim: centerLabel)
                        .font(.system(size: side * centerLabelScale, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(pendingColor)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                        .frame(width: side * coreScale, height: side * coreScale)
                        .opacity(isChecked ? 0 : 1)
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
                    .opacity(isChecked ? 0 : 1)
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

struct PulseWidgetRingLayer: View {
    let color: Color
    let isClosed: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            Circle()
                .trim(from: 0, to: isClosed ? 1 : 312 / 360)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: side * 0.09,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .rotationEffect(.degrees(isClosed ? 0 : -114))
                .padding(side * PulseWidgetDesign.ringLayerInsetRatio)
                .frame(width: side, height: side)
        }
        .accessibilityHidden(true)
    }
}
