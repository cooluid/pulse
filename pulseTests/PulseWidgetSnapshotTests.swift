import SwiftData
import XCTest
@testable import PulseCore

@MainActor
final class PulseWidgetSnapshotTests: XCTestCase {
    func testWidgetStringCatalogHasEnglishAndSimplifiedChineseForEveryKey() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectRoot
            .appendingPathComponent("PulseWidgets", isDirectory: true)
            .appendingPathComponent("Localizable.xcstrings", isDirectory: false)
        let widgetSourceURL = projectRoot
            .appendingPathComponent("PulseWidgets", isDirectory: true)
            .appendingPathComponent("PulseWidgets.swift", isDirectory: false)
        let catalog = try JSONDecoder().decode(
            WidgetStringCatalog.self,
            from: Data(contentsOf: catalogURL)
        )
        let widgetSource = try String(contentsOf: widgetSourceURL, encoding: .utf8)

        XCTAssertEqual(catalog.sourceLanguage, "en")
        XCTAssertFalse(catalog.strings.isEmpty)
        for (key, entry) in catalog.strings {
            XCTAssertTrue(
                widgetSource.contains("\"\(key)\""),
                "Widget localization key has no production consumer: \(key)."
            )
            for language in ["en", "zh-Hans"] {
                let value = entry.localizations[language]?.stringUnit.value
                XCTAssertFalse(
                    value?.isEmpty ?? true,
                    "Missing \(language) translation for \(key)."
                )
            }
        }
    }

    func testSharedInterfacePreferencesPersistLanguageAndStyleAndReset() throws {
        let suiteName = "PulseSharedInterfacePreferences.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PulseSharedInterfacePreferences(defaults: defaults)

        XCTAssertEqual(try preferences.loadLanguage(), .system)
        XCTAssertEqual(try preferences.loadWidgetStyle(), .breathingOrbit)

        for language in PulseInterfaceLanguage.allCases {
            preferences.saveLanguage(language)
            XCTAssertEqual(try preferences.loadLanguage(), language)
        }

        for style in PulseWidgetStyle.allCases {
            preferences.saveWidgetStyle(style)
            XCTAssertEqual(try preferences.loadWidgetStyle(), style)
        }

        preferences.reset()
        XCTAssertEqual(try preferences.loadLanguage(), .system)
        XCTAssertEqual(try preferences.loadWidgetStyle(), .breathingOrbit)
    }

    func testSharedInterfacePreferencesRejectUnknownStoredValues() throws {
        let suiteName = "PulseSharedInterfacePreferences.Invalid.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PulseSharedInterfacePreferences(defaults: defaults)

        defaults.set(
            "unknown-language",
            forKey: PulseSharedInterfacePreferences.languageStorageKey
        )
        XCTAssertThrowsError(try preferences.loadLanguage()) { error in
            XCTAssertEqual(
                error as? PulseSharedInterfacePreferenceError,
                .invalidStoredLanguage("unknown-language")
            )
        }

        defaults.set(
            "unknown-style",
            forKey: PulseSharedInterfacePreferences.widgetStyleStorageKey
        )
        XCTAssertThrowsError(try preferences.loadWidgetStyle()) { error in
            XCTAssertEqual(
                error as? PulseSharedInterfacePreferenceError,
                .invalidStoredWidgetStyle("unknown-style")
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
        _ = try repository.checkIn(habitID: habit.id)
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
            [.beforeHabit, .beforeHabit, .beforeHabit, .beforeHabit, .checked, .missed, .todayPending]
        )
        XCTAssertFalse(plan.snapshot.isCheckedToday)
        XCTAssertEqual(plan.snapshot.recentCheckedCount, 1)
        XCTAssertEqual(plan.snapshot.previousSixCheckedCount, 1)
        XCTAssertEqual(
            plan.refreshAfter,
            makeDate(2026, 8, 12, 0, timeZone: timeZone)
        )
    }

    func testProjectionIncludesTodayReceipt() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let now = makeDate(2026, 8, 11, 7, timeZone: timeZone)
        let clock = MutableWidgetClock(now: now)
        let repository = try makeRepository(clock: clock)
        let initialHabit = try repository.primaryHabit(systemTimeZone: timeZone)
        let habit = try repository.updateIdentity(
            habitID: initialHabit.id,
            identity: HabitIdentity(userName: "写一页", userPurpose: nil)
        )
        let receipt = try repository.checkIn(habitID: habit.id)

        let plan = try XCTUnwrap(
            PulseWidgetSnapshotReader.readTimelinePlan(
                repository: repository,
                at: now
            )
        )

        XCTAssertEqual(plan.snapshot.checkedAt, receipt.checkedAt)
        XCTAssertEqual(plan.snapshot.habitName, "写一页")
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
            plan.refreshAfter,
            makeDate(2026, 3, 9, 0, timeZone: timeZone)
        )
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

        let localizations: [String: Localization]
    }

    let sourceLanguage: String
    let strings: [String: Entry]
}

@MainActor
private final class MutableWidgetClock: PulseClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
