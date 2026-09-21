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
