# Pulse 技术设计

文档版本：1.0  
状态：Implemented

## 1. 工程基线

- SwiftUI + SwiftData + Observation + Swift Concurrency。
- Swift 6，严格并发检查，所有 target 警告即错误。
- iOS / iPadOS 17.0，iPhone 与 iPad 共用产品实现。
- App / 单元测试 / UI 测试 target：`pulse`、`pulseTests`、`pulseUITests`。
- Bundle ID：`co.fanr.pulse`。
- 不依赖第三方运行时库；品牌资产生成器唯一 Python 依赖固定在 `requirements.txt`。

## 2. 所有权链

```text
PulseClock
   ↓ authoritative now
SwiftDataCheckInRepository ──→ Habit + CheckInRecord
   ↓ validated snapshot
PulseAppModel ──→ Today / History / Settings
   ↓ value snapshot
ReminderScheduler ──→ UserNotifications
```

- Repository 是事实写入的唯一所有者，并持有与 AppModel 相同的 Clock。
- AppModel 是页面快照、操作互斥、导航复位和提醒意图顺序的唯一所有者。
- View 只呈现状态与发起意图，不直接访问 SwiftData、UserDefaults 或通知中心。
- 统计与月历从记录快照派生；按逻辑日字典为内存索引，不是第二份持久化事实。

## 3. 持久化模型

`Habit`：`id`、唯一 `slotKey`、`name`、`createdAt`、稳定 `startLogicalDayValue`、创建时区、当前签到时区。

`CheckInRecord`：唯一 `id`、唯一 `recordKey`、`habitID`、`logicalDayValue`、`checkedAt`、`createdAt`、记录时区。

当前 SwiftData 发布 schema 为 V1。由于产品尚未公开发布，本次模型清洁断代不携带旧开发 schema；首个公开版本之后必须走显式迁移。

## 4. 操作与失败语义

- `AppOperation` 串行化签到、删除、清除、导入和时区更新，防止 UI 并发写入。
- Repository 在 `save()` 失败时 rollback；View 只在成功返回后关闭详情或选择器。
- 启动分别识别持久化失败和设置损坏：前者只允许重试，避免诱导删数据；后者可以只重置设置，明确保留签到事实。
- 全量清除用持久化操作日志跨启动恢复，避免数据库已清空但设置/通知未清的假成功。
- 导入先限制文件大小，再解码和完整验证，最后由 Repository 单次替换。

## 5. 提醒一致性

- 提醒时间只存一个 `0...1439` 的午夜起分钟数。
- 调度消费纯值 `ReminderScheduleSnapshot`，不跨异步边界持有可变 SwiftData 模型。
- AppModel 为用户意图和协调任务分别维护单调 revision；旧权限结果和旧调度结果不能覆盖新操作。
- 协调任务串行执行。每次先移除 Pulse 的待处理请求，再按未来 30 天创建一次性通知；任何添加失败都会清理本轮部分结果。
- 已签到日期不生成提醒；关闭提醒和清除数据会移除 Pulse 的待处理与已送达通知。

## 6. 时间、格式与可测试性

- 领域与数据写入不直接调用 `Date.now`，统一注入 `PulseClock`。
- Debug UI 测试通过 `PULSE_UI_TEST_NOW` 注入 ISO-8601 固定时间，并用 UUID 命名的独立磁盘 store 验证跨重启持久化；单元测试宿主使用内存 store。无效测试配置直接触发前置条件失败。
- 存储日期使用 `LogicalDay` 固定格式，展示才使用本地化 formatter。
- 历史签到时间使用记录自己的时区；当前日期与后续签到使用项目当前时区。

## 7. 设计系统

- `design/brand-tokens.json` 是颜色真源，`scripts/build_brand_assets.py` 生成 Color Set、品牌标记与 AppIcon。
- JSON 生成物按字节检查；PNG 按解码后的 mode、尺寸和像素检查，隔离压缩器版本差异。
- 所有布局、透明度和动效常量集中于 `PulseDesign`。
- 正文使用 Dynamic Type；104 pt 日号用 `@ScaledMetric`。Accessibility 字号下，固定圆形主动作切换为可扩展胶囊。
- Reduce Motion 关闭脉冲呼吸和按压/保存缩放。

## 8. 安全与隐私

- 数据仅在应用沙盒和用户主动导出的 JSON 中存在。
- 不记录位置、广告标识或导出内容。
- 文件导入使用 security-scoped URL，并有 32 MiB 上限。
- CloudKit、分析 SDK 和远程账户不在 1.0，不保留隐藏入口或半成品实现。
