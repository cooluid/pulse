import PulseCore
import SwiftUI

extension PulseDesign {
    struct CalendarDayStyle {
        enum Mark: Equatable {
            case none, checked, missed, beforeHabit
        }

        let cornerRadius: CGFloat
        let tileSize: CGFloat
        let fill: Color
        let foreground: Color
        let todayStroke: Color
        let mediaForeground: Color
        let mark: Mark

        static func resolve(theme: PulseVisualTheme, status: CalendarDayStatus) -> CalendarDayStyle {
            let mark: Mark = switch status {
            case .checked: .checked
            case .missed: .missed
            case .beforeHabit: .beforeHabit
            case .todayPending, .future: .none
            }
            let radius: CGFloat = switch theme {
            case .editorialJournal, .prismLedger: 3
            case .quietField: 20
            case .sunlitDay: 8
            case .immersion: 19
            }
            return CalendarDayStyle(
                cornerRadius: radius,
                tileSize: calendarDayVisualSize + spacing4,
                fill: status == .checked ? appAccent(for: theme) : .clear,
                foreground: status == .checked ? appAccentForeground(for: theme) : appMuted(for: theme),
                todayStroke: appAccent(for: theme),
                mediaForeground: status == .checked ? appAccentForeground(for: theme) : appAccent(for: theme),
                mark: mark
            )
        }
    }
}
