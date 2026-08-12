# Pulse 实现与验收状态

更新时间：2026-08-12
当前工程结论：**GO（提交 `cabde80`、iOS 18.6 Simulator、Release 构建与静态分析）**。
当前候选结论：**RELEASE CANDIDATE GO**。正式 Archive 与 App Store Connect IPA 已生成并核验。
当前公开发布结论：**NO-GO**。App Store Connect 上传/处理、TestFlight 安装回归和商店版本提交尚未执行。

## 当前唯一生产基线

- 最低部署版本统一为 iOS / iPadOS 18.0；App、Widget、单元测试与 UI 测试 target 不再保留 17.x 分支。
- `CheckInRecord` 是签到事实唯一来源；`SwiftDataCheckInRepository` 独占 SwiftData 写入，页面与 Widget 只消费不可变快照。
- SwiftData 只有 `PulseSchema` 1.0.0；正式 store 只有 App Group 容器下 `Library/Application Support/Pulse/Pulse.store`。
- App 负责以本地化 `HabitIdentity` 创建缺失的主承诺；Widget 使用 `existingStoreOnly`，既不创建默认项目，也不在 App 首次打开前创建空 store。
- JSON 合同只有 `co.fanr.pulse.export` v1；导入必须精确匹配格式与版本，未知、缺失或旧开发载荷失败关闭。
- App Group `PulseSharedInterfacePreferences.interface.language` 是 App 与 Widget 内容语言唯一持久化状态；`AppSettings.language` 只是 App 侧可观察投影，不写 `AppleLanguages`，不要求重启，也不在 Widget 另存副本。
- 二级页面统一使用代码原生、可本地化的返回入口；简体中文历史标题为 `记录 / 年月`，英文设置与返回入口不混入中文界面文案。
- Widget 只读取同一 App Group SwiftData 事实；界面语言与样式统一由 `PulseSharedInterfacePreferences` 读取，仅保存不含业务事实的 `interface.language` 与 `widget.style`。
- Widget 运行内容、日期和辅助功能描述使用同一个显式 `Locale`；Widget Gallery、配置页和 AppIntent 的系统托管静态元数据仍遵循 iOS 的语言环境，不伪装成可被 App 内偏好动态改写。
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
- 删除 App 私有 `settings.language`、旧 `AppLanguage` 与旧 Widget 样式偏好类型，改为 PulseCore 内一个 App Group 强类型偏好入口；未知语言或样式值失败关闭，不猜测、不兼容旧开发值。
- 删除 Widget 固定 `MM / DD`、ISO 日期辅助功能读法、隐式当前语言格式化，以及未翻译或无生产消费者的 String Catalog 键；日期、月份、数字和完整日期辅助功能文本全部由显式 `Locale` 生成。
- App 语言切换在写入共享偏好后只刷新一次 Widget timeline；主承诺名称属于用户内容，保持原文，不被界面本地化错误翻译。
- 删除 AppSettings 的隐式共享偏好测试/调用捷径和启动恢复里的 `try?`；所有调用必须显式提供同一个共享偏好对象，共享设置不可访问时显示独立启动错误，不再静默跳过或误报为数据存储故障。

这是一次**上线前 clean break**，不是上线后迁移：旧开发安装、旧 SQLite store 和旧 JSON 样本不属于受支持的生产输入。开发设备与模拟器应全新安装，测试数据应使用当前 v1 合同重新生成。首个公开版本发布后，当前 schema/store/JSON 才成为必须迁移的生产基线，届时不得沿用本轮删除策略。

## 自动化与构建证据

当前验证环境：Xcode 26.4（17E192），iPhone 16 Pro，iOS 18.6 Simulator，arm64。

