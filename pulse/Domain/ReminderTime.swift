import Foundation
import PulseCore

struct ReminderTime: Equatable, Sendable {
    static let standard = ReminderTime(validatedMinutesFromMidnight: 20 * 60)

    let minutesFromMidnight: Int

    var hour: Int { minutesFromMidnight / 60 }
    var minute: Int { minutesFromMidnight % 60 }

    var pickerDate: Date {
        Date(timeIntervalSinceReferenceDate: TimeInterval(minutesFromMidnight * 60))
    }

    init?(minutesFromMidnight: Int) {
        guard (0..<(24 * 60)).contains(minutesFromMidnight) else {
            return nil
        }
        self.init(validatedMinutesFromMidnight: minutesFromMidnight)
    }

    init?(hour: Int, minute: Int) {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else {
            return nil
        }
        self.init(validatedMinutesFromMidnight: hour * 60 + minute)
    }

    init?(pickerDate: Date) {
        let components = Calendar.pulseGregorian(timeZone: .gmt)
            .dateComponents([.hour, .minute], from: pickerDate)
        guard let hour = components.hour, let minute = components.minute else {
            return nil
        }
        self.init(hour: hour, minute: minute)
    }

    private init(validatedMinutesFromMidnight: Int) {
        minutesFromMidnight = validatedMinutesFromMidnight
    }
}
