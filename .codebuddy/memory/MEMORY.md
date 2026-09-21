# Pulse 长期记忆

## 界面主题的架构现状（2026-09-21 起）

**核心结论：主题改不动，根因是架构而非美术。** `PulseVisualTheme` 原先唯一能力是提供 9 个 `PulseThemePalette` 颜色槽，布局差异只能靠散落在 6+ 文件的 `switch theme` 硬编码。因此每轮迭代必然只产出"换漆"。主题名（视觉隐喻）会让隐喻只能用装饰贴纸兑现，产出细线条。改名无效——git 历史已证明（Tidal Breath → Tide Archive → Sunlit Day）。

**已建立的能力**：`pulse/Shared/PulseTodayPage.swift` 现在是「事实容器 `PulseTodayFacts` + 分派器 + `legacyComposition`」。主题要自己的布局，就新写一个 `Pulse*TodayPage.swift` 并在分派器接一行；不要往 `legacyComposition` 里加 `switch` 分支。`PulseImmersionTodayPage.swift` 是第一个这么做的。

**做新主题时的硬约束**：
- 不能改名或删除已发布的 `PulseVisualTheme` case（rawValue 是用户设备上的持久化键）。只能新增。
- 新增 case 后必须同步：`brand-tokens.json` + `build_brand_assets.py` 的 `COLOR_ASSETS`（两边 key 集合必须完全一致，脚本会校验）、`PulseDesignSystem` 的 palette/appSuccess、`PulseCalendarDayStyle`、`HistoryView`（3 处）、`JournalNoteViews`（2 处）、`EnhancementStoreView`（hero）。
- 颜色资产由 `python3 scripts/build_brand_assets.py` 生成，需要 Pillow。
- 保留的 UI 测试标识符：`today.checkin.button`、`today.week.rail`、`today.rhythm.status`、`today.commitment.name`、`today.hero.kicker`、`today.week.day.<x>`、`today.media.capture.button`。签到控件的可达性由 `TodayView` 的 overlay 提供，`PulseCheckInFace` 本身 `accessibilityHidden`，所以重画它不影响测试。

## 用户偏好

- 直接、不迎合。要第一性原理 + 对抗式审查。反对过度设计和防御式编程。
- 长任务可用子智能体。
- 判断设计好坏的标准是"看了想不想付费/有没有态度"，不是"是否符合主题名"。
