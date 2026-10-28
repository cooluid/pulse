import SwiftUI
import UIKit

extension PulseVisualTheme {
    /// A theme printed on dark paper stays dark, so the system's own bars, menus and keyboards match it.
    var fixedColorScheme: ColorScheme? {
        switch self {
        case .sunlitDay: .dark
        case .editorialJournal, .quietField: nil
        }
    }
}

enum PulseThemeAppearance {
    static func preferredColorScheme(theme: PulseVisualTheme, appearance: AppTheme) -> ColorScheme? {
        if let fixed = theme.fixedColorScheme { return fixed }
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
