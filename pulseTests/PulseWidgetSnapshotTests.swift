import SwiftData
import SwiftUI
import XCTest
@testable import PulseCore
@testable import pulse

@MainActor
final class PulseWidgetSnapshotTests: XCTestCase {
    func testReminderActivityCompositionsRenderDistinctPendingAndCompletedStates() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let previewDirectory = projectRoot
            .appendingPathComponent(".tmp", isDirectory: true)
            .appendingPathComponent("activity-preview", isDirectory: true)
        try FileManager.default.createDirectory(
            at: previewDirectory,
            withIntermediateDirectories: true
        )

        var renderedImages: [Data] = []
        for phase in [PulseReminderActivityPhase.pending, .completed] {
            let content = PulseReminderActivityPreview(
                phase: phase,
                reminderDate: Date(timeIntervalSince1970: 67_320),
                timeZoneIdentifier: TimeZone.gmt.identifier,
                locale: Locale(identifier: "zh-Hans")
            )
            .environment(\.locale, Locale(identifier: "zh-Hans"))
            .frame(width: 344, height: 126)

            let renderer = ImageRenderer(content: content)
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage)
            let png = try XCTUnwrap(image.pngData())
            renderedImages.append(png)

            XCTAssertEqual(image.size.width, 344, accuracy: 0.5)
            XCTAssertEqual(image.size.height, 126, accuracy: 0.5)

            let previewURL = previewDirectory.appendingPathComponent(
                "activity-signature-\(phase.rawValue)@3x.png"
            )
            try png.write(to: previewURL)

