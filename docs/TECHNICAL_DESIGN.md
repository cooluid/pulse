# Pulse 技术设计

文档版本：1.6<br>
状态：Implemented App + PulseCore + App Group Shared Store + PulseWidgets

## 1. 工程基线

- SwiftUI + SwiftData + Observation + Swift Concurrency。
- Swift 6，严格并发检查，所有 target 警告即错误。
- iOS / iPadOS 17.0，iPhone 与 iPad 共用产品实现。
- 正式 target：`PulseCore`、`pulse`、`PulseWidgetsExtension`、`pulseTests`、`pulseUITests`。`PulseCore` 是静态 Swift framework，开启 `APPLICATION_EXTENSION_API_ONLY`，由 App 与 Widget 共同链接。
- Bundle ID：`co.fanr.pulse`。
- 不依赖第三方运行时库；品牌资产生成器唯一 Python 依赖固定在 `requirements.txt`。

## 2. 所有权链

```text
PulseCore
├── PulseClock ──→ authoritative now
├── SwiftDataCheckInRepository ──→ Habit + CheckInRecord
├── PulseExportCodec ──→ one decode / validation path
└── validated immutable snapshots
                 ↓ module boundary
PulseAppModel ──→ Today / History / Settings
   ↓ value snapshot
ReminderScheduler ──→ UserNotifications

AppSettings ──→ ConfiguredRootView
   ↓ persisted theme and language
SwiftUI environment + PulseLocalization

App + PulseWidgetsExtension
   ↓ same App Group URL
PulseSharedStoreBootstrapper ──→ one Pulse.store
   ↓ immutable projection
PulseWidgetSnapshot ──→ Widget timeline / one-way AppIntent
```

- `PulseCore` 只编译 `Domain / Persistence / ImportExport / Widget projection`；不依赖 SwiftUI、WidgetKit、UserNotifications、UserDefaults、触觉、页面或宿主本地化资源。App 与 Widget 源码都不再编译 Core 文件的副本。
- Repository 是事实写入和持久化语义校验的唯一所有者，并持有与 AppModel 相同的 Clock；SwiftData managed object 不越过模块边界，调用方只接收已经验证、关键日期与时区非可空的 `HabitSnapshot`、`CheckInRecordSnapshot` 和提交回执。
- `existingPrimaryHabit()` 是不产生默认项目的只读入口；启动迁移与 Widget 读取不能借用会创建数据的 `primaryHabit(systemTimeZone:)` 猜测事实。
- AppModel 是页面快照、操作互斥、导航复位和提醒意图顺序的唯一所有者。
- AppSettings 是主题与应用内语言的唯一持久化所有者；根窗口直接观察它，不能依赖页面级副本。
- View 只呈现状态与发起意图，不直接访问 SwiftData、UserDefaults 或通知中心。
- 统计与月历从记录快照派生；按逻辑日字典为内存索引，不是第二份持久化事实。

## 3. 持久化模型

`Habit`：`id`、唯一 `slotKey`、`name`、可选 `purpose`、`isIdentityConfirmed`、`createdAt`、稳定 `startLogicalDayValue`、创建时区、当前签到时区。

`CheckInRecord`：唯一 `id`、唯一 `recordKey`、`habitID`、`logicalDayValue`、`checkedAt`、`createdAt`、记录时区。

`HabitSnapshot`、`CheckInRecordSnapshot` 与 `PulseWidgetSnapshot` 是 `PulseCore` 对外公开的不可变、`Sendable` 输出；它们复制事实值但不拥有写入能力，也不持久化为第二套模型。Repository 在创建快照前统一验证身份规范、起始日来源、时区、recordKey、时间顺序和逻辑日唯一性；损坏事实不能以可空字段或静默默认值逃出 Core。AppModel、Today、History 和 Widget timeline 都不能持有 `PersistentModel` 实例。

当前 SwiftData schema 为 V2。`PulseSchemaV1` 和 `PulseSchemaV2` 分别冻结各自的命名空间模型，运行时代码只通过 latest typealias 消费 V2；V1→V2 使用明确的 lightweight migration，新增字段的迁移值为 `purpose == nil`、`isIdentityConfirmed == false`。真实磁盘 fixture 必须证明项目和记录全部保留。

