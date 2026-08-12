# Pulse 实现与验收状态

更新时间：2026-08-12
当前 checkout 结论：**BUILD 3 ENGINEERING GO / DISTRIBUTION NO-GO**。本轮源码已加入一次买断提醒增强、iOS 26 本地 scheduled Live Activity 与 iOS 18–25 通知通道；当前自动化、Release 无签名构建、静态分析和源文件检查通过，但尚未形成不可变提交、正式 Archive、Sandbox/TestFlight 购买或真机灵动岛证据。
历史 Build 2 结论：**INTERNAL TESTFLIGHT CORE HUMAN GO / READY TO SUBMIT（只对 Build 2 有效）**。正式 Archive 与 IPA 已从干净提交生成、核验并上传，Apple Delivery UUID 为 `0373b760-05e0-4299-bb50-6bd6ec3d2959`；App Store Connect 已显示 `Ready to Submit`、`Expires in 90 days`。产品负责人随后确认内部 TestFlight 的 Build 2 核心流程通过；该构建不包含本轮 StoreKit / ActivityKit 能力，证据不得外推到 Build 3。
当前公开发布结论：**NO-GO**。Build 3 仍缺 App Store Connect 正式商品、签名 Archive、Sandbox/TestFlight 购买恢复、iOS 26 真机 scheduled Activity / Dynamic Island、iOS 18–25 通知回退、无障碍与系统压力矩阵，也未提交 App Store Review。

Build 1 的上传证据保留在 [Pulse 1.0 (1) 发布候选证据](./RELEASE_CANDIDATE_1_0_1.md)，但该构建不包含当前加密合同，已被 Build 2 工程基线取代，不得继续作为下一轮测试或发布候选。

## Build 3 提醒增强受控变更

- App 与 Widget 统一递增为 `1.0 (3)`；Build 2 的 Archive、IPA、签名、上传和人工结论保持不可变历史，不冒充 Build 3 证据。
- 唯一非消耗型商品 ID 为 `co.fanr.pulse.reminder.lifetime`。`FeatureAccessController` 只消费 StoreKit 2 验证后的当前 entitlement 与交易更新；不保存 `isPro`、价格或购买状态副本。
- `FeatureAccessPolicy` 是唯一通道裁决：未购买关闭；已购买且 iOS 26 允许 Live Activities 时使用本地 scheduled transient Live Activity；已购买 iOS 18–25 或 iOS 26 关闭 Live Activities 时使用本地通知。
- `ReminderScheduler` 每次协调先取消 Pulse 的旧通知与旧 Activity，再只安排一个通道。iOS 26 滚动最多 7 个 scheduled Activity，系统容量不足时保留已接受前缀；第一个请求失败则失败关闭。通知通道保留 60 日计划。
- Widget extension 提供 Lock Screen、Dynamic Island Compact / Minimal / Expanded 视图，统一深链到 `pulse://today`；Activity 不保存签到事实，也不显示主承诺正文。`NSSupportsLiveActivities=true` 已进入 App 产物。
- StoreKit Configuration 提供本地开发商品；其中测试价格只用于本地 fixture，不是生产定价。当前 Xcode 26.4 的 `StoreKitTest` framework 导入会在“警告即错误”门禁下暴露 SDK 自身弃用警告，因此没有降低项目门禁；购买状态机使用注入 client 自动化，Sandbox/TestFlight/生产仍保持独立 NO-GO。
- 设置页未购买时只提供单一买断入口与恢复购买；已购买后才出现提醒开关/时间。商品展示名称与价格取 StoreKit 本地化返回值，版本通道说明来自 App String Catalog；加载失败、待处理、无可恢复购买和验证失败均有诚实状态。
- 公开支持/隐私站点源文件已同步新的本地 ActivityKit、通知和 App Store 处理边界；本轮未执行线上部署。

## 当前唯一生产基线

