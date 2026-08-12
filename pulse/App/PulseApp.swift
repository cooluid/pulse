import SwiftUI
import OSLog
import PulseCore

private enum StartupFailure: Equatable {
    case persistence
    case settings
    case sharedSettings
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
        category: "bootstrap"
    )

    @MainActor
    static func build() -> PulseBootstrap {
        do {
            let clock = runtimeClock()
            let initialIdentity = try HabitIdentity(
                userName: PulseLocalization.string(
                    "habit.default_name",
                    locale: .autoupdatingCurrent
                ),
                userPurpose: nil
            )
            let store = try runtimeStore()
            let container = try PersistenceController.makeContainer(
                inMemory: store.inMemory,
                storeName: store.name,
                storeURL: store.url
            )
            let repository = SwiftDataCheckInRepository(
                container: container,
                clock: clock,
                primaryHabitProvisioning: .createIfMissing(initialIdentity)
            )
            let settings = try AppSettings(
                sharedInterfacePreferences: try PulseSharedInterfacePreferences(
                    appGroupIdentifier: PulseRuntimeIdentity.appGroupIdentifier
                )
            )
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
        } catch let error as PulseSharedInterfacePreferenceError {
            logger.error("Failed to access shared interface settings: \(String(describing: error), privacy: .public)")
            return .failed(.sharedSettings)
        } catch {
            logger.fault("Failed to initialize the persistent store: \(error.localizedDescription, privacy: .private)")
            return .failed(.persistence)
        }
    }

    @MainActor
    static func resetSettings() throws {
        let sharedInterfacePreferences = try PulseSharedInterfacePreferences(
            appGroupIdentifier: PulseRuntimeIdentity.appGroupIdentifier
        )
        AppSettings.clearStoredValues(
            sharedInterfacePreferences: sharedInterfacePreferences
        )
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

    @MainActor
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
        let sharedLocation = try PulseStoreLocator().appGroupLocation(
            identifier: PulseRuntimeIdentity.appGroupIdentifier
        )
        return RuntimeStore(
            name: PulseStoreContract.storeName,
            inMemory: false,
            url: sharedLocation.storeURL
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
                        do {
                            try PulseBootstrap.resetSettings()
                            bootstrap = PulseBootstrap.build()
                        } catch {
                            bootstrap = .failed(.sharedSettings)
                        }
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
            case .sharedSettings:
                Text("startup.failure.shared_settings_message")
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