JSON 只导出 v2。`PulseExportCodec` 是编码、精确版本解码与完整语义验证的唯一公开入口；v1 只在内存中升级为 v2。App 的 `PulseExportDocument` 只是 FileDocument 适配器，不再拥有第二套 codec 或 validator。

## 4. 操作与失败语义

- `AppOperation` 串行化身份更新、签到、删除、清除、导入和时区更新，防止 UI 并发写入。
- Repository 在 `save()` 失败时 rollback；View 只在成功返回后关闭详情或选择器。
- 启动分别识别持久化失败和设置损坏：前者只允许重试，避免诱导删数据；后者可以只重置设置，明确保留签到事实。
- `PulseCoreError` 只表达领域、持久化和导入导出错误；设置与通知错误属于宿主 `PulseAppError`。用户文案由 App 的单一错误呈现器按当前应用 Locale 映射，Core 不反向读取宿主资源。
- 全量清除用持久化操作日志跨启动恢复，避免数据库已清空但设置/通知未清的假成功。
- 导入先限制文件大小，再解码和完整验证，最后由 Repository 单次替换。
- 主承诺输入由 `HabitIdentity` 统一规范化与验证；View 不直接修改 `Habit`。Repository 只在值变化或首次确认时保存，保存失败统一 rollback。
- Repository 的签到命令返回不可持久化的 `CheckInCommitReceipt`，明确标记新建或幂等命中；AppModel 在刷新正式快照后才把回执交给页面，并只为新建事实触发一次成功触觉。
- 今日页的日印状态机只拥有 `ready / saving / contracting / imprinting / imprinted` 短暂呈现状态。启动时从 `todayRecord` 投影为静态状态，失败回到 `ready`；不把动画阶段写入 SwiftData 或 UserDefaults。

## 5. 提醒一致性

- 提醒时间只存一个 `0...1439` 的午夜起分钟数。
- 调度消费纯值 `ReminderScheduleSnapshot`，不跨异步边界持有可变 SwiftData 模型。
- AppModel 为用户意图和协调任务分别维护单调 revision；旧权限结果和旧调度结果不能覆盖新操作。
- `ReminderSchedulePlanner` 先生成可独立测试的纯值计划。协调任务串行执行，每次先移除 Pulse 的待处理请求，再为从今天起的 60 个日历日创建一次性通知；保留 4 个系统待处理名额，不把平台上限全部占满。
- 启动、回到前台、签到、删除、导入、时区/语言/提醒设置变化都会滚动刷新计划。超过当前 60 日窗口且用户没有再次打开 App 时，不承诺继续送达提醒。
- 夏令时不存在的本地时间采用当天下一可用时间并保留分钟值；重复时间采用第一次出现的时刻。计划项保存归一后的绝对时间和一次性触发组件，测试不依赖通知中心。
- 已签到日期不生成提醒；关闭提醒和清除数据会移除 Pulse 的待处理与已送达通知。

## 6. 时间、格式与可测试性

- 领域与数据写入不直接调用 `Date.now`，统一注入 `PulseClock`。
- Debug UI 测试通过 `PULSE_UI_TEST_NOW` 注入 ISO-8601 固定时间，并用 UUID 命名的独立磁盘 store 验证跨重启持久化；单元测试宿主使用内存 store。无效测试配置直接触发前置条件失败。
- 首次确认状态保存在 `Habit`，与清除和导入一起迁移；不使用 `UserDefaults` onboarding 标志，不从默认名称猜测状态。
- 存储日期使用 `LogicalDay` 固定格式，展示才使用本地化 formatter。
- 历史签到时间使用记录自己的时区；当前日期与后续签到使用项目当前时区。
- 主题提供跟随系统、浅色、深色三种模式；语言提供跟随系统、English、简体中文三种模式。
- SwiftUI 文案消费根环境 Locale；代码生成的错误、格式串、辅助功能标签和通知文案由 `PulseLocalization` 显式选择 `en.lproj` 或 `zh-Hans.lproj`，避免切换后混用系统语言。
- 日期、星期、时间和时区名称显式消费当前应用 Locale；提醒快照携带不可变 Locale 标识，切换语言会重新协调待发送通知。

