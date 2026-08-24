import PulseCore
import SwiftUI

extension PulseDesign {
    struct CalendarDayStyle {
        enum Mark: Equatable {
            case none
            case checked
            case missed
            case beforeHabit
        }

        enum Tile: Equatable {
            case companion
            case rounded(CGFloat)
        }

        let tileSize: CGFloat
        let tile: Tile
        let fontDesign: Font.Design
        let fill: Color
        let foreground: Color
        let todayStroke: Color
        let mediaForeground: Color
        let showsCheckedRule: Bool
        let mark: Mark

        var usesCompanionShape: Bool {
            if case .companion = tile { return true }
            return false
        }

        static func resolve(
            theme: PulseVisualTheme,
            status: CalendarDayStatus
        ) -> CalendarDayStyle {
            CalendarDayStyle(
                tileSize: tileSize(for: theme),
                tile: tile(for: theme),
                fontDesign: fontDesign(for: theme),
                fill: fill(theme: theme, status: status),
                foreground: foreground(theme: theme, status: status),
                todayStroke: todayStroke(for: theme),
                mediaForeground: mediaForeground(theme: theme, status: status),
                showsCheckedRule: theme == .editorialJournal && status == .checked,
                mark: mark(for: status)
            )
        }

        private static func tileSize(for theme: PulseVisualTheme) -> CGFloat {
            switch theme {
            case .editorialJournal:
                calendarDayVisualSize
            case .quietField, .sunlitDay:
                calendarDayVisualSize + spacing4
            }
        }

        private static func tile(for theme: PulseVisualTheme) -> Tile {
            switch theme {
            case .quietField:
                .companion
            case .sunlitDay:
                .rounded(sunlitCalendarDayCornerRadius)
            case .editorialJournal:
                .rounded(editorialCalendarDayCornerRadius)
            }
        }

        private static func fontDesign(for theme: PulseVisualTheme) -> Font.Design {
            theme == .editorialJournal ? .serif : .default
        }

        private static func fill(
            theme: PulseVisualTheme,
            status: CalendarDayStatus
        ) -> Color {
            switch theme {
            case .quietField:
                switch status {
                case .checked:
                    quietGreen
                case .todayPending:
                    quietGreenSoft.opacity(0.54)
                case .missed:
                    quietPink.opacity(0.10)
                case .future, .beforeHabit:
                    .clear
                }
            case .sunlitDay:
                switch status {
                case .checked:
                    sunlitChrome
                case .todayPending:
                    sunlitSurface
                case .missed:
                    sunlitSurface.opacity(0.62)
                case .future, .beforeHabit:
                    .clear
                }
            case .editorialJournal:
                status == .checked
                    ? editorialAccent.opacity(editorialCalendarCheckedOpacity)
                    : .clear
            }
        }

        private static func foreground(
            theme: PulseVisualTheme,
            status: CalendarDayStatus
        ) -> Color {
            switch theme {
            case .quietField:
                switch status {
                case .checked:
                    quietOnGreen
                case .missed, .todayPending, .future:
                    quietMuted
                case .beforeHabit:
                    quietMuted.opacity(calendarBeforeHabitOpacity)
                }
            case .sunlitDay:
                switch status {
                case .checked:
                    sunlitAccent
                case .missed, .future:
                    sunlitMuted
                case .todayPending:
                    sunlitInk
                case .beforeHabit:
                    sunlitMuted.opacity(calendarBeforeHabitOpacity)
                }
            case .editorialJournal:
                switch status {
                case .checked:
                    editorialAccent
                case .missed, .todayPending, .future:
                    secondary
                case .beforeHabit:
                    secondary.opacity(calendarBeforeHabitOpacity)
                }
            }
        }

        private static func todayStroke(for theme: PulseVisualTheme) -> Color {
            switch theme {
            case .quietField:
                quietPink
            case .sunlitDay:
                sunlitChrome
            case .editorialJournal:
                editorialAccent
            }
        }

        private static func mediaForeground(
            theme: PulseVisualTheme,
            status: CalendarDayStatus
        ) -> Color {
            switch theme {
            case .quietField:
                quietBlue
            case .sunlitDay:
                status == .checked ? sunlitAccent : sunlitChrome
            case .editorialJournal:
                editorialAccent
            }
        }

        private static func mark(for status: CalendarDayStatus) -> Mark {
            switch status {
            case .checked:
                .checked
            case .missed:
                .missed
            case .beforeHabit:
                .beforeHabit
            case .todayPending, .future:
                .none
            }
        }
    }
}
