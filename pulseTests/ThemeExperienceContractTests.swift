import Foundation
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
    }

    func testBrandTokenContractContainsOnlyCurrentThemePalettes() throws {
        let data = try Data(
            contentsOf: repositoryRoot.appending(path: "design/brand-tokens.json")
        )
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: [String: String]]
        )
        let requiredRoles = [
            "editorialAccent",
            "quietCanvas", "quietSurface", "quietInk", "quietMuted", "quietDivider",
            "quietGreen", "quietGreenDeep", "quietGreenSoft", "quietChrome",
            "quietChromeForeground", "quietOnGreen", "quietPink", "quietBlue", "quietYellow",
            "sunlitCanvas", "sunlitCanvasDeep", "sunlitSurface", "sunlitInk",
            "sunlitMuted", "sunlitDivider", "sunlitAccent", "sunlitAccentSoft",
            "sunlitMap", "sunlitMapDeep", "sunlitChrome", "sunlitChromeForeground",
            "sunlitOnAccent",
        ]
        let retiredRoles = [
            "archiveCanvas", "archiveCopper", "archiveDepth", "archiveForeground",
            "archiveMist", "archiveNight", "archivePaper", "archiveSky", "archiveSkyDeep",
            "navigationGlyphSurface",
        ]

        for appearance in ["light", "dark"] {
            let palette = try XCTUnwrap(root[appearance])
            for role in requiredRoles {
                XCTAssertNotNil(palette[role], "Missing \(appearance) semantic role: \(role)")
            }
            for role in retiredRoles {
                XCTAssertNil(palette[role], "Retired \(appearance) role remains: \(role)")
            }
        }
    }

    func testRemovedThemeSpecificContractsDoNotRemain() throws {
        let productionRoots = [
            repositoryRoot.appending(path: "pulse", directoryHint: .isDirectory),
            repositoryRoot.appending(path: "pulseUITests", directoryHint: .isDirectory),
        ]
        let removedContracts = [
            "editorial.journal.input",
            "navigation.section.history",
            "history.calendar.surface",
            "EditorialHistoryContent",
            "tideArchive",
            "PulseArchive",
        ]

        for root in productionRoots {
            let enumerator = try XCTUnwrap(
                FileManager.default.enumerator(
                    at: root,
                    includingPropertiesForKeys: nil
                )
            )
            for case let fileURL as URL in enumerator
                where ["swift", "xcstrings"].contains(fileURL.pathExtension) {
                let source = try String(contentsOf: fileURL, encoding: .utf8)
                for removedContract in removedContracts {
                    XCTAssertFalse(
                        source.contains(removedContract),
                        "Removed contract \(removedContract) remains in \(fileURL.path)"
                    )
                }
            }
        }
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
