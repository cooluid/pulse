import SwiftData
import SwiftUI
import XCTest

@testable import PulseCore
@testable import pulse

@MainActor
final class PulseWidgetProjectionTests: XCTestCase {

    func testReminderActivityTimeUsesTheAttributeTimeZone() {
        let reminderDate = Date(timeIntervalSince1970: 67_320)

        XCTAssertEqual(
            PulseReminderActivityTimeFormatter.string(
                reminderDate: reminderDate,
                timeZoneIdentifier: TimeZone.gmt.identifier,
                locale: Locale(identifier: "zh-Hans")
            ),
            "18:42"
        )
        XCTAssertNil(
            PulseReminderActivityTimeFormatter.string(
                reminderDate: reminderDate,
                timeZoneIdentifier: "Not/A-Time-Zone",
                locale: Locale(identifier: "zh-Hans")
            )
        )
    }

    func testWidgetStringCatalogHasEnglishAndSimplifiedChineseForEveryKey() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL =
            projectRoot
            .appendingPathComponent("PulseWidgets", isDirectory: true)
            .appendingPathComponent("Localizable.xcstrings", isDirectory: false)
        let catalog = try JSONDecoder().decode(
            WidgetStringCatalog.self,
            from: Data(contentsOf: catalogURL)
        )

        XCTAssertEqual(catalog.sourceLanguage, "en")
        XCTAssertFalse(catalog.strings.isEmpty)
        for (key, entry) in catalog.strings {
            for language in ["en", "zh-Hans"] {
                let value = entry.localizations[language]?.stringUnit.value
                XCTAssertFalse(
                    value?.isEmpty ?? true,
                    "Missing \(language) translation for \(key)."
                )
            }
        }

