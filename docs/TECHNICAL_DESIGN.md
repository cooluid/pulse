# Pulse 技术设计

文档版本：2.0
状态：Canonical Implemented Contract
更新日期：2026-08-12

## 1. 工程基线

- SwiftUI + SwiftData + Observation + Swift Concurrency。
- Swift 6、严格并发检查、全部 target 警告即错误。
- 最低系统为 iOS / iPadOS 18.0；iPhone 与 iPad 共用正式实现。
- 正式 target 只有 `PulseCore`、`pulse`、`PulseWidgetsExtension`、`pulseTests`、`pulseUITests`。
- `PulseCore` 是 App 与 Widget 唯一共享的 extension-safe framework；无第三方运行时依赖。

## 2. 事实所有权

```text
PulseClock ──→ authoritative now
                       ↓
SwiftDataCheckInRepository ──→ PulseSchema ──→ one Pulse.store
             │                         ↑
             ├── immutable snapshots ──┤
             └── commit receipts       │
                                       │
PulseAppModel ──→ App UI       Widget/AppIntent

AppSettings ──→ theme / reminder preferences
PulseSharedInterfacePreferences ──→ interface.language / widget.style
StoreKit 2 verified entitlement ──→ PulseEnhancementContract
                                      ├── ReminderDeliveryPolicy ──→ one ReminderDeliveryMode
                                      └── PulseWidgetStyleAccessPolicy ──→ one resolved widget style
```

- `CheckInRecord` 是签到事实唯一来源；Repository 是唯一写入者。
- SwiftData managed object 不越过 `PulseCore`；App 和 Widget 只消费已验证的不可变快照。
- 统计、月历、连续天数、今日状态和 Widget timeline 都是可重建投影，不持久化第二份事实。
- `PulseSharedInterfacePreferences` 是 App 与 Widget 的界面语言和 Widget 构图唯一持久化边界；`AppSettings.language` 只是同一值的可观察投影和写入口，不在 `.standard` UserDefaults 保存副本。
- App Group UserDefaults 只允许 `interface.language` 与 `widget.style` 两个类型化展示偏好；不得保存名称、日期、签到或统计副本。缺失键分别表示正式默认值 `system` / `commitmentManifesto`，未知值失败关闭。
- 不写 `AppleLanguages`，不要求重启，不维护页面级或 Widget 专用语言副本。

## 3. 首发持久化合同

Pulse 尚未公开发布，因此 1.0 以一次干净基线开始：

- 唯一 SwiftData schema 为 `PulseSchema`，版本 `1.0.0`；
- 唯一 store 为系统 App Group 容器中的 `Library/Application Support/Pulse/Pulse.store`；
- 不存在 App 私有 store、位置 fallback、双写、搬迁 journal、staging 或预发布 schema 迁移器；
- 旧开发安装必须清洁安装，不能把开发期测试数据伪装成公开用户兼容责任。

`PersistenceController` 是创建目录和打开 ModelContainer 的唯一边界。App 负责首次建立 store；Widget 在主 store 文件不存在时只显示“打开 Pulse 完成设置”，不会先于 App 创建空库。

App 与 Widget entitlement、专用 store 目录和现存 sidecar 统一使用 `NSFileProtectionCompleteUntilFirstUserAuthentication`。这保证设备重启后首次解锁前不可读，同时保留首次解锁后的锁屏 Widget 读取能力；不得复制事实到 UserDefaults 或第二份明文缓存来绕过保护。

首个公开版本发布后，`PulseSchema 1.0.0` 才成为必须长期保留的迁移起点。以后任何 schema 变化都必须新增显式迁移计划和上一公开版本的真实磁盘 fixture，不允许再次清洁断代。

## 4. 加密备份恢复合同

