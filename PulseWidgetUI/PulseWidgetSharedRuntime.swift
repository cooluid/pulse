import Foundation
import PulseCore

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

    static func makeContext(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) throws -> Context {
        guard
            let identifier = bundle.object(
                forInfoDictionaryKey: "PulseAppGroupIdentifier"
            ) as? String,
            identifier.hasPrefix("group."),
            !identifier.contains("$(")
        else {
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
    static func commitToday(
        at location: PulseStoreLocation,
        fileManager: FileManager = .default,
        clock: any PulseClock
    ) throws -> CheckInCommitReceipt {
        try requireExistingStore(at: location, fileManager: fileManager)
        let repository = try makeRepository(at: location, clock: clock)
        guard let habit = try repository.existingPrimaryHabit(),
            habit.isIdentityConfirmed
        else {
            throw RuntimeError.missingPrimaryHabit
        }
        return try repository.checkIn(habitID: habit.id, journalNote: nil)
    }

    @discardableResult
    static func checkInAndCompleteTodayDelivery(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        clock: any PulseClock = SystemPulseClock(),
        reminderScheduler: any ReminderScheduling = ReminderScheduler()
    ) async throws -> CheckInCommitReceipt {
        let context = try makeContext(bundle: bundle, fileManager: fileManager)
        return try await checkInAndCompleteTodayDelivery(
            at: context.location,
            fileManager: fileManager,
            clock: clock,
            reminderScheduler: reminderScheduler
        )
    }

    @discardableResult
    static func checkInAndCompleteTodayDelivery(
        at location: PulseStoreLocation,
        fileManager: FileManager = .default,
        clock: any PulseClock,
        reminderScheduler: any ReminderScheduling
    ) async throws -> CheckInCommitReceipt {
        let receipt = try commitToday(
            at: location,
            fileManager: fileManager,
            clock: clock
        )
        await reminderScheduler.completeCheckIn(for: receipt.logicalDay)
        return receipt
    }
}
