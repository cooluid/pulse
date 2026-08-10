import SwiftUI

enum PulseDesign {
    static let brand = Color(red: 0.35, green: 0.29, blue: 0.92)
    static let brandDeep = Color(red: 0.22, green: 0.18, blue: 0.68)
    static let success = Color(red: 0.12, green: 0.64, blue: 0.45)
    static let warning = Color(red: 0.91, green: 0.48, blue: 0.16)
    static let cardCornerRadius: CGFloat = 24
    static let contentSpacing: CGFloat = 20
    static let horizontalPadding: CGFloat = 20
}

struct PulseCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PulseDesign.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: PulseDesign.cardCornerRadius)
                    .stroke(.primary.opacity(0.06), lineWidth: 1)
            }
    }
}

extension View {
    func pulseCard() -> some View {
        modifier(PulseCardModifier())
    }
}

struct PulseBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                PulseDesign.brand.opacity(0.12),
                Color(uiColor: .systemBackground),
                PulseDesign.success.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

