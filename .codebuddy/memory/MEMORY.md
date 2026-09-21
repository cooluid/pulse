# Pulse 长期记忆

## 界面主题的架构现状（2026-09-21 起）

**核心结论：主题改不动，根因是架构而非美术。** `PulseVisualTheme` 原先唯一能力是提供 9 个 `PulseThemePalette` 颜色槽，布局差异只能靠散落在 6+ 文件的 `switch theme` 硬编码。因此每轮迭代必然只产出"换漆"。主题名（视觉隐喻）会让隐喻只能用装饰贴纸兑现，产出细线条。改名无效——git 历史已证明（Tidal Breath → Tide Archive → Sunlit Day）。

**已建立的能力**：`pulse/Shared/PulseTodayPage.swift` 现在是「事实容器 `PulseTodayFacts` + 分派器 + `legacyComposition`」。主题要自己的布局，就新写一个 `Pulse*TodayPage.swift` 并在分派器接一行；不要往 `legacyComposition` 里加 `switch` 分支。

**当前阵容与骨架状态（2026-09-21）**：

| 主题 | 骨架 | 结构主张 |
| --- | --- | --- |
| `editorialJournal`（免费） | legacy | 纸页 + 印章（未重做） |
| `quietField` | legacy | 卡片 + 叶形（未重做） |
| `sunlitDay` | legacy | 日历感（未重做） |
| `prismLedger` | **已重做** `PulsePrismLedgerTodayPage.swift` | 并排读数格 + 直角签到条 + 等大方块周条（状态靠填充） |
| `immersion` | **已重做** `PulseImmersionTodayPage.swift` | 纵向：176pt 大日号（在 `PulseThemeBackdrop`）+ 全宽实色签到面 + 连续起伏周带 |
| ~~`moonTide`~~ | 已删除 | — |

三套（含已删月汐）的结构区分思路：**纵向大数字** vs **并排读数格** vs **居中留白**。不要靠颜色或装饰区分。

**做新主题时的硬约束**：
- **主题数量不能减少**。`store.capability.themes.title`（"四套额外界面主题"）、`store.hero.promise`、`store.hero.tagline` 都已公开点名静野/晴昼/月汐/棱镜刻度，随 `1.1 (9)` 发布。减套数等于改已公开的商业承诺。
- 可以删 `PulseVisualTheme` case 或改显示名，但**前提是 `AppSettings.init` 对未知 rawValue 回退而不是抛错**。2026-09-21 已把 `loadedVisualTheme` 从 `throw PulseAppError.invalidSettings` 改成回退 `freeTheme`（`testRetiredThemeFallsBackToTheFreeThemeInsteadOfFailingTheLoad` 守住）。旧 rawValue 会静默落到免费主题，不会再有 failed 启动页。
- **改主题阵容必须同步商店文案四处**：`store.capability.themes.title`（"四套额外界面主题"）、`store.capability.themes.detail`、`store.hero.promise`、`store.hero.tagline`。它们点名了主题名，数量和名字都要与实现一致。
- 退役主题的清理面：`Pulse*TodayPage.swift`、`PulseThemeBackdrop`/`PulseFieldBackground` 的分支、`PulseCheckInFace` 的 artwork 分支、`PulseDesign` 的 palette/appSuccess、`PulseCalendarDayStyle`、`HistoryView`(3 处)、`JournalNoteViews`(6 处)、`EnhancementStoreView`(3 处)、`PulseThemeAppearance`、UI 测试里的主题数组。`moon*` 颜色令牌保留未删（设计资产，删要同步 tokens + 脚本）。
- 新增 case 后必须同步：`brand-tokens.json` + `build_brand_assets.py` 的 `COLOR_ASSETS`（两边 key 集合必须完全一致，脚本会校验）、`PulseDesignSystem` 的 palette/appSuccess、`PulseCalendarDayStyle`、`HistoryView`（3 处）、`JournalNoteViews`（2 处）、`EnhancementStoreView`（hero）。
- **主题不能靠背景图**。用一张照片（或任何位图）当主题表面是"换壁纸"，不是设计：图片不吃 Dynamic Type、深浅色、提高对比度，也无法和内容发生关系。2026-09-21 用户明确否掉了 moonTide 的海面照片方案。主题必须由版式、比例、字重、色彩层次承载。
- **主视觉不要放进 `ScrollView`**。内容滚到顶部会被硬切（日号被裁成平头、照片底边跑到屏幕中间），加渐变治标不治本。正确做法：固定的东西放 `pulse/Shared/PulseThemeBackdrop.swift`（日期行 + 装饰性主视觉）或 `PulseFieldBackground`（全屏色场），内容侧只留 `Color.clear.frame(height:)` 占位。当前：沉浸的日期+日号在 backdrop，月汐的日期在 backdrop、光场在 `PulseFieldBackground`。日期行（`today.hero.kicker`）要保持可达，装饰性数字才 `accessibilityHidden`。
- 颜色资产由 `python3 scripts/build_brand_assets.py` 生成，需要 Pillow。
- 保留的 UI 测试标识符：`today.checkin.button`、`today.week.rail`、`today.rhythm.status`、`today.commitment.name`、`today.hero.kicker`、`today.week.day.<x>`、`today.media.capture.button`。签到控件的可达性由 `TodayView` 的 overlay 提供，`PulseCheckInFace` 本身 `accessibilityHidden`，所以重画它不影响测试。

## 用户偏好

- 直接、不迎合。要第一性原理 + 对抗式审查。反对过度设计和防御式编程。
- 长任务可用子智能体。
- 判断设计好坏的标准是"看了想不想付费/有没有态度"，不是"是否符合主题名"。
