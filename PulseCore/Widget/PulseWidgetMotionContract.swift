import Foundation

public enum PulseWidgetMotionContract {
    public enum PresentationMode: Equatable, Sendable {
        case phaseKeyframes
        case currentFrameOnly
    }

    public static let phaseStartHour: [PulseWidgetDayPhase: Int] = [
        .morning: 6,
        .midday: 12,
        .evening: 18,
        .night: 22,
    ]

    public static let minimumPhaseBoundaryInterval: TimeInterval = 30 * 60
}

public enum PulseWidgetDayPhase: String, Codable, Equatable, Sendable, CaseIterable {
    case morning
    case midday
    case evening
    case night

    public static func resolve(at date: Date, timeZone: TimeZone) -> PulseWidgetDayPhase {
        let hour = Calendar.pulseGregorian(timeZone: timeZone)
            .component(.hour, from: date)
        switch hour {
        case PulseWidgetMotionContract.phaseStartHour[.morning]!..<PulseWidgetMotionContract.phaseStartHour[.midday]!:
            return .morning
        case PulseWidgetMotionContract.phaseStartHour[.midday]!..<PulseWidgetMotionContract.phaseStartHour[.evening]!:
            return .midday
        case PulseWidgetMotionContract.phaseStartHour[.evening]!..<PulseWidgetMotionContract.phaseStartHour[.night]!:
            return .evening
        default:
            return .night
        }
    }

    public static func upcomingPhaseBoundaries(
        after date: Date,
        before boundary: Date,
        timeZone: TimeZone
    ) -> [Date] {
        guard date < boundary else { return [] }

        let logicalDay = LogicalDay.resolve(at: date, timeZone: timeZone)

        return Self.allCases.compactMap { phase -> Date? in
            guard let hour = PulseWidgetMotionContract.phaseStartHour[phase] else { return nil }
            let calendar = Calendar.pulseGregorian(timeZone: timeZone)
            guard let phaseStart = calendar.date(
                from: DateComponents(
                    year: logicalDay.year,
                    month: logicalDay.month,
                    day: logicalDay.day,
                    hour: hour
                )
            ) else { return nil }
            guard phaseStart > date, phaseStart < boundary else { return nil }
            return phaseStart
        }
        .sorted()
    }
}
