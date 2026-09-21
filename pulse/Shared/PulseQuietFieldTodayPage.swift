import PulseCore
import SwiftUI

/// Quiet Field arranges Today around one stalk of grass.
///
/// The stalk is the streak made visible: one node per recent day, bottom to top.
/// Keeping a day grows the stalk; the whole page stays in two colors — paper and ink —
/// because the stalk carries the story, not decoration. The check-in control is the
/// brush stroke beneath it: one stroke, one day.
struct PulseQuietFieldTodayPage<CheckIn: View, Journal: View, Media: View>: View {
    let facts: PulseTodayFacts
    let checkIn: CheckIn
    let journal: Journal
    let media: Media

    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var accent: Color { PulseDesign.appAccent(for: theme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            identity

            stalk
                .frame(maxWidth: .infinity)
                .padding(.top, PulseDesign.spacing12)
                .padding(.bottom, PulseDesign.spacing4)

            checkIn
                .frame(maxWidth: .infinity)
                .padding(.top, PulseDesign.spacing8)

            weekBlades
                .padding(.top, PulseDesign.spacing24)

            VStack(alignment: .leading, spacing: PulseDesign.spacing20) {
                journal
                media
            }
            .padding(.top, PulseDesign.spacing24)
        }
        .frame(maxWidth: horizontalSizeClass == .regular ? 620 : .infinity, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.top, PulseDesign.spacing4)
        .padding(.bottom, PulseDesign.spacing12)
    }

    // MARK: - Commitment and rhythm

