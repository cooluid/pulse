import Foundation

public struct PulseWidgetVisualVariant: Equatable, Sendable, Hashable {
    public let phase: PulseWidgetDayPhase
    public let ornamentSeed: UInt32

    public init(phase: PulseWidgetDayPhase, ornamentSeed: UInt32) {
        self.phase = phase
        self.ornamentSeed = ornamentSeed
    }

    public static func make(
        for day: LogicalDay,
        at date: Date,
        timeZone: TimeZone
    ) -> PulseWidgetVisualVariant {
        PulseWidgetVisualVariant(
            phase: PulseWidgetDayPhase.resolve(at: date, timeZone: timeZone),
            ornamentSeed: ornamentSeed(for: day)
        )
    }

    public static func ornamentSeed(for day: LogicalDay) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for byte in day.storageValue.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 1_677_761_9
        }
        return hash
    }

    /// Horizontal cloud drift normalized to roughly -1...1.
    public var cloudDrift: Double {
        let phaseOffset: Double = switch phase {
        case .morning: -0.55
        case .midday: 0.0
        case .evening: 0.42
        case .night: 0.12
        }
        let seedJitter = Double(ornamentSeed % 1_000) / 1_000 * 0.16 - 0.08
        return Self.clamp(phaseOffset + seedJitter, lower: -1, upper: 1)
    }

    /// Fish depth before check-in: 0 is deeper, 1 is nearer the surface.
    public var fishDepth: Double {
        let phaseOffset: Double = switch phase {
        case .morning: 0.72
        case .midday: 0.58
        case .evening: 0.66
        case .night: 0.48
        }
        let seedJitter = Double((ornamentSeed >> 8) % 1_000) / 1_000 * 0.12 - 0.06
        return Self.clamp(phaseOffset + seedJitter, lower: 0.32, upper: 0.82)
    }

    /// Fish arc when checked in: 0 resting near shore, 1 peak leap.
    public var fishLeap: Double {
        switch phase {
        case .morning: 0.92
        case .midday: 0.78
        case .evening: 0.86
        case .night: 0.68
        }
    }

    /// Ambient atmosphere intensity for non-tide styles.
    public var ambientIntensity: Double {
        switch phase {
        case .morning: 0.92
        case .midday: 1.0
        case .evening: 0.96
        case .night: 0.82
        }
    }

    /// Soft horizon lift applied to tide shore height ratios.
    public var tideHorizonLift: Double {
        switch phase {
        case .morning: -0.012
        case .midday: 0
        case .evening: 0.008
        case .night: -0.006
        }
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
