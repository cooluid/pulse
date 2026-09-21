import SwiftUI
import UIKit

enum PulseThemeAppearance {
    static func preferredColorScheme(theme: PulseVisualTheme, appearance: AppTheme) -> ColorScheme? {
        // Immersion is drawn on ink: its accent only carries on a dark surface.
        if theme == .immersion { return .dark }
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    @MainActor
    static func previewColorScheme(theme: PulseVisualTheme, appearance: AppTheme,
                                   inherited: ColorScheme) -> ColorScheme {
        if let specified = preferredColorScheme(theme: theme, appearance: appearance) {
            return specified
        }
        // Read the display's traits, outside the theme's presentation override.
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        switch scene?.screen.traitCollection.userInterfaceStyle {
        case .dark?: return .dark
        case .light?: return .light
        default: return inherited
        }
    }
}

struct PulseStampOutline: View {
    var body: some View {
        Image("PulseStampBorder")
            .renderingMode(.template)
            .resizable()
            .accessibilityHidden(true)
    }
}

struct PulsePageFold: View {
    @Environment(\.pulseVisualTheme) private var theme

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(PulseDesign.appAccentForeground(for: theme))
            .offset(x: 8, y: -8)
            .frame(width: 42, height: 42)
            .background {
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: 42, y: 42))
                    path.addLine(to: CGPoint(x: 4, y: 37))
                    path.closeSubpath()
                }
                .fill(PulseDesign.appSurface(for: theme))
                .shadow(color: PulseDesign.shadow.opacity(0.22), radius: 3, x: -1, y: 2)
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: 42, y: 0))
                    path.addLine(to: CGPoint(x: 42, y: 42))
                    path.closeSubpath()
                }
                .fill(PulseDesign.appAccent(for: theme))
            }
            .accessibilityHidden(true)
    }
}
