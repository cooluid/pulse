import PulseCore
import SwiftUI
import WidgetKit

/// Home Screen faces. Every style sets the same fact (today kept or not, and the six days before it)
/// as a different arrangement of date seals on one sheet of paper.
struct PulseWidgetHomeRenderer: View {
    let snapshot: PulseWidgetSnapshot
    let style: PulseWidgetStyle
    let usesMediumMetrics: Bool
    let usesFullColorPalette: Bool
    let allowsMotion: Bool
    let statusText: String
    let pathSummaryFormat: String

    @Environment(\.locale) private var locale

    var body: some View {
        GeometryReader { proxy in
            let metrics = PulseWidgetMetrics(size: proxy.size, isMedium: usesMediumMetrics)
            ZStack(alignment: .topLeading) {
                if usesFullColorPalette {
                    PulseWidgetDesign.paper
                }
                face(metrics)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentTransition(.identity)
    }

    @ViewBuilder
    private func face(_ metrics: PulseWidgetMetrics) -> some View {
        switch style {
        case .place: place(metrics)
        case .orbit: orbit(metrics)
        case .stack: stack(metrics)
        case .bleed: bleed(metrics)
        case .letter: letter(metrics)
        case .field: field(metrics)
        case .path: path(metrics)
        case .tide: tide(metrics)
        }
    }

    // MARK: - Styles

    private func place(_ m: PulseWidgetMetrics) -> some View {
        Group {
            if m.isMedium {
                HStack(alignment: .center, spacing: m.pt(18)) {
                    todaySeal(side: m.pt(112))
                    VStack(alignment: .leading, spacing: m.pt(6)) {
                        dateLine(m, includesWeekday: true)
                        name(size: m.pt(22), lines: 2)
                        Spacer(minLength: 0)
                        status(m)
                    }
                    .padding(.vertical, m.pt(4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(.horizontal, m.pt(20))
                .padding(.vertical, m.pt(18))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    todaySeal(side: m.pt(62))
                    Spacer(minLength: m.pt(6))
                    name(size: m.pt(15), lines: 2)
                    status(m)
                        .padding(.top, m.pt(3))
                }
                .padding(m.pt(16))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func orbit(_ m: PulseWidgetMetrics) -> some View {
        Group {
            if m.isMedium {
                HStack(spacing: m.pt(12)) {
                    VStack(alignment: .leading, spacing: m.pt(6)) {
                        dateLine(m, includesWeekday: true)
                        name(size: m.pt(21), lines: 2)
                        Spacer(minLength: 0)
                        summary(m)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    ring(side: m.pt(134))
                }
                .padding(.leading, m.pt(20))
                .padding(.trailing, m.pt(12))
                .padding(.vertical, m.pt(12))
            } else {
                ring(side: m.pt(136))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func stack(_ m: PulseWidgetMetrics) -> some View {
        Group {
            if m.isMedium {
                HStack(spacing: m.pt(8)) {
                    VStack(alignment: .leading, spacing: m.pt(6)) {
                        dateLine(m, includesWeekday: true)
                        name(size: m.pt(21), lines: 2)
                        Spacer(minLength: 0)
                        status(m)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    pile(side: m.pt(136))
                }
                .padding(.leading, m.pt(20))
                .padding(.trailing, m.pt(10))
                .padding(.vertical, m.pt(14))
            } else {
                VStack(spacing: 0) {
                    pile(side: m.pt(110))
                    Spacer(minLength: 0)
                    name(size: m.pt(14), lines: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, m.pt(14))
                .padding(.top, m.pt(8))
                .padding(.bottom, m.pt(14))
            }
        }
    }

    private func bleed(_ m: PulseWidgetMetrics) -> some View {
        let isChecked = snapshot.isCheckedToday
        let onInk = usesFullColorPalette ? PulseWidgetDesign.onSeal : Color.primary
        return ZStack(alignment: .topLeading) {
            PulseWidgetBleedNumber(
                day: snapshot.today.day,
                isMedium: m.isMedium,
                color: wash
            )
            .opacity(isChecked ? 0 : 1)

            PulseWidgetBleedField(
                day: snapshot.today.day,
                isMedium: m.isMedium,
                ink: seal.opacity(usesFullColorPalette ? 1 : 0.32),
                seed: todaySeed,
                texture: usesFullColorPalette ? 0.6 : 0
            )
            .opacity(isChecked ? 1 : 0)
            .scaleEffect(isChecked ? 1 : 1.06)
            .widgetAccentable()

            VStack(alignment: .leading, spacing: m.pt(4)) {
                Text(verbatim: PulseLocalizedDateFormatting.monthName(snapshot.today, locale: locale))
                    .font(.system(size: m.pt(12), weight: .bold))
                    .foregroundStyle(isChecked ? onInk : seal)
                    .lineLimit(1)
                name(size: m.pt(m.isMedium ? 20 : 15), lines: 2, color: isChecked ? onInk : ink)
                    .frame(maxWidth: m.pt(m.isMedium ? 128 : 126), alignment: .leading)
                if m.isMedium {
                    Spacer(minLength: 0)
                    Text(verbatim: statusText)
                        .font(.system(size: m.pt(12), weight: .semibold))
                        .foregroundStyle(isChecked ? onInk.opacity(0.86) : seal)
                        .lineLimit(1)
                        .frame(maxWidth: m.pt(128), alignment: .leading)
                }
            }
            .padding(m.pt(16))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .animation(stampAnimation, value: isChecked)
    }

    private func letter(_ m: PulseWidgetMetrics) -> some View {
        let chopSide = m.pt(m.isMedium ? 58 : 44)
        return ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                dateLine(m, includesWeekday: m.isMedium)
                Rectangle()
                    .fill(rule)
                    .frame(height: max(0.5, m.pt(0.75)))
                    .padding(.top, m.pt(8))
                Text(verbatim: snapshot.habitName)
                    .font(.system(size: m.pt(m.isMedium ? 25 : 18), weight: .semibold, design: .serif))
                    .foregroundStyle(ink)
                    .lineLimit(m.isMedium ? 2 : 3)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, m.pt(10))
                    .padding(.trailing, m.isMedium ? chopSide : 0)
                Spacer(minLength: 0)
                status(m)
                    .padding(.trailing, chopSide)
            }
            .padding(m.pt(16))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            todaySeal(side: chopSide)
                .padding(m.pt(14))
        }
    }

    private func field(_ m: PulseWidgetMetrics) -> some View {
        ZStack {
            todaySeal(side: m.pt(m.isMedium ? 100 : 88))
                .offset(y: m.isMedium ? 0 : m.pt(6))

            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: PulseLocalizedDateFormatting.shortWeekday(snapshot.today, locale: locale))
                    .font(.system(size: m.pt(11), weight: .semibold))
                    .foregroundStyle(muted)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if m.isMedium {
                    name(size: m.pt(13), lines: 1, color: muted)
                        .frame(maxWidth: m.pt(96), alignment: .leading)
                }
            }
            .padding(m.pt(14))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func path(_ m: PulseWidgetMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            name(size: m.pt(m.isMedium ? 20 : 15), lines: m.isMedium ? 1 : 2)
            summary(m)
                .padding(.top, m.pt(3))
            Spacer(minLength: m.pt(6))
            if m.isMedium {
                week(m)
            } else {
                compactWeek(m)
            }
        }
        .padding(.horizontal, m.pt(m.isMedium ? 18 : 14))
        .padding(.vertical, m.pt(m.isMedium ? 16 : 14))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Each kept day of the week raises the ink. The top of the sheet stays paper for the copy.
    private func tide(_ m: PulseWidgetMetrics) -> some View {
        let dayCount = CGFloat(snapshot.recentDays.count)
        let kept = CGFloat(snapshot.recentCheckedCount)
        let reach: CGFloat = m.isMedium ? 0.6 : 0.63
        let inkHeight = m.size.height * reach * kept / dayCount
        let nextHeight = m.size.height * reach * min(kept + 1, dayCount) / dayCount
        let numberSize = m.pt(m.isMedium ? 54 : 44)
        let numberCap = numberSize * 0.72
        let numberSitsInInk = inkHeight >= numberCap + m.pt(20)
        let waterline = snapshot.isCheckedToday ? inkHeight : nextHeight
        let numberBaseline = numberSitsInInk
            ? m.size.height - m.pt(10)
            : m.size.height - waterline - m.pt(7)
        let onInk = usesFullColorPalette ? PulseWidgetDesign.onSeal : Color.primary
        return ZStack(alignment: .topLeading) {
            PulseWidgetInkTide(
                ink: seal.opacity(usesFullColorPalette ? 1 : 0.32),
                seed: todaySeed,
                texture: usesFullColorPalette ? 0.55 : 0
            )
            .frame(width: m.size.width, height: m.size.height)
            .offset(y: m.size.height - inkHeight)
            .widgetAccentable()

            if !snapshot.isCheckedToday {
                PulseWidgetDashedLevel()
                    .stroke(
                        seal.opacity(0.8),
                        style: StrokeStyle(lineWidth: max(1, m.pt(1.4)), lineCap: .round, dash: [m.pt(5), m.pt(4)])
                    )
                    .frame(width: m.size.width - m.pt(28), height: max(1, m.pt(1.4)))
                    .offset(x: m.pt(14), y: m.size.height - nextHeight)
                    .widgetAccentable()
                    .transition(.opacity)
            }

            Text(verbatim: PulseLocalizedDateFormatting.dayNumber(snapshot.today, locale: locale))
                .font(.system(size: numberSize, weight: .black, design: .serif))
                .monospacedDigit()
                .foregroundStyle(numberSitsInInk ? onInk : seal)
                .lineLimit(1)
                .fixedSize()
                .alignmentGuide(.bottom) { $0[.lastTextBaseline] }
                .frame(width: m.size.width - m.pt(14), height: numberBaseline, alignment: .bottomTrailing)
                .widgetAccentable(!numberSitsInInk)

            VStack(alignment: .leading, spacing: m.pt(3)) {
                name(size: m.pt(m.isMedium ? 20 : 14), lines: 1)
                summary(m)
            }
            .padding(.horizontal, m.pt(14))
            .padding(.top, m.pt(14))
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .animation(riseAnimation, value: snapshot.isCheckedToday)
    }

    // MARK: - Parts

    /// Today: a dashed place before the check-in, the impression after.
    private func todaySeal(side: CGFloat) -> some View {
        ZStack {
            if snapshot.isCheckedToday {
                PulseSealImpression(
                    inscription: .number(snapshot.today.day),
                    ink: seal,
                    seed: todaySeed,
                    texture: usesFullColorPalette ? 0.75 : 0.35,
                    typeface: .systemSerif,
                    cornerFraction: PulseWidgetDesign.sealCornerFraction
                )
                .rotationEffect(PulseSealSeed.tilt(for: todaySeed, maximum: 4))
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 1.16).combined(with: .opacity),
                        removal: .opacity
                    )
                )
            } else {
                PulseSealSlot(
                    inscription: .number(snapshot.today.day),
                    tint: seal,
                    typeface: .systemSerif,
                    cornerFraction: PulseWidgetDesign.sealCornerFraction,
                    ghostOpacity: 0.24
                )
                .transition(.opacity)
            }
        }
        .frame(width: side, height: side)
        .widgetAccentable()
        .animation(stampAnimation, value: snapshot.isCheckedToday)
    }

    /// The six days before today around today's seal: six around one packs into a ring.
    private func ring(side: CGFloat) -> some View {
        let previous = Array(snapshot.recentDays.dropLast())
        let markSide = side * 0.21
        let radius = side / 2 - markSide / 2
        return ZStack {
            ForEach(Array(previous.enumerated()), id: \.element.id) { index, item in
                let angle = (-150 + Double(index) * 60) * .pi / 180
                dayMark(item, side: markSide)
                    .offset(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
            }
            todaySeal(side: side * 0.36)
        }
        .frame(width: side, height: side)
    }

    /// Earlier kept days fan out behind today's seal, the oldest farthest back and palest.
    private func pile(side: CGFloat) -> some View {
        let impressionSide = side * 0.6
        let pile = PulseWidgetPilePlacement.pile(
            for: Array(snapshot.recentDays.dropLast()),
            room: side - impressionSide
        )
        let todayTilt = snapshot.isCheckedToday ? PulseSealSeed.tilt(for: todaySeed, maximum: 4) : .zero
        return ZStack {
            ZStack {
                ForEach(pile.behind) { placement in
                    PulseSealImpression(
                        inscription: .number(placement.day.day),
                        ink: seal,
                        seed: placement.seed,
                        texture: usesFullColorPalette ? 0.6 : 0.3,
                        typeface: .systemSerif,
                        cornerFraction: PulseWidgetDesign.sealCornerFraction
                    )
                    .frame(width: impressionSide, height: impressionSide)
                    .rotationEffect(.degrees(placement.rotation))
                    .offset(placement.offset)
                    .opacity(placement.opacity)
                    .widgetAccentable()
                }
            }
            .frame(width: side, height: side)
            // Today lands on clean paper: earlier ink never shows through its date.
            .mask {
                PulseWidgetPunchedRect(
                    hole: CGSize(width: impressionSide + 3, height: impressionSide + 3),
                    offset: pile.today,
                    rotation: todayTilt,
                    cornerFraction: PulseWidgetDesign.sealCornerFraction
                )
                .fill(style: FillStyle(eoFill: true))
            }

            todaySeal(side: impressionSide)
                .offset(pile.today)
        }
        .frame(width: side, height: side)
    }

    private func week(_ m: PulseWidgetMetrics) -> some View {
        HStack(spacing: 0) {
            ForEach(snapshot.recentDays) { item in
                VStack(spacing: m.pt(5)) {
                    Text(verbatim: PulseLocalizedDateFormatting.narrowWeekday(item.day, locale: locale))
                        .font(.system(size: m.pt(10), weight: item.day == snapshot.today ? .bold : .medium))
                        .foregroundStyle(item.day == snapshot.today ? ink : muted)
                        .lineLimit(1)
                    dayMark(item, side: m.pt(32))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// The small face has no room for a legible row of seven, so the week folds into four and three.
    private func compactWeek(_ m: PulseWidgetMetrics) -> some View {
        let days = snapshot.recentDays
        let markSide = m.pt(26)
        let gap = m.pt(6)
        return VStack(alignment: .leading, spacing: gap) {
            HStack(spacing: gap) {
                ForEach(days.prefix(4)) { item in
                    dayMark(item, side: markSide)
                }
            }
            HStack(spacing: gap) {
                ForEach(days.dropFirst(4)) { item in
                    dayMark(item, side: markSide)
                }
            }
        }
    }

    private func dayMark(_ item: PulseWidgetDaySnapshot, side: CGFloat) -> some View {
        PulseDayMark(
            day: item.day.day,
            state: PulseDayMarkState(item.state),
            seed: PulseSealSeed.value(for: item.day),
            seal: seal,
            ink: ink,
            muted: muted,
            emphasized: item.day == snapshot.today
        )
        .frame(width: side, height: side)
        .widgetAccentable(item.state == .checked || item.state == .todayPending)
    }

    private func dateLine(_ m: PulseWidgetMetrics, includesWeekday: Bool) -> some View {
        Text(verbatim: includesWeekday
            ? PulseLocalizedDateFormatting.monthDayAndShortWeekday(snapshot.today, locale: locale)
            : PulseLocalizedDateFormatting.monthAndDay(snapshot.today, locale: locale))
            .font(.system(size: m.pt(12), weight: .bold))
            .foregroundStyle(seal)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .widgetAccentable()
    }

    private func name(size: CGFloat, lines: Int, color: Color? = nil) -> some View {
        Text(verbatim: snapshot.habitName)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(color ?? ink)
            .lineLimit(lines)
            .minimumScaleFactor(0.75)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func status(_ m: PulseWidgetMetrics) -> some View {
        Text(verbatim: statusText)
            .font(.system(size: m.pt(12), weight: .semibold))
            .foregroundStyle(snapshot.isCheckedToday ? muted : seal)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func summary(_ m: PulseWidgetMetrics, color: Color? = nil) -> some View {
        Text(verbatim: String(
            format: pathSummaryFormat,
            locale: locale,
            snapshot.previousSixCheckedCount
        ))
        .font(.system(size: m.pt(12), weight: .medium))
        .foregroundStyle(color ?? muted)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    // MARK: - Palette and motion

    private var todaySeed: UInt64 { PulseSealSeed.value(for: snapshot.today) }

    private var seal: Color { usesFullColorPalette ? PulseWidgetDesign.seal : .primary }
    private var ink: Color { usesFullColorPalette ? PulseWidgetDesign.ink : .primary }
    private var muted: Color { usesFullColorPalette ? PulseWidgetDesign.muted : .secondary }
    private var rule: Color { usesFullColorPalette ? PulseWidgetDesign.rule : .secondary.opacity(0.4) }
    private var wash: Color { usesFullColorPalette ? PulseWidgetDesign.sealWash : .primary.opacity(0.16) }

    private var stampAnimation: Animation? {
        PulseWidgetMotionPresentation.stamp(allowsMotion: allowsMotion)
    }

    private var riseAnimation: Animation? {
        PulseWidgetMotionPresentation.rise(allowsMotion: allowsMotion)
    }
}

/// Points scale with the family's height, so one layout serves every device's widget size.
private struct PulseWidgetMetrics {
    let size: CGSize
    let isMedium: Bool

    func pt(_ value: CGFloat) -> CGFloat {
        value * size.height / 158
    }
}

struct PulseWidgetPilePlacement: Identifiable {
    let day: LogicalDay
    let seed: UInt64
    let offset: CGSize
    let rotation: Double
    let opacity: Double

    var id: LogicalDay { day }

    static let maximumBehind = 4

    /// Fans the most recent kept days up and to the leading side, then centres the whole pile.
    static func pile(
        for days: [PulseWidgetDaySnapshot],
        room: CGFloat
    ) -> (behind: [PulseWidgetPilePlacement], today: CGSize) {
        let kept = Array(days.filter { $0.state == .checked }.suffix(maximumBehind))
        let step = room / (CGFloat(kept.count) + 0.6)
        var behind: [PulseWidgetPilePlacement] = kept.enumerated().map { index, item in
            let seed = PulseSealSeed.value(for: item.day)
            var random = PulseSealRandom(seed: seed ^ 0x51ac_9e37_0f2d_3b11)
            let depth = CGFloat(kept.count - index)
            let dx = -depth * step + CGFloat(random.range(-0.2, 0.2)) * step
            let dy = -depth * step * 0.6 + CGFloat(random.range(-0.2, 0.2)) * step
            return PulseWidgetPilePlacement(
                day: item.day,
                seed: seed,
                offset: CGSize(width: dx, height: dy),
                rotation: -Double(depth) * 4 + random.range(-3, 3),
                opacity: max(0.3, 0.82 - Double(depth - 1) * 0.16)
            )
        }
        let offsets = behind.map(\.offset) + [.zero]
        let shift = CGSize(
            width: -((offsets.map(\.width).min() ?? 0) + (offsets.map(\.width).max() ?? 0)) / 2,
            height: -((offsets.map(\.height).min() ?? 0) + (offsets.map(\.height).max() ?? 0)) / 2
        )
        behind = behind.map { placement in
            PulseWidgetPilePlacement(
                day: placement.day,
                seed: placement.seed,
                offset: CGSize(
                    width: placement.offset.width + shift.width,
                    height: placement.offset.height + shift.height
                ),
                rotation: placement.rotation,
                opacity: placement.opacity
            )
        }
        return (behind, shift)
    }
}

/// Before the check-in, today's date sits on the paper as a pale ghost, bled off the corner.
private struct PulseWidgetBleedNumber: View {
    let day: Int
    let isMedium: Bool
    let color: Color

    var body: some View {
        Canvas { context, size in
            let text = context.resolve(PulseWidgetBleedLayout.text(day: day, size: size, isMedium: isMedium).foregroundStyle(color))
            context.draw(text, at: PulseWidgetBleedLayout.anchor(in: size, isMedium: isMedium), anchor: .bottomTrailing)
        }
        .accessibilityHidden(true)
    }
}

/// After the check-in the whole sheet takes the ink, and the date is what stays paper.
private struct PulseWidgetBleedField: View {
    let day: Int
    let isMedium: Bool
    let ink: Color
    let seed: UInt64
    let texture: Double

    var body: some View {
        Canvas { context, size in
            let face = CGRect(origin: .zero, size: size)
            context.drawLayer { layer in
                layer.fill(Path(face), with: .color(ink))
                layer.blendMode = .destinationOut
                let text = layer.resolve(PulseWidgetBleedLayout.text(day: day, size: size, isMedium: isMedium).foregroundStyle(.black))
                layer.draw(text, at: PulseWidgetBleedLayout.anchor(in: size, isMedium: isMedium), anchor: .bottomTrailing)
                let square = CGRect(
                    x: 0,
                    y: (size.height - size.width) / 2,
                    width: size.width,
                    height: size.width
                )
                PulseSealImpression.erode(face: square, seed: seed, texture: texture, bitesRim: false, context: &layer)
            }
        }
        .accessibilityHidden(true)
    }
}

private enum PulseWidgetBleedLayout {
    static func text(day: Int, size: CGSize, isMedium: Bool) -> Text {
        Text(verbatim: String(day))
            .font(.system(size: size.height * (isMedium ? 1.0 : 0.86), weight: .black, design: .serif))
    }

    /// The date runs off the bottom and trailing edges; the copy keeps the top-leading corner.
    static func anchor(in size: CGSize, isMedium: Bool) -> CGPoint {
        CGPoint(
            x: size.width + size.height * (isMedium ? 0.04 : 0.1),
            y: size.height * (isMedium ? 1.36 : 1.32)
        )
    }
}

/// The ink that rises with each kept day of the week, its edge left rough the way soaked paper is.
private struct PulseWidgetInkTide: View {
    let ink: Color
    let seed: UInt64
    let texture: Double

    var body: some View {
        Canvas { context, size in
            context.drawLayer { layer in
                layer.fill(Self.edge(in: size, seed: seed), with: .color(ink))
                layer.blendMode = .destinationOut
                let square = CGRect(x: 0, y: 0, width: size.width, height: size.width)
                PulseSealImpression.erode(face: square, seed: seed, texture: texture * 0.6, bitesRim: false, context: &layer)
            }
        }
        .accessibilityHidden(true)
    }

    static func edge(in size: CGSize, seed: UInt64) -> Path {
        var random = PulseSealRandom(seed: seed ^ 0x7f4a_7c15_9e37_79b9)
        let steps = 28
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        for step in 0...steps {
            let x = size.width * CGFloat(step) / CGFloat(steps)
            let y = CGFloat(random.range(-1, 1)) * min(2.4, size.height * 0.012)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        return path
    }
}

/// The whole frame with one rounded square cut out of it.
private struct PulseWidgetPunchedRect: Shape {
    let hole: CGSize
    let offset: CGSize
    let rotation: Angle
    let cornerFraction: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        let holeRect = CGRect(
            x: -hole.width / 2,
            y: -hole.height / 2,
            width: hole.width,
            height: hole.height
        )
        let transform = CGAffineTransform(translationX: rect.midX + offset.width, y: rect.midY + offset.height)
            .rotated(by: rotation.radians)
        path.addPath(
            Path(roundedRect: holeRect, cornerRadius: hole.width * cornerFraction, style: .continuous),
            transform: transform
        )
        return path
    }
}

private struct PulseWidgetDashedLevel: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