- 正式文件格式只有 `co.fanr.pulse.backup` / `.pulsebackup` 容器 v1；内部负载只有 `co.fanr.pulse.payload` / `schemaVersion == 1`。
- CommonCrypto PBKDF2-HMAC-SHA256 与 CryptoKit AES-256-GCM 是唯一密码学实现；参数、随机 salt/nonce、authenticated data 和资源上限以 [DATA_ENCRYPTION_CONTRACT.md](./DATA_ENCRYPTION_CONTRACT.md) 为准。
- `PulseEncryptedBackupCodec` 是加解密和认证的唯一入口，`PulseBackupPayloadCodec` 是业务负载编解码与完整语义校验的唯一入口。
- `PulseBackupDocument` 只适配系统文件选择器，不拥有第二套 codec、KDF 或 validator。
- 错误口令、篡改、缺少格式标识、版本不是 1、非合同参数、字段不完整、超出上限或语义损坏时失败关闭；不猜参数、不轮询 decoder、不接受预发布明文 JSON。
- 完整验证成功后 Repository 才替换事实；失败不能先删除现有数据。

## 5. 操作与失败语义

- `AppOperation` 串行化身份更新、签到、删除、清除、备份恢复和时区更新。
- Repository 保存失败必须 rollback；页面只在成功回执和正式快照返回后推进。
- 同日并发签到由 `recordKey` 唯一约束、事务、失败回滚和正式回读共同裁决，不能依赖进程内锁。
- 启动区分持久化失败与设置损坏：持久化失败只允许重试；设置损坏可只重置设置，不删除签到事实。
- 全量清除使用持久化操作日志跨启动恢复，避免数据库和偏好只清一半。
- UI 动画阶段只存在内存中，不写 SwiftData 或 UserDefaults。

## 6. 时间、提醒与本地化

- 领域写入统一注入 `PulseClock`，不直接读取 `Date.now`。
- `LogicalDay` 使用项目时区和 Gregorian 日历；存储格式固定，展示才本地化。
- `PulseEnhancementContract.productIdentifier` 是增强商品 ID 唯一来源。`FeatureAccessController` 只从 StoreKit 2 已验证的当前 entitlement 和交易更新派生 `hasEnhancement`；不把 `isPro`、商品价格或 entitlement 缓存到 UserDefaults、SwiftData、备份或 App Group。
- `ReminderDeliveryPolicy` 是提醒意图、增强权益与平台能力到 `ReminderDeliveryMode` 的唯一映射：提醒关闭时为 `disabled`；未购买或不支持 scheduled Live Activity 时为免费 `localNotification`；已购买 + iOS 26 + Live Activities 可用时为 `scheduledLiveActivity`。
- `ReminderSchedulePlanner` 只生成项目时区下的可发送逻辑日；`ReminderScheduler.reconcile` 先清理 Pulse 旧通知和旧 Activity，再只安排一个通道。通知通道使用未来 60 个日历日的一次性请求；iOS 26 ActivityKit 通道使用 `Activity.request(... style: .transient, start:)` 滚动安排最多 7 个短暂系统入口，避免把设备相关调度预算误当作无限容量。
- iOS 26 设备如果关闭 Live Activities，策略在进入调度前选择基础本地通知；第一个定时 Activity 即失败且通知已授权时继续使用基础本地通知，两个正式通道都不可用才诚实报错；已有 Activity 前缀成功后遇到系统容量上限保留已接受前缀。系统可能压缩、延迟或不展示，业务正确性不依赖系统表面出现。
- 通知权限只在用户主动开启提醒时请求，用于免费基础通道及增强通道失效时的同一提醒连续性；拒绝通知不能阻止仍可用的 scheduled Live Activity。签到、删除、备份恢复、时区、语言、权益和提醒设置变化后重新协调；外部撤权导致协调失败时保留用户开关意图并明确显示失败，不能悄悄关掉设置。
- App 与 Widget 内容都由 `PulseSharedInterfacePreferences.interface.language` 解析同一个显式 Locale；SwiftUI 文案消费根环境 Locale，代码生成文案必须显式传入该 Locale。
- `LogicalDay` 的可见日期和 VoiceOver 日期统一通过 `PulseLocalizedDateFormatting` 生成；不得显示固定 `MM/DD`、存储格式或隐式系统 Locale。
- App 切换语言后同时重新协调提醒并刷新 Widget timeline。Widget Gallery 名称、配置说明与 AppIntent 等系统托管静态元数据继续由 iOS 的系统/应用语言决定，不伪装成可被运行时偏好覆盖。
- 二级页面返回按钮由 `PulseSecondaryNavigationBackButton` 统一呈现，跟随应用内语言，避免系统语言与页面语言混用。
- 日期、星期、时间、时区名和辅助功能文案都显式消费当前应用 Locale。

