# Pulse 系统入口与跨设备事实合同

文档版本：4.0
状态：Canonical Functional Contract
更新日期：2026-08-24

本文定义 App、Widget、通知、Live Activity 和 Apple Watch 如何消费同一个签到事实。

## 1. 单一事实

- `CheckInRecord` 是签到唯一事实；所有系统表面只读 Repository 快照或通过 Repository 提交。
- 成功只由持久化创建或幂等回读回执裁决。动画、触觉、Widget reload、Watch 本地状态和 Activity 状态都不能提前宣布成功。
- App、Widget、Live Activity 和 Watch 并发时按同一 `recordKey` 收敛为同一逻辑日一条记录。
- 系统表面不读取或显示每日记事、照片和主承诺备注。Home Screen Widget 可以显示用户确认的“我的一件事”；Lock Screen、StandBy、Always-On 和 Watch 不显示其正文。

## 2. 产品能力

- Home Screen Widget 提供待落之处、星环、叠印、数影、手札、静场、来路、潮痕八个样式；待落之处免费，其余由统一高级功能 entitlement 解锁。
- Lock Screen Widget 使用独立 kind，不消费 Home Screen 样式参数，永久免费。
- iOS 26 scheduled Live Activity 产品名为“萤火日晕”。
- Apple Watch 提供基础今日状态、签到、complication 和 Smart Stack，永久免费。

## 3. App 内签到

- 单击只签到；长按 0.45 秒表示签到并拍照。相机只能在权威签到成功后请求，取消或失败不回滚签到。
- 保存中阻止重复操作；失败恢复可操作状态并明确未保存。
- App 冷启动或回前台读取到既有记录时只显示当前事实，不重播一次性成功反馈。
- 跨日、时区变化和 Scene 激活都从 Repository 重新投影。

## 4. Widget

### 4.1 数据与配置

- App 与 Widget 使用同一 App Group SwiftData store，不存在 UserDefaults 签到副本、私有 store fallback 或第二 Repository。
- Home Screen 样式由 WidgetKit 逐实例配置持有；App Group 不保存全局 `widget.style`。
- Widget extension 在生成 snapshot/timeline 时验证 StoreKit 权益。未知样式、未验证或撤销的收费权益必须明确失败，不能静默替换成免费样式。
- Timeline 必须在下一逻辑日重新投影。系统不保证 timeline 准点展示。

### 4.2 交互

- 未签到时提供一个单向签到 AppIntent；完成后不提供撤销。
- 普通 Widget AppIntent 在 extension 进程调用 Repository，返回后使用 WidgetKit 保证的 timeline reload，不重复主动 reload。
- Intent 失败不能显示完成事实；用户应得到可理解的未保存或重试结果。
- Gallery 预览只使用内存投影，不写 Repository、App Group、权益或正式 Widget 配置。

## 5. 提醒与 Live Activity

- `PulseReminderDeliveryPolicy` 是唯一通道仲裁：关闭、本地通知或 scheduled Live Activity。
- 未购买、系统不支持或 Live Activities 关闭时使用免费本地通知；符合条件时可安排 iOS 26 standard Live Activity，并用本地通知覆盖系统未接受的剩余日期。
- 滚动计划覆盖 60 个日历日；scheduled Live Activity 产品上限为 7 个。系统容量、调度和呈现不受 App 保证，同一逻辑日不得双发。
- 权限只在用户主动开启提醒时请求；拒绝后不能伪装已开启。
- 任一入口完成签到后只完成回执逻辑日当天的投递，保留未来计划。
- Live Activity 直接签到使用 `LiveActivityIntent` 在 App 进程提交；提交成功后更新/结束当天 Activity 并刷新正式 Widget kind。
- Activity attributes 携带逻辑日、提醒时间、项目时区和 Locale。内容不得使用设备当前时区猜测项目事实。
- `staleDate` 不用于伪造完成或定时结束；系统表面不得承诺“到点一定出现”。

## 6. Apple Watch

### 6.1 所有权

- iPhone Repository 仍是唯一 `CheckInRecord` 真源。Watch 不共享 SQLite，也不创建第二签到数据库。
- Watch 本地只保存可重建快照、durable command outbox 和最后回执；这些是传输状态，不是签到历史。
- iPhone `AppSettings` 是 Watch 可配置偏好的唯一真源；Watch 只消费快照，不保存可独立修改的副本。

### 6.2 快照

快照至少包含协议版本、项目 ID/revision、项目时区、当前逻辑日、下一日边界、今日状态、近七日投影和必要设置。

- `nextDayBoundary` 到达后旧快照进入需要同步，不能继续猜测今天。
- 坏快照、旧 revision、时区变化或项目变化不得顺手删除 outbox。
- Watch App 可以向 iPhone 请求当前 Repository 快照；complication 等待正式上下文更新。

### 6.3 签到命令

Watch 点击先创建不可变命令：稳定 `operationID`、项目 ID/revision、动作绝对时间和当时项目时区。

- 即时消息与保证排队的后台用户信息复用同一命令和 iPhone 处理器。
- iPhone 验证协议、项目/revision、时区、未来时间和项目起始日后，才按 `occurredAt` 调用 Repository。
- 重复、乱序和跨午夜命令按领域合同幂等裁决；Watch 不提供任意日期或补签入口。
- 只有匹配的 iPhone Repository 回执才能让 Watch 进入已提交并清除 outbox。待同步、失败或拒绝不得冒充成功。

### 6.4 生命周期与隐私

- Watch 不建立第二套每日提醒计划；通知路由仍由系统和 iPhone 唯一提醒策略决定。
- Watch 不接收记事、照片、备份、口令或主承诺正文。
- 取消配对、退出项目或清除全部数据时，快照和 outbox 有可验证的清理路径。

## 7. 无障碍与系统硬限制

- 关键状态不能只靠颜色；VoiceOver 必须读出当前事实和操作后果。
- Dynamic Type 下关键任务可完成，不裁切或重叠操作。
- Reduce Motion、Always-On、低亮度和后台场景提供等价静态状态。
- Widget / Live Activity 单次动画遵守 Apple 当前平台上限。
- 系统托管表面的最终尺寸、位置、时机和动画由系统裁决。

## 8. 测试

自动化验证领域事实、幂等、权限、通道仲裁、Intent 进程结果、跨日、失败、Watch outbox/回执和隐私边界。

## 9. 发布证据

- Simulator 和自动化不替代真实 Widget host、通知、Live Activity、Dynamic Island 或配对 Watch。
- Watch 必须在真实配对设备覆盖前后台、失联、重启、飞行模式、跨午夜、重复/乱序命令、Always-On、VoiceOver、Reduce Motion、complication、Smart Stack 和电量。
