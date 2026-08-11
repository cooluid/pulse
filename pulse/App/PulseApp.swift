import SwiftUI
import OSLog
import PulseCore

private enum StartupFailure: Equatable {
    case persistence
    case settings
}

private enum PulseBootstrap {
    private struct RuntimeStore {
        let name: String
        let inMemory: Bool
        let url: URL?
    }

    case ready(PulseAppModel)
    case failed(StartupFailure)

    private static let logger = Logger(
        subsystem: PulseRuntimeIdentity.bundleIdentifier,
        category: "persistence"
    )

    @MainActor
    static func build() -> PulseBootstrap {
        do {
            let clock = runtimeClock()
            let store = try runtimeStore()
            let container = try PersistenceController.makeContainer(
                inMemory: store.inMemory,
                storeName: store.name,
                storeURL: store.url
            )
            let initialIdentity = try HabitIdentity(
                userName: PulseLocalization.string(
                    "habit.default_name",
                    locale: .autoupdatingCurrent
                ),
                userPurpose: nil
            )
            let repository = SwiftDataCheckInRepository(
                container: container,
                clock: clock,
                initialIdentity: initialIdentity
            )
            let settings = try AppSettings()
            let model = PulseAppModel(
                repository: repository,
                settings: settings,
                reminderScheduler: ReminderScheduler(),
                clock: clock,
                hapticFeedback: HapticFeedback()
            )
            return .ready(model)
        } catch PulseAppError.invalidSettings {
            logger.error("Failed to load application settings.")
            return .failed(.settings)
        } catch {
            logger.fault("Failed to initialize the persistent store: \(error.localizedDescription, privacy: .private)")
            return .failed(.persistence)
        }
    }

    @MainActor
    private static func runtimeClock() -> any PulseClock {
#if DEBUG
        if let value = ProcessInfo.processInfo.environment["PULSE_UI_TEST_NOW"] {
            let formatter = ISO8601DateFormatter()
            guard let date = formatter.date(from: value) else {
                preconditionFailure("PULSE_UI_TEST_NOW must be an ISO-8601 timestamp.")
            }
            return FixedPulseClock(now: date)
        }
#endif
        return SystemPulseClock()
    }

    private static func runtimeStore() throws -> RuntimeStore {
#if DEBUG
        if let value = ProcessInfo.processInfo.environment["PULSE_UI_TEST_STORE_ID"] {
            guard let identifier = UUID(uuidString: value) else {
                preconditionFailure("PULSE_UI_TEST_STORE_ID must be a UUID.")
            }
            return RuntimeStore(
                name: "PulseUITest-\(identifier.uuidString)",
                inMemory: false,
                url: nil
            )
        }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return RuntimeStore(name: "PulseUnitTests", inMemory: true, url: nil)
        }
#endif
        return RuntimeStore(
            name: PulseStoreContract.storeName,
            inMemory: false,
            url: try PulseStoreLocator().appPrivateLocation().storeURL
        )
    }
}

@main
struct PulseApp: App {
    @State private var bootstrap = PulseBootstrap.build()

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .ready(let model):
                ConfiguredRootView(model: model)
            case .failed(let failure):
                StartupFailureView(
                    failure: failure,
                    retry: { bootstrap = PulseBootstrap.build() },
                    resetSettings: {
                        AppSettings.clearStoredValues()
                        bootstrap = PulseBootstrap.build()
                    }
                )
            }
        }
    }
}

private struct ConfiguredRootView: View {
    let model: PulseAppModel
    @Bindable var settings: AppSettings

    init(model: PulseAppModel) {
        self.model = model
        settings = model.settings
    }

    var body: some View {
        RootView(model: model)
            .environment(\.locale, settings.locale)
            .preferredColorScheme(settings.theme.preferredColorScheme)
    }
}

private extension AppTheme {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private struct StartupFailureView: View {
    let failure: StartupFailure
    let retry: () -> Void
    let resetSettings: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("startup.failure.title", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            switch failure {
            case .persistence:
                Text("startup.failure.persistence_message")
            case .settings:
                Text("startup.failure.settings_message")
            }
        } actions: {
            Button("action.retry", action: retry)
                .buttonStyle(.borderedProminent)

            if failure == .settings {
                Button("startup.failure.reset_settings", action: resetSettings)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
