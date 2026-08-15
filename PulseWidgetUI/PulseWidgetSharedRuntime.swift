import Foundation
import PulseCore
import OSLog

@MainActor
enum PulseWidgetSharedRuntime {
    struct Context {
        let location: PulseStoreLocation
        let sharedSettings: PulseSharedSettings
    }

    enum RuntimeError: Error {
        case missingAppGroupIdentifier
        case sharedStoreMissing
        case missingPrimaryHabit
    }

    private static let logger = Logger(
        subsystem: PulseRuntimeIdentity.bundleIdentifier,
        category: "shared-check-in"
    )

    static func makeContext(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) throws -> Context {
        guard let identifier = bundle.object(
            forInfoDictionaryKey: "PulseAppGroupIdentifier"
        ) as? String,
        identifier.hasPrefix("group."),
        !identifier.contains("$(") else {
            throw RuntimeError.missingAppGroupIdentifier
        }

        return Context(
            location: try PulseStoreLocator(fileManager: fileManager)
                .appGroupLocation(identifier: identifier),
            sharedSettings: try PulseSharedSettings(
                appGroupIdentifier: identifier
            )
        )
    }

    static func requireExistingStore(
        at location: PulseStoreLocation,
        fileManager: FileManager = .default
    ) throws {
        guard fileManager.fileExists(atPath: location.storeURL.path) else {
            throw RuntimeError.sharedStoreMissing
        }
    }

    static func makeRepository(
        at location: PulseStoreLocation,
        clock: any PulseClock
    ) throws -> SwiftDataPulseRepository {
        SwiftDataPulseRepository(
            container: try PersistenceController.makeContainer(
                storeName: PulseStoreContract.storeName,
                storeURL: location.storeURL
            ),
            clock: clock,
            primaryHabitProvisioning: .existingStoreOnly
        )
    }

    @discardableResult
    static func checkIn(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        clock: any PulseClock = SystemPulseClock()
    ) throws -> CheckInCommitReceipt {
        let context = try makeContext(bundle: bundle, fileManager: fileManager)
        return try checkIn(
            at: context.location,
            fileManager: fileManager,
            clock: clock
        )
    }

    @discardableResult
    static func checkIn(
        at location: PulseStoreLocation,
        fileManager: FileManager = .default,
        clock: any PulseClock
    ) throws -> CheckInCommitReceipt {
        try requireExistingStore(at: location, fileManager: fileManager)
        let repository = try makeRepository(at: location, clock: clock)
        guard let habit = try repository.existingPrimaryHabit(),
              habit.isIdentityConfirmed else {
            throw RuntimeError.missingPrimaryHabit
        }
        return try repository.checkIn(habitID: habit.id)
    }

    @discardableResult
    static func checkInAndReconcileReminders(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        clock: any PulseClock = SystemPulseClock(),
        reminderScheduler: any ReminderScheduling = ReminderScheduler()
    ) async throws -> CheckInCommitReceipt {
        let context = try makeContext(bundle: bundle, fileManager: fileManager)
        try requireExistingStore(at: context.location, fileManager: fileManager)
        let repository = try makeRepository(at: context.location, clock: clock)
        guard let habit = try repository.existingPrimaryHabit(),
              habit.isIdentityConfirmed else {
            throw RuntimeError.missingPrimaryHabit
        }

        let receipt = try repository.checkIn(habitID: habit.id)
        let today = LogicalDay.resolve(
            at: clock.now,
            timeZone: habit.timeZone
        )
        await reminderScheduler.completeLiveActivity(for: today)

        do {
            let settings = try context.sharedSettings.load()
            let hasEnhancement = await PulseStoreKitEntitlementReader.hasCurrentEntitlement(
                for: PulseEnhancementContract.productIdentifier
            )
            let records = try repository.allRecords(habitID: habit.id)
            let snapshot = ReminderScheduleSnapshot(
                enabled: settings.reminderEnabled,
                deliveryMode: PulseReminderDeliveryPolicy.deliveryMode(
                    reminderEnabled: settings.reminderEnabled,
                    hasEnhancementEntitlement: hasEnhancement,
                    capabilities: reminderScheduler.deliveryCapabilities
                ),
                time: settings.reminderTime,
                activityStyle: settings.reminderActivityStyle,
                timeZoneIdentifier: habit.timeZoneIdentifier,
                localeIdentifier: settings.language.locale.identifier,
                checkedDays: Set(records.map(\.logicalDay)),
                now: clock.now
            )
            _ = try await reminderScheduler.reconcile(snapshot)
        } catch {
            logger.error(
                "Check-in committed, but reminder reconciliation failed: \(String(describing: error), privacy: .private)"
            )
        }
        return receipt
    }
}
