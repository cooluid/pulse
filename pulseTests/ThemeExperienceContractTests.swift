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

    func testCalendarDayStyleKeepsMarksAndDoesNotCopyQuietColorsIntoEditorial() {
        let quietChecked = PulseDesign.CalendarDayStyle.resolve(
            theme: .quietField,
            status: .checked
        )
        let quietMissed = PulseDesign.CalendarDayStyle.resolve(
            theme: .quietField,
            status: .missed
        )
        let editorialChecked = PulseDesign.CalendarDayStyle.resolve(
            theme: .editorialJournal,
            status: .checked
        )
        let editorialFuture = PulseDesign.CalendarDayStyle.resolve(
            theme: .editorialJournal,
            status: .future
        )
        let sunlitChecked = PulseDesign.CalendarDayStyle.resolve(
            theme: .sunlitDay,
            status: .checked
        )

        XCTAssertEqual(quietChecked.mark, .checked)
        XCTAssertEqual(quietMissed.mark, .missed)
        XCTAssertEqual(
            PulseDesign.CalendarDayStyle.resolve(theme: .quietField, status: .beforeHabit).mark,
            .beforeHabit
        )
        XCTAssertEqual(
            PulseDesign.CalendarDayStyle.resolve(theme: .sunlitDay, status: .todayPending).mark,
            .none
        )
        XCTAssertTrue(quietChecked.usesCompanionShape)
        XCTAssertFalse(editorialChecked.usesCompanionShape)
        XCTAssertFalse(sunlitChecked.usesCompanionShape)
        XCTAssertTrue(editorialChecked.showsCheckedRule)
        XCTAssertFalse(quietChecked.showsCheckedRule)
        XCTAssertFalse(sunlitChecked.showsCheckedRule)
        XCTAssertNotEqual(quietChecked.mark, quietMissed.mark)
        XCTAssertEqual(editorialFuture.mark, .none)
        XCTAssertEqual(
            PulseDesign.CalendarDayStyle.resolve(
                theme: .editorialJournal,
                status: .beforeHabit
            ).mark,
            .beforeHabit
        )
    }

}
