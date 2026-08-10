import Foundation

@MainActor
protocol PulseClock {
    var now: Date { get }
}

struct SystemPulseClock: PulseClock {
    var now: Date { Date() }
}

struct FixedPulseClock: PulseClock {
    let now: Date
}
