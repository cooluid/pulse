import PulseWatchShared
import WidgetKit

@MainActor
enum PulseWatchWidgetTimelineReloadCoordinator {
    static func reloadAllKinds() {
        for kind in PulseWatchContract.allWidgetKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}
