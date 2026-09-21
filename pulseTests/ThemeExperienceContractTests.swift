import XCTest

@testable import pulse

@MainActor
final class ThemeExperienceContractTests: XCTestCase {
    func testJournalPageIsTheOnlyFreeInterfaceTheme() {
        XCTAssertEqual(PulseVisualThemeAccessPolicy.freeTheme, .editorialJournal)
        XCTAssertEqual(
            PulseVisualThemeAccessPolicy.enhancementThemes,
            [.quietField, .sunlitDay, .moonTide, .prismLedger, .immersion]
        )
        XCTAssertFalse(
            PulseVisualThemeAccessPolicy.requiresEnhancement(.editorialJournal)
        )
        XCTAssertTrue(PulseVisualThemeAccessPolicy.requiresEnhancement(.quietField))
        XCTAssertTrue(PulseVisualThemeAccessPolicy.requiresEnhancement(.sunlitDay))
        XCTAssertTrue(PulseVisualThemeAccessPolicy.requiresEnhancement(.moonTide))
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
        XCTAssertNotEqual(PulseVisualThemeEnvironmentKey.defaultValue, .moonTide)
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
            PulseDesign.appAccent(for: .moonTide)
        )
    }
}