        let appCatalog = try JSONDecoder().decode(
            WidgetStringCatalog.self,
            from: Data(
                contentsOf:
                    projectRoot
                    .appendingPathComponent("pulse", isDirectory: true)
                    .appendingPathComponent("Localizable.xcstrings", isDirectory: false)
            )
        )
        for key in ["widget.state.checked", "widget.state.pending"] {
            let widgetEntry = try XCTUnwrap(catalog.strings[key])
            let appEntry = try XCTUnwrap(appCatalog.strings[key])
            for language in ["en", "zh-Hans"] {
                XCTAssertEqual(
                    widgetEntry.localizations[language]?.stringUnit.value,
                    appEntry.localizations[language]?.stringUnit.value,
                    "Shared renderer copy drifted for \(key) [\(language)]."
                )
            }
        }
    }

    func testPulseSystemUIStringCatalogHasBothSupportedLanguages() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL =
            projectRoot
            .appendingPathComponent("PulseWidgetUI", isDirectory: true)
            .appendingPathComponent("PulseSystemUI.xcstrings", isDirectory: false)
        let catalog = try JSONDecoder().decode(
            WidgetStringCatalog.self,
            from: Data(contentsOf: catalogURL)
        )

        XCTAssertEqual(catalog.sourceLanguage, "en")
        XCTAssertFalse(catalog.strings.isEmpty)
        for (key, entry) in catalog.strings {
            for language in ["en", "zh-Hans"] {
                XCTAssertFalse(
                    entry.localizations[language]?.stringUnit.value.isEmpty ?? true,
                    "Missing \(language) translation for \(key)."
                )
            }
        }
    }

    func testUserFacingCopyDoesNotExposePrivateImplementationLanguage() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURLs = [
            projectRoot
                .appendingPathComponent("pulse", isDirectory: true)
                .appendingPathComponent("Localizable.xcstrings", isDirectory: false),
            projectRoot
                .appendingPathComponent("pulse", isDirectory: true)
                .appendingPathComponent("PulseDebug.xcstrings", isDirectory: false),
            projectRoot
                .appendingPathComponent("PulseWidgets", isDirectory: true)
                .appendingPathComponent("Localizable.xcstrings", isDirectory: false),
            projectRoot
                .appendingPathComponent("PulseWidgetUI", isDirectory: true)
                .appendingPathComponent("PulseSystemUI.xcstrings", isDirectory: false),
        ]
        let forbiddenTerms = [
            "主承诺", "高阶权益", "小组件构图", "小组件事实", "共享存储", "数据校验",
            "虚构价格", "widget facts", "shared store", "advanced benefits", "main commitment",
            "widget composition",
            "不会在后台", "没有附带", "请勿填写或附带", "人脸身份", "健康推断", "never sent in the background",
        ]

        for catalogURL in catalogURLs {
            let catalog = try JSONDecoder().decode(
                WidgetStringCatalog.self,
                from: Data(contentsOf: catalogURL)
            )
            for (key, entry) in catalog.strings {
                XCTAssertNotEqual(
                    entry.extractionState,
                    "stale",
                    "String Catalog contains a stale runtime entry: \(key)."
                )
                for localization in entry.localizations.values {
                    let value = localization.stringUnit.value.lowercased()
                    for term in forbiddenTerms {
                        XCTAssertFalse(
                            value.contains(term.lowercased()),
                            "User-facing copy for \(key) exposes internal language: \(term)."
                        )
                    }
                }
            }
        }

        let metadataURLs = [
            projectRoot
                .appendingPathComponent("Config", isDirectory: true)
                .appendingPathComponent("PulseEnhancements.storekit", isDirectory: false),
            projectRoot
                .appendingPathComponent("Config", isDirectory: true)
                .appendingPathComponent("Pulse-Info.plist", isDirectory: false),
            projectRoot
                .appendingPathComponent("pulse", isDirectory: true)
                .appendingPathComponent("InfoPlist.xcstrings", isDirectory: false),
        ]
        for metadataURL in metadataURLs {
            let value = try String(contentsOf: metadataURL, encoding: .utf8).lowercased()
            for term in forbiddenTerms {
                XCTAssertFalse(
                    value.contains(term.lowercased()),
                    "User-facing metadata exposes internal language: \(term)."
                )
            }
        }
    }

    func testSharedSettingsPersistTypedSystemSurfaceChoicesAndReset() throws {
        let suiteName = "PulseSharedSettings.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PulseSharedSettings(defaults: defaults)

        XCTAssertEqual(try preferences.load().language, .system)

        for language in PulseInterfaceLanguage.allCases {
            preferences.saveLanguage(language)
            XCTAssertEqual(try preferences.load().language, language)
        }

        preferences.saveReminderEnabled(true)
        preferences.saveReminderTime(try XCTUnwrap(PulseReminderTime(hour: 8, minute: 15)))
        let configured = try preferences.load()
        XCTAssertTrue(configured.reminderEnabled)
        XCTAssertEqual(configured.reminderTime.minutesFromMidnight, 495)

        preferences.reset()
        XCTAssertEqual(
            try preferences.load(),
            PulseSharedSettings.Snapshot(
                language: .system,
                reminderEnabled: false,
                reminderTime: .standard
            )
        )
    }

    func testSharedInterfacePreferencesRejectUnknownStoredValues() throws {
        let suiteName = "PulseSharedSettings.Invalid.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PulseSharedSettings(defaults: defaults)

        defaults.set(
            "unknown-language",
            forKey: PulseSharedSettings.StorageKey.language
        )
        XCTAssertThrowsError(try preferences.load()) { error in
            XCTAssertEqual(
                error as? PulseSharedSettingsError,
                .invalidStoredLanguage("unknown-language")
            )
        }

    }

    func testProjectionBuildsSevenValidatedDays() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let clock = MutableWidgetClock(now: makeDate(2026, 8, 9, 8, timeZone: timeZone))
        let repository = try makeRepository(clock: clock)
        let initialHabit = try repository.primaryHabit(systemTimeZone: timeZone)
        let habit = try repository.updateIdentity(
            habitID: initialHabit.id,
            identity: HabitIdentity(userName: "每天走路", userPurpose: "保持活力")
        )
        _ = try repository.checkIn(habitID: habit.id, journalNote: nil)
        clock.now = makeDate(2026, 8, 11, 12, timeZone: timeZone)

        let plan = try XCTUnwrap(
            PulseWidgetSnapshotReader.readTimelinePlan(
                repository: repository,
                at: clock.now
            )
        )

        XCTAssertEqual(plan.snapshot.recentDays.count, 7)
        XCTAssertEqual(plan.snapshot.habitName, "每天走路")
        XCTAssertEqual(plan.snapshot.recentDays.first?.day.storageValue, "2026-08-05")
        XCTAssertEqual(plan.snapshot.recentDays.last?.day.storageValue, "2026-08-11")
        XCTAssertEqual(
            plan.snapshot.recentDays.map(\.state),
            [
                .beforeHabit, .beforeHabit, .beforeHabit, .beforeHabit, .checked, .missed,
                .todayPending,
            ]
        )
        XCTAssertFalse(plan.snapshot.isCheckedToday)
        XCTAssertEqual(plan.snapshot.recentCheckedCount, 1)
        XCTAssertEqual(plan.snapshot.previousSixCheckedCount, 1)
        XCTAssertEqual(
            plan.reloadAfter,
            makeDate(2026, 8, 12, 0, timeZone: timeZone)
        )
        XCTAssertEqual(plan.entries.count, 3)
        XCTAssertEqual(plan.entries.first?.snapshot.today.storageValue, "2026-08-11")
        XCTAssertEqual(
            plan.entries.dropFirst().first?.date,
            makeDate(2026, 8, 11, 18, timeZone: timeZone)
        )
        XCTAssertEqual(plan.entries.last?.date, plan.reloadAfter)
    }

    func testGalleryCheckInProjectionDoesNotMutateAuthoritativeSnapshot() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let now = makeDate(2026, 8, 11, 8, timeZone: timeZone)
        let repository = try makeRepository(clock: MutableWidgetClock(now: now))
        let initialHabit = try repository.primaryHabit(systemTimeZone: timeZone)
        _ = try repository.updateIdentity(
            habitID: initialHabit.id,
            identity: HabitIdentity(userName: "每天走路", userPurpose: "保持活力")
        )
        let snapshot = try XCTUnwrap(
            PulseWidgetSnapshotReader.readTimelinePlan(
                repository: repository,
                at: now
            )?.snapshot
        )

        let completedPreview = snapshot.projectingTodayCheckInForGallery(true)
        let pendingPreview = completedPreview.projectingTodayCheckInForGallery(false)
        let morningPreview = snapshot.projectingGallery(period: .morning, isChecked: false)
        let daylightPreview = snapshot.projectingGallery(period: .daylight, isChecked: false)
        let eveningPreview = snapshot.projectingGallery(period: .evening, isChecked: true)

        XCTAssertFalse(snapshot.isCheckedToday)
        XCTAssertEqual(snapshot.recentDays.last?.state, .todayPending)
        XCTAssertTrue(completedPreview.isCheckedToday)
        XCTAssertEqual(completedPreview.recentDays.last?.state, .checked)
        XCTAssertFalse(pendingPreview.isCheckedToday)
        XCTAssertEqual(pendingPreview.recentDays.last?.state, .todayPending)
        XCTAssertEqual(completedPreview.previousSixCheckedCount, snapshot.previousSixCheckedCount)
        XCTAssertEqual(
            PulseWidgetAmbientPeriod.resolve(
                at: morningPreview.generatedAt,
                timeZone: timeZone
            ),
            .morning
        )
        XCTAssertEqual(
            PulseWidgetAmbientPeriod.resolve(
                at: daylightPreview.generatedAt,
                timeZone: timeZone
            ),
            .daylight
        )
        XCTAssertEqual(
            PulseWidgetAmbientPeriod.resolve(
                at: eveningPreview.generatedAt,
                timeZone: timeZone
            ),
            .evening
        )
        XCTAssertEqual(morningPreview.recentDays, snapshot.recentDays)
        XCTAssertEqual(daylightPreview.recentDays, snapshot.recentDays)
        XCTAssertEqual(eveningPreview.previousSixCheckedCount, snapshot.previousSixCheckedCount)
        XCTAssertTrue(eveningPreview.isCheckedToday)
        XCTAssertFalse(snapshot.isCheckedToday)
    }

    func testProjectionIncludesTodayReceipt() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let now = makeDate(2026, 8, 11, 7, timeZone: timeZone)
        let clock = MutableWidgetClock(now: now)
        let repository = try makeRepository(clock: clock)
        let initialHabit = try repository.primaryHabit(systemTimeZone: timeZone)
        let habit = try repository.updateIdentity(
            habitID: initialHabit.id,
            identity: HabitIdentity(userName: "每天写一页", userPurpose: nil)
        )
        let receipt = try repository.checkIn(habitID: habit.id, journalNote: nil)

        let plan = try XCTUnwrap(
            PulseWidgetSnapshotReader.readTimelinePlan(
                repository: repository,
                at: now
            )
        )

        XCTAssertEqual(plan.snapshot.checkedAt, receipt.checkedAt)
        XCTAssertEqual(plan.snapshot.habitName, "每天写一页")
        XCTAssertTrue(plan.snapshot.isCheckedToday)
        XCTAssertEqual(plan.snapshot.recentDays.last?.state, .checked)
        XCTAssertEqual(plan.snapshot.previousSixCheckedCount, 0)
    }

    func testUnconfirmedIdentityCannotProduceAWidgetSnapshot() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let now = makeDate(2026, 8, 11, 7, timeZone: timeZone)
        let repository = try makeRepository(clock: MutableWidgetClock(now: now))
        _ = try repository.primaryHabit(systemTimeZone: timeZone)

        XCTAssertThrowsError(
            try PulseWidgetSnapshotReader.readTimelinePlan(
                repository: repository,
                at: now
            )
        ) { error in
            XCTAssertEqual(
                error as? PulseWidgetProjectionError,
                .identityNotConfirmed
            )
        }
    }

    func testTimelineBoundaryUsesProjectCalendarAcrossDST() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let now = makeDate(2026, 3, 8, 23, timeZone: timeZone)
        let repository = try makeRepository(clock: MutableWidgetClock(now: now))
        let initialHabit = try repository.primaryHabit(systemTimeZone: timeZone)
        _ = try repository.updateIdentity(
            habitID: initialHabit.id,
            identity: HabitIdentity(userName: "Keep moving", userPurpose: nil)
        )

        let plan = try XCTUnwrap(
            PulseWidgetSnapshotReader.readTimelinePlan(
                repository: repository,
                at: now
            )
        )

        XCTAssertEqual(
            plan.reloadAfter,
            makeDate(2026, 3, 9, 0, timeZone: timeZone)
        )
        XCTAssertEqual(plan.entries.last?.snapshot.today.storageValue, "2026-03-09")
        XCTAssertEqual(plan.snapshot.today.storageValue, "2026-03-08")
    }

    func testReaderDoesNotCreateAProjectForAnEmptyStore() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let now = makeDate(2026, 8, 11, 7, timeZone: timeZone)
        let repository = try makeRepository(clock: MutableWidgetClock(now: now))

        XCTAssertNil(
            try PulseWidgetSnapshotReader.readTimelinePlan(
                repository: repository,
                at: now
            )
        )
        XCTAssertNil(try repository.existingPrimaryHabit())
    }

    func testSharedWidgetRuntimeWritesOneAuthoritativeCheckInAndIsIdempotent() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let now = makeDate(2026, 8, 14, 8, timeZone: timeZone)
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseWidgetRuntimeTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let location = try PulseStoreLocation(directoryURL: directoryURL)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let repository = SwiftDataPulseRepository(
            container: try PersistenceController.makeContainer(
                storeName: PulseStoreContract.storeName,
                storeURL: location.storeURL
            ),
            clock: FixedPulseClock(now: now),
            primaryHabitProvisioning: .createIfMissing(
                try HabitIdentity(userName: "默认承诺", userPurpose: nil)
            )
        )
        let initialHabit = try repository.primaryHabit(systemTimeZone: timeZone)
        let habit = try repository.updateIdentity(
            habitID: initialHabit.id,
            identity: HabitIdentity(userName: "每天留印", userPurpose: nil)
        )

        let first = try PulseWidgetSharedRuntime.commitToday(
            at: location,
            clock: FixedPulseClock(now: now)
        )
        let second = try PulseWidgetSharedRuntime.commitToday(
            at: location,
            clock: FixedPulseClock(now: now.addingTimeInterval(60))
        )
        let records = try repository.allRecords(habitID: habit.id)

        XCTAssertEqual(first.disposition, .created)
        XCTAssertEqual(second.disposition, .alreadyPresent)
        XCTAssertEqual(first.recordID, second.recordID)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.logicalDay, first.logicalDay)
    }

    func testSharedWidgetRuntimeCompletesOnlyTheCommittedLogicalDay() async throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let now = makeDate(2026, 8, 14, 8, timeZone: timeZone)
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseWidgetRuntimeTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let location = try PulseStoreLocation(directoryURL: directoryURL)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let repository = SwiftDataPulseRepository(
            container: try PersistenceController.makeContainer(
                storeName: PulseStoreContract.storeName,
                storeURL: location.storeURL
            ),
            clock: FixedPulseClock(now: now),
            primaryHabitProvisioning: .createIfMissing(
                try HabitIdentity(userName: "默认承诺", userPurpose: nil)
            )
        )
        let initialHabit = try repository.primaryHabit(systemTimeZone: timeZone)
        _ = try repository.updateIdentity(
            habitID: initialHabit.id,
            identity: HabitIdentity(userName: "每天留印", userPurpose: nil)
        )
        let scheduler = RecordingWidgetReminderScheduler()

        let receipt = try await PulseWidgetSharedRuntime.checkInAndCompleteTodayDelivery(
            at: location,
            clock: FixedPulseClock(now: now),
            reminderScheduler: scheduler
        )

        XCTAssertEqual(scheduler.completedDays, [receipt.logicalDay])
    }

    func testSharedWidgetRuntimeRejectsAnUnconfirmedIdentity() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let now = makeDate(2026, 8, 14, 8, timeZone: timeZone)
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseWidgetRuntimeTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let location = try PulseStoreLocation(directoryURL: directoryURL)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let repository = SwiftDataPulseRepository(
            container: try PersistenceController.makeContainer(
                storeName: PulseStoreContract.storeName,
                storeURL: location.storeURL
            ),
            clock: FixedPulseClock(now: now),
            primaryHabitProvisioning: .createIfMissing(
                try HabitIdentity(userName: "默认承诺", userPurpose: nil)
            )
        )
        _ = try repository.primaryHabit(systemTimeZone: timeZone)

        XCTAssertThrowsError(
            try PulseWidgetSharedRuntime.commitToday(
                at: location,
                clock: FixedPulseClock(now: now)
            )
        ) { error in
            guard case PulseWidgetSharedRuntime.RuntimeError.missingPrimaryHabit = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertTrue(
            try repository.allRecords(
                habitID: try XCTUnwrap(repository.existingPrimaryHabit()).id
            ).isEmpty)
    }

    private func makeRepository(
        clock: MutableWidgetClock
    ) throws -> SwiftDataPulseRepository {
        SwiftDataPulseRepository(
            container: try PersistenceController.makeInMemoryContainer(),
            clock: clock,
            primaryHabitProvisioning: .createIfMissing(
                try HabitIdentity(userName: "默认承诺", userPurpose: nil)
            )
        )
    }

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        timeZone: TimeZone
    ) -> Date {
        Calendar.pulseGregorian(timeZone: timeZone).date(
            from: DateComponents(year: year, month: month, day: day, hour: hour)
        )!
    }
}

private struct WidgetStringCatalog: Decodable {
    struct Entry: Decodable {
        struct Localization: Decodable {
            struct StringUnit: Decodable {
                let value: String
            }

            let stringUnit: StringUnit
        }

        let extractionState: String?
        let localizations: [String: Localization]
    }

    let sourceLanguage: String
    let strings: [String: Entry]
}

@MainActor
private final class RecordingWidgetReminderScheduler: ReminderScheduling {
    let deliveryCapabilities = PulseReminderDeliveryCapabilities(
        supportsScheduledLiveActivities: false,
        liveActivitiesEnabled: false
    )
    private(set) var completedDays: [LogicalDay] = []

    func permissionState() async -> NotificationPermissionState { .denied }
    func requestPermission() async throws -> Bool { false }
    func reconcile(
        _ snapshot: ReminderScheduleSnapshot
    ) async throws -> PulseReminderDeliveryMode { .disabled }
    func completeCheckIn(for logicalDay: LogicalDay) async {
        completedDays.append(logicalDay)
    }
    func removeAllPulseNotifications() async {}
}

@MainActor
private final class MutableWidgetClock: PulseClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