- 最低部署版本统一为 iOS / iPadOS 18.0；App、Widget、单元测试与 UI 测试 target 不保留 17.x 分支。
- `CheckInRecord` 是签到事实唯一来源；`SwiftDataCheckInRepository` 独占 SwiftData 写入，页面与 Widget 只消费不可变快照。
- SwiftData 只有 `PulseSchema` 1.0.0；正式 store 只有 App Group 容器下 `Library/Application Support/Pulse/Pulse.store`。
- App 与 Widget 的默认 Data Protection entitlement 统一为 `NSFileProtectionCompleteUntilFirstUserAuthentication`；store 目录、SQLite 主文件和 sidecar 在打开前后都由同一保护入口校验并设置。
- 正式外部备份格式只有 `co.fanr.pulse.backup` v1，扩展名只有 `.pulsebackup`；旧明文 JSON 不再是可导入、可导出或可兼容的产品格式。
- 备份使用 PBKDF2-HMAC-SHA256（600,000 次）派生 AES-256 密钥，再以 AES-256-GCM 加密并认证容器头、盐、nonce 和载荷；任一字节被篡改、密码错误、版本未知或长度异常都失败关闭。
- 密码只在一次加密/解密操作的内存生命周期内存在；App 不保存、不上传、不可恢复密码，也不存在空密码、设备密钥或明文 fallback。
- 备份恢复会先完成容器认证、解密、payload 版本检查和领域校验，再显示全量替换确认；失败不会修改正式 store。
- 加密备份与恢复属于用户数据可携带权，首版免费，未来不得由 StoreKit / Plus 权益门禁包围。
- App Group `PulseSharedInterfacePreferences.interface.language` 是 App 与 Widget 内容语言唯一持久化状态；加密备份界面和错误已提供 English / 简体中文本地化。
- Widget 只读取同一 App Group SwiftData 事实，不另建业务状态副本，也不获得第二条数据写入路径。

权威合同为 [数据加密合同](./DATA_ENCRYPTION_CONTRACT.md)、[领域合同](./DOMAIN_CONTRACT.md)、[技术设计](./TECHNICAL_DESIGN.md)、[Widget 共享 Store 合同](./WIDGET_SHARED_STORE_CONTRACT.md) 和 [测试计划](./TEST_PLAN.md)。

## 本轮 clean break

- 删除 `PulseExportContract`、`PulseExportDocument`、`PulseExportPayload`、`co.fanr.pulse.export` 和对应明文 JSON 测试入口。
- 建立一个 `PulseBackupContract` / `PulseEncryptedBackupCodec` / `PulseBackupDocument` 正式路径，不保留双格式、旧格式探测、自动升级或兼容读取。
- App 与 Widget 同步递增为 `1.0 (2)`；导出配置禁止 Xcode 静默修改版本号。
- 设置页统一为一个强类型密码 sheet 状态，避免多个 `.sheet` 竞争；导出要求二次确认，恢复只要求一次密码。
- 密码输入使用安全字段、明确标签和不可找回说明；不匹配、提交、取消或失败后清除敏感输入。
- PBKDF2、加密和解密在高优先级后台任务执行，避免阻塞主线程；进度显示有统一延迟策略，避免快速操作闪烁。
- `ITSAppUsesNonExemptEncryption=false` 同步进入 App 与 Widget 产物；当前只调用 Apple 平台内置加密能力，不提交自研/第三方密码模块。

这是上线前 clean break。Build 1 和旧开发样本不是当前生产输入；首个公开版本发布后，当前 schema、store 和 `.pulsebackup` v1 才成为必须迁移的生产基线，届时不得继续采用删除式升级。

## 自动化与构建证据

验证环境：Xcode 26.4（17E192）；全量测试使用 iPhone 16 Pro / iOS 18.6 Simulator，提醒增强定向测试使用 iPhone 17 Pro / iOS 26.4 Simulator，均为 arm64。

- 全量 `xcodebuild test`：124/124 通过，0 失败；其中单元/集成 108 项，UI 16 项。
- iOS 26.4 定向测试：13/13 通过，覆盖 StoreKit entitlement / 购买恢复状态机、版本与能力通道裁决、scheduled Activity 七日滚动预算、容量不足保留已接受前缀和首请求失败关闭。
- 加密测试覆盖 PBKDF2 官方向量、随机盐/nonce、往返、明文泄露检查、错误密码、头/盐/密文/tag 篡改、截断、尾随数据、未知算法/版本、敌意长度、Unicode 精确性和 32 MiB 输入上限。
- UI 自动化覆盖加密导出的产品级密码规则、二次确认和不匹配错误，以及未购买入口与购买后提醒解锁；运行截图已人工检查。购买截图只属于 Simulator **INTERFACE CANDIDATE**，不是 StoreKit Sandbox 或真机系统表面证据。
- Debug Simulator 构建、Release `generic/platform=iOS` 构建、Release 静态分析均通过；Swift 编译警告按错误处理。
- 18 项品牌资产生成检查通过；App、InfoPlist 与 Widget String Catalog 均可解析且所有生产键具有 English / 简体中文值。
- Build 3 公开站点源文件的 lint 与 3/3 测试通过；新提醒边界尚未部署。干净提交、线上 HTTP 证据和正式分发产物仍只属于 Build 2 历史，不能外推到 Build 3。

## Build 2 分发产物证据