    private var identity: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
            if let today = facts.today, let timeZone = facts.timeZone {
                Text(PulseFormatting.fullDate(today, timeZone: timeZone, locale: locale))
                    .font(.subheadline)
                    .foregroundStyle(PulseDesign.appMuted(for: theme))
                    .accessibilityIdentifier("today.hero.kicker")
            }
            if let habitName = facts.habitName {
                Text(habitName)
                    .font(PulseDesign.editorialDisplayFont(size: 30, relativeTo: .largeTitle).weight(.bold))
                    .foregroundStyle(PulseDesign.appInk(for: theme))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("today.commitment.name")
            }
            Text(
                PulseTodayPresentation.rhythmStatusText(
                    currentStreak: facts.currentStreak,
                    locale: locale
                )
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(accent)
            .accessibilityIdentifier("today.rhythm.status")
        }
    }

    // MARK: - The streak as one stalk

    /// Decorative only: the week rail and rhythm text below carry the same facts to VoiceOver.
    private var stalk: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                EmptyView()
            } else {
                Canvas { context, size in
                    let days = Array(facts.recentDays.suffix(PulseDesign.quietStalkMaxNodes))
                    guard !days.isEmpty else { return }

                    let curve = stemCurve(in: size)

                    // The stem is one continuous stroke from soil to top node.
                    var stem = Path()
                    stem.move(to: curve.start)
                    stem.addCurve(to: curve.end, control1: curve.control1, control2: curve.control2)
                    context.stroke(
                        stem,
                        with: .color(accent),
                        style: StrokeStyle(
                            lineWidth: PulseDesign.quietStalkLineWidth,
                            lineCap: .round
                        )
                    )

                    let count = CGFloat(days.count)
                    for (index, item) in days.enumerated() {
                        // The oldest day rises from the soil; the newest sits at the top.
                        let t = count > 1 ? CGFloat(index) / (count - 1) : 1
                        let point = curve.point(at: t)
                        drawNode(
                            in: &context,
                            at: point,
                            item: item,
                            growthDirection: index % 2 == 0 ? -1 : 1
                        )
                    }
                }
                .frame(height: PulseDesign.quietStalkHeight)
            }
        }
        .accessibilityHidden(true)
    }

    private struct StemCurve {
        let start: CGPoint
        let control1: CGPoint
        let control2: CGPoint
        let end: CGPoint

        func point(at t: CGFloat) -> CGPoint {
            let oneMinus = 1 - t
            let weight0 = oneMinus * oneMinus * oneMinus
            let weight1 = 3 * oneMinus * oneMinus * t
            let weight2 = 3 * oneMinus * t * t
            let weight3 = t * t * t
            return CGPoint(
                x: weight0 * start.x + weight1 * control1.x + weight2 * control2.x + weight3 * end.x,
                y: weight0 * start.y + weight1 * control1.y + weight2 * control2.y + weight3 * end.y
            )
        }
    }

    private func stemCurve(in size: CGSize) -> StemCurve {
        let nodeRadius = PulseDesign.quietStalkNodeDiameter / 2
        return StemCurve(
            start: CGPoint(x: size.width * 0.62, y: size.height + nodeRadius),
            control1: CGPoint(x: size.width * 0.68, y: size.height * 0.62),
            control2: CGPoint(x: size.width * 0.46, y: size.height * 0.34),
            end: CGPoint(x: size.width * 0.42, y: nodeRadius)
        )
    }

    private func drawNode(
        in context: inout GraphicsContext,
        at point: CGPoint,
        item: CalendarDayItem,
        growthDirection: Int
    ) {
        let nodeRadius = PulseDesign.quietStalkNodeDiameter / 2
        let circle = Circle().path(in: CGRect(
            x: point.x - nodeRadius,
            y: point.y - nodeRadius,
            width: nodeRadius * 2,
            height: nodeRadius * 2
        ))

        switch item.status {
        case .checked:
            context.fill(circle, with: .color(accent))
            // A kept day puts one leaf on the stalk.
            let leaf = leafPath(at: point, direction: growthDirection)
            context.fill(leaf, with: .color(accent.opacity(0.85)))
        case .todayPending:
            // The day's node: hollow, waiting for its stroke.
            context.fill(circle, with: .color(PulseDesign.appSurface(for: theme)))
            context.stroke(
                circle,
                with: .color(accent),
                style: StrokeStyle(lineWidth: 2, dash: [4, 3])
            )
        case .missed:
            // A missed day stays a withered mark on the stalk.
            context.stroke(
                circle,
                with: .color(PulseDesign.appDivider(for: theme)),
                style: StrokeStyle(lineWidth: 1.5)
            )
        case .beforeHabit, .future:
            context.fill(circle, with: .color(PulseDesign.appDivider(for: theme).opacity(0.5)))
        }
    }

    private func leafPath(at point: CGPoint, direction: Int) -> Path {
        let length: CGFloat = 22
        let width: CGFloat = 8
        var path = Path()
        let tip = CGPoint(x: point.x + CGFloat(direction) * length, y: point.y - 6)
        path.move(to: point)
        path.addCurve(
            to: tip,
            control1: CGPoint(x: point.x + CGFloat(direction) * length * 0.4, y: point.y - width),
            control2: CGPoint(x: point.x + CGFloat(direction) * length * 0.6, y: point.y - width)
        )
        path.addCurve(
            to: point,
            control1: CGPoint(x: point.x + CGFloat(direction) * length * 0.6, y: point.y - 1),
            control2: CGPoint(x: point.x + CGFloat(direction) * length * 0.4, y: point.y - 1)
        )
        path.closeSubpath()
        return path
    }

    // MARK: - The week as grass blades

    private var weekBlades: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: PulseDesign.spacing16) {
                    ForEach(facts.recentDays) { item in
                        bladeLabel(item).frame(maxWidth: .infinity)
                    }
                }
            } else {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(facts.recentDays) { item in
                        bladeLabel(item).frame(maxWidth: .infinity)
                    }
                }
                .frame(minHeight: PulseDesign.minimumHitTarget)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.week.rail")
    }

    @ViewBuilder
    private func bladeLabel(_ item: CalendarDayItem) -> some View {
        let isToday = item.day == facts.today && item.status == .todayPending
        VStack(spacing: PulseDesign.spacing8) {
            if !dynamicTypeSize.isAccessibilitySize {
                bladeHeightMark(item)
            }
            VStack(spacing: 2) {
                if let timeZone = facts.timeZone {
                    Text(PulseFormatting.shortWeekday(item.day, timeZone: timeZone, locale: locale))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PulseDesign.appMuted(for: theme))
                }
                Text(item.day.day, format: .number)
                    .font(.system(size: 12, weight: isToday ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(
                        item.status == .checked
                            ? accent
                            : (isToday ? PulseDesign.appInk(for: theme) : PulseDesign.appMuted(for: theme))
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            facts.timeZone.map {
                PulseTodayPresentation.weekDayAccessibilityLabel(item, timeZone: $0, locale: locale)
            } ?? ""
        )
        .accessibilityIdentifier("today.week.day.\(item.day.storageValue)")
    }

    /// A kept day is a blade at full height; a missed one is cut short. Height is the state,
    /// so the rail never leans on color alone.
    private func bladeHeightMark(_ item: CalendarDayItem) -> some View {
        Capsule()
            .fill(bladeColor(item))
            .frame(width: PulseDesign.quietBladeWidth, height: bladeHeight(item))
            .accessibilityHidden(true)
    }

    private func bladeHeight(_ item: CalendarDayItem) -> CGFloat {
        switch item.status {
        case .checked: PulseDesign.quietBladeMaxHeight
        case .todayPending: PulseDesign.quietBladeMaxHeight * 0.66
        case .missed: 6
        case .beforeHabit, .future: 4
        }
    }

    private func bladeColor(_ item: CalendarDayItem) -> Color {
        switch item.status {
        case .checked: accent
        case .todayPending: accent.opacity(0.45)
        case .missed: PulseDesign.appDivider(for: theme)
        case .beforeHabit, .future: PulseDesign.appDivider(for: theme).opacity(0.6)
        }
    }
}
