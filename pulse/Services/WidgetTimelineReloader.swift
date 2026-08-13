import PulseCore
import WidgetKit

@MainActor
protocol WidgetTimelineReloading: AnyObject {
    func reloadDailyImprint()
}

@MainActor
final class WidgetTimelineReloader: WidgetTimelineReloading {
    func reloadDailyImprint() {
        for kind in PulseWidgetContract.allKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}
