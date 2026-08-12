# Pulse 项目合同与证据路由

先确认文档的责任边界，避免把路线图、旧方向、当前实现说明和正式合同混成一份真源。

## 每次必读

从技能目录到仓库根目录为 `../../..`。每次审阅至少读取：

- `../../../docs/RELEASE_SCOPE_1_1.md`：1.1 正式范围与发布门禁。
- `../../../docs/IMPLEMENTATION_STATUS.md`：当前实现和已经取得/尚未取得的证据；它是状态报告，不覆盖正式合同。
- `../../../design/BRAND_SPEC.md`：1.1 App、AppIcon 与商店素材的冻结视觉合同。
- `../../../pulse/Shared/PulseDesignSystem.swift`：运行时视觉与动效令牌消费者。
- 本次目标对应的正式 SwiftUI view、字符串资源与 UI 测试。

不要只读文档。将合同、正式实现与运行证据三者对照；任一缺失都明确标记。

## 按问题类型读取

| 问题 | 权威来源 |
| --- | --- |
| 日期、签到、统计、删除、导入与事实语义 | `../../../docs/DOMAIN_CONTRACT.md` |
| 产品任务、用户、P0 功能和非功能要求 | `../../../docs/PRODUCT_REQUIREMENTS.md` |
| 1.1 范围、明确排除项和上线门禁 | `../../../docs/RELEASE_SCOPE_1_1.md` |
| 1.1 App 视觉、导航、布局、颜色、AppIcon | `../../../design/BRAND_SPEC.md` |
| 正式颜色值与外观变体 | `../../../design/brand-tokens.json` |
| App 内基础落印与未来系统仪式的状态/时序 | `../../../docs/PULSE_RITUAL_CONTRACT.md` |
| 未来版本先后关系 | `../../../docs/PRODUCT_ROADMAP.md` |
| 当前完成度、验证环境和独立 NO-GO | `../../../docs/IMPLEMENTATION_STATUS.md` |
| SwiftUI 架构、依赖与状态所有权 | `../../../docs/TECHNICAL_DESIGN.md` |
| 自动化与人工验收矩阵 | `../../../docs/TEST_PLAN.md` |

## 合同冲突处理

这些来源按各自责任域生效，不建立一个粗暴的全局优先级：

- 业务事实只由 `DOMAIN_CONTRACT.md` 决定；界面和动画只能投影事实。
- 1.1 范围只由 `RELEASE_SCOPE_1_1.md` 决定；路线图和仪式愿景不能把未来能力提前变成当前功能。
- 当前 1.1 App 视觉以 `design/BRAND_SPEC.md` 为准。该合同已经明确禁用旧黑白单色系统。
- `PULSE_RITUAL_CONTRACT.md` 控制仪式状态、时序、系统表面和未来体验语义，但不能覆盖 1.0 App 的冻结品牌方向。
- 若 `PULSE_RITUAL_CONTRACT.md` 与草野脉冲品牌冲突，以修复合同为前置，不把新旧视觉混成运行时分支。
- `IMPLEMENTATION_STATUS.md` 只说明当前证据，不把尚未实现或尚未人工验收的事项变成 GO。

## 当前范围边界

1.1 正式 App 包括主承诺、今日签到、今日入镜、有限落印、最近七日、历史/月历/统计、设置、本地提醒、含媒体加密归档、主题、双语、Dynamic Type、VoiceOver、iPhone/iPad 与 AppIcon。

以下能力即使已有设计，也不能作为 1.1 已实现体验审阅：岁月流影生成、面貌分析、Apple Watch、账号、云同步和多项目。基础 Widget 与今日入镜已进入 1.1，但仍必须分开报告设计、工程、系统表面和真机门禁；缺少真实相机/设备证据时不能给 `INTERFACE GO` 或 `EXPERIENCE GO`。

## 实现与运行证据

按目标读取真实消费者：

- 今日与落印：`../../../pulse/Features/Today/TodayView.swift`、`ImprintRitualPhase.swift`。
- 历史、月历与详情：`../../../pulse/Features/History/HistoryView.swift`。
- 主导航与根转场：`../../../pulse/Shared/PulsePrimaryNavigation.swift`、`../../../pulse/App/RootView.swift`。
- 设置与主承诺：`../../../pulse/Features/Settings/SettingsView.swift`、`../../../pulse/Features/Commitment/CommitmentIdentityEditor.swift`。
- 颜色、几何、字体和动效参数：`../../../pulse/Shared/PulseDesignSystem.swift`、`../../../design/brand-tokens.json`。
- UI 自动化和现有截图入口：`../../../pulseUITests/PulseFlowUITests.swift`。

运行视觉证据优先使用正式 App、正式字符串、固定业务时间和可复现状态。截图只能审静态界面；动效、触觉、导航、滚动、错误恢复和焦点顺序需要录屏、事件或人工证据。