            let attachment = XCTAttachment(image: image)
            attachment.name = "Signature activity \(phase.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        XCTAssertEqual(Set(renderedImages).count, 2)
    }

    func testEnhancementActivityStoreCardShowsEverySystemMorphology() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let previewDirectory = projectRoot
            .appendingPathComponent(".tmp", isDirectory: true)
            .appendingPathComponent("activity-preview", isDirectory: true)
        try FileManager.default.createDirectory(
            at: previewDirectory,
            withIntermediateDirectories: true
        )

        let content = PulseReminderActivityStoreCard(
            reminderDate: Date(timeIntervalSince1970: 67_320),
            timeZoneIdentifier: TimeZone.gmt.identifier,
            locale: Locale(identifier: "zh-Hans")
        )
        .environment(\.locale, Locale(identifier: "zh-Hans"))
        .frame(width: 344, height: 460)
        .background(PulseDesign.background)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        let png = try XCTUnwrap(image.pngData())

        XCTAssertEqual(image.size.width, 344, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 460, accuracy: 0.5)

        let previewURL = previewDirectory.appendingPathComponent(
            "activity-store-morphologies@3x.png"
        )
        try png.write(to: previewURL)

        let attachment = XCTAttachment(image: image)
        attachment.name = "Advanced features activity morphologies"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testEnhancementStoreHeroUsesProductInventoryInsteadOfExplanatoryCopy() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectRoot
            .appendingPathComponent("pulse", isDirectory: true)
            .appendingPathComponent("Localizable.xcstrings", isDirectory: false)
        let viewURL = projectRoot
            .appendingPathComponent("pulse", isDirectory: true)
            .appendingPathComponent("Features", isDirectory: true)
            .appendingPathComponent("Settings", isDirectory: true)
            .appendingPathComponent("EnhancementStoreView.swift", isDirectory: false)
        let catalog = try JSONDecoder().decode(
            WidgetStringCatalog.self,
            from: Data(contentsOf: catalogURL)
        )
        let source = try String(contentsOf: viewURL, encoding: .utf8)
        let approvedCopy: [String: [String: String]] = [
            "store.hero.tagline": [
                "en": "Two themes. Seven compositions. One Firefly Halo.",
                "zh-Hans": "两套主题。七种构图。一个萤火日晕。",
            ],
            "store.hero.scope": [
                "en": "Themes · Widgets · System Surfaces",
                "zh-Hans": "界面主题 · 小组件 · 系统表面",
            ],
            "store.hero.promise": [
                "en": "Quiet Field, Sunlit Day, seven widget styles, and Firefly Halo for Lock Screen and Dynamic Island.",
                "zh-Hans": "静野、晴昼、七种小组件样式，以及用于锁屏与灵动岛的萤火日晕。",
            ],
        ]

        for (key, localizedValues) in approvedCopy {
            let entry = try XCTUnwrap(catalog.strings[key])
            for (language, approvedValue) in localizedValues {
                XCTAssertEqual(
                    entry.localizations[language]?.stringUnit.value,
                    approvedValue,
                    "Enhancement store copy drifted for \(key) [\(language)]."
                )
            }
        }

        XCTAssertFalse(source.contains("Text(\"store.title\")"))
        XCTAssertFalse(source.contains("Text(\"store.hero.promise\")"))
        XCTAssertFalse(source.contains("store.preview.section"))
        XCTAssertFalse(source.contains("store.capabilities.section"))
        XCTAssertTrue(source.contains("ForEach(PulseEnhancementContract.currentCapabilities)"))
        XCTAssertTrue(source.contains("PulseVisualThemeAccessPolicy.enhancementThemes"))
        XCTAssertNil(catalog.strings["store.preview.section"])
        XCTAssertNil(catalog.strings["store.capabilities.section"])
    }

    func testReminderActivityLockScreenRendersTheSignatureHierarchy() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let previewDirectory = projectRoot
            .appendingPathComponent(".tmp", isDirectory: true)
            .appendingPathComponent("activity-preview", isDirectory: true)
        try FileManager.default.createDirectory(
            at: previewDirectory,
            withIntermediateDirectories: true
        )

        var renderedImages: [Data] = []
        for colorScheme in [ColorScheme.light, .dark] {
            for phase in [PulseReminderActivityPhase.pending, .completed] {
                let content = PulseReminderLockScreenView(
                    phase: phase,
                    reminderDate: Date(timeIntervalSince1970: 67_320),
                    timeZoneIdentifier: TimeZone.gmt.identifier,
                    locale: Locale(identifier: "zh-Hans")
                )
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .frame(width: 382, height: 126)
                .background(PulseWidgetDesign.activityLockScreenBackground)
                .environment(\.colorScheme, colorScheme)

                let renderer = ImageRenderer(content: content)
                renderer.scale = 3
                let image = try XCTUnwrap(renderer.uiImage)
                let png = try XCTUnwrap(image.pngData())
                renderedImages.append(png)

                XCTAssertEqual(image.size.width, 382, accuracy: 0.5)
                XCTAssertEqual(image.size.height, 126, accuracy: 0.5)

                let appearance = colorScheme == .dark ? "dark" : "light"
                let previewURL = previewDirectory.appendingPathComponent(
                    "activity-lock-screen-signature-\(appearance)-\(phase.rawValue)@3x.png"
                )
                try png.write(to: previewURL)

                let attachment = XCTAttachment(image: image)
                attachment.name = "Lock Screen signature activity \(appearance) \(phase.rawValue)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }

        XCTAssertEqual(Set(renderedImages).count, 4)
    }

    func testReminderActivityCompactMarksRenderInsideSystemSizedCanvas() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let previewDirectory = projectRoot
            .appendingPathComponent(".tmp", isDirectory: true)
            .appendingPathComponent("activity-preview", isDirectory: true)
        try FileManager.default.createDirectory(
            at: previewDirectory,
            withIntermediateDirectories: true
        )

        let layouts: [(layout: PulseReminderActivityMarkLayout, name: String)] = [
            (.islandCompact, "compact"),
            (.islandMinimal, "minimal"),
        ]
        var renderedImages: [Data] = []
        for configuration in layouts {
            for phase in [PulseReminderActivityPhase.pending, .completed] {
                let content = PulseReminderActivityMark(
                    phase: phase,
                    layout: configuration.layout
                )
                .frame(
                    width: configuration.layout.size,
                    height: configuration.layout.size
                )
                .padding(5)
                .background(Color.black)

                let renderer = ImageRenderer(content: content)
                renderer.scale = 3
                let image = try XCTUnwrap(renderer.uiImage)
                let png = try XCTUnwrap(image.pngData())
                renderedImages.append(png)

                let renderedSide = configuration.layout.size + 10
                XCTAssertEqual(image.size.width, renderedSide, accuracy: 0.5)
                XCTAssertEqual(image.size.height, renderedSide, accuracy: 0.5)

                let previewURL = previewDirectory.appendingPathComponent(
                    "activity-\(configuration.name)-signature-\(phase.rawValue)@3x.png"
                )
                try png.write(to: previewURL)

                let attachment = XCTAttachment(image: image)
                attachment.name = "\(configuration.name) signature activity \(phase.rawValue)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }

        XCTAssertEqual(
            PulseReminderActivityMarkLayout.islandCompact.size,
            PulseReminderActivityMarkLayout.islandMinimal.size
        )
        XCTAssertEqual(Set(renderedImages).count, 2)
    }

    func testReminderActivityFireflySharesTheArcPathRadius() {
        let ringDiameter: CGFloat = 42
        let offset = PulseReminderActivityMarkGeometry.fireflyOffset(
            ringDiameter: ringDiameter
        )

        XCTAssertEqual(hypot(offset.width, offset.height), ringDiameter / 2, accuracy: 0.0001)
        XCTAssertGreaterThan(offset.width, 0)
        XCTAssertLessThan(offset.height, 0)
    }

    func testReminderActivityFireflyFitsInsideEveryRenderedMarkCanvas() {
        for layout in PulseReminderActivityMarkLayout.allCases {
            let metrics = PulseReminderActivityMarkGeometry.metrics(layout: layout)
            let canvasRadius = metrics.glyphSize / 2

            if layout.drawsHalo {
                let offset = PulseReminderActivityMarkGeometry.fireflyOffset(
                    ringDiameter: metrics.ringDiameter
                )
                let fireflyOuterRadius =
                    (metrics.fireflyDiameter + metrics.fireflyOutlineWidth) / 2
                XCTAssertLessThanOrEqual(
                    abs(offset.width) + fireflyOuterRadius,
                    canvasRadius + 0.0001
                )
                XCTAssertLessThanOrEqual(
                    abs(offset.height) + fireflyOuterRadius,
                    canvasRadius + 0.0001
                )
                XCTAssertLessThan(metrics.fireflyDiameter, metrics.ringDiameter)
                XCTAssertGreaterThan(
                    metrics.fireflyGlowDiameter,
                    metrics.fireflyDiameter
                )
                XCTAssertLessThanOrEqual(
                    abs(offset.width) + metrics.fireflyGlowDiameter / 2,
                    canvasRadius + 0.0001
                )
                XCTAssertLessThanOrEqual(
                    abs(offset.height) + metrics.fireflyGlowDiameter / 2,
                    canvasRadius + 0.0001
                )
                let ringOuterRadius = metrics.ringDiameter / 2 + metrics.lineWidth / 2
                XCTAssertLessThanOrEqual(ringOuterRadius, canvasRadius + 0.0001)
            } else {
                XCTAssertEqual(metrics.ringDiameter, 0, accuracy: 0.0001)
                XCTAssertEqual(metrics.lineWidth, 0, accuracy: 0.0001)
                XCTAssertGreaterThanOrEqual(
                    metrics.fireflyDiameter,
                    PulseReminderActivityMarkGeometry.islandFireflyDiameterMinimum
                )
                XCTAssertGreaterThan(metrics.fireflyGlowDiameter, metrics.fireflyDiameter)
                XCTAssertLessThanOrEqual(
                    metrics.fireflyGlowDiameter / 2,
                    canvasRadius + 0.0001
                )
                XCTAssertLessThan(
                    metrics.fireflyDiameter,
                    metrics.completedCoreDiameter
                )
                XCTAssertLessThanOrEqual(
                    metrics.completedCoreDiameter / 2,
                    canvasRadius + 0.0001
                )
            }
        }
    }

    func testIslandMarksKeepTheHaloOnLockScreenOnly() {
        for layout in [
            PulseReminderActivityMarkLayout.islandExpanded,
            .islandCompact,
            .islandMinimal,
        ] {
            XCTAssertFalse(layout.drawsHalo)
            XCTAssertEqual(
                PulseReminderActivityMarkGeometry.metrics(layout: layout).ringDiameter,
                0,
                accuracy: 0.0001
            )
        }

        XCTAssertTrue(PulseReminderActivityMarkLayout.lockScreen.drawsHalo)
        XCTAssertGreaterThan(
            PulseReminderActivityMarkGeometry.metrics(layout: .lockScreen).ringDiameter,
            0
        )
    }

    func testActivityColorsKeepIslandFireflySeparateFromLockScreenContrast() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let tokenURL = projectRoot
            .appendingPathComponent("design", isDirectory: true)
            .appendingPathComponent("brand-tokens.json", isDirectory: false)
        let assetRoot = projectRoot
            .appendingPathComponent("pulse", isDirectory: true)
            .appendingPathComponent("Assets.xcassets", isDirectory: true)
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: tokenURL))
                as? [String: Any]
        )

        for appearance in ["light", "dark"] {
            let colors = try XCTUnwrap(root[appearance] as? [String: String])
            XCTAssertEqual(colors["activityIslandFirefly"], "#F5C84B")
            XCTAssertNil(colors["activityIslandTime"])
            XCTAssertNil(colors["activityFirefly"])
        }

        let lightColors = try XCTUnwrap(root["light"] as? [String: String])
        let darkColors = try XCTUnwrap(root["dark"] as? [String: String])
        XCTAssertEqual(lightColors["activityLockScreenFirefly"], "#B86A00")
        XCTAssertEqual(darkColors["activityLockScreenFirefly"], "#F5C84B")
        XCTAssertNotEqual(
            lightColors["activityIslandFirefly"],
            lightColors["activityLockScreenFirefly"]
        )

        try assertActivityColorset(
            named: "PulseActivityIslandFirefly",
            in: assetRoot,
            light: "#F5C84B",
            dark: "#F5C84B"
        )
        try assertActivityColorset(
            named: "PulseActivityLockScreenFirefly",
            in: assetRoot,
            light: "#B86A00",
            dark: "#F5C84B"
        )

        for assetName in [
            "PulseActivityIslandFirefly",
            "PulseActivityLockScreenFirefly",
        ] {
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: assetRoot
                        .appendingPathComponent("\(assetName).colorset", isDirectory: true)
                        .appendingPathComponent("Contents.json", isDirectory: false)
                        .path
                )
            )
        }
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: assetRoot
                    .appendingPathComponent(
                        "PulseActivityIslandTime.colorset",
                        isDirectory: true
                    )
                    .appendingPathComponent("Contents.json", isDirectory: false)
                    .path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: assetRoot
                    .appendingPathComponent("PulseActivityFirefly.colorset", isDirectory: true)
                    .appendingPathComponent("Contents.json", isDirectory: false)
                    .path
            )
        )
    }

    func testWatchCatalogContainsOnlyWatchSemanticColors() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let tokenURL = projectRoot
            .appendingPathComponent("design", isDirectory: true)
            .appendingPathComponent("brand-tokens.json", isDirectory: false)
        let watchAssetRoot = projectRoot
            .appendingPathComponent("PulseWatchAssets", isDirectory: true)
            .appendingPathComponent("Assets.xcassets", isDirectory: true)
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: tokenURL))
                as? [String: Any]
        )
        let watch = try XCTUnwrap(root["watch"] as? [String: String])

        XCTAssertEqual(
            watch,
            [
                "canvasTop": "#04152E",
                "canvasBottom": "#075EA8",
                "waveBack": "#093D7C",
                "waveMiddle": "#0865B8",
                "waveFront": "#0789E6",
                "axis": "#32C2FF",
                "ink": "#F0F5EC",
                "secondary": "#A6B0A2",
                "field": "#73966D",
                "committed": "#91D55B",
                "committedForeground": "#102013",
                "pending": "#F5C84B",
            ]
        )
        let colorDirectories = try FileManager.default.contentsOfDirectory(
            at: watchAssetRoot,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "colorset" }
        .map(\.lastPathComponent)
        .sorted()
        XCTAssertEqual(
            colorDirectories,
            [
                "AccentColor.colorset",
                "PulseWatchAxis.colorset",
                "PulseWatchCanvasBottom.colorset",
                "PulseWatchCanvasTop.colorset",
                "PulseWatchCommitted.colorset",
                "PulseWatchCommittedForeground.colorset",
                "PulseWatchField.colorset",
                "PulseWatchInk.colorset",
                "PulseWatchPending.colorset",
                "PulseWatchSecondary.colorset",
                "PulseWatchWaveBack.colorset",
                "PulseWatchWaveFront.colorset",
                "PulseWatchWaveMiddle.colorset",
            ]
        )
    }

    func testReminderActivityLetsTheSystemOwnTheLockScreenBackgroundPair() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: projectRoot
                .appendingPathComponent("PulseWidgets", isDirectory: true)
                .appendingPathComponent("PulseWidgets.swift", isDirectory: false),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains(".activityBackgroundTint(nil)"))
        XCTAssertTrue(source.contains(".activitySystemActionForegroundColor(nil)"))
        XCTAssertTrue(source.contains(".keylineTint(PulseWidgetDesign.activityIslandFirefly)"))
        XCTAssertTrue(source.contains("compactTrailing: {\n                EmptyView()"))
        XCTAssertFalse(source.contains("PulseReminderActivityCompactTrailing"))
        XCTAssertFalse(source.contains("keylineTint(PulseWidgetDesign.grass)"))
        XCTAssertFalse(
            source.contains(".activityBackgroundTint(PulseWidgetDesign.background)")
        )
    }

    func testRetiredReminderActivityImplementationsDoNotRemain() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let renderer = try String(
            contentsOf: projectRoot
                .appendingPathComponent("PulseWidgetUI", isDirectory: true)
                .appendingPathComponent(
                    "PulseReminderActivityRenderer.swift",
                    isDirectory: false
                ),
            encoding: .utf8
        )

        let store = try String(
            contentsOf: projectRoot
                .appendingPathComponent("pulse", isDirectory: true)
                .appendingPathComponent("Features", isDirectory: true)
                .appendingPathComponent("Settings", isDirectory: true)
                .appendingPathComponent("EnhancementStoreView.swift", isDirectory: false),
            encoding: .utf8
        )
        let retiredSymbols = [
            "PulseReminderDynamicIslandCenterView",
            "PulseReminderActivityCompactTrailing",
            "PulseReminderDynamicIslandBottomView",
            "PulseNavigationGlyphSurface",
            "PulseGrassForeground",
        ]
        for symbol in retiredSymbols {
            XCTAssertFalse(renderer.contains(symbol), "Retired Activity symbol remains: \(symbol)")
            XCTAssertFalse(store.contains(symbol), "Retired store-preview symbol remains: \(symbol)")
        }
    }

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

    func testReminderActivityLockScreenRendersAtMaximumDynamicType() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let previewURL = projectRoot
            .appendingPathComponent(".tmp", isDirectory: true)
            .appendingPathComponent("activity-preview", isDirectory: true)
            .appendingPathComponent("activity-lock-screen-accessibility5@3x.png")
        try FileManager.default.createDirectory(
            at: previewURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let content = PulseReminderLockScreenView(
            phase: .pending,
            reminderDate: Date(timeIntervalSince1970: 67_320),
            timeZoneIdentifier: TimeZone.gmt.identifier,
            locale: Locale(identifier: "en")
        )
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.dynamicTypeSize, .accessibility5)
        .frame(width: 382, height: 260, alignment: .top)
        .background(PulseWidgetDesign.activityLockScreenBackground)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        let png = try XCTUnwrap(image.pngData())
        try png.write(to: previewURL)

        XCTAssertEqual(image.size.width, 382, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 260, accuracy: 0.5)
    }

    func testLetterCompositionRendersMixedHistoricalFactsAtBothHomeSizes() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let today = LogicalDay(year: 2026, month: 8, day: 10)
        let generatedAt = makeDate(2026, 8, 10, 12, timeZone: timeZone)
        let snapshot = PulseWidgetSnapshot(
            habitID: try XCTUnwrap(
                UUID(uuidString: "9FA0F56B-6D71-4E81-B6ED-07BF287049A5")
            ),
            habitName: "我的一件事",
            today: today,
            checkedAt: nil,
            recentDays: [
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 4), state: .beforeHabit),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 5), state: .checked),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 6), state: .missed),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 7), state: .checked),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 8), state: .checked),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 9), state: .missed),
                PulseWidgetDaySnapshot(day: today, state: .todayPending),
            ],
            generatedAt: generatedAt,
            nextDayBoundary: makeDate(2026, 8, 11, 0, timeZone: timeZone),
            projectTimeZoneIdentifier: timeZone.identifier
        )
        let configurations: [(name: String, size: CGSize, usesMediumMetrics: Bool)] = [
            ("small", CGSize(width: 158, height: 158), false),
            ("medium", CGSize(width: 338, height: 158), true),
        ]

        for configuration in configurations {
            let content = PulseWidgetHomeRenderer(
                snapshot: snapshot,
                style: .letter,
                usesMediumMetrics: configuration.usesMediumMetrics,
                usesFullColorPalette: true,
                allowsMotion: false,
                statusText: "今天还未签到",
                pathSummaryFormat: "六日 · 签到 %d 天",
                emptyPlaceText: "待签到",
                placeStatusText: "今天还未签到"
            )
            .environment(\.locale, Locale(identifier: "zh-Hans"))
            .frame(width: configuration.size.width, height: configuration.size.height)

            let renderer = ImageRenderer(content: content)
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertEqual(image.size.width, configuration.size.width, accuracy: 0.5)
            XCTAssertEqual(image.size.height, configuration.size.height, accuracy: 0.5)

            let attachment = XCTAttachment(image: image)
            attachment.name = "Letter mixed history \(configuration.name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testPathCompositionRendersAtmosphericRouteAtBothHomeSizesAndStates() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let today = LogicalDay(year: 2026, month: 8, day: 10)
        let generatedAt = makeDate(2026, 8, 10, 12, timeZone: timeZone)
        let pending = PulseWidgetSnapshot(
            habitID: try XCTUnwrap(
                UUID(uuidString: "DB447BE9-C776-4F35-BDBA-D9EDB3EC18BC")
            ),
            habitName: "我的一件事",
            today: today,
            checkedAt: nil,
            recentDays: [
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 4), state: .beforeHabit),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 5), state: .checked),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 6), state: .missed),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 7), state: .checked),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 8), state: .checked),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 9), state: .missed),
                PulseWidgetDaySnapshot(day: today, state: .todayPending),
            ],
            generatedAt: generatedAt,
            nextDayBoundary: makeDate(2026, 8, 11, 0, timeZone: timeZone),
            projectTimeZoneIdentifier: timeZone.identifier
        )
        let states: [(name: String, snapshot: PulseWidgetSnapshot)] = [
            ("pending", pending),
            ("completed", pending.projectingTodayCheckInForGallery(true)),
        ]
        let configurations: [(name: String, size: CGSize, usesMediumMetrics: Bool)] = [
            ("small", CGSize(width: 158, height: 158), false),
            ("medium", CGSize(width: 338, height: 158), true),
        ]
        let schemes: [(name: String, value: ColorScheme)] = [
            ("light", .light),
            ("dark", .dark),
        ]

        for state in states {
            for configuration in configurations {
                for scheme in schemes {
                    let content = PulseWidgetHomeRenderer(
                        snapshot: state.snapshot,
                        style: .path,
                        usesMediumMetrics: configuration.usesMediumMetrics,
                        usesFullColorPalette: true,
                        allowsMotion: false,
                        statusText: state.snapshot.isCheckedToday ? "今天已签到" : "今天还未签到",
                        pathSummaryFormat: "六日 · 签到 %d 天",
                        emptyPlaceText: "待签到",
                        placeStatusText: state.snapshot.isCheckedToday ? "今天已签到" : "今天还未签到"
                    )
                    .environment(\.locale, Locale(identifier: "zh-Hans"))
                    .environment(\.colorScheme, scheme.value)
                    .frame(width: configuration.size.width, height: configuration.size.height)

                    let renderer = ImageRenderer(content: content)
                    renderer.scale = 3
                    let image = try XCTUnwrap(renderer.uiImage)
                    XCTAssertEqual(image.size.width, configuration.size.width, accuracy: 0.5)
                    XCTAssertEqual(image.size.height, configuration.size.height, accuracy: 0.5)

                    let attachment = XCTAttachment(image: image)
                    attachment.name = "Path " + state.name + " "
                        + configuration.name + " " + scheme.name
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }

    func testTideCompositionRendersSkyAndReflectionAcrossHomeSizesAndStates() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let today = LogicalDay(year: 2026, month: 8, day: 15)
        let generatedAt = makeDate(2026, 8, 15, 12, timeZone: timeZone)
        let pending = PulseWidgetSnapshot(
            habitID: try XCTUnwrap(
                UUID(uuidString: "A38DBF61-0D11-43FD-B30B-E0D9A8A80D8B")
            ),
            habitName: "晨间书写",
            today: today,
            checkedAt: nil,
            recentDays: [
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 9), state: .checked),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 10), state: .missed),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 11), state: .checked),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 12), state: .checked),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 13), state: .missed),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 14), state: .checked),
                PulseWidgetDaySnapshot(day: today, state: .todayPending),
            ],
            generatedAt: generatedAt,
            nextDayBoundary: makeDate(2026, 8, 16, 0, timeZone: timeZone),
            projectTimeZoneIdentifier: timeZone.identifier
        )
        let states: [(name: String, snapshot: PulseWidgetSnapshot)] = [
            ("pending", pending),
            ("completed", pending.projectingTodayCheckInForGallery(true)),
        ]
        let configurations: [(name: String, size: CGSize, usesMediumMetrics: Bool)] = [
            ("small", CGSize(width: 158, height: 158), false),
            ("medium", CGSize(width: 338, height: 158), true),
        ]
        let schemes: [(name: String, value: ColorScheme)] = [
            ("light", .light),
            ("dark", .dark),
        ]

        for state in states {
            for configuration in configurations {
                for scheme in schemes {
                    let content = PulseWidgetHomeRenderer(
                        snapshot: state.snapshot,
                        style: .tide,
                        usesMediumMetrics: configuration.usesMediumMetrics,
                        usesFullColorPalette: true,
                        allowsMotion: false,
                        statusText: state.snapshot.isCheckedToday ? "今天已签到" : "今天还未签到",
                        pathSummaryFormat: "六日 · 签到 %d 天",
                        emptyPlaceText: "待签到",
                        placeStatusText: state.snapshot.isCheckedToday ? "今天已签到" : "今天还未签到"
                    )
                    .environment(\.locale, Locale(identifier: "zh-Hans"))
                    .environment(\.colorScheme, scheme.value)
                    .frame(width: configuration.size.width, height: configuration.size.height)

                    let renderer = ImageRenderer(content: content)
                    renderer.scale = 3
                    let image = try XCTUnwrap(renderer.uiImage)
                    XCTAssertEqual(image.size.width, configuration.size.width, accuracy: 0.5)
                    XCTAssertEqual(image.size.height, configuration.size.height, accuracy: 0.5)

                    let attachment = XCTAttachment(image: image)
                    attachment.name = "Tide " + state.name + " "
                        + configuration.name + " " + scheme.name
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }

    func testTideSunTravelsThroughDistinctAmbientPositions() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let today = LogicalDay(year: 2026, month: 8, day: 15)
        let recentDays = [
            PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 9), state: .checked),
            PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 10), state: .missed),
            PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 11), state: .checked),
            PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 12), state: .checked),
            PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 13), state: .missed),
            PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 14), state: .checked),
            PulseWidgetDaySnapshot(day: today, state: .todayPending),
        ]
        let periods: [(name: String, value: PulseWidgetAmbientPeriod, hour: Int)] = [
            ("morning", .morning, 8),
            ("daylight", .daylight, 13),
            ("evening", .evening, 20),
        ]
        let configurations: [(name: String, size: CGSize, usesMediumMetrics: Bool)] = [
            ("small", CGSize(width: 158, height: 158), false),
            ("medium", CGSize(width: 338, height: 158), true),
        ]

        for configuration in configurations {
            let morning = PulseTideSkyGeometry(
                size: configuration.size,
                usesMediumMetrics: configuration.usesMediumMetrics,
                period: .morning
            )
            let daylight = PulseTideSkyGeometry(
                size: configuration.size,
                usesMediumMetrics: configuration.usesMediumMetrics,
                period: .daylight
            )
            let evening = PulseTideSkyGeometry(
                size: configuration.size,
                usesMediumMetrics: configuration.usesMediumMetrics,
                period: .evening
            )

            XCTAssertLessThan(morning.center.x, daylight.center.x)
            XCTAssertLessThan(daylight.center.x, evening.center.x)
            XCTAssertLessThan(daylight.center.y, morning.center.y)
            XCTAssertLessThan(morning.center.y, evening.center.y)
            XCTAssertGreaterThan(
                morning.center.y - daylight.center.y,
                configuration.size.height * 0.20
            )
            XCTAssertGreaterThan(
                evening.center.y - morning.center.y,
                configuration.size.height * 0.15
            )

            for period in periods {
                let generatedAt = makeDate(
                    2026,
                    8,
                    15,
                    period.hour,
                    timeZone: timeZone
                )
                XCTAssertEqual(
                    PulseWidgetAmbientPeriod.resolve(at: generatedAt, timeZone: timeZone),
                    period.value
                )

                let snapshot = PulseWidgetSnapshot(
                    habitID: try XCTUnwrap(
                        UUID(uuidString: "C299EA0C-75A6-4A44-B1C4-B16055BE184F")
                    ),
                    habitName: "晨间书写",
                    today: today,
                    checkedAt: nil,
                    recentDays: recentDays,
                    generatedAt: generatedAt,
                    nextDayBoundary: makeDate(2026, 8, 16, 0, timeZone: timeZone),
                    projectTimeZoneIdentifier: timeZone.identifier
                )
                let content = PulseWidgetHomeRenderer(
                    snapshot: snapshot,
                    style: .tide,
                    usesMediumMetrics: configuration.usesMediumMetrics,
                    usesFullColorPalette: true,
                    allowsMotion: false,
                    statusText: "今天还未签到",
                    pathSummaryFormat: "六日 · 签到 %d 天",
                    emptyPlaceText: "待签到",
                    placeStatusText: "今天还未签到"
                )
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .environment(\.colorScheme, ColorScheme.light)
                .frame(width: configuration.size.width, height: configuration.size.height)

                let renderer = ImageRenderer(content: content)
                renderer.scale = 3
                let image = try XCTUnwrap(renderer.uiImage)
                let attachment = XCTAttachment(image: image)
                attachment.name = "Tide sun " + period.name + " " + configuration.name
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testOrbitCleanBreakRendersPendingAndCompletedAcrossSupportedHomeSizes() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let today = LogicalDay(year: 2026, month: 8, day: 15)
        let generatedAt = makeDate(2026, 8, 15, 12, timeZone: timeZone)
        let pending = PulseWidgetSnapshot(
            habitID: try XCTUnwrap(
                UUID(uuidString: "7832FF6C-AEAE-4C04-BD22-5DE680439423")
            ),
            habitName: "晨间书写",
            today: today,
            checkedAt: nil,
            recentDays: [
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 9), state: .checked),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 10), state: .missed),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 11), state: .checked),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 12), state: .checked),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 13), state: .missed),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 14), state: .checked),
                PulseWidgetDaySnapshot(day: today, state: .todayPending),
            ],
            generatedAt: generatedAt,
            nextDayBoundary: makeDate(2026, 8, 16, 0, timeZone: timeZone),
            projectTimeZoneIdentifier: timeZone.identifier
        )
        let completed = PulseWidgetSnapshot(
            habitID: pending.habitID,
            habitName: pending.habitName,
            today: pending.today,
            checkedAt: generatedAt,
            recentDays: Array(pending.recentDays.dropLast()) + [
                PulseWidgetDaySnapshot(day: today, state: .checked)
            ],
            generatedAt: pending.generatedAt,
            nextDayBoundary: pending.nextDayBoundary,
            projectTimeZoneIdentifier: pending.projectTimeZoneIdentifier
        )
        let states: [(name: String, snapshot: PulseWidgetSnapshot)] = [
            ("pending", pending),
            ("completed", completed),
        ]
        let configurations: [(name: String, size: CGSize, usesMediumMetrics: Bool)] = [
            ("small-158", CGSize(width: 158, height: 158), false),
            ("small-170", CGSize(width: 170, height: 170), false),
            ("medium-338", CGSize(width: 338, height: 158), true),
            ("medium-364", CGSize(width: 364, height: 170), true),
        ]

        for state in states {
            for configuration in configurations {
                let content = PulseWidgetHomeRenderer(
                    snapshot: state.snapshot,
                    style: .orbit,
                    usesMediumMetrics: configuration.usesMediumMetrics,
                    usesFullColorPalette: true,
                    allowsMotion: false,
                    statusText: state.snapshot.isCheckedToday ? "今天已签到" : "今天还未签到",
                    pathSummaryFormat: "六日 · 签到 %d 天",
                    emptyPlaceText: "待签到",
                    placeStatusText: state.snapshot.isCheckedToday ? "今天已签到" : "今天还未签到"
                )
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .frame(width: configuration.size.width, height: configuration.size.height)

                let renderer = ImageRenderer(content: content)
                renderer.scale = 3
                let image = try XCTUnwrap(renderer.uiImage)
                XCTAssertEqual(image.size.width, configuration.size.width, accuracy: 0.5)
                XCTAssertEqual(image.size.height, configuration.size.height, accuracy: 0.5)

                let attachment = XCTAttachment(image: image)
                attachment.name = "Orbit \(state.name) \(configuration.name)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testStarRingGeometryKeepsASingleStarOnTheBrandRing() {
        let sizes = [
            CGSize(width: 145, height: 145),
            CGSize(width: 155, height: 155),
            CGSize(width: 158, height: 158),
            CGSize(width: 169, height: 169),
            CGSize(width: 170, height: 170),
            CGSize(width: 180, height: 180),
            CGSize(width: 329, height: 155),
            CGSize(width: 338, height: 158),
            CGSize(width: 360, height: 169),
            CGSize(width: 364, height: 170),
        ]

        for size in sizes {
            for period in PulseWidgetAmbientPeriod.allCases {
                for isChecked in [false, true] {
                    let geometry = PulseStarRingGeometry(
                        size: size,
                        period: period,
                        isChecked: isChecked
                    )

                    XCTAssertGreaterThanOrEqual(
                        geometry.ringDiameter / min(size.width, size.height),
                        0.62,
                        "Ring is too small to be the main object at \(size)."
                    )
                    XCTAssertEqual(
                        geometry.ringPathDiameter,
                        geometry.ringDiameter - geometry.ringLineWidth,
                        accuracy: 0.001
                    )
                    XCTAssertGreaterThanOrEqual(
                        geometry.starDiameter / geometry.ringLineWidth,
                        1.25,
                        "Today's star must read as a bead, not a thickened stroke."
                    )
                    XCTAssertLessThan(
                        geometry.innerWellDiameter,
                        geometry.ringPathDiameter - geometry.ringLineWidth,
                        "Inner well must leave a gutter inside the ring wall at \(size)."
                    )
                    XCTAssertGreaterThanOrEqual(
                        geometry.innerWellDiameter / geometry.ringDiameter,
                        0.48,
                        "Inner well is too small to fill the hollow at \(size)."
                    )
                    XCTAssertTrue(
                        geometry.safeFrame.contains(geometry.starFrame),
                        "Today's star escaped the safe frame at \(size), \(period), checked=\(isChecked)."
                    )

                    let dx = geometry.starPosition.x - geometry.ringCenter.x
                    let dy = geometry.starPosition.y - geometry.ringCenter.y
                    let distance = (dx * dx + dy * dy).squareRoot()
                    XCTAssertEqual(
                        distance,
                        geometry.midlineRadius,
                        accuracy: 0.001,
                        "Today's star is not on the ring at \(size), \(period), checked=\(isChecked)."
                    )
                }
            }
        }
    }

    func testStackGeometryFillsTheCanvasWithFourSheetsAndAPressPlate() {
        XCTAssertEqual(PulseWidgetDesign.stackPhysicalSheetCount, 4)

        let sizes: [(CGSize, Bool)] = [
            (CGSize(width: 145, height: 145), false),
            (CGSize(width: 158, height: 158), false),
            (CGSize(width: 180, height: 180), false),
            (CGSize(width: 329, height: 155), true),
            (CGSize(width: 338, height: 158), true),
            (CGSize(width: 364, height: 170), true),
        ]

        for (size, usesMediumMetrics) in sizes {
            for isChecked in [false, true] {
                let geometry = PulseStackPaperGeometry(
                    size: size,
                    usesMediumMetrics: usesMediumMetrics,
                    isChecked: isChecked
                )
                let bounds = geometry.stackBounds

                XCTAssertGreaterThanOrEqual(
                    bounds.width / size.width,
                    0.88,
                    "Stack is too narrow to fill the canvas at \(size)."
                )
                XCTAssertGreaterThanOrEqual(
                    bounds.height / size.height,
                    0.88,
                    "Stack is too short to fill the canvas at \(size)."
                )
                XCTAssertGreaterThanOrEqual(
                    min(geometry.foldSize.width, geometry.foldSize.height)
                        / min(geometry.topPaperFrame.width, geometry.topPaperFrame.height),
                    0.28,
                    "Folded corner is too small to read as a dog-ear at \(size)."
                )
                XCTAssertGreaterThanOrEqual(
                    (geometry.pressSize.width * geometry.pressSize.height)
                        / (geometry.topPaperFrame.width * geometry.topPaperFrame.height),
                    0.08,
                    "Press plate is too small to occupy the top sheet at \(size)."
                )
                XCTAssertTrue(
                    geometry.topPaperFrame.insetBy(dx: -0.5, dy: -0.5).contains(geometry.pressFrame),
                    "Press plate escaped the top sheet at \(size), checked=\(isChecked)."
                )
                // The formal composition intentionally overlaps the dog-ear; do not force clearance.
                if usesMediumMetrics {
                    XCTAssertEqual(
                        geometry.pressSize.width / size.width,
                        86 / 338,
                        accuracy: 0.01,
                        "Medium press width must track the formal 86/338 geometry."
                    )
                    XCTAssertEqual(
                        (size.width - geometry.pressFrame.maxX) / size.width,
                        48 / 338,
                        accuracy: 0.02,
                        "Medium press right inset must remain 48pt in the formal geometry."
                    )
                    XCTAssertEqual(
                        (size.height - geometry.pressFrame.maxY) / size.height,
                        36 / 158,
                        accuracy: 0.03,
                        "Medium press bottom inset must remain 36pt in the formal geometry."
                    )
                } else {
                    XCTAssertEqual(
                        geometry.pressSize.width / size.width,
                        54 / 158,
                        accuracy: 0.01,
                        "Small press width must track the formal 54/158 geometry."
                    )
                    XCTAssertEqual(
                        (size.width - geometry.pressFrame.maxX) / size.width,
                        28 / 158,
                        accuracy: 0.02,
                        "Small press right inset must remain 28pt in the formal geometry."
                    )
                    XCTAssertEqual(
                        (size.height - geometry.pressFrame.maxY) / size.height,
                        46 / 158,
                        accuracy: 0.03,
                        "Small press bottom inset must remain 46pt in the formal geometry."
                    )
                }
                let reservedCascade = geometry.topPaperFrame.minX - bounds.minX
                if isChecked {
                    XCTAssertLessThan(
                        geometry.layerStep * CGFloat(PulseStackPaperGeometry.sheetCount - 1),
                        reservedCascade,
                        "Checked sheets must compress inside the reserved cascade at \(size)."
                    )
                } else {
                    XCTAssertEqual(
                        geometry.layerStep * CGFloat(PulseStackPaperGeometry.sheetCount - 1),
                        reservedCascade,
                        accuracy: 0.001,
                        "Pending sheets must use the full reserved cascade at \(size)."
                    )
                }
            }
        }
    }

    func testStackCleanBreakRendersPendingAndCompletedAcrossSupportedHomeSizes() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let today = LogicalDay(year: 2026, month: 8, day: 15)
        let generatedAt = makeDate(2026, 8, 15, 12, timeZone: timeZone)
        let pending = PulseWidgetSnapshot(
            habitID: try XCTUnwrap(
                UUID(uuidString: "7832FF6C-AEAE-4C04-BD22-5DE680439423")
            ),
            habitName: "晨间书写",
            today: today,
            checkedAt: nil,
            recentDays: [
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 9), state: .checked),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 10), state: .missed),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 11), state: .checked),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 12), state: .checked),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 13), state: .missed),
                PulseWidgetDaySnapshot(day: LogicalDay(year: 2026, month: 8, day: 14), state: .checked),
                PulseWidgetDaySnapshot(day: today, state: .todayPending),
            ],
            generatedAt: generatedAt,
            nextDayBoundary: makeDate(2026, 8, 16, 0, timeZone: timeZone),
            projectTimeZoneIdentifier: timeZone.identifier
        )
        let completed = PulseWidgetSnapshot(
            habitID: pending.habitID,
            habitName: pending.habitName,
            today: pending.today,
            checkedAt: generatedAt,
            recentDays: Array(pending.recentDays.dropLast()) + [
                PulseWidgetDaySnapshot(day: today, state: .checked)
            ],
            generatedAt: pending.generatedAt,
            nextDayBoundary: pending.nextDayBoundary,
            projectTimeZoneIdentifier: pending.projectTimeZoneIdentifier
        )
        let states: [(name: String, snapshot: PulseWidgetSnapshot)] = [
            ("pending", pending),
            ("completed", completed),
        ]
        let configurations: [(name: String, size: CGSize, usesMediumMetrics: Bool)] = [
            ("small-158", CGSize(width: 158, height: 158), false),
            ("medium-338", CGSize(width: 338, height: 158), true),
        ]

        for state in states {
            for configuration in configurations {
                let content = PulseWidgetHomeRenderer(
                    snapshot: state.snapshot,
                    style: .stack,
                    usesMediumMetrics: configuration.usesMediumMetrics,
                    usesFullColorPalette: true,
                    allowsMotion: false,
                    statusText: state.snapshot.isCheckedToday ? "今天已签到" : "今天还未签到",
                    pathSummaryFormat: "六日 · 签到 %d 天",
                    emptyPlaceText: "待签到",
                    placeStatusText: state.snapshot.isCheckedToday ? "今天已签到" : "今天还未签到"
                )
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .frame(width: configuration.size.width, height: configuration.size.height)

                let renderer = ImageRenderer(content: content)
                renderer.scale = 3
                let image = try XCTUnwrap(renderer.uiImage)
                XCTAssertEqual(image.size.width, configuration.size.width, accuracy: 0.5)
                XCTAssertEqual(image.size.height, configuration.size.height, accuracy: 0.5)

                let previewDir = projectRoot
                    .appendingPathComponent(".tmp", isDirectory: true)
                    .appendingPathComponent("stack-preview", isDirectory: true)
                try FileManager.default.createDirectory(at: previewDir, withIntermediateDirectories: true)
                let previewURL = previewDir.appendingPathComponent(
                    "stack-\(state.name)-\(configuration.name)@3x.png"
                )
                try XCTUnwrap(image.pngData()).write(to: previewURL)

                let attachment = XCTAttachment(image: image)
                attachment.name = "Stack \(state.name) \(configuration.name)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testWidgetAppIntentsAreSharedWithTheContainerApp() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sharedSourceDirectory = projectRoot
            .appendingPathComponent("PulseWidgetUI", isDirectory: true)
        let extensionSourceDirectory = projectRoot
            .appendingPathComponent("PulseWidgets", isDirectory: true)
        let projectSource = try String(
            contentsOf: projectRoot
                .appendingPathComponent("pulse.xcodeproj", isDirectory: true)
                .appendingPathComponent("project.pbxproj", isDirectory: false),
            encoding: .utf8
        )
        let sharedSource = try swiftSource(in: sharedSourceDirectory)
        let extensionSource = try swiftSource(in: extensionSourceDirectory)

        for typeName in ["PulseWidgetConfigurationIntent", "PulseCheckInIntent"] {
            XCTAssertTrue(sharedSource.contains("struct \(typeName)"))
            XCTAssertFalse(extensionSource.contains("struct \(typeName)"))
        }
        XCTAssertGreaterThanOrEqual(
            projectSource.components(separatedBy: "/* PulseWidgetUI */").count - 1,
            3,
            "PulseWidgetUI must remain a synchronized source group of both the app and widget-extension targets."
        )
    }

    func testWidgetStringCatalogHasEnglishAndSimplifiedChineseForEveryKey() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectRoot
            .appendingPathComponent("PulseWidgets", isDirectory: true)
            .appendingPathComponent("Localizable.xcstrings", isDirectory: false)
        let widgetSourceURLs = ["PulseWidgets", "PulseWidgetUI"].flatMap { directory in
            let directoryURL = projectRoot.appendingPathComponent(directory, isDirectory: true)
            return (try? FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            ))?.filter { $0.pathExtension == "swift" } ?? []
        }
        let catalog = try JSONDecoder().decode(
            WidgetStringCatalog.self,
            from: Data(contentsOf: catalogURL)
        )
        let widgetSource = try widgetSourceURLs
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")

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

        let appCatalog = try JSONDecoder().decode(
            WidgetStringCatalog.self,
            from: Data(
                contentsOf: projectRoot
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

    func testWidgetGalleryRitualCaptionsMatchApprovedBilingualCopy() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectRoot
            .appendingPathComponent("pulse", isDirectory: true)
            .appendingPathComponent("Localizable.xcstrings", isDirectory: false)
        let catalog = try JSONDecoder().decode(
            WidgetStringCatalog.self,
            from: Data(contentsOf: catalogURL)
        )
        let approvedCopy: [String: [String: String]] = [
            "settings.widget.style.place.detail": [
                "en": "Night still clings to the grass as morning clears the hill. A small clearing at the center waits for today’s check-in.",
                "zh-Hans": "草尖还留着昨夜，晨光已越过远处的坡。中间那一小处空白，正等今天签到。",
            ],
            "settings.widget.style.orbit.detail": [
                "en": "Toward dawn, the stars recede one by one. One remains on the ring, waiting for today to fall into place.",
                "zh-Hans": "天快亮时，群星一颗颗退远。只有这一颗留在环上，等今天归位。",
            ],
            "settings.widget.style.stack.detail": [
                "en": "The pages lie quietly stacked, each edge holding a trace of light. One imprint, and the day takes on weight.",
                "zh-Hans": "纸页叠得很静，边角各自含着一点光。一枚印落下，今天便有了重量。",
            ],
            "settings.widget.style.bleed.detail": [
                "en": "The sun leans west; shadows count the hours for the silent grass. When green crosses the paper’s edge, the day gains depth.",
                "zh-Hans": "日头一路西斜，影子替沉默的草数着时辰。等绿意越过纸边，这一天便有了深浅。",
            ],
            "settings.widget.style.letter.detail": [
                "en": "A sheet lies open, a few words scattered across it. Somehow, the afternoon stretches on.",
                "zh-Hans": "信纸摊开，字疏疏落落，下午却显得很长。",
            ],
            "settings.widget.style.field.detail": [
                "en": "A sound falls away; its echo widens into silence. The empty field holds its center for today.",
                "zh-Hans": "一声落下，余响一圈圈走远。场子空着，只替今天守住最中心的位置。",
            ],
            "settings.widget.style.path.detail": [
                "en": "A fine path winds in from the hills, carrying days of wind and rain. By the time it reaches today, only your step is missing.",
                "zh-Hans": "一线从远山蜿蜒而来，沿途收下几日风雨。到了今天，它只差你这一步。",
            ],
            "settings.widget.style.tide.detail": [
                "en": "Once the tide has come and gone, light on the sand can tell morning from evening. The day finds its rhythm there.",
                "zh-Hans": "潮水走过一遭，沙上的光便有了早晚，一天也跟着有了节奏。",
            ],
        ]

        for (key, localizedValues) in approvedCopy {
            let entry = try XCTUnwrap(catalog.strings[key], "Missing approved Widget caption: \(key)")
            for (language, approvedValue) in localizedValues {
                XCTAssertEqual(
                    entry.localizations[language]?.stringUnit.value,
                    approvedValue,
                    "Widget caption drifted for \(key) [\(language)]."
                )
            }
        }
    }

    func testPulseSystemUIStringCatalogHasBothSupportedLanguages() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectRoot
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

    func testLiveActivityCopyIsConciseAndUsesCheckInForEveryActionAndState() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectRoot
            .appendingPathComponent("PulseWidgetUI", isDirectory: true)
            .appendingPathComponent("PulseSystemUI.xcstrings", isDirectory: false)
        let catalog = try JSONDecoder().decode(
            WidgetStringCatalog.self,
            from: Data(contentsOf: catalogURL)
        )
        let approvedCopy: [String: [String: String]] = [
            "activity.reminder.title": [
                "en": "Not checked in today",
                "zh-Hans": "今日未签到",
            ],
            "activity.reminder.check_in": [
                "en": "Check in",
                "zh-Hans": "签到",
            ],
            "activity.reminder.completed.title": [
                "en": "Checked in today",
                "zh-Hans": "今日已签到",
            ],
            "store.activity.preview.section": [
                "en": "Lock Screen & Dynamic Island",
                "zh-Hans": "锁屏与灵动岛",
            ],
            "store.activity.preview.expanded": [
                "en": "Expanded",
                "zh-Hans": "展开",
            ],
            "store.activity.preview.compact": [
                "en": "Compact",
                "zh-Hans": "紧凑",
            ],
            "store.activity.preview.minimal": [
                "en": "Minimal",
                "zh-Hans": "最小",
            ],
            "store.activity.preview.completed": [
                "en": "Checked in",
                "zh-Hans": "已签到",
            ],
            "store.activity.preview.lock_screen": [
                "en": "Lock Screen",
                "zh-Hans": "锁屏",
            ],
        ]

        for (key, localizedValues) in approvedCopy {
            let entry = try XCTUnwrap(catalog.strings[key])
            for (language, approvedValue) in localizedValues {
                XCTAssertEqual(
                    entry.localizations[language]?.stringUnit.value,
                    approvedValue,
                    "Live Activity copy drifted for \(key) [\(language)]."
                )
            }
        }

        XCTAssertNil(catalog.strings["activity.reminder.body"])
        XCTAssertNil(catalog.strings["activity.reminder.completed.body"])
        XCTAssertNil(catalog.strings["activity.reminder.completed.compact"])
        XCTAssertNil(catalog.strings["store.activity.preview.detail"])
    }

    func testUserFacingCopyDoesNotExposeDesignOrEngineeringJargon() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURLs = [
            projectRoot
                .appendingPathComponent("pulse", isDirectory: true)
                .appendingPathComponent("Localizable.xcstrings", isDirectory: false),
            projectRoot
                .appendingPathComponent("PulseWidgets", isDirectory: true)
                .appendingPathComponent("Localizable.xcstrings", isDirectory: false),
            projectRoot
                .appendingPathComponent("PulseWidgetUI", isDirectory: true)
                .appendingPathComponent("PulseSystemUI.xcstrings", isDirectory: false),
        ]
        let forbiddenTerms = [
            "大开口日环", "开放日环", "承印坑", "潮唇", "巨大剪影", "蜡封", "邮戳", "七枚日印", "落印",
            "留一印", "已留印", "直接留印", "今天还空着",
            "主承诺", "高阶权益", "小组件构图", "小组件事实", "共享存储", "数据校验",
            "虚构价格", "open seal", "imprint well", "postmarks", "widget facts",
            "leave mark", "leave one mark", "today is marked", "today awaits its mark",
            "today is still open", "today’s mark", "today's mark", "imprinted today",
            "shared store", "advanced benefits", "main commitment", "widget composition", "seven marks",
            "不会在后台", "没有附带", "请勿填写或附带", "人脸身份", "健康推断", "never sent in the background",
            "准备好时", "回来即可", "直接打卡", "come back when you are ready",
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
            [.beforeHabit, .beforeHabit, .beforeHabit, .beforeHabit, .checked, .missed, .todayPending]
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

    func testTimelinePlanContainsAmbientPeriodsAndNextLogicalDay() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let now = makeDate(2026, 8, 11, 8, timeZone: timeZone)
        let repository = try makeRepository(clock: MutableWidgetClock(now: now))
        let initialHabit = try repository.primaryHabit(systemTimeZone: timeZone)
        _ = try repository.updateIdentity(
            habitID: initialHabit.id,
            identity: HabitIdentity(userName: "每天走路", userPurpose: "保持活力")
        )

        let plan = try XCTUnwrap(
            PulseWidgetSnapshotReader.readTimelinePlan(
                repository: repository,
                at: now
            )
        )
        XCTAssertEqual(plan.entries.count, 4)
        XCTAssertEqual(plan.entries.first?.date, now)
        XCTAssertEqual(plan.entries.first?.snapshot.isCheckedToday, false)
        XCTAssertEqual(
            plan.entries.map(\.date),
            [
                now,
                makeDate(2026, 8, 11, 12, timeZone: timeZone),
                makeDate(2026, 8, 11, 18, timeZone: timeZone),
                makeDate(2026, 8, 12, 0, timeZone: timeZone),
            ]
        )
        XCTAssertEqual(
            plan.entries.dropLast().map(\.snapshot.today.storageValue),
            ["2026-08-11", "2026-08-11", "2026-08-11"]
        )
        XCTAssertEqual(plan.entries.last?.date, makeDate(2026, 8, 12, 0, timeZone: timeZone))
        XCTAssertEqual(
            plan.entries.last?.snapshot.today.storageValue,
            "2026-08-12"
        )
    }

    func testAmbientPeriodsResolveFromCentralProjectSchedule() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let start = makeDate(2026, 8, 11, 5, timeZone: timeZone)
        let midnight = makeDate(2026, 8, 12, 0, timeZone: timeZone)

        XCTAssertEqual(
            PulseWidgetAmbientPeriod.resolve(
                at: makeDate(2026, 8, 11, 5, timeZone: timeZone),
                timeZone: timeZone
            ),
            .evening
        )
        XCTAssertEqual(
            PulseWidgetAmbientPeriod.resolve(
                at: makeDate(2026, 8, 11, 6, timeZone: timeZone),
                timeZone: timeZone
            ),
            .morning
        )
        XCTAssertEqual(
            PulseWidgetAmbientPeriod.resolve(
                at: makeDate(2026, 8, 11, 12, timeZone: timeZone),
                timeZone: timeZone
            ),
            .daylight
        )
        XCTAssertEqual(
            PulseWidgetAmbientPeriod.resolve(
                at: makeDate(2026, 8, 11, 18, timeZone: timeZone),
                timeZone: timeZone
            ),
            .evening
        )
        XCTAssertEqual(
            PulseWidgetAmbientPeriod.boundaries(
                after: start,
                before: midnight,
                timeZone: timeZone
            ),
            [
                makeDate(2026, 8, 11, 6, timeZone: timeZone),
                makeDate(2026, 8, 11, 12, timeZone: timeZone),
                makeDate(2026, 8, 11, 18, timeZone: timeZone),
            ]
        )
    }

    func testWidgetMotionSpecificationsRespectSystemLimitAndMaterialIdentity() {
        let materials = PulseWidgetMotionPresentation.Material.allCases

        XCTAssertLessThanOrEqual(
            PulseWidgetDesign.activityAppearanceAnimationDuration,
            PulseWidgetMotionPresentation.systemMaximumAnimationDuration
        )
        XCTAssertLessThanOrEqual(
            PulseWidgetDesign.activityCompletionAnimationDuration,
            PulseWidgetMotionPresentation.systemMaximumAnimationDuration
        )
        XCTAssertLessThanOrEqual(
            PulseWidgetDesign.activityCopyTransitionDuration,
            PulseWidgetMotionPresentation.systemMaximumAnimationDuration
        )
        XCTAssertLessThan(
            PulseWidgetDesign.activityAppearanceAnimationDuration,
            PulseWidgetDesign.activityCompletionAnimationDuration
        )

        XCTAssertEqual(
            PulseWidgetMotionPresentation.completionDuration(for: .starRing),
            1.70,
            accuracy: 0.001
        )

        for material in materials {
            let completionDuration = PulseWidgetMotionPresentation.completionDuration(for: material)
            let ambientDuration = PulseWidgetMotionPresentation.ambientDuration(for: material)
            XCTAssertLessThanOrEqual(
                completionDuration,
                PulseWidgetMotionPresentation.systemMaximumAnimationDuration
            )
            XCTAssertLessThanOrEqual(
                ambientDuration,
                PulseWidgetMotionPresentation.systemMaximumAnimationDuration
            )
            XCTAssertLessThan(
                ambientDuration,
                completionDuration,
                "Ambient changes must settle before the material completion transition."
            )
        }

        let morningPoses = Set(materials.map {
            PulseWidgetMotionPresentation.ambientPose(for: $0, period: .morning)
        })
        XCTAssertEqual(
            morningPoses.count,
            materials.count,
            "Every Widget material needs its own ambient motion grammar."
        )
        XCTAssertGreaterThan(
            PulseWidgetMotionPresentation.galleryAmbientStateHold,
            .milliseconds(960)
        )
        XCTAssertGreaterThan(
            PulseWidgetMotionPresentation.galleryCompletionStateHold,
            .milliseconds(1_900)
        )
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

        let first = try PulseWidgetSharedRuntime.checkIn(
            at: location,
            clock: FixedPulseClock(now: now)
        )
        let second = try PulseWidgetSharedRuntime.checkIn(
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
            try PulseWidgetSharedRuntime.checkIn(
                at: location,
                clock: FixedPulseClock(now: now)
            )
        ) { error in
            guard case PulseWidgetSharedRuntime.RuntimeError.missingPrimaryHabit = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertTrue(try repository.allRecords(
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

    private func swiftSource(in directoryURL: URL) throws -> String {
        try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "swift" }
        .map { try String(contentsOf: $0, encoding: .utf8) }
        .joined(separator: "\n")
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

private func assertActivityColorset(
    named name: String,
    in assetRoot: URL,
    light: String,
    dark: String,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    let url = assetRoot
        .appendingPathComponent("\(name).colorset", isDirectory: true)
        .appendingPathComponent("Contents.json", isDirectory: false)
    let root = try XCTUnwrap(
        JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
        file: file,
        line: line
    )
    let colors = try XCTUnwrap(root["colors"] as? [[String: Any]], file: file, line: line)
    XCTAssertEqual(colors.count, 2, file: file, line: line)

    func components(at index: Int) throws -> [String: String] {
        let color = try XCTUnwrap(
            colors[index]["color"] as? [String: Any],
            file: file,
            line: line
        )
        return try XCTUnwrap(
            color["components"] as? [String: String],
            file: file,
            line: line
        )
    }

    func expected(_ hex: String) -> (red: String, green: String, blue: String) {
        let channels = [1, 3, 5].map { offset -> String in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            let end = hex.index(start, offsetBy: 2)
            let value = Int(hex[start..<end], radix: 16)!
            return String(format: "%.3f", Double(value) / 255.0)
        }
        return (channels[0], channels[1], channels[2])
    }

    let lightComponents = try components(at: 0)
    let darkComponents = try components(at: 1)
    let expectedLight = expected(light)
    let expectedDark = expected(dark)
    XCTAssertEqual(lightComponents["red"], expectedLight.red, file: file, line: line)
    XCTAssertEqual(lightComponents["green"], expectedLight.green, file: file, line: line)
    XCTAssertEqual(lightComponents["blue"], expectedLight.blue, file: file, line: line)
    XCTAssertEqual(darkComponents["red"], expectedDark.red, file: file, line: line)
    XCTAssertEqual(darkComponents["green"], expectedDark.green, file: file, line: line)
    XCTAssertEqual(darkComponents["blue"], expectedDark.blue, file: file, line: line)
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
private final class MutableWidgetClock: PulseClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
