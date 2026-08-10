# Pulse 日签到技术设计

文档版本：1.0  
状态：Ready for Implementation

## 1. 当前工程基线

仓库当前状态：

- SwiftUI App，入口为 `PulseApp`。
- App target：`pulse`。
- 单元测试 target：`pulseTests`。
- UI 测试 target：`pulseUITests`。
- 支持 iPhone 和 iPad。
- Bundle Identifier 为 `cool.pulse`。
- Swift Language Version 为 5。
- Deployment Target 已统一为 iOS / iPadOS 17.0。

工程使用共享 scheme，Debug、Release、单元测试和 UI 测试不依赖个人 `xcuserdata`。

## 2. 技术目标

- 核心功能离线可用。
- 业务日期逻辑可独立单元测试。
- 同一天重复签到在 UI 和数据层均安全。
- 页面只消费可观察状态，不自行拼接日期和统计规则。
- 初期结构足够小，不引入不必要的第三方架构框架。
- 提醒和导入/导出已经通过正式服务边界实现；CloudKit 在冲突模型确定前不启用。

## 3. 推荐技术栈

- UI：SwiftUI。
- 持久化：SwiftData。
- 并发：Swift Concurrency；持有 `ModelContext` 的写入服务限定在 `@MainActor`。
- 通知：UserNotifications，使用 30 天滚动一次性请求。
- 测试：统一使用 XCTest，不并存第二套测试框架。
- 依赖：MVP 不引入第三方库。

## 4. 模块边界

建议采用 Feature + Domain + Data 的轻量分层：

```text
pulse/
  App/
    PulseApp.swift
    RootView.swift
    PulseAppModel.swift
  Domain/
    Habit.swift
    CheckInRecord.swift
    LogicalDay.swift
    CheckInStatistics.swift
    PulseClock.swift
    PulseError.swift
  Data/
    PersistenceController.swift
    CheckInRepository.swift
    AppSettings.swift
    PulseExportDocument.swift
  Services/
    ReminderScheduler.swift
    HapticFeedback.swift
  Features/
    Today/
      TodayView.swift
    History/
      HistoryView.swift
    Settings/
      SettingsView.swift
  Shared/
    PulseDesignSystem.swift
    PulseFormatting.swift

pulseTests/
  LogicalDayTests.swift
  CheckInStatisticsTests.swift
  CheckInRepositoryTests.swift
  PulseExportDocumentTests.swift
  PulseAppModelTests.swift

pulseUITests/
  PulseFlowUITests.swift
```

## 5. 数据模型

### 5.1 Habit

建议字段：

```swift
@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var timeZoneIdentifier: String
    var dayStartMinutes: Int
    var isArchived: Bool
}
```

### 5.2 CheckInRecord

建议字段：

```swift
@Model
final class CheckInRecord {
    @Attribute(.unique) var recordKey: String
    var id: UUID
    var habitID: UUID
    var logicalDay: String
    var checkedAt: Date
    var createdAt: Date
    var sourceRawValue: String
}
```

`recordKey` 是持久化唯一约束，格式由一个统一工厂生成，不允许页面自行字符串拼接。

不建议持久化以下派生数据：

- `isCheckedToday`。
- `currentStreak`。
- `longestStreak`。
- `totalCount`。
- 月完成率。

这些值全部从记录计算；否则删除、恢复或规则升级后容易失真。

## 6. 领域类型

### 6.1 LogicalDay

不要在领域层四处传递未约束的日期字符串。建议提供值类型：

```swift
struct LogicalDay: Hashable, Comparable, Codable {
    let year: Int
    let month: Int
    let day: Int
}
```

职责：

- 从绝对时间、项目时区和日界线计算。
- 生成稳定存储字符串。
- 通过 Calendar 取得前一天、后一天和月份边界。
- 负责比较，不依赖本地化展示字符串。

展示层再通过独立 formatter 生成中文或系统地区格式。

### 6.2 Clock

```swift
protocol Clock {
    var now: Date { get }
}
```

生产环境使用 `SystemClock`，测试使用 `FixedClock`。业务服务和 ViewModel 通过依赖注入获取 Clock。

## 7. Repository 设计

```swift
@MainActor
protocol CheckInRepository {
    func defaultHabit() throws -> Habit
    func record(habitID: UUID, day: LogicalDay) throws -> CheckInRecord?
    func checkIn(habit: Habit, at date: Date) throws -> CheckInRecord
    func records(habitID: UUID, in interval: DateInterval?) throws -> [CheckInRecord]
    func delete(recordID: UUID) throws
    func resetAllData() throws
}
```

`checkIn` 的实现顺序：

1. 在主 actor 串行边界计算目标逻辑日。
2. 生成 `recordKey`。
3. 查询已有记录。
4. 已存在时直接返回已有记录。
5. 不存在时插入并保存 `ModelContext`。
6. `save()` 成功后才返回成功。
7. 唯一约束作为最后一道完整性保护。

ViewModel 不直接操作 `ModelContext`，否则不同页面会逐渐形成不同保存和错误处理语义。

