import Foundation

enum PulseWidgetStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case place
    case orbit
    case stack
    case bleed
    case letter
    case field
    case path
    case tide

    var id: String { rawValue }
}

enum PulseWidgetStyleAccessPolicy {
    static let freeStyle = PulseWidgetStyle.place

    static var enhancementStyles: [PulseWidgetStyle] {
        PulseWidgetStyle.allCases.filter(requiresEnhancement)
    }

    static func requiresEnhancement(_ style: PulseWidgetStyle) -> Bool {
        style != freeStyle
    }

    static func isAvailable(
        _ style: PulseWidgetStyle,
        hasEnhancementEntitlement: Bool
    ) -> Bool {
        !requiresEnhancement(style) || hasEnhancementEntitlement
    }
}
