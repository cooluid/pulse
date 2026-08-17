import Foundation
import XCTest
@testable import pulse

@MainActor
final class ThemeExperienceContractTests: XCTestCase {
    func testJournalCapabilityIsOwnedBySharedSurfaces() throws {
        let todaySource = try source("pulse/Features/Today/TodayView.swift")
        let historySource = try source("pulse/Features/History/HistoryView.swift")
        let editorialSource = try source(
            "pulse/Features/Editorial/EditorialJournalTheme.swift"
        )

        XCTAssertTrue(todaySource.contains("JournalDraftComposer("))
        XCTAssertTrue(
            todaySource.contains("model.checkIn(journalNote: draftJournalNote)")
        )
        XCTAssertTrue(historySource.contains("JournalHistorySection("))

        XCTAssertFalse(editorialSource.contains("model.checkIn("))
        XCTAssertFalse(editorialSource.contains("@State private var draftJournalNote"))
        XCTAssertFalse(editorialSource.contains("EditorialHistoryContent"))
    }

    func testEveryThemeHasAnExplicitAmbientSignature() throws {
        let source = try source("pulse/Shared/PulseDesignSystem.swift")

        XCTAssertTrue(source.contains("case .quietField:\n            quietField"))
        XCTAssertTrue(source.contains("case .editorialJournal:\n            editorialField"))
        XCTAssertTrue(source.contains("case .tideArchive:\n            archiveField"))
        XCTAssertTrue(source.contains("quietFieldSprig"))
        XCTAssertTrue(source.contains("PulseEditorialFieldCanvas("))
        XCTAssertTrue(source.contains("archiveMarker"))
    }

    func testRemovedThemeSpecificContractsDoNotRemain() throws {
        let repositoryRoot = repositoryRoot
        let productionRoots = [
            repositoryRoot.appending(path: "pulse", directoryHint: .isDirectory),
            repositoryRoot.appending(path: "pulseUITests", directoryHint: .isDirectory),
        ]
        let removedContracts = [
            "editorial.journal.input",
            "navigation.section.history",
            "history.calendar.surface",
            "EditorialHistoryContent",
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

    private func source(_ relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryRoot.appending(path: relativePath),
            encoding: .utf8
        )
    }
}
