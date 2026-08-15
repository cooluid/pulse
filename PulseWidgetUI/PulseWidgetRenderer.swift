import PulseCore
import SwiftUI
import WidgetKit

enum PulseWidgetStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case place
    case orbit
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
    let emptyPlaceText: String
    let placeStatusText: String

    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            Group {
                switch style {
                case .place:
                    place(size: proxy.size)
                case .orbit:
                    orbit(size: proxy.size)
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
        .contentTransition(allowsMotion ? .interpolate : .identity)
        .animation(motion(materialForCurrentStyle), value: snapshot.isCheckedToday)
        .animation(ambientMotion(materialForCurrentStyle), value: ambientPeriod)
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
        .rotationEffect(.degrees(ambientRotation * 0.32))
        .offset(x: ambientHorizontalShift(in: size) * 0.28)
        .animation(motion(.place), value: snapshot.isCheckedToday)
    }

    private func orbit(size: CGSize) -> some View {
        return ZStack(alignment: .topLeading) {
            baseBackground
            orbitAmbientField(size: size)

            PulseStarRingArtwork(
                isChecked: snapshot.isCheckedToday,
                usesFullColorPalette: usesFullColorPalette,
                ambientPeriod: ambientPeriod
            )
            .frame(width: size.width, height: size.height)
            .offset(
                x: ambientHorizontalShift(in: size) * 0.10,
                y: ambientVerticalShift(in: size) * 0.10
            )

            orbitCopyVeil(size: size)

            Text(verbatim: monthAndDay)
                .font(.system(
                    size: pt(usesMediumMetrics ? 14 : 11, in: size),
                    weight: .bold
                ))
                .tracking(pt(usesMediumMetrics ? 0.8 : 0.6, in: size))
                .foregroundStyle(actionColor)
                .monospacedDigit()
                .lineLimit(1)
                .padding(.leading, pt(usesMediumMetrics ? 18 : 12, in: size))
                .padding(.top, pt(usesMediumMetrics ? 16 : 13, in: size))

            habitName(
                size: pt(usesMediumMetrics ? 22 : 16, in: size),
                width: pt(usesMediumMetrics ? 148 : 88, in: size),
                alignment: .leading
            )
            .padding(.leading, pt(usesMediumMetrics ? 18 : 12, in: size))
            .padding(.top, pt(usesMediumMetrics ? 52 : 46, in: size))
        }
    }

    private func stack(size: CGSize) -> some View {
        let geometry = PulseStackPaperGeometry(
            size: size,
            usesMediumMetrics: usesMediumMetrics,
            isChecked: snapshot.isCheckedToday
        )
        let paperFrame = geometry.topPaperFrame
        let paperInset = geometry.paperInset
        let copyLeading = paperInset + pt(usesMediumMetrics ? 2 : 1, in: size)
        let copyTop = paperInset
        // Keep small copy narrow like the prototype (≈4.6em), but pin it to the
        // paper's top-leading — a free-floating VStack inside an expanded ZStack
        // was reading as a centered cluster on small sizes.
        let copyWidth = min(
            pt(usesMediumMetrics ? 150 : 74, in: size),
            paperFrame.width * (usesMediumMetrics ? 0.48 : 0.52)
        )

        return ZStack(alignment: .topLeading) {
            baseBackground
            stackDeskMat(size: size)
            stackedPaperBackdrop(size: size)

            Color.clear
                .frame(width: paperFrame.width, height: paperFrame.height)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: pt(usesMediumMetrics ? 8 : 6, in: size)) {
                        Text(verbatim: monthAndDay)
                            .font(.system(size: pt(usesMediumMetrics ? 12 : 11, in: size), weight: .bold))
                            .tracking(pt(usesMediumMetrics ? 0.5 : 0.4, in: size))
                            .foregroundStyle(actionColor)
                            .monospacedDigit()
                            .lineLimit(1)

                        habitName(
                            size: pt(usesMediumMetrics ? 24 : 16, in: size),
                            width: copyWidth,
                            alignment: .leading
                        )
                    }
                    .frame(width: copyWidth, alignment: .leading)
                    .padding(.leading, copyLeading)
                    .padding(.top, copyTop)
                }
                .overlay(alignment: .bottomLeading) {
                    if usesMediumMetrics {
                        statusLabel(size: pt(11, in: size))
                            .padding(.leading, copyLeading)
                            .padding(.bottom, copyTop)
                    }
                }
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
            tideAtmosphere(size: size)
            tideShore(size: size, shoreHeight: shoreHeight)

            PulseTideStaffMark(
                isChecked: snapshot.isCheckedToday,
                usesFullColorPalette: usesFullColorPalette
            )
            .frame(width: markSide, height: markSide)
            .position(
                x: markX,
                y: markY + ambientVerticalShift(in: size) * 0.62
            )
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
        let water = waterColor

        return ZStack(alignment: .topLeading) {
            PulseTideCurve(kind: .water, usesMediumMetrics: usesMediumMetrics)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: water.opacity(snapshot.isCheckedToday ? 0.10 : 0.07), location: 0),
                            .init(color: water.opacity(snapshot.isCheckedToday ? 0.22 : 0.16), location: 0.46),
                            .init(color: shoreColor.opacity(snapshot.isCheckedToday ? 0.30 : 0.20), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
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
        .offset(
            x: ambientHorizontalShift(in: size) * 0.72,
            y: ambientVerticalShift(in: size) * 0.62
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(motion(.tide), value: snapshot.isCheckedToday)
    }

    @ViewBuilder
    private func tideAtmosphere(size: CGSize) -> some View {
        if usesFullColorPalette {
            LinearGradient(
                stops: [
                    .init(color: paperColor.opacity(0.52), location: 0),
                    .init(color: Color.clear, location: 0.52),
                    .init(color: waterColor.opacity(0.08), location: 1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: size.width, height: size.height)
        }
    }

    private func bleed(size: CGSize) -> some View {
        let inset = pt(usesMediumMetrics ? 16 : 12, in: size)
        let topSplit = bleedTopSplitFraction
        let bottomSplit = bleedBottomSplitFraction(top: topSplit)

        return ZStack(alignment: .topLeading) {
            baseBackground
            bleedPaperWash(size: size)

            bleedSplitTone(size: size, topSplit: topSplit, bottomSplit: bottomSplit)
                .animation(motion(.number), value: snapshot.isCheckedToday)
                .animation(ambientMotion(.number), value: ambientPeriod)

            bleedSeamHighlight(size: size, topSplit: topSplit, bottomSplit: bottomSplit)
                .animation(motion(.number), value: snapshot.isCheckedToday)
                .animation(ambientMotion(.number), value: ambientPeriod)

            Text(verbatim: monthName)
                .font(.system(size: pt(11, in: size), weight: .bold))
                .tracking(pt(0.6, in: size))
                .foregroundStyle(bleedLeadingColor)
                .shadow(
                    color: shadowColor.opacity(usesFullColorPalette ? 0.18 : 0),
                    radius: 0,
                    y: pt(1, in: size)
                )
                .padding(.leading, inset)
                .padding(.top, pt(usesMediumMetrics ? 14 : 11, in: size))

            Text(verbatim: snapshot.habitName)
                .font(.system(size: pt(usesMediumMetrics ? 22 : 16, in: size), weight: .semibold))
                .foregroundStyle(bleedLeadingColor)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .allowsTightening(true)
                .shadow(
                    color: shadowColor.opacity(usesFullColorPalette ? 0.16 : 0),
                    radius: 0,
                    y: pt(1, in: size)
                )
                .frame(
                    width: pt(usesMediumMetrics ? 168 : 70, in: size),
                    alignment: .leading
                )
                .padding(.leading, inset)
                .padding(.top, pt(usesMediumMetrics ? 44 : 36, in: size))

            Text(verbatim: dayNumber)
                .font(.system(size: pt(usesMediumMetrics ? 56 : 42, in: size), weight: .bold))
                .foregroundStyle(bleedDayColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .shadow(
                    color: bleedDayShadow,
                    radius: 0,
                    y: pt(1, in: size)
                )
                .padding(.trailing, inset)
                .padding(.bottom, pt(usesMediumMetrics ? 14 : 34, in: size))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .animation(motion(.number), value: snapshot.isCheckedToday)

            Text(verbatim: statusText)
                .font(.system(size: pt(usesMediumMetrics ? 11 : 10, in: size), weight: .medium))
                .foregroundStyle(bleedStatusColor)
                .lineLimit(1)
                .shadow(
                    color: usesMediumMetrics
                        ? shadowColor.opacity(usesFullColorPalette ? 0.14 : 0)
                        : .clear,
                    radius: 0,
                    y: pt(1, in: size)
                )
                .padding(.leading, usesMediumMetrics ? inset : 0)
                .padding(.trailing, usesMediumMetrics ? 0 : inset)
                .padding(.bottom, pt(usesMediumMetrics ? 14 : 12, in: size))
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: usesMediumMetrics ? .bottomLeading : .bottomTrailing
                )
        }
    }

    private func bleedSplitTone(
        size: CGSize,
        topSplit: CGFloat,
        bottomSplit: CGFloat
    ) -> some View {
        let shape = PulseBleedSplitShape(topFraction: topSplit, bottomFraction: bottomSplit)
        let pendingGradient = LinearGradient(
            colors: [
                actionColor.opacity(usesFullColorPalette ? 0.96 : 0.90),
                actionColor,
                actionColor.opacity(usesFullColorPalette ? 0.88 : 0.82),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let checkedGradient = LinearGradient(
            colors: [
                grassColor.opacity(usesFullColorPalette ? 0.94 : 0.88),
                grassColor,
                grassColor.opacity(usesFullColorPalette ? 0.86 : 0.80),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        return shape
            .fill(snapshot.isCheckedToday ? checkedGradient : pendingGradient)
            .overlay {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(usesFullColorPalette ? 0.16 : 0.08),
                                .clear,
                                shadowColor.opacity(usesFullColorPalette ? 0.16 : 0.08),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .allowsHitTesting(false)
            }
            .frame(width: size.width, height: size.height)
    }

    private func bleedPaperWash(size: CGSize) -> some View {
        ZStack {
            RadialGradient(
                colors: [
                    fieldColor.opacity(usesFullColorPalette ? 0.10 : 0.04),
                    .clear,
                ],
                center: UnitPoint(x: 0.78, y: 0.72),
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.62
            )
            LinearGradient(
                colors: [
                    surfaceColor.opacity(usesFullColorPalette ? 0.55 : 0.18),
                    .clear,
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.42)
            )
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private func bleedSeamHighlight(
        size: CGSize,
        topSplit: CGFloat,
        bottomSplit: CGFloat
    ) -> some View {
        let midX = size.width * ((topSplit + bottomSplit) * 0.5)
        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        shadowColor.opacity(usesFullColorPalette ? 0.10 : 0.05),
                        Color.white.opacity(usesFullColorPalette ? 0.22 : 0.10),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: pt(16, in: size), height: size.height * 1.16)
            .rotationEffect(.degrees(-10))
            .position(x: midX, y: size.height * 0.5)
            .blendMode(.softLight)
            .opacity(snapshot.isCheckedToday ? 0.72 : 0.92)
            .allowsHitTesting(false)
    }

    private var bleedTopSplitFraction: CGFloat {
        if snapshot.isCheckedToday {
            return usesMediumMetrics
                ? PulseWidgetDesign.bleedCheckedTopSplitMedium
                : PulseWidgetDesign.bleedCheckedTopSplitSmall
        }

        let base: CGFloat
        switch ambientPeriod {
        case .morning:
            base = PulseWidgetDesign.bleedPendingTopSplitMorning
        case .daylight:
            base = PulseWidgetDesign.bleedPendingTopSplitDaylight
        case .evening:
            base = PulseWidgetDesign.bleedPendingTopSplitEvening
        }
        return base
    }

    private func bleedBottomSplitFraction(top: CGFloat) -> CGFloat {
        if snapshot.isCheckedToday {
            return usesMediumMetrics
                ? PulseWidgetDesign.bleedCheckedBottomSplitMedium
                : PulseWidgetDesign.bleedCheckedBottomSplitSmall
        }
        let skew = usesMediumMetrics
            ? PulseWidgetDesign.bleedPendingSkewMedium
            : PulseWidgetDesign.bleedPendingSkewSmall
        return min(top - 0.04, max(0.16, top - skew))
    }

    private var bleedDayColor: Color {
        guard usesFullColorPalette else { return .primary }
        if colorScheme == .dark {
            return snapshot.isCheckedToday ? primaryColor : grassColor
        }
        return snapshot.isCheckedToday ? PulseWidgetDesign.grassForeground : actionColor
    }

    private var bleedDayShadow: Color {
        guard usesFullColorPalette else { return .clear }
        if colorScheme == .dark {
            return shadowColor.opacity(0.45)
        }
        return Color.white.opacity(0.35)
    }

    private var bleedStatusColor: Color {
        guard usesMediumMetrics else { return secondaryColor }
        guard usesFullColorPalette else { return .secondary }
        return snapshot.isCheckedToday
            ? PulseWidgetDesign.grassForeground.opacity(0.82)
            : actionForegroundColor.opacity(0.86)
    }

    private var bleedLeadingColor: Color {
        guard usesFullColorPalette else { return .white }
        return snapshot.isCheckedToday
            ? PulseWidgetDesign.grassForeground
            : PulseWidgetDesign.actionForeground
    }

    private var actionForegroundColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.actionForeground : .white
    }

    private func letter(size: CGSize) -> some View {
        let inset = pt(usesMediumMetrics ? 22 : 18, in: size)
        let sealSide = pt(usesMediumMetrics ? 62 : 48, in: size)
        let sealWidth = sealSide * 1.20

        return ZStack(alignment: .topLeading) {
            baseBackground
            letterDeskField(size: size)
            letterPaper(size: size)
            letterWritingLines(size: size)

            Text(verbatim: monthName)
                .font(.system(size: pt(11, in: size), weight: .semibold))
                .foregroundStyle(actionColor)
                .lineLimit(1)
                .padding(.leading, inset)
                .padding(.top, pt(usesMediumMetrics ? 14 : 16, in: size))

            letterHabitName(
                size: pt(usesMediumMetrics ? 28 : 22, in: size),
                width: pt(usesMediumMetrics ? 208 : 70, in: size),
                alignment: .leading
            )
            .padding(.leading, inset)
            .padding(.top, pt(48, in: size))

            pastPostmarkRow(size: size)
                .padding(.horizontal, inset)
                .padding(.bottom, pt(usesMediumMetrics ? 14 : 12, in: size))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            PulseLetterDateSeal(
                isChecked: snapshot.isCheckedToday,
                dayNumber: dayNumber,
                usesFullColorPalette: usesFullColorPalette
            )
            .frame(width: sealWidth, height: sealSide)
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
                .fill(
                    LinearGradient(
                        colors: [
                            paperColor,
                            paperColor.opacity(0.97),
                            surfaceColor.opacity(0.94),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
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

            PulseOrganicInkShape()
                .fill(fieldColor.opacity(usesFullColorPalette ? 0.028 : 0.018))
                .frame(width: paperWidth * 0.24, height: paperHeight * 0.34)
                .rotationEffect(.degrees(-14))
                .offset(
                    x: paperWidth * (usesMediumMetrics ? 0.68 : 0.54),
                    y: paperHeight * 0.20
                )
        }
        .frame(width: paperWidth, height: paperHeight, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .frame(width: size.width, height: size.height)
        .rotationEffect(.degrees(ambientRotation * 0.18))
        .offset(x: ambientHorizontalShift(in: size) * 0.24)
    }

    private func letterWritingLines(size: CGSize) -> some View {
        let paperInset = pt(usesMediumMetrics ? 22 : 18, in: size)
        let lineWidth = size.width * (usesMediumMetrics ? 0.58 : 0.60)
        let firstY = size.height * (usesMediumMetrics ? 0.61 : 0.59)

        return PulseLetterPencilRules()
            .stroke(
                secondaryColor.opacity(usesFullColorPalette ? 0.14 : 0.09),
                style: StrokeStyle(
                    lineWidth: pt(0.9, in: size),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(
                width: lineWidth,
                height: pt(usesMediumMetrics ? 16 : 13, in: size)
            )
            .position(
                x: paperInset + lineWidth / 2,
                y: firstY
            )
    }

    private func letterHabitName(
        size: CGFloat,
        width: CGFloat,
        alignment: TextAlignment
    ) -> some View {
        ZStack(alignment: .bottomLeading) {
            PulseLetterHandUnderline()
                .stroke(
                    fieldColor.opacity(usesFullColorPalette ? 0.42 : 0.24),
                    style: StrokeStyle(
                        lineWidth: max(1, size * 0.045),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(
                    width: width * (usesMediumMetrics ? 0.74 : 0.90),
                    height: max(5, size * 0.24)
                )
                .offset(x: size * 0.02, y: size * 0.12)

            Text(verbatim: snapshot.habitName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(primaryColor)
                .multilineTextAlignment(alignment)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .allowsTightening(true)
                .frame(width: max(width, 1), alignment: .leading)
        }
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

            PulseEchoCompletionMark(
                isChecked: snapshot.isCheckedToday,
                usesFullColorPalette: usesFullColorPalette
            )
                .frame(width: sealSide, height: sealSide)
                .padding(.trailing, pt(usesMediumMetrics ? 15 : 11, in: size))
                .padding(.bottom, pt(usesMediumMetrics ? 13 : 11, in: size))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    private func path(size: CGSize) -> some View {
        let inset = pt(usesMediumMetrics ? 16 : 12, in: size)
        let todaySide = pt(usesMediumMetrics ? 60 : 46, in: size)
        let geometry = pathTrailGeometry(in: size)

        return ZStack(alignment: .topLeading) {
            baseBackground
            pathAtmosphere(size: size, geometry: geometry)

            pathInkStroke(size: size)
            pathDayNodes(size: size)

            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: usesMediumMetrics
                    ? PulseLocalizedDateFormatting.monthDayAndWeekday(
                        snapshot.today,
                        locale: locale
                    )
                    : monthAndDay
                )
                Spacer(minLength: pt(8, in: size))
                Text(verbatim: pathSummaryText)
                    .font(.system(size: pt(11, in: size), weight: .semibold))
                    .foregroundStyle(
                        colorScheme == .dark && usesFullColorPalette
                            ? grassColor.opacity(0.82)
                            : actionColor
                    )
                    .lineLimit(1)
            }
            .font(.system(size: pt(11, in: size), weight: .semibold))
            .foregroundStyle(secondaryColor)
            .padding(.horizontal, inset)
            .padding(.top, pt(usesMediumMetrics ? 14 : 11, in: size))

            habitName(
                size: pt(usesMediumMetrics ? 20 : 16, in: size),
                width: pt(usesMediumMetrics ? 168 : 90, in: size),
                alignment: .leading
            )
            .padding(.leading, inset)
            .padding(.top, pt(usesMediumMetrics ? 38 : 32, in: size))

            PulsePathTodaySeal(
                isChecked: snapshot.isCheckedToday,
                dayNumber: dayNumber,
                usesFullColorPalette: usesFullColorPalette
            )
            .frame(width: todaySide, height: todaySide)
            .scaleEffect(snapshot.isCheckedToday ? 1 : 0.94)
            .animation(motion(.footprint), value: snapshot.isCheckedToday)
            .position(geometry.todayCenter)
        }
        .clipped()
    }

    @ViewBuilder
    private func pathAtmosphere(
        size: CGSize,
        geometry: PulsePathTrailGeometry
    ) -> some View {
        if usesFullColorPalette {
            LinearGradient(
                stops: [
                    .init(color: surfaceColor.opacity(0.72), location: 0),
                    .init(color: baseBackground.opacity(0.96), location: 0.48),
                    .init(
                        color: fieldColor.opacity(snapshot.isCheckedToday ? 0.13 : 0.08),
                        location: 1
                    ),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    surfaceColor.opacity(0.58),
                    surfaceColor.opacity(0.14),
                    Color.clear,
                ],
                center: .center,
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.48
            )
            .frame(width: size.width * 0.78, height: size.height * 0.82)
            .position(
                x: size.width * 0.18 + ambientHorizontalShift(in: size) * 0.72,
                y: size.height * 0.59 + ambientVerticalShift(in: size) * 0.46
            )

            PulsePathHillContours()
                .stroke(
                    fieldColor.opacity(pathContourOpacity),
                    style: StrokeStyle(
                        lineWidth: pt(0.85, in: size),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: size.width, height: size.height)
                .offset(
                    x: ambientHorizontalShift(in: size) * 0.34,
                    y: ambientVerticalShift(in: size) * 0.24
                )

            RadialGradient(
                colors: [
                    grassColor.opacity(snapshot.isCheckedToday ? 0.16 : 0.09),
                    grassColor.opacity(snapshot.isCheckedToday ? 0.055 : 0.03),
                    Color.clear,
                ],
                center: .center,
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.40
            )
            .frame(width: size.width * 0.66, height: size.height * 1.02)
            .position(
                x: geometry.todayCenter.x + ambientHorizontalShift(in: size) * 0.92,
                y: geometry.todayCenter.y + ambientVerticalShift(in: size) * 0.62
            )
        } else {
            PulsePathHillContours()
                .stroke(
                    secondaryColor.opacity(0.10),
                    style: StrokeStyle(
                        lineWidth: pt(0.8, in: size),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: size.width, height: size.height)
        }
    }

    private func pathInkStroke(size: CGSize) -> some View {
        let geometry = pathTrailGeometry(in: size)
        let lineWidth = pt(usesMediumMetrics ? 2.2 : 1.6, in: size)
        let softWidth = pt(usesMediumMetrics ? 24 : 18, in: size)
        let shape = PulsePathInkSpineShape(points: geometry.spinePoints)
        let arrivalStart: CGFloat = usesMediumMetrics ? 0.72 : 0.68
        let arrivalEnd = snapshot.isCheckedToday ? 1.0 : arrivalStart

        return ZStack {
            shape
                .stroke(
                    actionColor.opacity(usesFullColorPalette ? 0.055 : 0.08),
                    style: StrokeStyle(lineWidth: softWidth, lineCap: .round, lineJoin: .round)
                )
            shape
                .stroke(
                    actionColor.opacity(usesFullColorPalette ? 0.72 : 0.76),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
            shape
                .trim(from: arrivalStart, to: arrivalEnd)
                .stroke(
                    usesFullColorPalette ? grassColor : primaryColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth * 1.24,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            shape
                .trim(from: arrivalStart, to: arrivalEnd)
                .stroke(
                    (usesFullColorPalette ? grassColor : primaryColor).opacity(0.13),
                    style: StrokeStyle(
                        lineWidth: softWidth * 0.72,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
        }
        .frame(width: size.width, height: size.height)
        .animation(motion(.footprint), value: snapshot.isCheckedToday)
        .allowsHitTesting(false)
    }

    private func pathDayNodes(size: CGSize) -> some View {
        let days = Array(snapshot.recentDays.dropLast())
        let geometry = pathTrailGeometry(in: size)

        return ZStack {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, item in
                let point = geometry.nodePoints[min(index, geometry.nodePoints.count - 1)]
                pathDayNode(item, diameter: point.diameter)
                    .position(x: point.center.x, y: point.center.y)
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(motion(.footprint), value: snapshot.isCheckedToday)
        .allowsHitTesting(false)
    }

    private func pathDayNode(
        _ item: PulseWidgetDaySnapshot,
        diameter: CGFloat
    ) -> some View {
        let lineWidth = max(0.9, diameter * 0.15)

        return Circle()
            .fill(pathNodeFill(item))
            .overlay {
                Circle()
                    .stroke(pathNodeStroke(item), lineWidth: lineWidth)
            }
            .frame(width: diameter, height: diameter)
            .scaleEffect(item.state == .beforeHabit ? 0.82 : 1)
            .opacity(item.state == .beforeHabit ? 0.42 : 1)
    }

    private func pathNodeFill(_ item: PulseWidgetDaySnapshot) -> Color {
        switch item.state {
        case .checked:
            return actionColor
        case .missed, .beforeHabit, .todayPending:
            return baseBackground.opacity(usesFullColorPalette ? 0.88 : 0.35)
        }
    }

    private func pathNodeStroke(_ item: PulseWidgetDaySnapshot) -> Color {
        guard usesFullColorPalette else {
            return item.state == .checked ? .primary : .secondary
        }
        switch item.state {
        case .checked:
            return actionColor
        case .missed, .beforeHabit, .todayPending:
            // Pale grass — never gray secondary — for hollow missed marks.
            return grassColor.opacity(0.42)
        }
    }

    private func pathTrailGeometry(in size: CGSize) -> PulsePathTrailGeometry {
        PulsePathTrailGeometry(
            size: size,
            usesMediumMetrics: usesMediumMetrics
        )
    }

    private func orbitAmbientField(size: CGSize) -> some View {
        let color = snapshot.isCheckedToday ? grassColor : fieldColor

        return ZStack {
            Ellipse()
                .fill(color.opacity(usesFullColorPalette ? (snapshot.isCheckedToday ? 0.11 : 0.085) : 0.06))

            if usesFullColorPalette {
                RadialGradient(
                    colors: [
                        color.opacity(snapshot.isCheckedToday ? 0.13 : 0.09),
                        color.opacity(0.035),
                        Color.clear,
                    ],
                    center: UnitPoint(x: 0.68, y: 0.46),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.48
                )
            }
        }
        .frame(
            width: size.width * (usesMediumMetrics ? 0.72 : 0.94),
            height: size.height * (usesMediumMetrics ? 1.04 : 0.86)
        )
        .animation(motion(.starRing), value: snapshot.isCheckedToday)
        .position(
            x: size.width * (usesMediumMetrics ? 0.72 : 0.59)
                + ambientHorizontalShift(in: size) * 0.35,
            y: size.height * (usesMediumMetrics ? 0.58 : 0.62)
        )
    }

    @ViewBuilder
    private func orbitCopyVeil(size: CGSize) -> some View {
        if usesFullColorPalette {
            RadialGradient(
                stops: [
                    .init(color: baseBackground.opacity(0.99), location: 0),
                    .init(color: baseBackground.opacity(0.92), location: 0.48),
                    .init(color: baseBackground.opacity(0.28), location: 0.80),
                    .init(color: baseBackground.opacity(0), location: 1),
                ],
                center: UnitPoint(
                    x: usesMediumMetrics ? 0.12 : 0.13,
                    y: usesMediumMetrics ? 0.31 : 0.30
                ),
                startRadius: 0,
                endRadius: size.width * (usesMediumMetrics ? 0.62 : 0.78)
            )
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
        }
    }

    private func placeAmbientField(size: CGSize) -> some View {
        let color = snapshot.isCheckedToday ? grassColor : fieldColor

        return ZStack {
            if usesFullColorPalette {
                LinearGradient(
                    stops: [
                        .init(color: paperColor.opacity(0.34), location: 0),
                        .init(color: Color.clear, location: 0.42),
                        .init(color: color.opacity(0.055), location: 1),
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        paperColor.opacity(0.07),
                        Color.clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.34
                )
                .frame(width: size.width * 0.64, height: size.height * 0.72)
                .rotationEffect(.degrees(-10 + ambientRotation * 0.18))
                .position(
                    x: size.width * (usesMediumMetrics ? 0.26 : 0.48),
                    y: size.height * 0.42
                )
            } else {
                Ellipse()
                    .fill(color.opacity(0.055))
                    .frame(
                        width: size.width * (usesMediumMetrics ? 0.58 : 0.92),
                        height: size.height * (usesMediumMetrics ? 1.18 : 0.72)
                    )
                    .position(
                        x: size.width * (usesMediumMetrics ? 0.20 : 0.46),
                        y: size.height * (usesMediumMetrics ? 0.54 : 0.50)
                    )
            }
        }
        .scaleEffect(snapshot.isCheckedToday ? 1.03 : 1)
        .offset(x: ambientHorizontalShift(in: size) * 0.42)
        .animation(motion(.place), value: snapshot.isCheckedToday)
    }

    private func stackDeskMat(size: CGSize) -> some View {
        let geometry = PulseStackPaperGeometry(
            size: size,
            usesMediumMetrics: usesMediumMetrics,
            isChecked: snapshot.isCheckedToday
        )
        let color = snapshot.isCheckedToday ? grassColor : fieldColor

        return RoundedRectangle(
            cornerRadius: geometry.deskCornerRadius,
            style: .continuous
        )
        .fill(color.opacity(usesFullColorPalette ? (snapshot.isCheckedToday ? 0.16 : 0.13) : 0.07))
        .frame(
            width: size.width - pt(6, in: size),
            height: size.height - pt(6, in: size)
        )
        .rotationEffect(.degrees((usesMediumMetrics ? 1.1 : 1.6) + ambientRotation * 0.28))
        .scaleEffect(snapshot.isCheckedToday ? 0.99 : 1)
        .animation(motion(.paper), value: snapshot.isCheckedToday)
        .position(
            x: size.width / 2 + ambientHorizontalShift(in: size) * 0.28,
            y: size.height / 2 + pt(1.5, in: size)
        )
    }

    private func stackedPaperBackdrop(size: CGSize) -> some View {
        let geometry = PulseStackPaperGeometry(
            size: size,
            usesMediumMetrics: usesMediumMetrics,
            isChecked: snapshot.isCheckedToday
        )
        let paperFrame = geometry.topPaperFrame

        return ZStack {
            ForEach(0..<PulseStackPaperGeometry.sheetCount, id: \.self) { index in
                let depth = PulseStackPaperGeometry.sheetCount - 1 - index
                let cutsCorner = snapshot.isCheckedToday && depth == 0
                let sheet = PulseStackedSheetShape(
                    cornerRadius: geometry.paperCornerRadius,
                    foldSide: cutsCorner ? geometry.foldSize.width : 0
                )

                sheet
                    .fill(paperColor)
                    .overlay {
                        sheet
                            .fill(fieldColor.opacity(Double(depth) * 0.08))
                    }
                    .overlay {
                        if !cutsCorner {
                            sheet
                                .stroke(
                                    fieldColor.opacity(0.18 + Double(depth) * 0.07),
                                    lineWidth: pt(1, in: size)
                                )
                        }
                    }
                    .shadow(
                        color: shadowColor.opacity(0.07 + Double(depth) * 0.025),
                        radius: pt(5 + CGFloat(depth), in: size),
                        y: pt(2.4, in: size)
                    )
                    .frame(width: paperFrame.width, height: paperFrame.height)
                    .rotationEffect(.degrees(Double(depth) * geometry.rotationPerLayer))
                    .offset(
                        x: -CGFloat(depth) * geometry.layerStep,
                        y: CGFloat(depth) * geometry.layerStep
                    )
            }

            PulsePaperPressMark(
                isChecked: snapshot.isCheckedToday,
                usesFullColorPalette: usesFullColorPalette
            )
            .frame(width: geometry.pressSize.width, height: geometry.pressSize.height)
            .position(
                x: geometry.pressFrame.midX - paperFrame.minX,
                y: geometry.pressFrame.midY - paperFrame.minY
            )

            if snapshot.isCheckedToday {
                // Keep the outer corner anchored; grow the flap inward so it seals the
                // cut hypotenuse. Any sub-pixel gap shows the darker under-sheet as a
                // false black crease.
                let foldSide = geometry.foldSize.width
                let foldOverlap = pt(3.0, in: size)
                PulseFoldedPaperFlap()
                    .fill(paperColor)
                    .overlay {
                        PulseFoldedPaperFlap()
                            .fill(fieldColor.opacity(usesFullColorPalette ? 0.10 : 0.05))
                    }
                    .frame(width: foldSide + foldOverlap, height: foldSide + foldOverlap)
                    .position(
                        x: paperFrame.width - (foldSide + foldOverlap) / 2,
                        y: paperFrame.height - (foldSide + foldOverlap) / 2
                    )
            }
        }
        .frame(width: paperFrame.width, height: paperFrame.height)
        .rotationEffect(.degrees(ambientRotation * 0.22))
        .position(x: paperFrame.midX, y: paperFrame.midY)
        .animation(motion(.paper), value: snapshot.isCheckedToday)
    }

    private func letterDeskField(size: CGSize) -> some View {
        let color = snapshot.isCheckedToday ? grassColor : fieldColor

        return Ellipse()
            .fill(color.opacity(usesFullColorPalette ? 0.065 : 0.04))
            .frame(width: size.width * 0.94, height: size.height * 0.68)
            .rotationEffect(.degrees(-4 + ambientRotation * 0.4))
            .position(
                x: size.width * 0.48 + ambientHorizontalShift(in: size) * 0.45,
                y: size.height * 0.58
            )
    }

    private func pastPostmarkRow(size: CGSize) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(snapshot.recentDays.dropLast()), id: \.id) { item in
                postmarkNode(
                    item,
                    size: pt(usesMediumMetrics ? 17 : 12.5, in: size)
                )
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: pt(usesMediumMetrics ? 18 : 13, in: size))
    }

    private func postmarkNode(
        _ item: PulseWidgetDaySnapshot,
        size: CGFloat
    ) -> some View {
        ZStack {
            if item.state == .checked {
                PulseLetterPressedInkMark(markColor: fieldColor)
            } else {
                Circle()
                    .stroke(
                        secondaryColor.opacity(item.state == .beforeHabit ? 0.24 : 0.42),
                        lineWidth: max(1, size * 0.10)
                    )
                    .scaleEffect(item.state == .beforeHabit ? 0.82 : 1)
            }
        }
        .frame(width: size, height: size)
    }

    private func quietFieldAfterimage(size: CGSize) -> some View {
        let ringSide = pt(usesMediumMetrics ? 188 : 172, in: size)
        let center = CGPoint(
            x: size.width - pt(usesMediumMetrics ? 8 : 4, in: size)
                + ambientHorizontalShift(in: size) * 0.42,
            y: size.height - pt(usesMediumMetrics ? 7 : 6, in: size)
                + ambientVerticalShift(in: size) * 0.42
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

    private var paperColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.widgetPaper : .clear
    }

    private var waterColor: Color {
        usesFullColorPalette ? PulseWidgetDesign.widgetWater : .primary
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

    private var pathContourOpacity: Double {
        switch ambientPeriod {
        case .morning: 0.055
        case .daylight: 0.075
        case .evening: 0.10
        }
    }

    private var ambientPeriod: PulseWidgetAmbientPeriod {
        PulseWidgetAmbientPeriod.resolve(
            at: snapshot.generatedAt,
            timeZone: snapshot.projectTimeZone
        )
    }

    private var ambientPose: PulseWidgetMotionPresentation.AmbientPose {
        PulseWidgetMotionPresentation.ambientPose(
            for: materialForCurrentStyle,
            period: ambientPeriod
        )
    }

    private var ambientRotation: Double {
        ambientPose.rotationDegrees
    }

    private func ambientHorizontalShift(in size: CGSize) -> CGFloat {
        pt(ambientPose.horizontalPoints, in: size)
    }

    private func ambientVerticalShift(in size: CGSize) -> CGFloat {
        pt(ambientPose.verticalPoints, in: size)
    }

    private var materialForCurrentStyle: PulseWidgetMotionPresentation.Material {
        switch style {
        case .place: .place
        case .orbit: .starRing
        case .stack: .paper
        case .bleed: .number
        case .letter: .letter
        case .field: .echo
        case .path: .footprint
        case .tide: .tide
        }
    }

    private func motion(_ material: PulseWidgetMotionPresentation.Material) -> Animation? {
        PulseWidgetMotionPresentation.completionAnimation(
            for: material,
            allowsMotion: allowsMotion
        )
    }

    private func ambientMotion(_ material: PulseWidgetMotionPresentation.Material) -> Animation? {
        PulseWidgetMotionPresentation.ambientAnimation(
            for: material,
            allowsMotion: allowsMotion
        )
    }

    private func pt(_ value: CGFloat, in size: CGSize) -> CGFloat {
        value * size.height / 158
    }
}

private struct PulseBleedSplitShape: Shape {
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

private struct PulseStarRingArtwork: View {
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
        // Prototype canvas coords: small 158² press 54×46 at right 28 / bottom 46;
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

private struct PulseOrganicInkShape: Shape {
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

private struct PulsePaperPressMark: View {
    let isChecked: Bool
    let usesFullColorPalette: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let radius = hypot(width, height) * 0.52

            ZStack {
                if isChecked {
                    // Single soft oval matching prototype plate; keep side soaks very faint.
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
                } else {
                    Ellipse()
                        .fill(markColor.opacity(0.06))
                        .overlay {
                            Ellipse()
                                .stroke(markColor.opacity(0.38), lineWidth: max(1.2, min(width, height) * 0.035))
                        }
                        .padding(min(width, height) * 0.06)
                        .rotationEffect(.degrees(-11))
                }
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

private struct PulseLetterPressedInkMark: View {
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

private struct PulseLetterHandUnderline: Shape {
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

private struct PulseLetterPencilRules: Shape {
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

private struct PulseLetterPressRidges: Shape {
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

private struct PulseStackedSheetShape: Shape {
    var cornerRadius: CGFloat
    var foldSide: CGFloat

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

private struct PulseFoldedPaperFlap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct PulseLetterDateSeal: View {
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

private struct PulseEchoCompletionMark: View {
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
                        if isChecked {
                            Image(systemName: "checkmark")
                                .font(.system(size: side * 0.11, weight: .bold))
                                .foregroundStyle(completedForeground)
                        }
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

private struct PulseTideStaffMark: View {
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

private struct PulsePathTrailGeometry {
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

private struct PulsePathHillContours: Shape {
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

private struct PulsePathInkSpineShape: Shape {
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

private struct PulsePathTodaySeal: View {
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
    static let widgetPaper = Color("PulseWidgetPaper")
    static let widgetWater = Color("PulseWidgetWater")
    static let stackPhysicalSheetCount = 4

    static let bleedPendingTopSplitMorning: CGFloat = 0.60
    static let bleedPendingTopSplitDaylight: CGFloat = 0.50
    static let bleedPendingTopSplitEvening: CGFloat = 0.40
    static let bleedPendingSkewSmall: CGFloat = 0.16
    static let bleedPendingSkewMedium: CGFloat = 0.09
    static let bleedCheckedTopSplitSmall: CGFloat = 0.74
    static let bleedCheckedBottomSplitSmall: CGFloat = 0.58
    static let bleedCheckedTopSplitMedium: CGFloat = 0.68
    static let bleedCheckedBottomSplitMedium: CGFloat = 0.56

    static let stackPendingLayerStepMedium: CGFloat = 6.5
    static let stackPendingLayerStepSmall: CGFloat = 5.5
    static let stackCheckedLayerStepMedium: CGFloat = 4.2
    static let stackCheckedLayerStepSmall: CGFloat = 3.6
    static let stackCanvasMarginMedium: CGFloat = 6
    static let stackCanvasMarginSmall: CGFloat = 5
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
