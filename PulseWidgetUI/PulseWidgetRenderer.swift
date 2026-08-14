import PulseCore
import SwiftUI
import WidgetKit

enum PulseWidgetStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case place
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
    static let freeStyle = PulseWidgetStyle.place

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
    let allowsMotion: Bool
    let statusText: String
    let pathSummaryFormat: String
    let actionText: String
    let emptyPlaceText: String
    let placeStatusText: String

    @Environment(\.locale) private var locale

    var body: some View {
        GeometryReader { proxy in
            Group {
                switch style {
                case .place:
                    place(size: proxy.size)
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

    private func place(size: CGSize) -> some View {
        let blotterSide = pt(usesMediumMetrics ? 122 : 86, in: size)

        return ZStack(alignment: .topLeading) {
            baseBackground
            placeAmbientField(size: size)

            if usesMediumMetrics {
                awaitingPlaceBlotter(side: blotterSide, size: size)
                    .position(
                        x: pt(18, in: size) + blotterSide / 2,
                        y: size.height / 2
                    )

                VStack(alignment: .leading, spacing: pt(10, in: size)) {
                    Text(verbatim: PulseLocalizedDateFormatting.monthDayAndWeekday(
                        snapshot.today,
                        locale: locale
                    ))
                    .font(.system(size: pt(13, in: size), weight: .bold))
                    .tracking(pt(0.5, in: size))
                    .foregroundStyle(actionColor)
                    .lineLimit(1)

                    habitName(
                        size: pt(22, in: size),
                        width: pt(166, in: size),
                        alignment: .leading
                    )

                    Spacer(minLength: 0)

                    Text(verbatim: placeStatusText)
                        .font(.system(size: pt(12, in: size), weight: .medium))
                        .foregroundStyle(secondaryColor)
                        .lineLimit(1)
                }
                .frame(
                    width: pt(166, in: size),
                    height: size.height - pt(40, in: size),
                    alignment: .topLeading
                )
                .padding(.leading, pt(154, in: size))
                .padding(.top, pt(20, in: size))
            } else {
                VStack(spacing: 0) {
                    Text(verbatim: monthAndDay)
                        .font(.system(size: pt(11, in: size), weight: .bold))
                        .tracking(pt(0.7, in: size))
                        .foregroundStyle(actionColor)
                        .monospacedDigit()
                        .lineLimit(1)

                    Spacer(minLength: pt(7, in: size))

                    awaitingPlaceBlotter(side: blotterSide, size: size)

                    Spacer(minLength: pt(7, in: size))

                    habitName(
                        size: pt(13, in: size),
                        width: pt(130, in: size),
                        alignment: .center
                    )
                }
                .padding(.top, pt(12, in: size))
                .padding(.bottom, pt(12, in: size))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func awaitingPlaceBlotter(side: CGFloat, size: CGSize) -> some View {
        RoundedRectangle(
            cornerRadius: side * (usesMediumMetrics ? 32 / 122 : 24 / 86),
            style: .continuous
        )
        .fill((snapshot.isCheckedToday ? grassColor : fieldColor).opacity(0.09))
        .overlay {
            RoundedRectangle(
                cornerRadius: side * (usesMediumMetrics ? 32 / 122 : 24 / 86),
                style: .continuous
            )
            .stroke(primaryColor.opacity(0.05), lineWidth: pt(1, in: size))
        }
        .overlay {
            PulseAwaitingPlaceWell(
                isChecked: snapshot.isCheckedToday,
                usesFullColorPalette: usesFullColorPalette,
                emptyText: emptyPlaceText
            )
            .frame(
                width: side * (usesMediumMetrics ? 74 / 122 : 52 / 86),
                height: side * (usesMediumMetrics ? 74 / 122 : 52 / 86)
            )
        }
        .frame(width: side, height: side)
        .animation(motion(.place), value: snapshot.isCheckedToday)
    }

    private func seal(size: CGSize) -> some View {
        let stampSide = pt(usesMediumMetrics ? 128 : 110, in: size)
        let stampX = pt(usesMediumMetrics ? 10 : 4, in: size) + stampSide / 2
        let copyX = pt(usesMediumMetrics ? 156 : 12, in: size)

        return ZStack(alignment: .topLeading) {
            baseBackground
            sealAmbientField(size: size)

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
        let sealSide = pt(usesMediumMetrics ? 106 : 78, in: size)
        let paperFrame = stackTopPaperFrame(in: size)
        let paperInset = pt(usesMediumMetrics ? 10 : 8, in: size)

        return ZStack(alignment: .topLeading) {
            baseBackground
            stackDeskMat(size: size)
            stackedPaperBackdrop(size: size)

            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: pt(usesMediumMetrics ? 7 : 6, in: size)) {
                    Text(verbatim: monthAndDay)
                        .font(.system(size: pt(usesMediumMetrics ? 12 : 11, in: size), weight: .bold))
                        .tracking(pt(usesMediumMetrics ? 0.5 : 0.4, in: size))
                        .foregroundStyle(actionColor)
                        .monospacedDigit()
                        .lineLimit(1)

                    habitName(
                        size: pt(usesMediumMetrics ? 23 : 16, in: size),
                        width: pt(usesMediumMetrics ? 154 : 88, in: size),
                        alignment: .leading
                    )

                    if usesMediumMetrics {
                        Spacer(minLength: 0)
                        statusLabel(size: pt(11, in: size))
                    }
                }
                .frame(
                    width: pt(usesMediumMetrics ? 154 : 88, in: size),
                    height: usesMediumMetrics ? paperFrame.height - paperInset * 2 : nil,
                    alignment: .topLeading
                )
                .padding(.leading, paperInset)
                .padding(.top, paperInset)

                ritualSeal(side: sealSide, showsWash: false, showsCheck: true)
                    .padding(.trailing, paperInset)
                    .padding(.bottom, paperInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .frame(width: paperFrame.width, height: paperFrame.height)
            .position(x: paperFrame.midX, y: paperFrame.midY)
        }
    }

    private func tide(size: CGSize) -> some View {
        let isMedium = usesMediumMetrics
        let inset = pt(isMedium ? 16 : 12, in: size)
        let markSide = pt(isMedium ? 58 : 40, in: size)
        let shoreHeightRatio = snapshot.isCheckedToday
            ? (isMedium
                ? PulseWidgetDesign.tideCheckedHeightRatioMedium
                : PulseWidgetDesign.tideCheckedHeightRatioSmall)
            : (isMedium
                ? PulseWidgetDesign.tidePendingHeightRatioMedium
                : PulseWidgetDesign.tidePendingHeightRatioSmall)
        let shoreHeight = size.height * shoreHeightRatio
        let markX = isMedium
            ? size.width - pt(28, in: size) - markSide / 2
            : size.width * PulseWidgetDesign.tideSmallMarkXRatio
        let markY = size.height - shoreHeight * PulseWidgetDesign.tideLipInverseRatio
        let copyWidth = isMedium ? size.width - pt(126, in: size) : pt(76, in: size)

        return ZStack(alignment: .topLeading) {
            baseBackground
            tideShore(size: size, shoreHeight: shoreHeight)

            PulseTideDayMark(
                isChecked: snapshot.isCheckedToday,
                usesFullColorPalette: usesFullColorPalette
            )
            .frame(width: markSide, height: markSide)
            .position(x: markX, y: markY)
            .animation(motion(.tide), value: snapshot.isCheckedToday)

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

    private func tideShore(size: CGSize, shoreHeight: CGFloat) -> some View {
        let shoreColor = snapshot.isCheckedToday ? grassColor : fieldColor

        return ZStack(alignment: .topLeading) {
            PulseTideCurve(kind: .water, usesMediumMetrics: usesMediumMetrics)
                .fill(shoreColor.opacity(snapshot.isCheckedToday ? 0.24 : 0.18))
            PulseTideCurve(kind: .lip, usesMediumMetrics: usesMediumMetrics)
                .stroke(
                    shoreColor.opacity(snapshot.isCheckedToday ? 0.75 : 0.58),
                    style: StrokeStyle(lineWidth: pt(1.7, in: size), lineCap: .round)
                )
            PulseTideCurve(kind: .trace, usesMediumMetrics: usesMediumMetrics)
                .stroke(
                    shoreColor.opacity(snapshot.isCheckedToday ? 0.24 : 0.18),
                    style: StrokeStyle(lineWidth: pt(1, in: size), lineCap: .round)
                )
        }
        .frame(width: size.width, height: shoreHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(motion(.tide), value: snapshot.isCheckedToday)
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
                .scaleEffect(snapshot.isCheckedToday ? 1 : 1.035, anchor: .leading)
                .animation(motion(.number), value: snapshot.isCheckedToday)

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
        let inset = pt(usesMediumMetrics ? 22 : 18, in: size)
        let sealSide = pt(usesMediumMetrics ? 62 : 48, in: size)

        return ZStack(alignment: .topLeading) {
            baseBackground
            letterDeskField(size: size)
            letterPaper(size: size)
            letterWritingLines(size: size)

            if usesMediumMetrics {
                Text(verbatim: monthName)
                    .font(.system(size: pt(11, in: size), weight: .semibold))
                    .foregroundStyle(actionColor)
                    .padding(.leading, inset)
                    .padding(.top, pt(14, in: size))
                Text(verbatim: dayNumber)
                    .font(.system(size: pt(38, in: size), weight: .light))
                    .tracking(pt(-1.5, in: size))
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

            postmarkRow(size: size)
                .padding(.horizontal, inset)
                .padding(.bottom, pt(usesMediumMetrics ? 14 : 12, in: size))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            ZStack {
                Circle()
                    .fill(fieldColor.opacity(usesFullColorPalette ? 0.11 : 0.07))
                    .shadow(
                        color: shadowColor.opacity(usesFullColorPalette ? 0.10 : 0),
                        radius: pt(5, in: size),
                        y: pt(2, in: size)
                    )
                ritualSeal(side: sealSide, showsWash: false, showsCheck: true)
            }
            .frame(width: sealSide, height: sealSide)
            .scaleEffect(snapshot.isCheckedToday ? 1 : 0.94)
            .animation(motion(.letter), value: snapshot.isCheckedToday)
            .padding(.trailing, pt(usesMediumMetrics ? 16 : 12, in: size))
            .padding(.top, pt(usesMediumMetrics ? 14 : 12, in: size))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }

    private func letterPaper(size: CGSize) -> some View {
        let cornerRadius = pt(usesMediumMetrics ? 17 : 15, in: size)
        let paperWidth = size.width - pt(usesMediumMetrics ? 14 : 12, in: size)
        let paperHeight = size.height - pt(usesMediumMetrics ? 16 : 14, in: size)

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(surfaceColor)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(fieldColor.opacity(0.18), lineWidth: pt(1, in: size))
                }
                .shadow(
                    color: shadowColor.opacity(0.07),
                    radius: pt(6, in: size),
                    y: pt(3, in: size)
                )
                .frame(width: paperWidth, height: paperHeight)

            Rectangle()
                .fill(fieldColor.opacity(usesFullColorPalette ? 0.11 : 0.06))
                .frame(width: pt(7, in: size), height: paperHeight)
        }
        .frame(width: paperWidth, height: paperHeight, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .frame(width: size.width, height: size.height)
    }

    private func letterWritingLines(size: CGSize) -> some View {
        let paperInset = pt(usesMediumMetrics ? 22 : 18, in: size)
        let lineWidth = size.width * (usesMediumMetrics ? 0.58 : 0.60)
        let firstY = size.height * (usesMediumMetrics ? 0.61 : 0.59)

        return VStack(alignment: .leading, spacing: pt(usesMediumMetrics ? 11 : 9, in: size)) {
            Rectangle()
                .fill(secondaryColor.opacity(usesFullColorPalette ? 0.12 : 0.08))
                .frame(width: lineWidth, height: pt(1, in: size))
            Rectangle()
                .fill(secondaryColor.opacity(usesFullColorPalette ? 0.09 : 0.06))
                .frame(width: lineWidth * 0.72, height: pt(1, in: size))
        }
        .position(
            x: paperInset + lineWidth / 2,
            y: firstY
        )
    }

    private func field(size: CGSize) -> some View {
        let inset = pt(usesMediumMetrics ? 15 : 12, in: size)
        let sealSide = pt(usesMediumMetrics ? 48 : 40, in: size)

        return ZStack(alignment: .topLeading) {
            baseBackground
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
            baseBackground
            pathGround(size: size)

            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: monthAndDay)
                Spacer(minLength: pt(8, in: size))
                Text(verbatim: pathSummaryText)
                    .font(.system(size: pt(11, in: size), weight: .medium))
                    .lineLimit(1)
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
            .animation(motion(.footprint), value: snapshot.isCheckedToday)
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
        .animation(motion(materialForCurrentStyle), value: snapshot.isCheckedToday)
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

    private func placeAmbientField(size: CGSize) -> some View {
        let color = snapshot.isCheckedToday ? grassColor : fieldColor

        return Ellipse()
            .fill(color.opacity(usesFullColorPalette ? 0.085 : 0.055))
            .frame(
                width: size.width * (usesMediumMetrics ? 0.58 : 0.92),
                height: size.height * (usesMediumMetrics ? 1.18 : 0.72)
            )
            .rotationEffect(.degrees(usesMediumMetrics ? -8 : -4))
            .scaleEffect(snapshot.isCheckedToday ? 1.03 : 1)
            .animation(motion(.place), value: snapshot.isCheckedToday)
            .position(
                x: size.width * (usesMediumMetrics ? 0.20 : 0.46),
                y: size.height * (usesMediumMetrics ? 0.54 : 0.50)
            )
    }

    private func sealAmbientField(size: CGSize) -> some View {
        let color = snapshot.isCheckedToday ? grassColor : fieldColor

        return ZStack {
            Circle()
                .fill(color.opacity(usesFullColorPalette ? 0.075 : 0.045))
                .frame(
                    width: size.height * (usesMediumMetrics ? 1.32 : 1.08),
                    height: size.height * (usesMediumMetrics ? 1.32 : 1.08)
                )
                .position(
                    x: size.width * (usesMediumMetrics ? 0.22 : 0.28),
                    y: size.height * 0.50
                )

            Circle()
                .stroke(
                    color.opacity(usesFullColorPalette ? 0.10 : 0.06),
                    lineWidth: pt(18, in: size)
                )
                .frame(
                    width: size.height * (usesMediumMetrics ? 1.56 : 1.28),
                    height: size.height * (usesMediumMetrics ? 1.56 : 1.28)
                )
                .position(
                    x: size.width * (usesMediumMetrics ? 0.22 : 0.28),
                    y: size.height * 0.50
                )
        }
        .scaleEffect(snapshot.isCheckedToday ? 1.04 : 0.98)
        .animation(motion(.ink), value: snapshot.isCheckedToday)
    }

    private func stackDeskMat(size: CGSize) -> some View {
        let color = snapshot.isCheckedToday ? grassColor : fieldColor

        return RoundedRectangle(
            cornerRadius: pt(usesMediumMetrics ? 26 : 22, in: size),
            style: .continuous
        )
        .fill(color.opacity(usesFullColorPalette ? 0.085 : 0.05))
        .frame(
            width: size.width - pt(usesMediumMetrics ? 10 : 12, in: size),
            height: size.height - pt(usesMediumMetrics ? 8 : 10, in: size)
        )
        .rotationEffect(.degrees(usesMediumMetrics ? 1.3 : 1.8))
        .scaleEffect(snapshot.isCheckedToday ? 0.99 : 1)
        .animation(motion(.paper), value: snapshot.isCheckedToday)
        .position(x: size.width / 2, y: size.height / 2 + pt(2, in: size))
    }

    private func stackedPaperBackdrop(size: CGSize) -> some View {
        let paperFrame = stackTopPaperFrame(in: size)
        let pendingLayerStep = usesMediumMetrics
            ? PulseWidgetDesign.stackPendingLayerStepMedium
            : PulseWidgetDesign.stackPendingLayerStepSmall
        let checkedLayerStep = usesMediumMetrics
            ? PulseWidgetDesign.stackCheckedLayerStepMedium
            : PulseWidgetDesign.stackCheckedLayerStepSmall
        let layerStep = pt(snapshot.isCheckedToday ? checkedLayerStep : pendingLayerStep, in: size)

        return ZStack {
            ForEach(0..<PulseWidgetDesign.stackPhysicalSheetCount, id: \.self) { index in
                let depth = PulseWidgetDesign.stackPhysicalSheetCount - 1 - index
                RoundedRectangle(
                    cornerRadius: pt(usesMediumMetrics ? 19 : 17, in: size),
                    style: .continuous
                )
                .fill(surfaceColor.opacity(0.98 - Double(depth) * 0.055))
                .overlay {
                    RoundedRectangle(
                        cornerRadius: pt(usesMediumMetrics ? 19 : 17, in: size),
                        style: .continuous
                    )
                    .stroke(
                        fieldColor.opacity(0.13 + Double(depth) * 0.04),
                        lineWidth: pt(1, in: size)
                    )
                }
                .shadow(
                    color: shadowColor.opacity(0.05 + Double(depth) * 0.015),
                    radius: pt(4 + CGFloat(depth), in: size),
                    y: pt(2, in: size)
                )
                .frame(width: paperFrame.width, height: paperFrame.height)
                .rotationEffect(.degrees(Double(depth) * (usesMediumMetrics ? -0.65 : -0.9)))
                .offset(
                    x: -CGFloat(depth) * layerStep,
                    y: CGFloat(depth) * layerStep
                )
            }
        }
        .frame(width: paperFrame.width, height: paperFrame.height)
        .position(x: paperFrame.midX, y: paperFrame.midY)
        .animation(motion(.paper), value: snapshot.isCheckedToday)
    }

    private func stackTopPaperFrame(in size: CGSize) -> CGRect {
        let width = size.width - pt(usesMediumMetrics ? 22 : 24, in: size)
        let height = size.height - pt(usesMediumMetrics ? 22 : 24, in: size)
        let center = CGPoint(
            x: size.width / 2 + pt(usesMediumMetrics ? 3 : 4, in: size),
            y: size.height / 2 - pt(usesMediumMetrics ? 8 : 9, in: size) / 2
        )

        return CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
    }

    private func letterDeskField(size: CGSize) -> some View {
        let color = snapshot.isCheckedToday ? grassColor : fieldColor

        return Ellipse()
            .fill(color.opacity(usesFullColorPalette ? 0.065 : 0.04))
            .frame(width: size.width * 0.94, height: size.height * 0.68)
            .rotationEffect(.degrees(-4))
            .position(x: size.width * 0.48, y: size.height * 0.58)
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
        .scaleEffect(x: snapshot.isCheckedToday ? 0.98 : 1.03, y: 1)
        .animation(motion(.number), value: snapshot.isCheckedToday)
    }

    private func postmarkRow(size: CGSize) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(snapshot.recentDays.enumerated()), id: \.element.id) { index, item in
                let isToday = index == snapshot.recentDays.count - 1
                postmarkNode(
                    item,
                    isToday: isToday,
                    size: pt(usesMediumMetrics ? 16 : 11.5, in: size)
                )
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: pt(usesMediumMetrics ? 18 : 13, in: size))
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
                Circle()
                    .fill(isToday ? grassColor : fieldColor)
                    .overlay {
                        Circle().stroke(surfaceColor.opacity(0.72), lineWidth: max(1, size * 0.07))
                    }
            } else {
                Circle().stroke(secondaryColor.opacity(0.42), lineWidth: max(1, size * 0.10))
            }
        }
        .frame(width: size, height: size)
    }

    private func quietFieldAfterimage(size: CGSize) -> some View {
        let ringSide = pt(usesMediumMetrics ? 188 : 172, in: size)
        let center = CGPoint(
            x: size.width - pt(usesMediumMetrics ? 8 : 4, in: size),
            y: size.height - pt(usesMediumMetrics ? 7 : 6, in: size)
        )
        let color = snapshot.isCheckedToday ? grassColor : fieldColor

        return ZStack {
            Circle()
                .fill(color.opacity(snapshot.isCheckedToday ? 0.15 : 0.12))
                .frame(width: ringSide * 0.82, height: ringSide * 0.82)
            Circle()
                .stroke(color.opacity(0.38), lineWidth: pt(1.2, in: size))
                .frame(width: ringSide, height: ringSide)
            Circle()
                .stroke(color.opacity(0.13), lineWidth: pt(16, in: size))
                .frame(width: ringSide + pt(20, in: size), height: ringSide + pt(20, in: size))
            Circle()
                .stroke(color.opacity(0.065), lineWidth: pt(20, in: size))
                .frame(width: ringSide + pt(58, in: size), height: ringSide + pt(58, in: size))
        }
        .scaleEffect(snapshot.isCheckedToday ? 1.06 : 0.96)
        .animation(motion(.echo), value: snapshot.isCheckedToday)
        .position(center)
    }

    private func pathGround(size: CGSize) -> some View {
        let color = snapshot.isCheckedToday ? grassColor : fieldColor

        return ZStack {
            Ellipse()
                .fill(color.opacity(usesFullColorPalette ? 0.075 : 0.045))
                .frame(width: size.width * 1.12, height: size.height * 0.45)
                .rotationEffect(.degrees(-6))
                .position(x: size.width * 0.43, y: size.height * 0.78)

            Ellipse()
                .stroke(
                    color.opacity(usesFullColorPalette ? 0.12 : 0.07),
                    lineWidth: pt(1, in: size)
                )
                .frame(width: size.width * 0.82, height: size.height * 0.28)
                .rotationEffect(.degrees(-6))
                .position(x: size.width * 0.48, y: size.height * 0.76)
        }
        .animation(motion(.footprint), value: snapshot.isCheckedToday)
    }

    private func pathTrail(size: CGSize) -> some View {
        GeometryReader { proxy in
            let days = Array(snapshot.recentDays.dropLast())
            let baseWidth: CGFloat = usesMediumMetrics ? 294 : 142
            let baseHeight: CGFloat = usesMediumMetrics ? 120 : 86
            let rawPoints: [CGPoint] = usesMediumMetrics
                ? [
                    CGPoint(x: 16, y: 106), CGPoint(x: 52, y: 94),
                    CGPoint(x: 86, y: 102), CGPoint(x: 126, y: 82),
                    CGPoint(x: 168, y: 90), CGPoint(x: 214, y: 64),
                ]
                : [
                    CGPoint(x: 10, y: 76), CGPoint(x: 24, y: 68),
                    CGPoint(x: 38, y: 74), CGPoint(x: 53, y: 60),
                    CGPoint(x: 69, y: 66), CGPoint(x: 87, y: 50),
                ]
            let points = rawPoints.map {
                CGPoint(x: $0.x / baseWidth * proxy.size.width, y: $0.y / baseHeight * proxy.size.height)
            }

            ZStack(alignment: .topLeading) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, item in
                    let sides: [CGFloat] = usesMediumMetrics
                        ? [8, 10, 12, 15, 18, 22]
                        : [5.5, 6.5, 7.5, 9, 10.5, 12.5]
                    let angles: [Double] = [-22, 18, -14, 20, -12, 16]

                    pathFootprint(
                        item,
                        side: pt(sides[index], in: size),
                        angle: angles[index]
                    )
                    .position(points[index])
                }
            }
        }
        .frame(height: pt(usesMediumMetrics ? 120 : 86, in: size))
    }

    private func pathFootprint(
        _ item: PulseWidgetDaySnapshot,
        side: CGFloat,
        angle: Double
    ) -> some View {
        let isChecked = item.state == .checked

        return ZStack(alignment: .top) {
            HStack(alignment: .bottom, spacing: side * 0.055) {
                Circle()
                    .frame(width: side * 0.17, height: side * 0.17)
                Circle()
                    .frame(width: side * 0.20, height: side * 0.20)
                Circle()
                    .frame(width: side * 0.15, height: side * 0.15)
            }
            .foregroundStyle(isChecked ? fieldColor.opacity(0.84) : secondaryColor.opacity(0.42))

            Capsule(style: .continuous)
                .fill(isChecked ? fieldColor : .clear)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            isChecked ? fieldColor.opacity(0.76) : secondaryColor.opacity(0.48),
                            lineWidth: max(1, side * 0.11)
                        )
                }
                .frame(width: side * 0.58, height: side * 0.82)
                .offset(y: side * 0.28)
        }
        .frame(width: side, height: side * 1.12)
        .rotationEffect(.degrees(angle))
        .opacity(item.state == .beforeHabit ? 0.42 : 1)
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

    private var pathSummaryText: String {
        return String(
            format: pathSummaryFormat,
            locale: locale,
            Int32(snapshot.previousSixCheckedCount)
        )
    }

    private var materialForCurrentStyle: PulseWidgetMotionPresentation.Material {
        switch style {
        case .place: .place
        case .seal: .ink
        case .stack: .paper
        case .bleed: .number
        case .letter: .letter
        case .field: .echo
        case .path: .footprint
        case .tide: .tide
        }
    }

    private func motion(_ material: PulseWidgetMotionPresentation.Material) -> Animation? {
        PulseWidgetMotionPresentation.animation(for: material, allowsMotion: allowsMotion)
    }

    private func pt(_ value: CGFloat, in size: CGSize) -> CGFloat {
        value * size.height / 158
    }
}

private struct PulseAwaitingPlaceWell: View {
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

                if isChecked {
                    ZStack {
                        Circle().fill(completedColor)
                        Image(systemName: "checkmark")
                            .font(.system(size: side * 0.31, weight: .semibold))
                            .foregroundStyle(usesFullColorPalette
                                ? PulseWidgetDesign.grassForeground
                                : Color.black)
                            .blendMode(usesFullColorPalette ? .normal : .destinationOut)
                    }
                    .compositingGroup()
                    .frame(width: side * 0.70, height: side * 0.70)
                } else {
                    Circle()
                        .fill(surfaceColor.opacity(0.82))
                        .frame(width: side * 0.58, height: side * 0.58)

                    Text(verbatim: emptyText)
                        .font(.system(size: side * 0.22, weight: .bold))
                        .foregroundStyle(actionColor)
                        .minimumScaleFactor(0.70)
                        .lineLimit(1)
                        .frame(width: side * 0.52)
                }
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

                PulseStateRing(
                    isChecked: isChecked,
                    color: ringColor,
                    lineWidth: side * 0.052
                )
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
                    PulseStateRing(
                        isChecked: isChecked,
                        color: ringColor.opacity(0.22),
                        lineWidth: side * 0.18
                    )
                }
                PulseStateRing(
                    isChecked: isChecked,
                    color: ringColor,
                    lineWidth: side * 0.055
                )

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
                PulseStateRing(
                    isChecked: isChecked,
                    color: ringColor,
                    lineWidth: side * 0.055
                )
                Circle()
                    .fill(ringColor.opacity(isChecked ? 0.18 : 0.12))
                    .frame(width: side * 0.40, height: side * 0.40)
                Text(verbatim: dayNumber)
                    .font(.system(size: side * 0.39, weight: .semibold))
                    .foregroundStyle(inkColor)
                    .monospacedDigit()
                    .minimumScaleFactor(0.74)
                    .lineLimit(1)

                if isChecked {
                    Circle()
                        .fill(ringColor)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.system(size: side * 0.12, weight: .bold))
                                .foregroundStyle(completedForeground)
                        }
                        .frame(width: side * 0.27, height: side * 0.27)
                        .offset(x: side * 0.34, y: side * 0.34)
                }
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

    private var completedForeground: Color {
        usesFullColorPalette ? PulseWidgetDesign.grassForeground : .black
    }
}

private struct PulseStateRing: View {
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
    static let stackPhysicalSheetCount = 4

    static let stackPendingLayerStepMedium: CGFloat = 3.5
    static let stackPendingLayerStepSmall: CGFloat = 3
    static let stackCheckedLayerStepMedium: CGFloat = 2.4
    static let stackCheckedLayerStepSmall: CGFloat = 2.1
    static let tidePendingHeightRatioMedium: CGFloat = 0.38
    static let tidePendingHeightRatioSmall: CGFloat = 0.40
    static let tideCheckedHeightRatioMedium: CGFloat = 0.48
    static let tideCheckedHeightRatioSmall: CGFloat = 0.52
    static let tideSmallMarkXRatio: CGFloat = 0.70
    static let tideLipInverseRatio: CGFloat = 0.62
    static let openRingTrim: CGFloat = 312 / 360
    static let openRingRotationDegrees = -18.0

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
