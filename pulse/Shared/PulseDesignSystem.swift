import SwiftUI
import UIKit

enum PulseDesign {
    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let tint = Color.primary
    static let actionBackground = Color.primary
    static let actionForeground = Color(uiColor: .systemBackground)
    static let separator = Color(uiColor: .separator)

    static let contentSpacing: CGFloat = 24
    static let horizontalPadding: CGFloat = 20
}

struct PulseScreenBackground: View {
    var body: some View {
        PulseDesign.background
            .ignoresSafeArea()
    }
}
