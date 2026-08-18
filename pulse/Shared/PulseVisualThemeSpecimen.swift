import SwiftUI

struct PulseVisualThemeSpecimen: View {
    let theme: PulseVisualTheme

    var body: some View {
        ZStack {
            PulseScreenBackground()
            PulseFieldBackground(presentation: .today, allowsMotion: false)
            mark
        }
        .frame(maxWidth: .infinity)
        .frame(height: PulseDesign.themePreviewHeight)
        .clipShape(
            RoundedRectangle(
                cornerRadius: PulseDesign.themePreviewCornerRadius,
                style: .continuous
            )
        )
        .environment(\.pulseVisualTheme, theme)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var mark: some View {
        switch theme {
        case .editorialJournal:
            VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
                Text(verbatim: "Aa")
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(PulseDesign.ink)

                VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                    Rectangle()
                        .fill(PulseDesign.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: PulseDesign.emphasisLineWidth)
                    Rectangle()
                        .fill(PulseDesign.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: PulseDesign.thinLineWidth)
                        .padding(.trailing, PulseDesign.spacing32)
                    Rectangle()
                        .fill(PulseDesign.editorialAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: PulseDesign.thinLineWidth)
                        .padding(.trailing, PulseDesign.spacing32 + PulseDesign.spacing24)
                }
            }
            .padding(PulseDesign.spacing16)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .quietField:
            HStack(spacing: PulseDesign.spacing12) {
                PulseBrandMark(size: PulseDesign.minimumHitTarget)

                VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                    Capsule()
                        .fill(PulseDesign.quietChrome)
                        .frame(maxWidth: .infinity)
                        .frame(height: PulseDesign.spacing8)
                        .padding(.trailing, PulseDesign.spacing32)
                    Capsule()
                        .fill(PulseDesign.quietGreen)
                        .frame(maxWidth: .infinity)
                        .frame(height: PulseDesign.spacing8)
                }
            }
            .padding(PulseDesign.spacing16)
            .frame(maxWidth: .infinity)
        case .sunlitDay:
            VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "sun.max.fill")
                        .font(.headline.weight(.bold))
                    Spacer(minLength: 0)
                    Circle()
                        .fill(PulseDesign.sunlitSurface)
                        .frame(width: PulseDesign.spacing16, height: PulseDesign.spacing16)
                }

                RoundedRectangle(
                    cornerRadius: PulseDesign.spacing12,
                    style: .continuous
                )
                .fill(PulseDesign.sunlitChrome)
                .frame(height: PulseDesign.spacing32)
                .overlay(alignment: .trailing) {
                    Circle()
                        .fill(PulseDesign.sunlitAccent)
                        .padding(PulseDesign.spacing4)
                }
            }
            .padding(PulseDesign.spacing16)
            .foregroundStyle(PulseDesign.sunlitInk)
            .frame(maxWidth: .infinity)
        }
    }
}
