import SwiftUI
import SwiftData
import OSLog
import PulseCore

private enum StartupFailure: Equatable {
    case persistence
    case settings
    case sharedSettings
}

private enum PulseBootstrap {
    private enum RuntimeStore {
        case inMemory(name: String, workingDirectoryURL: URL)
        case disk(name: String, location: PulseStoreLocation)

        func makeContainer() throws -> ModelContainer {
            switch self {
            case .inMemory(let name, _):
                try PersistenceController.makeInMemoryContainer(storeName: name)
            case .disk(let name, let location):
                try PersistenceController.makeContainer(
                    storeName: name,
                    storeURL: location.storeURL
                )
            }
        }

        var workingDirectoryURL: URL {
            switch self {
            case .inMemory(_, let workingDirectoryURL): workingDirectoryURL
            case .disk(_, let location): location.directoryURL
            }
        }
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
            let container = try store.makeContainer()
            let repository = SwiftDataPulseRepository(
                container: container,
                clock: clock,
                primaryHabitProvisioning: .createIfMissing(initialIdentity)
            )
            let mediaRootURL = try runtimeMediaDirectoryURL(
                for: store,
                repository: repository
            )
            let mediaFileStore = try PulseMediaFileStore(rootURL: mediaRootURL)
            let archiveWorkingDirectoryURL = store.workingDirectoryURL.appendingPathComponent(
                PulseStoreContract.archiveWorkingDirectoryName,
                isDirectory: true
            )
            try prepareArchiveWorkingDirectory(archiveWorkingDirectoryURL)
            let sharedSettings = try PulseSharedSettings(
                appGroupIdentifier: PulseRuntimeIdentity.appGroupIdentifier
            )
#if DEBUG
            if ProcessInfo.processInfo.environment["PULSE_UI_TEST_RESET"] == "1" {
                AppSettings.clearStoredValues(sharedSettings: sharedSettings)
            }
#endif
            let settings = try AppSettings(sharedSettings: sharedSettings)
            let watchConnectivity = PulseWatchConnectivityFactory.make()
            let model = PulseAppModel(
                repository: repository,
                mediaService: ImprintMediaService(
                    repository: repository,
                    fileStore: mediaFileStore,
                    clock: clock
                ),
                archiveWorkingDirectoryURL: archiveWorkingDirectoryURL,
                settings: settings,
                featureAccess: runtimeFeatureAccess(),
                reminderScheduler: runtimeReminderScheduler(),
                clock: clock,
                hapticFeedback: HapticFeedback(),
                widgetTimelineReloader: WidgetTimelineReloader(),
                watchConnectivity: watchConnectivity
            )
            return .ready(model)
        } catch PulseAppError.invalidSettings {
            logger.error("Failed to load application settings.")
            return .failed(.settings)
        } catch let error as PulseSharedSettingsError {
            logger.error("Failed to access shared interface settings: \(String(describing: error), privacy: .public)")
            return .failed(.sharedSettings)
        } catch {
            logger.fault("Failed to initialize the persistent store: \(error.localizedDescription, privacy: .private)")
            return .failed(.persistence)
        }
    }

    private static func prepareArchiveWorkingDirectory(_ directoryURL: URL) throws {
        guard directoryURL.isFileURL,
              directoryURL.lastPathComponent == PulseStoreContract.archiveWorkingDirectoryName else {
            throw PulseStoreLocationError.invalidDirectoryURL
        }
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let staleItems = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        for item in staleItems {
            try FileManager.default.removeItem(at: item)
        }
        try PulseStoreProtection.enforce(in: directoryURL)
    }

    @MainActor
    private static func runtimeFeatureAccess() -> FeatureAccessController {
#if DEBUG
        if let value = ProcessInfo.processInfo.environment["PULSE_UI_TEST_ENHANCEMENT_PURCHASED"] {
            return FeatureAccessController(
                client: UITestStoreKitAccessClient(hasEntitlement: value == "1"),
                listensForTransactionUpdates: false
            )
        }
#endif
        return FeatureAccessController()
    }

    @MainActor
    private static func runtimeReminderScheduler() -> any ReminderScheduling {
#if DEBUG
        if ProcessInfo.processInfo.environment["PULSE_UI_TEST_STORE_ID"] != nil {
            return PulseUITestReminderScheduler()
        }
#endif
        return ReminderScheduler()
    }

    @MainActor
    static func resetSettings() throws {
        let sharedSettings = try PulseSharedSettings(
            appGroupIdentifier: PulseRuntimeIdentity.appGroupIdentifier
        )
        AppSettings.clearStoredValues(
            sharedSettings: sharedSettings
        )
        AppSettings.discardCorruptedResetJournal()
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
            let directoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("PulseUITests", isDirectory: true)
                .appendingPathComponent(identifier.uuidString, isDirectory: true)
            return .disk(
                name: "PulseUITest-\(identifier.uuidString)",
                location: try PulseStoreLocation(directoryURL: directoryURL)
            )
        }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .inMemory(
                name: "PulseUnitTests",
                workingDirectoryURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("PulseUnitTests-\(UUID().uuidString)", isDirectory: true)
            )
        }
