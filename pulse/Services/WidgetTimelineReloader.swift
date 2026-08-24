@MainActor
protocol WidgetTimelineReloading: AnyObject {
    func reloadDailyImprint()
}

@MainActor
final class WidgetTimelineReloader: WidgetTimelineReloading {
    func reloadDailyImprint() {
        PulseWidgetTimelineReloadCoordinator.reloadAllKinds()
    }
}