## 8. 状态管理

MVP 使用一个 `@MainActor @Observable PulseAppModel` 持有当前项目、记录快照、逻辑日和页面派生状态。选择单一根状态的原因是当前只有一个签到项目，今日页和历史页必须消费同一份记录，避免多个 ViewModel 各自缓存并发生刷新漂移。功能扩展为多项目前不拆分第二套状态所有者。

### 8.1 今日状态

建议可观察状态：

```text
today
checkInState: loading | available | saving | checked | failed
checkedAt
currentStreak
recentDays
errorPresentation
```

关键动作：

- `load()`：读取默认项目、今日记录和派生统计。
- `checkIn()`：防重入，调用 Repository，成功后整体刷新状态。
- `refreshForDateBoundary()`：重新计算 today 并刷新。
- `sceneDidBecomeActive()`：处理后台跨日和系统设置变化。

### 8.2 历史状态

职责：

- 维护当前展示月份。
- 查询覆盖该月和统计所需范围的记录。
- 将记录映射为月历单元状态。
- 删除记录后重新查询并计算统计。

## 9. 日期边界监听

需要同时覆盖：

- `scenePhase` 变为 `.active`。
- `UIApplication.significantTimeChangeNotification`。
- 前台运行时根据下一个逻辑日边界安排一次性计时器。

计时器只是触发刷新，不作为真实时间源。触发后仍通过 `Clock` 和 `LogicalDayCalculator` 重新计算，避免计时器延迟造成错误。

## 10. 本地提醒设计（P1）

使用滚动窗口的一次性通知，而不是无法根据签到状态精确取消的永久重复通知。

建议策略：

- 用户开启提醒后请求权限。
- 提醒时间只存储一个 `0...1439` 的午夜起分钟数；小时、分钟只是派生值，不分别持久化。
- 时间选择器使用固定的纯时间表示，通知投递统一解释为签到项目固定时区中的墙上时间，不读取设备当前日历作为业务规则。
- 为未来 30 个逻辑日分别安排一次性通知。
- 每次 App 启动、回到前台、修改提醒设置或完成签到后重新协调窗口。
- 当天签到成功后删除当天尚未发送的请求。
- 清除数据或关闭提醒时删除 Pulse 创建的全部通知请求。
- 通知 identifier 包含稳定前缀和逻辑日，不能误删其他 App 通知。

若实测系统待处理通知上限或调度策略不符合预期，调整窗口长度，但不能改为“今天已签到仍照常提醒”的退化行为而不更新需求。

## 11. 错误处理

错误按用户是否能行动分类：

- 可重试保存失败：保留页面数据，恢复签到按钮，提示重试。
- 数据读取失败：显示错误状态和重新加载入口。
- 通知权限拒绝：签到照常可用，设置页提供系统设置入口。
- 无效时区标识或损坏的持久化设置：阻止相关状态加载并显示明确错误，不回退、不静默重写。
- 数据模型迁移失败：发布阶段需要迁移测试，不能通过清库掩盖。

面向用户的文案不暴露 SwiftData、ModelContext 或错误码。调试构建可以记录底层错误。

## 12. 数据迁移

首版也要配置明确的 SwiftData schema version。后续模型新增字段时：

- 提供默认值或迁移计划。
- 用旧版本 fixture 验证升级。
- 不把删除用户数据库作为正常迁移策略。
- `recordKey` 格式一旦发布即视为持久化协议；若需调整必须显式迁移。

## 13. 数据导入与导出

推荐首先支持 JSON，字段语义稳定且便于未来恢复：

```json
{
  "schemaVersion": 1,
  "exportedAt": "2026-08-10T06:30:00Z",
  "habit": {
    "id": "...",
    "name": "每日签到",
    "timeZoneIdentifier": "Asia/Shanghai",
    "dayStartMinutes": 0
  },
  "records": []
}
```

JSON 是唯一恢复协议。导入先完整解码和验证，再通过 Repository 原子替换现有项目与记录；不执行隐式合并。CSV 可以作为未来便于阅读的附加格式，但不能承担恢复协议。

## 14. 安全与隐私边界

- P0 数据只保存在应用沙盒。
- 不记录精确位置、设备标识或无关行为数据。
- 日志不得输出完整导出内容。
- 清除数据必须包含应用创建的通知和设置。
- CloudKit 加入前必须设计冲突合并；简单开启同步不等于数据安全。

## 15. 可观测性

个人本地工具不需要先接入远程分析。开发阶段建议使用统一日志类别：

- `persistence`
- `check-in`
- `date-boundary`
- `notification`

日志记录结果和错误类型，不记录不必要的用户内容。Release 构建不依赖日志维持业务状态。

## 16. 技术完成标准

- 架构中只有 Repository 能写签到记录。
- 业务日期和连续天数逻辑无 UI 依赖并有完整单元测试。
- Debug 和 Release 均可构建。
- 单元测试与核心 UI 测试通过。
- SwiftData 真机持久化、跨启动恢复和删除经过验证。
- 不存在用于演示的内存假数据路径进入 Release。
