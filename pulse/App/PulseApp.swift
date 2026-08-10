import SwiftUI
import OSLog

private enum PulseBootstrap {
    case ready(PulseAppModel)
    case failed

    private static let logger = Logger(
        subsystem: PulseRuntimeIdentity.bundleIdentifier,
        category: "persistence"
    )

    @MainActor
    static func build() -> PulseBootstrap {
        do {
            let container = try PersistenceController.makeContainer()
            let repository = SwiftDataCheckInRepository(container: container)
            let settings = try AppSettings()
            let model = PulseAppModel(
                repository: repository,
                settings: settings,
                reminderScheduler: ReminderScheduler(),
                clock: SystemPulseClock(),
                hapticFeedback: HapticFeedback()
            )
            return .ready(model)
        } catch {
            logger.fault("Failed to initialize the persistent store: \(error.localizedDescription, privacy: .private)")
            return .failed
        }
    }
}

@main
struct PulseApp: App {
    private let bootstrap = PulseBootstrap.build()

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .ready(let model):
                RootView(model: model)
            case .failed:
                StartupFailureView()
            }
        }
    }
}

private struct StartupFailureView: View {
    var body: some View {
        ContentUnavailableView {
            Label("startup.failure.title", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("startup.failure.message")
        }
        .padding()
    }
}
