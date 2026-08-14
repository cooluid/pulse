# Pulse Widget 动效合同

文档版本：1.0
状态：Canonical Implemented Contract
更新日期：2026-08-14

本文定义 Home Screen 与 Accessory Widget 的**时段关键帧动效**边界。签到事实、逻辑日与唯一 store 仍以 [DOMAIN_CONTRACT.md](./DOMAIN_CONTRACT.md) 为准；共享 store 与跨进程边界仍以 [WIDGET_SHARED_STORE_CONTRACT.md](./WIDGET_SHARED_STORE_CONTRACT.md) 为准。

## 1. 设计原则

Widget 动效服务**仪式物件识别、时段节律与事实变装**，不是 App 内环境层的复制，也不是加载进度或连续 GIF。

| 级别 | 名称 | 机制 | 允许 |
| --- | --- | --- | --- |
| L0 | 当前帧 | 单 entry | Reduce Motion、错误态、预览 |
| L1 | 时段关键帧 | Timeline 多 entry + WidgetKit 切换过渡 | 默认 Home / Accessory |
| L2 | 事实变装 | reload 后 entry 间过渡 | 签到、跨逻辑日 |

**禁止：** 无限循环动画、伪造业务事实、用 ornament 覆盖 store 投影、App Group 持久化 variant、高频率 entry（< 30 分钟间隔）。

## 2. 正式类型

| 类型 | 模块 | 职责 |
| --- | --- | --- |
| `PulseWidgetDayPhase` | PulseCore | 晨 / 午 / 暮 / 夜，按项目时区 06 / 12 / 18 / 22 时切分 |
| `PulseWidgetVisualVariant` | PulseCore | 由 `LogicalDay` + 当前时刻派生的 phase 与 ornamentSeed |
| `PulseWidgetTimelineEntry` | PulseCore | `date` + 不可变 `PulseWidgetSnapshot` + `PulseWidgetVisualVariant` |
| `PulseWidgetTimelinePlan` | PulseCore | 严格 chronological 的 entry 数组；末 entry 日期即 reload 边界 |
| `PulseWidgetTimelineSchedule` | PulseCore | 从 snapshot 生成「当前帧 + 剩余时段边界 + 逻辑日零点」 |
| `PulseWidgetMotionPresentation` | PulseWidgetUI | 统一 entry 过渡曲线 |
| `PulseWidgetPhaseAtmosphere` | PulseWidgetUI | 八式共享的环境强度/旋转偏移 |

`PulseWidgetSnapshot` 额外携带 `projectTimeZoneIdentifier`，供 Renderer 与 Gallery 在无 Repository 时正确派生 variant。

## 3. Timeline 调度

默认 `PresentationMode.phaseKeyframes`：

1. 当前时刻 entry（事实 snapshot + 当前 phase variant）
2. 当日剩余 phase 边界 entry（事实不变，variant 变）
3. 逻辑日零点 entry（事实与 variant 均按新逻辑日重投影）

Reduce Motion 时使用 `PresentationMode.currentFrameOnly`：仅保留「当前帧 + 逻辑日零点」两条 entry。

Widget Extension 对成功 plan 使用 `TimelineReloadPolicy.atEnd`；失败/未解锁态使用单 entry + `.after(retryInterval)`。

## 4. 八式动效表达

八式消费同一 `PulseWidgetVisualVariant`，但只通过各自物件语法解释：

- **潮痕**：云团水平漂移、潮位/天际抬升、单鱼深度与签到跃动；仍禁止鱼群、气象图标、百分比水位
- **待落之处 / 落印 / 叠印 / 数影 / 手札 / 静场 / 来路**：通过 `PulseWidgetPhaseAtmosphere` 调整环境层透明度与微旋转；不得改变业务布局或引入第二主角

variant **不得**写入 App Group、UserDefaults 或 snapshot 持久字段；ornamentSeed 由 `LogicalDay.storageValue` 的 FNV-1a 稳定派生。

## 5. 交互与无障碍

- 签到 Intent 保存事实后 reload 两个正式 kind；过渡仅作用于视觉层
- Reduce Motion 下 Extension 必须切换为 `currentFrameOnly`
- VoiceOver 与状态文案只朗读事实，不朗读 phase 名称
- Always-On / Accessory 使用与 Home Screen 相同的 plan；不得为 Lock Screen 另存动效副本

## 6. 自动化门禁

必须覆盖：

- phase 边界在 project time zone 下正确生成（含 DST）
- `currentFrameOnly` 与 `phaseKeyframes` entry 数差异
- ornamentSeed 对同一 `LogicalDay` 稳定、对不同日变化
- 末 entry 对齐 `nextDayBoundary`
- Renderer 接收 explicit `visualVariant`（Gallery、Extension 同源）

## 7. 真机验收

- 一日内多次瞥见 Widget，潮痕云位/氛围应随 phase 变化（不要求精确到分钟）
- 签到瞬间潮涌/环闭/鱼位变化可辨认
- Reduce Motion 开启后仅保留当前帧直至跨日
- 八式在 accented / vibrant / Clear / 深浅色下动效不破坏待签/已签可读性
