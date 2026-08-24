import PulseCore
import WidgetKit

@MainActor
enum PulseWidgetTimelineReloadCoordinator {
    static func reloadAllKinds() {
        for kind in PulseWidgetContract.allKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}
