import PulseCore
import WidgetKit

@MainActor
protocol WidgetTimelineReloading: AnyObject {
    func reloadDailyImprint()
}

@MainActor
final class WidgetTimelineReloader: WidgetTimelineReloading {
    func reloadDailyImprint() {
        WidgetCenter.shared.reloadTimelines(ofKind: PulseWidgetContract.kind)
    }
}
