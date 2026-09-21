import PulseCore
import SwiftUI

/// The part of a theme that holds still while the page scrolls.
///
/// Immersion keeps the day's number here, Moon Tide keeps the date line — the water itself lives
/// in `PulseFieldBackground`. Scrolling then moves the day's work across a surface that does not
/// slide away underneath it, and nothing gets cut off flat at the top of the list.
///
/// The date line stays readable to VoiceOver because it carries a real fact; the number does not.
struct PulseThemeBackdrop: View {
    let facts: PulseTodayFacts

    @Environment(\.pulseVisualTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    private var accent: Color { PulseDesign.appAccent(for: theme) }
    private var topInset: CGFloat { PulseDesign.topBarHeight + PulseDesign.spacing4 }

    var body: some View {
        Group {
            switch theme {
            case .immersion:
                immersion
            default:
                EmptyView()
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Immersion

    private var immersion: some View {
        VStack(alignment: .trailing, spacing: 0) {
            dateLine
                .frame(maxWidth: .infinity, alignment: .leading)

            if !dynamicTypeSize.isAccessibilitySize {
                dayNumber
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, topInset)
        .padding(.horizontal, PulseDesign.horizontalPadding)
    }

    private var dayNumber: some View {
        Text(facts.today.map { String($0.day) } ?? "")
            .font(.system(size: 176, weight: .black))
            .kerning(-9)
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(accent.opacity(0.36))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .mask(sinkGradient)
            .accessibilityHidden(true)
    }

    /// The number stays loud at the top and gives way quickly below, so the day's work can scroll
    /// over it without two loud things fighting for the same space.
    private var sinkGradient: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black.opacity(0.90), location: 0.44),
                .init(color: .black.opacity(0.32), location: 0.80),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Moon Tide

    // MARK: - Shared

    @ViewBuilder
    private var dateLine: some View {
        if let today = facts.today, let timeZone = facts.timeZone {
            Text(PulseFormatting.fullDate(today, timeZone: timeZone, locale: locale))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PulseDesign.appMuted(for: theme))
                .accessibilityIdentifier("today.hero.kicker")
        }
    }
}