## 7. 设计系统

- `design/brand-tokens.json` 是颜色真源，`scripts/build_brand_assets.py` 生成 Color Set、品牌标记与 AppIcon。
- JSON 生成物按字节检查；PNG 按解码后的 mode、尺寸和像素检查，隔离压缩器版本差异。
- 所有布局、透明度和动效常量集中于 `PulseDesign`。
- 正文使用 Dynamic Type；104 pt 日号用 `@ScaledMetric`。Accessibility 字号下，固定圆形主动作切换为可扩展胶囊。
- 待签到光环只在今日页成为当前页时进行一次有限呼吸；背景场保持静态，不存在 `repeatForever` 动画。
- 正常落印总时长不超过两秒；Reduce Motion 关闭呼吸、收缩、回弹和扩散，只保留短淡入与静态形状替换。

## 8. 安全与隐私

- 数据仅在 App/Widget 共用的本地 App Group 容器和用户主动导出的 JSON 中存在。
- 不记录位置、广告标识或导出内容。
- 文件导入使用 security-scoped URL，并有 32 MiB 上限。
- `PrivacyInfo.xcprivacy` 声明不跟踪、不收集数据，并以 `CA92.1` 说明仅为 App 功能持久化设置而访问 UserDefaults。
- 设置页直接提供公开隐私政策和产品支持入口；两者共享一份集中式 URL 定义。
- CloudKit、分析 SDK 和远程账户不在 1.0，不保留隐藏入口或半成品实现。

## 9. Widget 与共享 Store

基础 Widget 建立在一个 App Group SwiftData store 和唯一 `PulseCore` 编译目标上，不复制 model、Repository 或签到状态。正式身份是 App `co.fanr.pulse`、Widget `co.fanr.pulse.widgets`、App Group `group.co.fanr.pulse`；group ID 由项目级 `PULSE_APP_GROUP_IDENTIFIER` 注入两个 target 的 Info 与 entitlement。开发设备构建已经取得两个独立 provisioning profile，签名 entitlement 都包含同一个正式 group。

`PulseSharedStoreBootstrapper` 是 App 启动的唯一位置裁决器：存在私有旧库时走 `.existingStore`，不存在任何旧库时走显式 `.newInstallation` staging；冲突或不完整源失败关闭。两条路径共享 journal v2 和 `copying → verified → sourceRemoved → ready` 状态机。迁移阶段的 SHA-256 摘要只证明源/目标事务一致；进入 `ready` 后目标已经成为可变事实真源，重启只验证源未复现、目标存在且可读取主承诺，不能拿旧摘要拒绝正常签到或身份编辑。

App 与 Widget 只通过系统 App Group API 解析 `Library/Application Support/Pulse/Pulse.store`。App 私有 store 只作为一次性迁移源，完成后主文件、WAL 与 SHM 被精确删除；不存在共享失败回退、双写或第二份签到状态。Widget 在 journal 未 `ready` 或身份未确认时显示明确“打开 App 完成设置”状态，不创建默认项目、不打开未录用目标、不伪装成待签到。

`PulseWidgetProjector` 从正式 Repository 投影最近七日、今日记录、可选名称、生成时间与项目时区下一个零点；`PulseWidgetSnapshotReader` 不产生写入。App Group UserDefaults 只保存 `widget.showsHabitName` 展示偏好，默认关闭，Lock Screen 始终忽略名称。

Widget AppIntent 在独立扩展进程执行单向签到；进程内由各自 ModelContext 串行化，进程间由 SQLite 事务、`recordKey` 唯一约束和保存失败后的 rollback + 回读裁决。App 与 AppIntent 只在事实保存并重新读取成功后请求 timeline reload；刷新失败不能反向覆盖 store。详细状态机、隐私与设备门禁以 [WIDGET_SHARED_STORE_CONTRACT.md](./WIDGET_SHARED_STORE_CONTRACT.md) 为准。
