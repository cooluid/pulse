import PulseCore
import SwiftUI
import WidgetKit

enum PulseWidgetStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case seal
    case stack
    case bleed
    case letter
    case field
    case path
    case tide

    var id: String { rawValue }
}

enum PulseWidgetStyleAccessPolicy {
    static let freeStyle = PulseWidgetStyle.seal

    static func requiresEnhancement(_ style: PulseWidgetStyle) -> Bool {
        style != freeStyle
    }

    static func isAvailable(
        _ style: PulseWidgetStyle,
        hasEnhancementEntitlement: Bool
    ) -> Bool {
        !requiresEnhancement(style) || hasEnhancementEntitlement
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
                case .seal:
                    seal(size: proxy.size)
                case .stack:
                    stack(size: proxy.size)
                case .bleed:
                    bleed(size: proxy.size)
                case .letter:
                    letter(size: proxy.size)
                case .field:
                    field(size: proxy.size)
                case .path:
                    path(size: proxy.size)
                case .tide:
                    tide(size: proxy.size)
                }
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height,
                alignment: .topLeading
            )
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func seal(size: CGSize) -> some View {
        let stampSide = pt(usesMediumMetrics ? 128 : 110, in: size)
        let stampX = pt(usesMediumMetrics ? 10 : 4, in: size) + stampSide / 2
        let copyX = pt(usesMediumMetrics ? 156 : 12, in: size)

        return ZStack(alignment: .topLeading) {
            surfaceBackground

            sealAfterimage(side: stampSide, size: size)
                .position(x: stampX, y: size.height / 2)

            ritualSeal(side: stampSide, showsWash: true, showsCheck: true)
                .position(x: stampX, y: size.height / 2)

            Text(verbatim: monthAndDay)
                .font(.system(
                    size: pt(usesMediumMetrics ? 15 : 12, in: size),
                    weight: .semibold
                ))
                .tracking(pt(usesMediumMetrics ? 0.9 : 0.5, in: size))
                .foregroundStyle(actionColor)
                .monospacedDigit()
                .lineLimit(1)
                .padding(.leading, usesMediumMetrics ? copyX : 0)
                .padding(.trailing, usesMediumMetrics ? 0 : pt(12, in: size))
                .padding(.top, pt(usesMediumMetrics ? 16 : 12, in: size))
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: usesMediumMetrics ? .topLeading : .topTrailing
                )

            habitName(
                size: pt(usesMediumMetrics ? 22 : 13, in: size),
                width: pt(usesMediumMetrics ? 150 : 70, in: size),
                alignment: usesMediumMetrics ? .leading : .trailing
            )
            .padding(.leading, usesMediumMetrics ? copyX : 0)
            .padding(.trailing, usesMediumMetrics ? 0 : pt(12, in: size))
            .padding(.bottom, pt(usesMediumMetrics ? 18 : 12, in: size))
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: usesMediumMetrics ? .bottomLeading : .bottomTrailing
            )
        }
    }

    private func stack(size: CGSize) -> some View {
        let sealSide = pt(usesMediumMetrics ? 118 : 100, in: size)
        let sealTrailing = pt(usesMediumMetrics ? 10 : -8, in: size)
        let sealBottom = pt(usesMediumMetrics ? 8 : 4, in: size)

        return ZStack(alignment: .topLeading) {
            surfaceBackground
            stackLayers(size: size)

            if usesMediumMetrics {
                VStack(alignment: .leading, spacing: pt(8, in: size)) {
                    Text(verbatim: monthName)
                        .font(.system(size: pt(11, in: size), weight: .bold))
                        .foregroundStyle(actionColor)
                    habitName(
                        size: pt(24, in: size),
                        width: pt(150, in: size),
                        alignment: .leading
                    )
                    Text(verbatim: dayNumber)
                        .font(.system(size: pt(52, in: size), weight: .ultraLight))
                        .foregroundStyle(actionColor)
                        .tracking(pt(-2.5, in: size))
                        .monospacedDigit()
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    statusLabel(size: pt(11, in: size))
                }
                .frame(width: pt(150, in: size), alignment: .leading)
                .frame(
                    height: size.height - pt(30, in: size),
                    alignment: .topLeading
                )
                .padding(.leading, pt(18, in: size))
                .padding(.top, pt(16, in: size))
                .padding(.bottom, pt(14, in: size))
            } else {
                let dayWidth = pt(58, in: size)
                let dayHeight = pt(40, in: size)

                VStack(alignment: .leading, spacing: pt(6, in: size)) {
                    Text(verbatim: monthName)
                        .font(.system(size: pt(11, in: size), weight: .bold))
                        .foregroundStyle(actionColor)
                    habitName(
                        size: pt(16, in: size),
                        width: pt(72, in: size),
                        alignment: .leading
                    )
                }
                .padding(.leading, pt(12, in: size))
                .padding(.top, pt(11, in: size))

                Text(verbatim: dayNumber)
                    .font(.system(size: pt(40, in: size), weight: .ultraLight))
                    .foregroundStyle(actionColor)
                    .tracking(pt(-2.4, in: size))
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(width: dayWidth, height: dayHeight, alignment: .topTrailing)
                    .position(
                        x: size.width - pt(12, in: size) - dayWidth / 2,
                        y: pt(6, in: size) + dayHeight / 2
                    )
            }

            ritualSeal(side: sealSide, showsWash: false, showsCheck: true)
                .position(
                    x: size.width - sealTrailing - sealSide / 2,
                    y: size.height - sealBottom - sealSide / 2
                )
        }
    }

    private func tide(size: CGSize) -> some View {
        let isMedium = usesMediumMetrics
        let inset = pt(isMedium ? 16 : 12, in: size)
        let markSide = pt(isMedium ? 58 : 40, in: size)
        let markBottomRatio: CGFloat = snapshot.isCheckedToday
            ? (isMedium ? 0.32 : 0.36)
            : (isMedium ? 0.24 : 0.28)
        let markX = isMedium
            ? size.width - pt(28, in: size) - markSide / 2
            : size.width / 2
        let markY = size.height - size.height * markBottomRatio - markSide / 2
        let copyWidth = isMedium ? size.width - pt(126, in: size) : pt(76, in: size)

        return ZStack(alignment: .topLeading) {
            tideBackground
            tideSky(size: size)
            tideShore(size: size)

            PulseTideDayMark(
                isChecked: snapshot.isCheckedToday,
                usesFullColorPalette: usesFullColorPalette
            )
            .frame(width: markSide, height: markSide)
            .position(x: markX, y: markY)

            VStack(alignment: .leading, spacing: pt(isMedium ? 10 : 8, in: size)) {
                Text(verbatim: tideDate)
                    .font(.system(size: pt(isMedium ? 13 : 11, in: size), weight: .bold))
                    .tracking(pt(0.55, in: size))
                    .foregroundStyle(actionColor)
                    .monospacedDigit()
                    .lineLimit(1)

                habitName(
                    size: pt(isMedium ? 22 : 15, in: size),
                    width: copyWidth,
                    alignment: .leading
                )
            }
            .frame(width: copyWidth, alignment: .leading)
            .padding(.leading, inset)
            .padding(.top, pt(isMedium ? 16 : 12, in: size))

            statusLabel(size: pt(isMedium ? 12 : 11, in: size))
                .foregroundStyle(tideFootColor)
                .padding(.leading, inset)
                .padding(.bottom, pt(isMedium ? 14 : 10, in: size))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }

    private var tideBackground: some View {
        LinearGradient(
            stops: [
                .init(color: usesFullColorPalette ? PulseWidgetDesign.widgetSky : .clear, location: 0),
                .init(color: usesFullColorPalette ? PulseWidgetDesign.widgetSkyMiddle : .clear, location: 0.48),
                .init(color: surfaceColor, location: 0.62),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func tideSky(size: CGSize) -> some View {
        let sunSide = pt(16, in: size)
        let skyHeight = size.height * (usesMediumMetrics ? 0.50 : 0.46)

        return ZStack(alignment: .topLeading) {
            Circle()
                .fill(fieldColor.opacity(0.35))
                .frame(width: sunSide, height: sunSide)
                .overlay {
                    Circle()
                        .stroke(fieldColor.opacity(0.08), lineWidth: pt(5, in: size))
                }
                .position(
                    x: size.width - pt(18, in: size) - sunSide / 2,
                    y: pt(14, in: size) + sunSide / 2
                )

            Rectangle()
                .fill(primaryColor.opacity(0.10))
                .frame(width: size.width * 0.84, height: pt(1, in: size))
                .position(x: size.width / 2, y: skyHeight * 0.98)
        }
        .frame(width: size.width, height: skyHeight, alignment: .topLeading)
    }

    private func tideShore(size: CGSize) -> some View {
        let shoreHeightRatio: CGFloat = snapshot.isCheckedToday
            ? (usesMediumMetrics ? 0.48 : 0.50)
            : (usesMediumMetrics ? 0.40 : 0.42)
        let shoreHeight = size.height * shoreHeightRatio
        let shoreColor = snapshot.isCheckedToday ? grassColor : fieldColor
        let fishXRatio: CGFloat = usesMediumMetrics ? 250 / 340 : 118 / 160
        let fishYRatio: CGFloat = usesMediumMetrics ? 62 / 100 : 58 / 90
        let fishScale = pt(usesMediumMetrics ? 1.15 : 0.9, in: size)

        return ZStack(alignment: .topLeading) {
            PulseTideCurve(kind: .water, usesMediumMetrics: usesMediumMetrics)
                .fill(shoreColor.opacity(snapshot.isCheckedToday ? 0.24 : 0.18))
            PulseTideCurve(kind: .lip, usesMediumMetrics: usesMediumMetrics)
                .stroke(
                    shoreColor.opacity(snapshot.isCheckedToday ? 0.75 : 0.58),
                    style: StrokeStyle(lineWidth: pt(1.7, in: size), lineCap: .round)
                )
            PulseTideCurve(kind: .foam, usesMediumMetrics: usesMediumMetrics)
                .stroke(
                    shoreColor.opacity(0.28),
                    style: StrokeStyle(lineWidth: pt(1, in: size), lineCap: .round)
                )

            PulseTideFish()
                .fill(shoreColor.opacity(snapshot.isCheckedToday ? 0.48 : 0.34))
                .frame(
                    width: (usesMediumMetrics ? 21 : 18) * fishScale,
                    height: (usesMediumMetrics ? 8 : 7) * fishScale
                )
                .position(x: size.width * fishXRatio, y: shoreHeight * fishYRatio)
        }
        .frame(width: size.width, height: shoreHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private func bleed(size: CGSize) -> some View {
        let sealSide = pt(usesMediumMetrics ? 48 : 40, in: size)
        let inset = pt(usesMediumMetrics ? 16 : 12, in: size)

        return ZStack(alignment: .topLeading) {
            baseBackground
            mistField(size: size)

            Text(verbatim: dayNumber)
                .font(.system(size: pt(usesMediumMetrics ? 112 : 76, in: size), weight: .bold))
                .foregroundStyle((snapshot.isCheckedToday ? grassColor : actionColor)
                    .opacity(snapshot.isCheckedToday ? 0.52 : 0.44))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: usesMediumMetrics ? size.width * 0.56 : size.width * 0.72)
                .offset(
                    x: pt(usesMediumMetrics ? 12 : 8, in: size),
                    y: pt(usesMediumMetrics ? 18 : 34, in: size)
                )

            Text(verbatim: monthName)
                .font(.system(size: pt(11, in: size), weight: .bold))
                .tracking(pt(0.7, in: size))
                .foregroundStyle(actionColor)
                .padding(.leading, inset)
                .padding(.top, pt(usesMediumMetrics ? 14 : 11, in: size))

            habitName(
                size: pt(usesMediumMetrics ? 22 : 16, in: size),
                width: pt(usesMediumMetrics ? 118 : 70, in: size),
                alignment: .trailing
            )
            .padding(.trailing, inset)
            .padding(.top, pt(usesMediumMetrics ? 14 : 12, in: size))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            statusLabel(size: pt(usesMediumMetrics ? 11 : 10, in: size))
                .padding(.leading, inset)
                .padding(.bottom, pt(usesMediumMetrics ? 14 : 12, in: size))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            ritualSeal(side: sealSide, showsWash: false, showsCheck: true)
                .padding(.trailing, pt(usesMediumMetrics ? 14 : 10, in: size))
                .padding(.bottom, pt(usesMediumMetrics ? 12 : 10, in: size))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    private func letter(size: CGSize) -> some View {
        let inset = pt(usesMediumMetrics ? 18 : 14, in: size)
        let sealSide = pt(usesMediumMetrics ? 58 : 52, in: size)

        return ZStack(alignment: .topLeading) {
            surfaceBackground

            Rectangle()
                .fill((snapshot.isCheckedToday ? grassColor : fieldColor).opacity(0.30))
                .frame(height: pt(5, in: size))

            if usesMediumMetrics {
                Text(verbatim: monthName)
                    .font(.system(size: pt(11, in: size), weight: .semibold))
                    .foregroundStyle(actionColor)
                    .padding(.leading, inset)
                    .padding(.top, pt(14, in: size))
                Text(verbatim: dayNumber)
                    .font(.system(size: pt(40, in: size), weight: .ultraLight))
                    .tracking(pt(-2, in: size))
                    .foregroundStyle(actionColor)
                    .monospacedDigit()
                    .padding(.leading, inset)
                    .padding(.top, pt(28, in: size))
            } else {
                Text(verbatim: monthAndDay)
                    .font(.system(size: pt(11, in: size), weight: .semibold))
                    .foregroundStyle(actionColor)
                    .padding(.leading, inset)
                    .padding(.top, pt(16, in: size))
            }

            habitName(
                size: pt(usesMediumMetrics ? 28 : 22, in: size),
                width: pt(usesMediumMetrics ? 220 : 78, in: size),
                alignment: .leading
            )
            .padding(.leading, inset)
            .padding(.top, pt(usesMediumMetrics ? 72 : 48, in: size))

            postmarkRail(size: size)
                .padding(.horizontal, inset)
                .padding(.bottom, pt(10, in: size))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            ZStack {
                Circle()
                    .fill(fieldColor.opacity(usesFullColorPalette ? 0.08 : 0.06))
                    .shadow(
                        color: shadowColor.opacity(usesFullColorPalette ? 0.08 : 0),
                        radius: pt(5, in: size),
                        y: pt(2, in: size)
                    )
                ritualSeal(side: sealSide, showsWash: false, showsCheck: true)
            }
            .frame(width: sealSide, height: sealSide)
            .padding(.trailing, pt(usesMediumMetrics ? 16 : 12, in: size))
            .padding(.top, pt(usesMediumMetrics ? 14 : 12, in: size))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }

    private func field(size: CGSize) -> some View {
        let inset = pt(usesMediumMetrics ? 15 : 12, in: size)
        let sealSide = pt(usesMediumMetrics ? 48 : 40, in: size)

        return ZStack(alignment: .topLeading) {
            surfaceBackground
            quietFieldAfterimage(size: size)

            Text(verbatim: monthAndDay)
                .font(.system(size: pt(11, in: size), weight: .bold))
                .foregroundStyle(actionColor)
                .padding(.leading, inset)
                .padding(.top, pt(usesMediumMetrics ? 13 : 12, in: size))

            habitName(
                size: pt(usesMediumMetrics ? 28 : 22, in: size),
                width: pt(usesMediumMetrics ? 230 : 112, in: size),
                alignment: .leading
            )
            .padding(.leading, inset)
            .padding(.top, pt(usesMediumMetrics ? 46 : 48, in: size))

            if usesMediumMetrics {
                statusLabel(size: pt(11, in: size))
                    .padding(.leading, inset)
                    .padding(.bottom, pt(14, in: size))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }

            ritualSeal(side: sealSide, showsWash: false, showsCheck: true)
                .padding(.trailing, pt(usesMediumMetrics ? 15 : 11, in: size))
                .padding(.bottom, pt(usesMediumMetrics ? 13 : 11, in: size))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    private func path(size: CGSize) -> some View {
        let inset = pt(12, in: size)
        let todaySide = pt(usesMediumMetrics ? 92 : 56, in: size)

        return ZStack(alignment: .topLeading) {
            surfaceBackground

            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: monthAndDay)
                Spacer(minLength: pt(8, in: size))
                statusLabel(size: pt(11, in: size))
            }
            .font(.system(size: pt(11, in: size), weight: .semibold))
            .foregroundStyle(secondaryColor)
            .padding(.horizontal, inset)
            .padding(.top, pt(11, in: size))

            habitName(
                size: pt(usesMediumMetrics ? 22 : 17, in: size),
                width: pt(usesMediumMetrics ? 154 : 104, in: size),
                alignment: .leading
            )
            .padding(.leading, inset)
            .padding(.top, pt(30, in: size))

            pathTrail(size: size)
                .padding(.leading, pt(8, in: size))
                .padding(.trailing, pt(usesMediumMetrics ? 36 : 8, in: size))
                .padding(.bottom, pt(usesMediumMetrics ? 4 : 8, in: size))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            PulsePathTodayMark(
                isChecked: snapshot.isCheckedToday,
                dayNumber: dayNumber,
                usesFullColorPalette: usesFullColorPalette
            )
            .frame(width: todaySide, height: todaySide)
            .padding(.trailing, pt(usesMediumMetrics ? 6 : 10, in: size))
            .padding(.bottom, pt(usesMediumMetrics ? 10 : 12, in: size))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    private func ritualSeal(
        side: CGFloat,
        showsWash: Bool,
        showsCheck: Bool
    ) -> some View {
        PulseRitualSealMark(
            isChecked: snapshot.isCheckedToday,
            usesFullColorPalette: usesFullColorPalette,
            actionText: actionText,
            showsWash: showsWash,
            showsCheck: showsCheck
        )
        .frame(width: side, height: side)
    }

    private func sealAfterimage(side: CGFloat, size: CGSize) -> some View {
        ZStack {
            Circle()
                .stroke(fieldColor.opacity(0.22), lineWidth: pt(1, in: size))
                .frame(width: side * 0.84, height: side * 0.84)
            Circle()
                .stroke(fieldColor.opacity(0.07), lineWidth: pt(14, in: size))
                .frame(width: side * 0.84 + pt(14, in: size), height: side * 0.84 + pt(14, in: size))
            Circle()
                .stroke(fieldColor.opacity(0.04), lineWidth: pt(14, in: size))
                .frame(width: side * 0.84 + pt(42, in: size), height: side * 0.84 + pt(42, in: size))
        }
    }

    private func stackLayers(size: CGSize) -> some View {
        let pileSide = pt(usesMediumMetrics ? 220 : 196, in: size)
        let ringSide = pileSide * 0.50
        let trailing = pt(usesMediumMetrics ? -40 : -42, in: size)
        let bottom = pt(usesMediumMetrics ? -48 : -36, in: size)
        let offsets: [(CGFloat, CGFloat, Double)] = usesMediumMetrics
            ? [(-36, -4, -7), (-20, 4, -2), (-8, 8, 4)]
            : [(-34, -8, -8), (-20, 2, -3), (-8, 8, 4)]
        let opacities = [0.11, 0.17, 0.24]

        return ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(fieldColor.opacity(opacities[index]))
                    .overlay {
                        Circle().stroke(surfaceColor, lineWidth: pt(1.4, in: size))
                    }
                    .frame(width: ringSide, height: ringSide)
                    .rotationEffect(.degrees(offsets[index].2))
                    .offset(
                        x: pt(offsets[index].0, in: size),
                        y: pt(offsets[index].1, in: size)
                    )
            }
        }
        .frame(width: pileSide, height: pileSide)
        .offset(
            x: size.width - pileSide - trailing,
            y: size.height - pileSide - bottom
        )
    }

    private func mistField(size: CGSize) -> some View {
        let color = snapshot.isCheckedToday ? grassColor : fieldColor
        return ZStack {
            Ellipse()
                .fill(color.opacity(0.10))
                .frame(width: size.width * 0.88, height: size.height * 0.43)
                .position(x: size.width * 0.30, y: size.height * (usesMediumMetrics ? 0.62 : 0.74))
            Ellipse()
                .fill(color.opacity(0.14))
                .frame(width: size.width * 0.73, height: size.height * 0.36)
                .position(x: size.width * 0.69, y: size.height * (usesMediumMetrics ? 0.70 : 0.83))
            Ellipse()
                .fill(color.opacity(0.08))
                .frame(width: size.width, height: size.height * 0.33)
                .position(x: size.width * 0.49, y: size.height * (usesMediumMetrics ? 0.84 : 0.92))
        }
    }

    private func postmarkRail(size: CGSize) -> some View {
        GeometryReader { proxy in
            let nodeSide = pt(usesMediumMetrics ? 14 : 10, in: size)
            let todaySide = pt(usesMediumMetrics ? 16 : 11.2, in: size)
            let centers = snapshot.recentDays.indices.map { index in
                proxy.size.width * CGFloat(index) / 6
            }
            ZStack(alignment: .topLeading) {
                Path { path in
                    guard let first = centers.first, let last = centers.last else { return }
                    let y = proxy.size.height * 0.68
                    path.move(to: CGPoint(x: first, y: y))
                    path.addLine(to: CGPoint(x: last, y: y))
                }
                .stroke(fieldColor.opacity(0.34), lineWidth: pt(1, in: size))

                ForEach(Array(snapshot.recentDays.enumerated()), id: \.element.id) { index, item in
                    let isToday = index == snapshot.recentDays.count - 1
                    Text(verbatim: PulseLocalizedDateFormatting.dayNumber(item.day, locale: locale))
                        .font(.system(
                            size: pt(usesMediumMetrics ? 10 : 7.5, in: size),
                            weight: isToday ? .bold : .semibold
                        ))
                        .foregroundStyle(isToday || item.state == .checked ? actionColor : secondaryColor)
                        .monospacedDigit()
                        .position(x: centers[index], y: proxy.size.height * 0.22)

                    postmarkNode(item, isToday: isToday, size: isToday ? todaySide : nodeSide)
                        .position(x: centers[index], y: proxy.size.height * 0.68)
                }
            }
        }
        .frame(height: pt(usesMediumMetrics ? 36 : 34, in: size))
    }

    private func postmarkNode(
        _ item: PulseWidgetDaySnapshot,
        isToday: Bool,
        size: CGFloat
    ) -> some View {
        ZStack {
            if isToday && !snapshot.isCheckedToday {
                Circle()
                    .trim(from: 0, to: 0.867)
                    .stroke(fieldColor, style: StrokeStyle(lineWidth: max(1, size * 0.12), lineCap: .round))
                    .rotationEffect(.degrees(-18))
            } else if item.state == .checked {
                Circle().fill(isToday ? grassColor : fieldColor)
            } else {
                Circle().stroke(secondaryColor.opacity(0.42), lineWidth: max(1, size * 0.10))
            }
        }
        .frame(width: size, height: size)
    }

    private func quietFieldAfterimage(size: CGSize) -> some View {
        let ringSide = pt(170, in: size)
        let center = CGPoint(x: size.width - pt(5, in: size), y: size.height - pt(10, in: size))
        return ZStack {
            Circle()
                .stroke(fieldColor.opacity(0.25), lineWidth: pt(1, in: size))
                .frame(width: ringSide, height: ringSide)
            Circle()
                .stroke(fieldColor.opacity(0.06), lineWidth: pt(14, in: size))
                .frame(width: ringSide + pt(14, in: size), height: ringSide + pt(14, in: size))
            Circle()
                .stroke(fieldColor.opacity(0.05), lineWidth: pt(18, in: size))
                .frame(width: ringSide + pt(46, in: size), height: ringSide + pt(46, in: size))
        }
        .position(center)
    }

    private func pathTrail(size: CGSize) -> some View {
        GeometryReader { proxy in
            let days = Array(snapshot.recentDays.dropLast())
            let baseWidth: CGFloat = usesMediumMetrics ? 294 : 142
            let baseHeight: CGFloat = usesMediumMetrics ? 120 : 86
            let rawPoints: [CGPoint] = usesMediumMetrics
                ? [
                    CGPoint(x: 16, y: 104), CGPoint(x: 56, y: 98),
                    CGPoint(x: 98, y: 88), CGPoint(x: 140, y: 80),
                    CGPoint(x: 180, y: 74), CGPoint(x: 220, y: 70),
                ]
                : [
                    CGPoint(x: 10, y: 74), CGPoint(x: 24, y: 70),
                    CGPoint(x: 38, y: 65), CGPoint(x: 52, y: 61),
                    CGPoint(x: 66, y: 58), CGPoint(x: 80, y: 56),
                ]
            let points = rawPoints.map {
                CGPoint(x: $0.x / baseWidth * proxy.size.width, y: $0.y / baseHeight * proxy.size.height)
            }
            let end = CGPoint(
                x: (usesMediumMetrics ? 278 : 112) / baseWidth * proxy.size.width,
                y: (usesMediumMetrics ? 68 : 54) / baseHeight * proxy.size.height
            )

            ZStack(alignment: .topLeading) {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for index in 1..<points.count {
                        let previous = points[index - 1]
                        let current = points[index]
                        let midpoint = (previous.x + current.x) / 2
                        path.addCurve(
                            to: current,
                            control1: CGPoint(x: midpoint, y: previous.y),
                            control2: CGPoint(x: midpoint, y: current.y)
                        )
                    }
                    if let previous = points.last {
                        path.addCurve(
                            to: end,
                            control1: CGPoint(x: (previous.x + end.x) / 2, y: previous.y),
                            control2: CGPoint(x: (previous.x + end.x) / 2, y: end.y)
                        )
                    }
                }
                .stroke(
                    fieldColor.opacity(0.32),
                    style: StrokeStyle(lineWidth: pt(1.35, in: size), lineCap: .round)
                )

                ForEach(Array(days.enumerated()), id: \.element.id) { index, item in
                    let radii: [CGFloat] = usesMediumMetrics
                        ? [4, 3.6, 6.2, 7.4, 4.6, 8.5]
                        : [2.4, 2.2, 3.5, 4.2, 2.6, 4.8]
                    Text(verbatim: PulseLocalizedDateFormatting.dayNumber(item.day, locale: locale))
                        .font(.system(size: pt(usesMediumMetrics ? 9 : 7.5, in: size), weight: .semibold))
                        .foregroundStyle(secondaryColor)
                        .monospacedDigit()
                        .position(
                            x: points[index].x,
                            y: points[index].y - pt(usesMediumMetrics ? 13 : 9, in: size)
                        )

                    Circle()
                        .fill(item.state == .checked ? fieldColor : .clear)
                        .overlay {
                            if item.state != .checked {
                                Circle().stroke(
                                    secondaryColor.opacity(0.40),
                                    lineWidth: pt(1.3, in: size)
                                )
                            }
                        }
                        .frame(
                            width: pt(radii[index] * 2, in: size),
                            height: pt(radii[index] * 2, in: size)
                        )
                        .position(points[index])
                }
            }
        }
        .frame(height: pt(usesMediumMetrics ? 120 : 86, in: size))
    }

    private func habitName(
        size: CGFloat,
        width: CGFloat,
        alignment: TextAlignment
    ) -> some View {
        Text(verbatim: snapshot.habitName)
            .font(.system(size: size, weight: .semibold))
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

    private var baseBackground: Color {
        usesFullColorPalette ? PulseWidgetDesign.background : .clear
    }

    private var surfaceBackground: Color {
        usesFullColorPalette ? PulseWidgetDesign.surface : .clear
    }

    private var surfaceColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.surface : .clear
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
        usesFullColorPalette ? PulseWidgetDesign.field : .primary
    }

    private var shadowColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.shadow : .clear
    }

    private var monthAndDay: String {
        PulseLocalizedDateFormatting.monthAndDay(snapshot.today, locale: locale)
    }

    private var monthName: String {
        PulseLocalizedDateFormatting.monthName(snapshot.today, locale: locale)
    }

    private var dayNumber: String {
        PulseLocalizedDateFormatting.dayNumber(snapshot.today, locale: locale)
    }

    private var tideDate: String {
        usesMediumMetrics
            ? PulseLocalizedDateFormatting.monthDayAndWeekday(snapshot.today, locale: locale)
            : monthAndDay
    }

    private var tideFootColor: Color {
        guard snapshot.isCheckedToday else { return secondaryColor }
        return usesFullColorPalette ? primaryColor.opacity(0.78) : .primary
    }

    private func pt(_ value: CGFloat, in size: CGSize) -> CGFloat {
        value * size.height / 158
    }
}

private struct PulseTideDayMark: View {
    let isChecked: Bool
    let usesFullColorPalette: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(ringColor.opacity(isChecked ? 0.22 : 0.12))
                    .frame(width: side * 0.52, height: side * 0.52)

                if isChecked {
                    Circle()
                        .stroke(ringColor, lineWidth: side * 0.052)
                        .padding(side * 0.052 / 2)
                } else {
                    Circle()
                        .trim(from: 0, to: 0.867)
                        .stroke(
                            ringColor,
                            style: StrokeStyle(lineWidth: side * 0.052, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-18))
                        .padding(side * 0.052 / 2)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    private var ringColor: Color {
        guard usesFullColorPalette else { return .primary }
        return isChecked ? PulseWidgetDesign.grass : PulseWidgetDesign.field
    }
}

private struct PulseTideCurve: Shape {
    enum Kind {
        case water
        case lip
        case foam
    }

    let kind: Kind
    let usesMediumMetrics: Bool

    func path(in rect: CGRect) -> Path {
        let referenceWidth: CGFloat = usesMediumMetrics ? 340 : 160
        let referenceHeight: CGFloat = usesMediumMetrics ? 100 : 90
        let points: [CGPoint]

        if usesMediumMetrics {
            points = kind == .foam
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
            points = kind == .foam
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

private struct PulseTideFish: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(ellipseIn: CGRect(
            x: rect.minX,
            y: rect.midY - rect.height * 0.40,
            width: rect.width * 0.66,
            height: rect.height * 0.80
        ))
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.58, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct PulseRitualSealMark: View {
    let isChecked: Bool
    let usesFullColorPalette: Bool
    let actionText: String
    let showsWash: Bool
    let showsCheck: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                if showsWash {
                    ritualRing(color: ringColor.opacity(0.22), width: side * 0.18)
                }
                ritualRing(color: ringColor, width: side * 0.055)

                Circle()
                    .fill(ringColor.opacity(isChecked ? 1 : 0.10))
                    .frame(width: side * 0.40, height: side * 0.40)

                if isChecked, showsCheck {
                    Image(systemName: "checkmark")
                        .font(.system(size: side * 0.22, weight: .bold))
                        .foregroundStyle(usesFullColorPalette ? completedForeground : Color.black)
                        .blendMode(usesFullColorPalette ? .normal : .destinationOut)
                } else if !isChecked {
                    Text(verbatim: actionText)
                        .font(.system(size: side * 0.14, weight: .bold))
                        .foregroundStyle(actionColor)
                        .minimumScaleFactor(0.66)
                        .lineLimit(1)
                        .padding(.horizontal, side * 0.05)
                }
            }
            .compositingGroup()
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func ritualRing(color: Color, width: CGFloat) -> some View {
        if isChecked {
            Circle().stroke(color, lineWidth: width).padding(width / 2)
        } else {
            Circle()
                .trim(from: 0, to: 0.867)
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-18))
                .padding(width / 2)
        }
    }

    private var ringColor: Color {
        guard usesFullColorPalette else { return .primary }
        return isChecked ? PulseWidgetDesign.grass : PulseWidgetDesign.field
    }

    private var actionColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.action : .primary
    }

    private var completedForeground: Color {
        PulseWidgetDesign.grassForeground
    }
}

private struct PulsePathTodayMark: View {
    let isChecked: Bool
    let dayNumber: String
    let usesFullColorPalette: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                if isChecked {
                    Circle()
                        .stroke(ringColor, lineWidth: side * 0.055)
                        .padding(side * 0.055 / 2)
                } else {
                    Circle()
                        .trim(from: 0, to: 0.867)
                        .stroke(
                            ringColor,
                            style: StrokeStyle(lineWidth: side * 0.055, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-18))
                        .padding(side * 0.055 / 2)
                }
                Circle()
                    .fill(ringColor.opacity(isChecked ? 0.18 : 0.12))
                    .frame(width: side * 0.40, height: side * 0.40)
                Text(verbatim: dayNumber)
                    .font(.system(size: side * 0.39, weight: .semibold))
                    .foregroundStyle(inkColor)
                    .monospacedDigit()
                    .minimumScaleFactor(0.74)
                    .lineLimit(1)
            }
        }
        .accessibilityHidden(true)
    }

    private var ringColor: Color {
        guard usesFullColorPalette else { return .primary }
        return isChecked ? PulseWidgetDesign.grass : PulseWidgetDesign.field
    }

    private var inkColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.ink : .primary
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
                PulsePrototypeRing(
                    color: isChecked ? completedColor : pendingColor,
                    isClosed: isChecked
                )
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
    let isClosed: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            if isClosed {
                Circle()
                    .stroke(color, lineWidth: side * 0.09)
                    .padding(side * PulseWidgetDesign.prototypeRingInsetRatio)
                    .frame(width: side, height: side)
            } else {
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
    static let shadow = Color("PulseShadow")
    static let widgetSky = Color("PulseWidgetSky")
    static let widgetSkyMiddle = Color("PulseWidgetSkyMiddle")

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
