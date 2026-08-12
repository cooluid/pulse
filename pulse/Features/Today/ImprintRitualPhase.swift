enum ImprintRitualPhase: Equatable {
    case ready
    case saving
    case contracting
    case imprinting
    case imprinted

    var usesSolidGlyph: Bool {
        self == .imprinting || self == .imprinted
    }
}