## 7. 设计系统

- `design/brand-tokens.json` 是颜色真源，`scripts/build_brand_assets.py` 生成 Color Set、品牌标记与 AppIcon。
- 布局、透明度、动效和触控尺寸统一由 `PulseDesign` 管理。
- 正文支持 Dynamic Type；Accessibility 字号下固定圆形动作切换为可扩展形态。
- Reduce Motion 关闭呼吸、收缩、回弹和扩散，只保留必要状态过渡。
- 一级 Today / History 使用品牌导航；Settings、承诺编辑和时区选择使用同一二级导航合同。

## 8. Widget 与共享 Store

- App `co.fanr.pulse` 与 Widget `co.fanr.pulse.widgets` 通过 `group.co.fanr.pulse` 读取同一个 store。
- group ID 由项目级 `PULSE_APP_GROUP_IDENTIFIER` 注入 Info 与 entitlement，不能在多个 target 分别定义。
- Widget 的快照读取不产生默认项目；身份未确认、store 缺失或读取失败都有明确状态，不能伪装成“今日未签到”。
- AppIntent 只执行单向签到，成功落盘后才请求 timeline reload；Widget 无删除、清除、备份恢复、改时区或编辑承诺能力。
- Home Screen 可显示已确认名称；Lock Screen、StandBy、Always-On 不显示名称；任何 Widget 都不显示“为什么重要”。
- `commitmentManifesto` 是唯一免费 Home Screen 构图，另外三种构图属于同一个增强 entitlement。App 与 Widget 共用 `PulseStoreKitEntitlementReader` 的验证实现；App 写入前检查权益，Widget extension 每次生成 snapshot/timeline 时独立读取当前权益并经 `PulseWidgetStyleAccessPolicy` 解析。收费构图的 timeline 最迟每 15 分钟请求一次权益复核，同时由 App 交易更新主动 reload；iOS 仍拥有实际刷新时机。撤销、未验证或读取失败一律渲染免费构图，不能只靠设置页隐藏入口。

详细系统表面合同见 [WIDGET_SHARED_STORE_CONTRACT.md](./WIDGET_SHARED_STORE_CONTRACT.md)。

## 9. 安全与发布边界

- 数据只存在于受 iOS Data Protection 保护的本地 App Group store，以及用户主动创建、由独立口令保护的 AES-256-GCM 加密备份。
- 口令、派生密钥和明文负载不持久化；加密备份与恢复永久属于免费数据主权能力，后续 StoreKit 权益不得介入 Repository 或备份 codec。
- App 与 Widget 的 `ITSAppUsesNonExemptEncryption` 均为 `NO`；依据是运行时只调用 Apple OS 提供的标准密码学能力。若未来引入第三方或随 App 分发的密码学实现，必须重新审查出口合规。
- `PrivacyInfo.xcprivacy` 声明不跟踪、不收集数据，并说明 UserDefaults API 的功能性用途。
- 1.0 含一个 StoreKit 2 非消耗型“一日一印增强”商品：解锁 scheduled Live Activity 与三种额外 Home Screen Widget 构图；基础本地提醒和“承诺宣言”构图免费。不含 CloudKit、账户、分析 SDK、远程调度服务或第二套购买事实。
- 自动化与 Simulator 证据只能关闭工程门；真机、无障碍、Widget 系统表面、签名分发、TestFlight 和 App Store 门禁分别判定。
