import SwiftUI

@main
struct PulseWatchApp: App {
    @State private var bootstrap = PulseWatchBootstrap.build()

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .ready(let model):
                PulseWatchTodayView(model: model)
            case .failed:
                PulseWatchStartupFailureView {
                    bootstrap = PulseWatchBootstrap.build()
                }
            }
        }
    }
}
