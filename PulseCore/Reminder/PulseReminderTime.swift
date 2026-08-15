import Foundation

public struct PulseReminderTime: Equatable, Sendable {
    public static let standard = PulseReminderTime(validatedMinutesFromMidnight: 20 * 60)

    public let minutesFromMidnight: Int

    public var hour: Int { minutesFromMidnight / 60 }
    public var minute: Int { minutesFromMidnight % 60 }

    public var pickerDate: Date {
        Date(timeIntervalSinceReferenceDate: TimeInterval(minutesFromMidnight * 60))
    }

    public init?(minutesFromMidnight: Int) {
        guard (0..<(24 * 60)).contains(minutesFromMidnight) else { return nil }
        self.init(validatedMinutesFromMidnight: minutesFromMidnight)
    }

    public init?(hour: Int, minute: Int) {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        self.init(validatedMinutesFromMidnight: hour * 60 + minute)
    }

    public init?(pickerDate: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = calendar.dateComponents([.hour, .minute], from: pickerDate)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        self.init(hour: hour, minute: minute)
    }

    private init(validatedMinutesFromMidnight: Int) {
        minutesFromMidnight = validatedMinutesFromMidnight
    }
}