完整记录见 [Pulse 1.0 (2) 发布候选与 TestFlight 交付证据](./RELEASE_CANDIDATE_1_0_2.md)。

- 证据根目录：`/Users/fanr/Documents/work/pulse-release-artifacts/Pulse-1.0.2-17f2ef44-formal`。
- 签名 Archive：`Pulse-1.0.2-17f2ef44.xcarchive`。
- App Store Connect IPA：`AppStoreExport/pulse.ipa`。
- IPA SHA-256：`7944287f128bcd8a64ae6bff077c3ddac6701861ea95e702fe43fde93dc1e6cc`。
- App 与 Widget 均由 Cloud Managed Apple Distribution 重签名，Store profile 有效至 2027-08-12。
- App 与 Widget 均为 `get-task-allow=false`、`beta-reports-active=true`，且都包含 `NSFileProtectionCompleteUntilFirstUserAuthentication` 和唯一 App Group `group.co.fanr.pulse`。
- App 与 Widget 均为 `1.0 (2)`、arm64、最低 iOS 18.0；嵌套签名严格校验通过。
- App / Widget 二进制 UUID 分别与对应 dSYM 一致，两个 dSYM 均通过结构校验；隐私清单与源码 SHA-256 一致。
- App 与 Widget 的 `ITSAppUsesNonExemptEncryption` 均为 `false`；App 只声明 `.pulsebackup` / `co.fanr.pulse.backup` 正式文档类型。
- Xcode 上传成功，Apple Delivery UUID 为 `0373b760-05e0-4299-bb50-6bd6ec3d2959`；App Store Connect 随后显示 `Ready to Submit`、`Expires in 90 days`。

## 设计与人工证据边界

- 加密密码 sheet 的简体中文、Dark、iPhone 16 Pro、iOS 18.6 Simulator 状态为 **INTERFACE / EXPERIENCE CANDIDATE**：信息层级、显式标签、不可找回说明、错误状态和清理行为成立。
- 产品负责人于 2026-08-12 确认内部 TestFlight Build 2 的 English / 简体中文、Light / Dark、iPhone / iPad 基本布局、文件导出器、错误密码失败关闭及清除后完整恢复均通过，记为范围受限的 **HUMAN GO**。
- 本次人工证据没有设备型号、精确 OS、截图或逐项日志，不得外推到最大动态字体、真人 VoiceOver、最旧 iOS 18.x、篡改文件真机导入、通知和完整 Widget 压力矩阵。

## 分层结论

- **工程 GO**：当前 checkout 的单一事实源、加密格式、失败语义、Data Protection、内购边界、全量测试、Release 构建和静态分析成立。
- **安全实现 GO**：在已定义威胁模型内，设备内文件保护与口令加密备份已落地；不宣称防越狱、运行时注入、截屏、键盘记录或用户弱密码。
- **Apple Distribution artifact GO**：Build 2 的 App Store Connect IPA 已成功生成，最终分发签名、Store profile 与 entitlement 已核验。
- **Release candidate GO**：源码、线上政策、测试、Archive、IPA、签名、符号、隐私清单和唯一构建身份已形成可追溯闭环。
- **TestFlight delivery GO**：Build 2 已上传、Apple 处理完成并由内部测试员安装；这不等于已通过外部 Beta App Review 或已提交面向用户的 App Store Review。
- **Internal TestFlight core HUMAN GO**：Build 2 全新安装、核心事实、Widget 一致性、加密导出、错误密码失败关闭、完整恢复及基础本地化/主题/双设备布局由产品负责人确认通过。
- **公开发布 NO-GO**：未记录的真机/无障碍/系统压力门禁及商店材料仍未完成，也未提交 App Store Review。

## 下一步顺序

1. 在 App Store Connect 创建并配置非消耗型商品 `co.fanr.pulse.reminder.lifetime`，决定真实价格并关闭协议/税务/商品审核材料门禁。
2. 分别完成 StoreKit Sandbox、TestFlight 和换机恢复购买；验证取消、待处理、退款/撤销、离线启动和商品加载失败，不把本地 StoreKit Configuration 当成生产证据。
3. 真机验证 iOS 26 scheduled transient Live Activity、支持设备 Dynamic Island、无灵动岛/iPad 系统表面、Live Activities 关闭后的通知回退，以及 iOS 18–25 通知实际到达与取消。
4. 完成 Build 3 签名 Archive、隐私答案、商店文案/截图、最大动态字体、真人 VoiceOver、最旧 iOS 18.x 与 Widget 压力矩阵；产品负责人审阅后再单独授权上传或提交 App Store Review。