- 最终 `xcodebuild test`：101/101 通过，0 失败、0 跳过；其中单元/集成测试 87 项，UI 测试 14 项。
- Debug Simulator 构建：通过；Swift 编译告警按错误处理。
- Release `generic/platform=iOS` 无签名构建：通过；证明 Release 源码与链接可成立，不等于可分发 Archive。
- Release 静态分析：通过。
- 品牌资产生成检查：18 项与生成器一致。
- App、InfoPlist 与 Widget String Catalog：JSON 解析通过，全部键均有非空 English / 简体中文值；Widget 另有生产消费者回归门禁。
- 根仓库 `site` submodule：来源已声明，当前指针可解析且子仓库干净。
- 提交 `cabde80` 已位于 `main` 与 `origin/main`；正式 Archive 生成成功。
- App Store Connect 导出成功：App 与 Widget 均使用 Cloud Managed Apple Distribution 和 Store profile，`get-task-allow=false`、`beta-reports-active=true`，嵌套签名严格校验通过。
- 导出 IPA SHA-256：`729ad834049ade944c02e03af22a82b705f5896a2439d86ecc82f16de0f673696`；完整证据见 [Pulse 1.0 (1) 发布候选证据](./RELEASE_CANDIDATE_1_0_1.md)。
- 产品负责人于 2026-08-12 确认真机与其余人工验收无问题；该确认作为人工验收来源记录，不伪造成设备日志或自动化证据。
- 产品、隐私和支持页面在候选生成时均返回 HTTPS 200。

UI 运行证据另行人工检查了四张截图：

- English + Dark 设置页：导航标题、设置项和返回辅助功能标签均为英文；未发现中文界面文案。主承诺名称仍为用户内容，不应随界面语言被翻译。
- 简体中文历史页：标题为 `记录 / 2026、八月`，未出现 `ARCHIVE`。
- iPadOS 18.6 Home Screen English：中号与小号 Widget 的品牌标签、月份和状态同步切换为 `Imprint`、`August`、`Still open`；用户主承诺 `每日签到` 保持原文。
- iPadOS 18.6 Home Screen 简体中文：同一组 Widget 同步切换为 `印记`、`八月`、`今天还空着`，日期事实与构图未改变。

上述截图只关闭本轮 App 语言、二级导航和 iPad Home Screen 小/中号 Widget 运行内容的中英文缺陷，不能外推为全部 Widget 系统表面、真人 VoiceOver 或真实设备视觉验收。

## 分层结论

- **工程 GO**：当前 checkout 的单一 schema/store/JSON、Repository 写入边界、App/Widget provisioning 边界、共享界面偏好、显式 Locale、iOS 18 部署目标、全量测试、Release 构建、静态分析和资源生成门禁已成立。
- **界面候选 GO**：限 English 设置页、简体中文历史标题，以及 iPadOS 18.6 Home Screen 小/中号 Widget 的 English / 简体中文运行内容；主承诺原文保留符合用户内容边界。
- **人工产品验收 GO**：产品负责人确认真机及其余人工验收无问题；仓库只记录该验收来源，不补造设备型号、OS 或截图细节。
- **最低系统 ACCEPTED BY OWNER**：工程目标为 18.0，产品负责人确认其余验收无问题；当前自动化机器证据仍来自 18.6 Simulator。
- **视觉与可访问性 ACCEPTED BY OWNER**：产品负责人确认相关人工验收无问题；自动化与此前截图证据范围保持原样。
- **Archive / Apple Distribution GO**：正式 Archive 与 App Store Connect IPA 已成功生成并完成身份、权限、隐私清单、dSYM 和签名核验。
- **外部分发 NO-GO**：IPA 尚未上传 App Store Connect，尚无 Apple 处理结果、TestFlight 安装/升级/恢复记录和商店版本提交结果。

## 下一步顺序

1. 经产品负责人明确授权，将候选 `pulse.ipa` 上传 App Store Connect；上传前确认 `1.0 (1)` 尚未被占用。
2. 等待 Apple 处理完成并关闭构建警告、出口合规与隐私提示。
3. 分配 TestFlight 内部测试，验证安装、升级、JSON 导出/恢复和 Widget 数据连续性。
4. 完成并复核商店文案、截图、年龄分级、App Privacy、审核联系信息和版本提交。
5. 只有 Apple 处理、TestFlight 与商店提交门禁全部通过后，才把公开发布结论改为 GO。
