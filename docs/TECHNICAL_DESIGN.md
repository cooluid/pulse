# Pulse 技术设计

文档版本：1.7
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

AppSettings ──→ theme / language / reminder preferences
PulseWidgetStylePreferences ──→ widget.style only
```

- `CheckInRecord` 是签到事实唯一来源；Repository 是唯一写入者。
- SwiftData managed object 不越过 `PulseCore`；App 和 Widget 只消费已验证的不可变快照。
- 统计、月历、连续天数、今日状态和 Widget timeline 都是可重建投影，不持久化第二份事实。
- `AppSettings.language` 是应用内语言唯一状态；不写 `AppleLanguages`，不要求重启，也不维护页面级语言副本。
- App Group UserDefaults 只允许 `widget.style`，不得保存名称、日期、签到或统计副本。

## 3. 首发持久化合同

Pulse 尚未公开发布，因此 1.0 以一次干净基线开始：

- 唯一 SwiftData schema 为 `PulseSchema`，版本 `1.0.0`；
- 唯一 store 为系统 App Group 容器中的 `Library/Application Support/Pulse/Pulse.store`；
- 不存在 App 私有 store、位置 fallback、双写、搬迁 journal、staging 或预发布 schema 迁移器；
- 旧开发安装必须清洁安装，不能把开发期测试数据伪装成公开用户兼容责任。

`PersistenceController` 是创建目录和打开 ModelContainer 的唯一边界。App 负责首次建立 store；Widget 在主 store 文件不存在时只显示“打开 Pulse 完成设置”，不会先于 App 创建空库。

首个公开版本发布后，`PulseSchema 1.0.0` 才成为必须长期保留的迁移起点。以后任何 schema 变化都必须新增显式迁移计划和上一公开版本的真实磁盘 fixture，不允许再次清洁断代。

## 4. JSON 恢复合同

- 正式格式只有 `co.fanr.pulse.export` / `schemaVersion == 1`。
- `PulseExportCodec` 是编码、精确解码和完整语义校验的唯一入口。
- `PulseExportDocument` 只适配系统文件选择器，不拥有第二套 codec 或 validator。
- 缺少格式标识、版本不是 1、字段不完整、超出上限或语义损坏时失败关闭；不猜字段、不轮询多套 decoder、不升级预发布 JSON。
- 完整验证成功后 Repository 才替换事实；失败不能先删除现有数据。

## 5. 操作与失败语义

- `AppOperation` 串行化身份更新、签到、删除、清除、导入和时区更新。
- Repository 保存失败必须 rollback；页面只在成功回执和正式快照返回后推进。
- 同日并发签到由 `recordKey` 唯一约束、事务、失败回滚和正式回读共同裁决，不能依赖进程内锁。
- 启动区分持久化失败与设置损坏：持久化失败只允许重试；设置损坏可只重置设置，不删除签到事实。
- 全量清除使用持久化操作日志跨启动恢复，避免数据库和偏好只清一半。
- UI 动画阶段只存在内存中，不写 SwiftData 或 UserDefaults。

## 6. 时间、提醒与本地化

- 领域写入统一注入 `PulseClock`，不直接读取 `Date.now`。
- `LogicalDay` 使用项目时区和 Gregorian 日历；存储格式固定，展示才本地化。
- 提醒由纯值计划器生成未来 60 个日历日的一次性请求，签到、删除、导入、时区和设置变化后重新协调。
- SwiftUI 文案消费根环境 Locale；代码生成文案使用 `PulseLocalization` 读取同一 String Catalog。
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
- AppIntent 只执行单向签到，成功落盘后才请求 timeline reload；Widget 无删除、清除、导入、改时区或编辑承诺能力。
- Home Screen 可显示已确认名称；Lock Screen、StandBy、Always-On 不显示名称；任何 Widget 都不显示“为什么重要”。

详细系统表面合同见 [WIDGET_SHARED_STORE_CONTRACT.md](./WIDGET_SHARED_STORE_CONTRACT.md)。

## 9. 安全与发布边界

- 数据只存在于本地 App Group store 和用户主动导出的 JSON。
- `PrivacyInfo.xcprivacy` 声明不跟踪、不收集数据，并说明 UserDefaults API 的功能性用途。
- 1.0 不含 CloudKit、账户、分析 SDK、远程服务或半成品入口。
- 自动化与 Simulator 证据只能关闭工程门；真机、无障碍、Widget 系统表面、签名分发、TestFlight 和 App Store 门禁分别判定。
