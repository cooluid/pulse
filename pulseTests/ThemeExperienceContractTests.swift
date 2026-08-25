import XCTest

@testable import pulse

@MainActor
final class ThemeExperienceContractTests: XCTestCase {
    func testJournalPageIsTheOnlyFreeInterfaceTheme() {
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
}
