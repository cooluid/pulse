# Pulse 实现与验收状态

更新时间：2026-08-12
当前工程结论：**GO（限当前源码、iOS 18.6 Simulator、无签名 Release 构建与静态分析）**。
当前发布结论：**NO-GO**。真实设备、最低系统、完整系统表面、Apple Distribution、Archive、TestFlight 与 App Store 门禁尚未关闭。

## 当前唯一生产基线

- 最低部署版本统一为 iOS / iPadOS 18.0；App、Widget、单元测试与 UI 测试 target 不再保留 17.x 分支。
- `CheckInRecord` 是签到事实唯一来源；`SwiftDataCheckInRepository` 独占 SwiftData 写入，页面与 Widget 只消费不可变快照。
- SwiftData 只有 `PulseSchema` 1.0.0；正式 store 只有 App Group 容器下 `Library/Application Support/Pulse/Pulse.store`。
- App 负责以本地化 `HabitIdentity` 创建缺失的主承诺；Widget 使用 `existingStoreOnly`，既不创建默认项目，也不在 App 首次打开前创建空 store。
- JSON 合同只有 `co.fanr.pulse.export` v1；导入必须精确匹配格式与版本，未知、缺失或旧开发载荷失败关闭。
- `AppSettings.language` 是 App 内语言唯一状态；不写 `AppleLanguages`，不要求重启，不保存第二份运行时语言状态。
- 二级页面统一使用代码原生、可本地化的返回入口；简体中文历史标题为 `记录 / 年月`，英文设置与返回入口不混入中文界面文案。
- Widget 只读取同一 App Group SwiftData 事实；样式偏好仍只保存不含业务事实的 `widget.style`。
- 网站由根仓库声明的 `site` Git submodule 提供，仓库不再处于“gitlink 存在但无 `.gitmodules` 来源合同”的不完整状态。

领域规则以 [领域合同](./DOMAIN_CONTRACT.md)、[技术设计](./TECHNICAL_DESIGN.md)、[Widget 共享 Store 合同](./WIDGET_SHARED_STORE_CONTRACT.md) 和 [测试计划](./TEST_PLAN.md) 为准。

## 本轮清理与重构

- 删除 `PulseSchemaV1` / `PulseSchemaV2` / `PulseMigrationPlan`，以及对应旧 schema 迁移测试。
- 删除 `PulseSharedStoreBootstrapper`、`PulseSharedStoreMigrator`、journal、staging、私有 Application Support 迁移源和相关测试。
- 删除 App 私有 store fallback；App Group 定位或 store 打开失败时直接报告真实错误。
- 删除 JSON v1→v2 双模型与升级路径；当前只读写一个 v1 正式合同。
- 删除 Widget 内硬编码的默认主承诺名称 `Pulse`；缺失主承诺是明确错误，而不是静默补值。
- 删除 Widget 读取时创建主承诺的副作用，并新增 `existingStoreOnly` 回归测试。
- 清理文档中 iOS 17、JSON v2、SwiftData V1/V2、旧私有 store 迁移和旧 journal 的现役表述。
- 修复语言切换后系统返回按钮仍沿用启动语言、中文历史标题混入 `ARCHIVE` 的界面合同问题；新增跨重启与中文历史 UI 回归断言。

这是一次**上线前 clean break**，不是上线后迁移：旧开发安装、旧 SQLite store 和旧 JSON 样本不属于受支持的生产输入。开发设备与模拟器应全新安装，测试数据应使用当前 v1 合同重新生成。首个公开版本发布后，当前 schema/store/JSON 才成为必须迁移的生产基线，届时不得沿用本轮删除策略。

## 自动化与构建证据

当前验证环境：Xcode 26.4（17E192），iPhone 16 Pro，iOS 18.6 Simulator，arm64。

- 最终 `xcodebuild test`：99/99 通过，0 失败、0 跳过；其中单元/集成测试 85 项，UI 测试 14 项。
- Debug Simulator 构建：通过；Swift 编译告警按错误处理。
- Release `generic/platform=iOS` 无签名构建：通过；证明 Release 源码与链接可成立，不等于可分发 Archive。
- Release 静态分析：通过。
- 品牌资产生成检查：18 项与生成器一致。
- String Catalog JSON：解析通过。
- 根仓库 `site` submodule：来源已声明，当前指针可解析且子仓库干净。

UI 运行证据另行人工检查了两张测试截图：

- English + Dark 设置页：导航标题、设置项和返回辅助功能标签均为英文；未发现中文界面文案。主承诺名称仍为用户内容，不应随界面语言被翻译。
- 简体中文历史页：标题为 `记录 / 2026、八月`，未出现 `ARCHIVE`。

上述截图只关闭本轮语言与二级导航缺陷，不能外推为全 App、Widget 或真实设备视觉验收。

## 分层结论

- **工程 GO**：当前 checkout 的单一 schema/store/JSON、Repository 写入边界、App/Widget provisioning 边界、iOS 18 部署目标、全量测试、Release 构建、静态分析和资源生成门禁已成立。
- **界面候选 GO**：仅限本轮 English 设置页返回入口与简体中文历史标题，且证据来自 iOS 18.6 iPhone Simulator。
- **真实设备 NO-GO**：尚未在全新安装的真实 iPhone / iPad 上验证 App 首开建库、Widget 先于 App、App/Widget 同日竞争、杀进程重启、跨时区、通知和清除恢复。
- **最低系统 NO-GO**：部署目标已提高到 18.0，但尚未在 iOS / iPadOS 18.0 设备或 Simulator 运行。
- **完整视觉与可访问性 NO-GO**：当前 Widget 改版仍需 Home / Lock Screen / StandBy / Always-On、深浅色、accented/vibrant、最大动态字体、VoiceOver、Reduce Motion、降低透明度与 iPad 分屏证据。
- **分发 NO-GO**：无 Apple Distribution、正式 Archive、TestFlight、App Store Connect 校验和商店材料验收证据。

## 下一步顺序

1. 在真实 iPhone 与 iPad 做当前基线的全新安装，先验证 App 首开建库、Widget 先于 App 不建空库，以及 App/Widget 同日竞争的唯一事实结果。
2. 在最低支持版本 iOS / iPadOS 18.0 重跑核心签到、历史、设置语言、通知、App Group 与 Widget 门禁。
3. 完成真实设备上的通知异常、跨时区、清除恢复、动态字体、VoiceOver、Reduce Motion 和全部 Widget 系统表面验收。
4. 对当前 AppIcon、商店截图、隐私/支持页面和网站 submodule 对应部署版本做最终内容验收。
5. 建立 Apple Distribution，生成并检查 Archive，经 TestFlight 实装回归后再作上线 GO 决策。