#endif
        let sharedLocation = try PulseStoreLocator().appGroupLocation(
            identifier: PulseRuntimeIdentity.appGroupIdentifier
        )
        return .disk(name: PulseStoreContract.storeName, location: sharedLocation)
    }

    @MainActor
    private static func runtimeMediaDirectoryURL(
        for store: RuntimeStore,
        repository: SwiftDataPulseRepository
    ) throws -> URL {
        switch store {
        case .inMemory(_, let workingDirectoryURL):
            return workingDirectoryURL.appendingPathComponent(
                PulseStoreContract.mediaDirectoryName,
                isDirectory: true
            )
        case .disk(let name, let location):
            // Production shares only the store. Widget and Watch never consume media, so
            // photo files remain in the main app's private container.
            guard name == PulseStoreContract.storeName else {
                return location.mediaDirectoryURL
            }
            let locator = PulseStoreLocator()
            let mediaDirectoryURL = try locator.applicationMediaDirectoryURL()
            let referencedMedia: [ImprintMediaSnapshot]
            if let habit = try repository.existingPrimaryHabit() {
                referencedMedia = try repository.allMedia(habitID: habit.id)
            } else {
                referencedMedia = []
            }
            do {
                try PulseMediaFileStore.migrateLegacyMediaIfNeeded(
                    from: location.mediaDirectoryURL,
                    to: mediaDirectoryURL,
                    referencedMedia: referencedMedia
                )
            } catch {
                let code: String
                if let mediaError = error as? PulseMediaStorageError {
                    code = switch mediaError {
                    case .fileUnavailable: "media.migration.file_unavailable"
                    case .identityMismatch: "media.migration.identity_mismatch"
                    case .storageUnavailable: "media.migration.storage_unavailable"
                    case .invalidInput: "media.migration.invalid_input"
                    case .precommitVerificationFailed: "media.migration.verification_failed"
                    }
                } else {
                    code = "media.migration.unknown"
                }
                logger.error(
                    "Media migration failed; code=\(code, privacy: .public)."
                )
                throw error
            }
            return mediaDirectoryURL
        }
    }
}

#if DEBUG
@MainActor
private final class PulseUITestReminderScheduler: ReminderScheduling {
    let deliveryCapabilities = PulseReminderDeliveryCapabilities(
        supportsScheduledLiveActivities: true,
        liveActivitiesEnabled: true
    )

    func permissionState() async -> NotificationPermissionState {
        .authorized
    }

    func requestPermission() async throws -> Bool {
        true
    }

    func reconcile(
        _ snapshot: ReminderScheduleSnapshot
    ) async throws -> PulseReminderDeliveryMode {
        snapshot.enabled ? snapshot.deliveryMode : .disabled
    }

    func completeCheckIn(for logicalDay: LogicalDay) async {}

    func removeAllPulseNotifications() async {}
}
#endif

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
            .environment(\.pulseVisualTheme, model.resolvedVisualTheme)
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
