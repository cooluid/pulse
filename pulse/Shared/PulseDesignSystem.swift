import SwiftUI

enum PulseDesign {
    static let background = Color("PulseBackground")
    static let surface = Color("PulseSurface")
    static let ink = Color("PulseInk")
    static let secondary = Color("PulseSecondary")
    static let brand = Color.accentColor
    static let success = Color("PulseSuccess")
    static let actionForeground = background
    static let separator = ink.opacity(0.14)

    static let surfaceCornerRadius: CGFloat = 20
    static let contentSpacing: CGFloat = 24
    static let horizontalPadding: CGFloat = 24
}

struct PulseSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(PulseDesign.surface, in: RoundedRectangle(cornerRadius: PulseDesign.surfaceCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: PulseDesign.surfaceCornerRadius)
                    .stroke(PulseDesign.separator, lineWidth: 1)
            }
    }
}

extension View {
    func pulseSurface() -> some View {
        modifier(PulseSurfaceModifier())
    }
}

struct PulseBackground: View {
    var body: some View {
        PulseDesign.background
            .ignoresSafeArea()
    }
}
