import PulseCore
import XCTest

@testable import pulse

@MainActor
final class ThemeExperienceContractTests: XCTestCase {
    func testJournalPageIsTheOnlyFreeInterfaceTheme() {
        XCTAssertEqual(PulseVisualThemeAccessPolicy.freeTheme, .editorialJournal)
        XCTAssertEqual(
            PulseVisualThemeAccessPolicy.enhancementThemes,
            [.quietField, .sunlitDay, .prismLedger, .immersion]
        )
        XCTAssertFalse(
            PulseVisualThemeAccessPolicy.requiresEnhancement(.editorialJournal)
        )
        XCTAssertTrue(PulseVisualThemeAccessPolicy.requiresEnhancement(.quietField))
        XCTAssertTrue(PulseVisualThemeAccessPolicy.requiresEnhancement(.sunlitDay))
        XCTAssertTrue(PulseVisualThemeAccessPolicy.requiresEnhancement(.prismLedger))
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
        XCTAssertNotEqual(PulseVisualThemeEnvironmentKey.defaultValue, .prismLedger)
        XCTAssertNotEqual(PulseVisualThemeEnvironmentKey.defaultValue, .immersion)
    }

    func testImmersionCarriesItsOwnSurfaceTokensAndStaysBehindTheEnhancement() {
        XCTAssertTrue(PulseVisualThemeAccessPolicy.requiresEnhancement(.immersion))
        XCTAssertEqual(PulseVisualTheme.immersion.rawValue, "immersion")

        let dark = PulseDesign.palette(for: .immersion)
        XCTAssertEqual(dark.accent, PulseDesign.immersionAccent)
        XCTAssertEqual(dark.canvas, PulseDesign.immersionCanvas)
        XCTAssertEqual(dark.surface, PulseDesign.immersionSurface)
        XCTAssertNotEqual(
            PulseDesign.appAccent(for: .immersion),
            PulseDesign.appAccent(for: .prismLedger)
        )
    }

    /// A stored theme that is no longer offered must fall back, not fail the whole load.
    func testRetiredThemeFallsBackToTheFreeThemeInsteadOfFailingTheLoad() throws {
        let suiteName = "ThemeExperienceContractTests.Retired.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("moonTide", forKey: AppSettings.StorageKey.visualTheme)

        let settings = try AppSettings(
            sharedSettings: PulseSharedSettings(defaults: defaults),
            defaults: defaults
        )

        XCTAssertNil(PulseVisualTheme(rawValue: "moonTide"))
        XCTAssertEqual(settings.visualTheme, PulseVisualThemeAccessPolicy.freeTheme)
    }
}
