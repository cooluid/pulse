import Foundation

@MainActor
public protocol PulseClock {
    var now: Date { get }
}

public struct SystemPulseClock: PulseClock {
    public init() {}

    public var now: Date { Date() }
}

public struct FixedPulseClock: PulseClock {
    public let now: Date

    public init(now: Date) {
        self.now = now
    }
}
