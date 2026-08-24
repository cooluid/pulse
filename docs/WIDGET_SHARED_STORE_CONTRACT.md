# Pulse Widget 与共享 Store 合同

文档版本：4.0
状态：Canonical Functional Contract
更新日期：2026-08-24

本文定义 Widget 的产品能力、数据所有权和跨进程行为。

## 1. 产品能力

- Home Screen 小号/中号当前支持待落之处、星环、叠印、数影、手札、静场、来路、潮痕八个产品样式名。
- 待落之处免费，其余七个样式由统一高级功能 entitlement 解锁。
- Home Screen 每个实例独立选择样式；Lock Screen 使用独立 kind，不接收 Home Screen 样式参数。
- 未签到时 Widget 提供单向签到；完成后不提供撤销。
- 产品名称和收费边界以本节为准。

## 2. 唯一身份与容器

| 项目 | 正式值 |
| --- | --- |
| App Bundle ID | `co.fanr.pulse` |
| Widget Bundle ID | `co.fanr.pulse.widgets` |
| App Group | `group.co.fanr.pulse` |
| Store | `Library/Application Support/Pulse/Pulse.store` |

App、Widget 和相关 Intent 从同一 build setting 取得 App Group。系统容器不可用、store 不存在或 schema 不兼容时失败关闭，不拼接替代沙盒路径，也不创建第二空库。

## 3. 数据所有权

- `SwiftDataPulseRepository` 是 Habit 和 CheckInRecord 唯一写入者。
- Widget 不保存 `isCheckedToday`、连续天数、日期、名称、记录、权益或统计副本。
- Widget 不查询、读取或显示每日记事和照片。
- App Group UserDefaults 只由 `PulseSharedSettings` 管理界面语言、提醒开关和提醒时间。
- Home Screen 样式由 WidgetKit 逐实例配置持有，不存在全局 `widget.style`。

## 4. 快照与 Timeline

- `PulseWidgetSnapshotReader` 从 Repository 生成不可变快照。
- 快照包含当前项目、逻辑日、今日状态和所需历史投影；所有派生值均可重建。
- Timeline 必须覆盖下一逻辑日边界，不能跨日继续显示昨天的今天。
- 系统不保证 timeline 准点交付。
- Gallery 可以投影内存预览，但不得写 Repository、UserDefaults、正式 Timeline 或权益。

## 5. 权益

- `PulseWidgetStyleAccessPolicy` 是样式访问唯一策略。
- Widget extension 在生成 snapshot/timeline 时读取已验证 StoreKit entitlement。
- 未验证、撤销或未知样式明确返回不可用状态，不能静默替换成免费样式。
- App 不保存购买布尔副本，备份也不包含权益。

## 6. 交互

- Widget AppIntent 直接调用共享 Repository，依赖数据库唯一约束保证同日幂等。
- 普通 Widget Intent 返回后使用 WidgetKit 保证的 timeline reload，不重复主动 reload。
- App/Widget/Live Activity/Watch 并发仍只产生一条 CheckInRecord。
- 保存失败不得显示完成；应保留可理解的重试路径。

## 7. 隐私与无障碍

- Home Screen 可以显示用户确认的名称；Lock Screen、StandBy 和 Always-On 不显示名称；任何 Widget 都不显示备注、记事或照片。
- 状态不能只靠颜色，VoiceOver 提供日期、状态和操作后果。
- Reduce Motion、Always-On、低亮度和系统 rendering mode 下保持事实可读。

## 8. 测试

自动化验证 store 身份、schema、快照事实、跨日、幂等、权益、Intent、失败、隐私和无障碍结果。
