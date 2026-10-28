import PulseCore
import XCTest

@testable import pulse

@MainActor
final class ThemeExperienceContractTests: XCTestCase {
    func testVermilionPageIsTheOnlyFreeInterfaceTheme() {
        XCTAssertEqual(PulseVisualThemeAccessPolicy.freeTheme, .editorialJournal)
        XCTAssertEqual(
            PulseVisualThemeAccessPolicy.enhancementThemes,
            [.quietField, .sunlitDay]
        )
        XCTAssertFalse(
            PulseVisualThemeAccessPolicy.requiresEnhancement(.editorialJournal)
        )
        XCTAssertTrue(PulseVisualThemeAccessPolicy.requiresEnhancement(.quietField))
        XCTAssertTrue(PulseVisualThemeAccessPolicy.requiresEnhancement(.sunlitDay))
        XCTAssertEqual(
            PulseVisualThemeAccessPolicy.resolvedTheme(
                requested: .sunlitDay,
                hasEnhancementEntitlement: false
            ),
            .editorialJournal
        )
        XCTAssertEqual(
            PulseVisualThemeAccessPolicy.resolvedTheme(
                requested: .sunlitDay,
                hasEnhancementEntitlement: true
            ),
            .sunlitDay
        )
        XCTAssertEqual(
            PulseVisualThemeEnvironmentKey.defaultValue,
            PulseVisualThemeAccessPolicy.freeTheme
        )
        XCTAssertNotEqual(PulseVisualThemeEnvironmentKey.defaultValue, .quietField)
        XCTAssertNotEqual(PulseVisualThemeEnvironmentKey.defaultValue, .sunlitDay)
    }

    /// Published identifiers stay readable: a setting saved by an earlier build keeps its theme.
    func testPublishedThemeIdentifiersStayStable() {
        XCTAssertEqual(PulseVisualTheme(rawValue: "editorialJournal"), .editorialJournal)
        XCTAssertEqual(PulseVisualTheme(rawValue: "quietField"), .quietField)
        XCTAssertEqual(PulseVisualTheme(rawValue: "sunlitDay"), .sunlitDay)
    }

    /// A stored theme that is no longer offered must fall back, not fail the whole load.
    func testRetiredThemeFallsBackToTheFreeThemeInsteadOfFailingTheLoad() throws {
        for retired in ["moonTide", "prismLedger", "immersion"] {
            let suiteName = "ThemeExperienceContractTests.Retired.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
            defer { defaults.removePersistentDomain(forName: suiteName) }
            defaults.set(retired, forKey: AppSettings.StorageKey.visualTheme)

            let settings = try AppSettings(
                sharedSettings: PulseSharedSettings(defaults: defaults),
                defaults: defaults
            )

            XCTAssertNil(PulseVisualTheme(rawValue: retired))
            XCTAssertEqual(settings.visualTheme, PulseVisualThemeAccessPolicy.freeTheme, retired)
        }
    }
}
