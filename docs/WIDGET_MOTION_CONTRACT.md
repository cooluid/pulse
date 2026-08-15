# Pulse Widget 动效合同

文档版本：3.0
状态：Canonical Implemented Contract
更新日期：2026-08-15

本文定义 Home Screen Widget 的产品级动效边界。签到事实、逻辑日与唯一 store 以 [DOMAIN_CONTRACT.md](./DOMAIN_CONTRACT.md) 为准；共享 store 与跨进程边界以 [WIDGET_SHARED_STORE_CONTRACT.md](./WIDGET_SHARED_STORE_CONTRACT.md) 为准。

## 1. 第一原则

Widget 不是持续运行的动画画布。它首先必须准确表达“今天是否已经签到”，其次才允许在系统交付新 entry 时，用一次有限过渡表现物件发生了什么。早间、日间、晚间只是同一事实在一天中的三种低幅构图状态，不承担报时语义，也不承诺准点切换。

| 级别 | 名称 | 机制 | 允许范围 |
| --- | --- | --- | --- |
| L0 | 静态终态 | 单一事实画面 | Reduce Motion、Accessory、错误态 |
| L1A | 时段氛围 | 早间 / 日间 / 晚间三种稀疏静态 entry | Home Screen 八式 |
| L1 | 事实变装 | 权威事实保存并 reload 后的有限过渡 | Home Screen 八式 |
| L1P | 变化预览 | App 内依次投影三种时段氛围，再播放完成帧 | 构图画廊逐卡重播 |

禁止无限循环、密集 Timeline 帧、准点承诺、伪造签到事实、持久化纯视觉状态，以及用运动掩盖布局或可读性问题。外观题材由实现与人工观感决定。

## 2. 正式数据流

1. `PulseWidgetSnapshotReader` 从唯一 Repository 投影不可变 snapshot。
2. `PulseWidgetTimelineSchedule` 生成当前 entry、当天剩余的 06:00 / 12:00 / 18:00 氛围边界，以及下一逻辑日零点；每天最多五条，边界只由一个集中定义持有。
3. App Intent 保存签到事实后，reload 两个正式 Widget kind。
4. `PulseWidgetHomeRenderer` 根据 `snapshot.generatedAt` 与项目时区推导氛围状态，根据 `snapshot.isCheckedToday` 选择事实终态；氛围状态不能改变日期、签到、历史或文案。
5. `PulseWidgetMotionPresentation` 为各物件提供一次、有限、可关闭的过渡曲线。

不存在第二套可持久化的预览状态。Gallery 与 Widget Extension 使用同一 Renderer；画廊重播只允许从当前权威 snapshot 瞬时投影早间 / 日间 / 晚间与今天的待签到 / 已签到外观，生命周期限于单张卡片，不写 Repository、App Group、UserDefaults 或正式 Widget Timeline。

## 3. 物件变化

签到 reload 后，各式用**自己的主物件**做一次有限变装。具体长什么样由实现与人工观感决定。

当前实现可参考 `PulseWidgetHomeRenderer`；改画直接改渲染器即可。

“来路”在时段 entry 变化时只移动雾层与远山轮廓，主路线保持稳定；签到 entry 到达后，最后一段抵达线沿路径生长，今日缺口圆环连续闭合并留下低幅光晕。待签到与已签到必须保持同一 Renderer 层级，不能因为交互按钮出现或消失而替换整棵内容视图、截断系统的数据更新过渡。

工程上仍遵守：单次动画 ≤ 两秒、Reduce Motion 直接终态、不伪造事实、不密集 Timeline 帧。

## 4. 曲线与 Reduce Motion

- Apple 的 [Widget 动效文档](https://developer.apple.com/documentation/widgetkit/animating-data-updates-in-widgets-and-live-activities) 与 [Widgets HIG](https://developer.apple.com/design/human-interface-guidelines/widgets) 明确规定 Widget / Live Activity 单次动画最长为两秒。`PulseWidgetMotionPresentation.systemMaximumAnimationDuration` 是同一上限的唯一工程定义，测试逐材料失败关闭，不能依赖系统静默截断。
- 每种材料的事实变装、时段氛围 duration、spring/easing 与早中晚姿态统一由 `PulseWidgetMotionPresentation` 管理；Renderer 不散落自定义曲线。事实变装按材料为 1.45...1.90 秒，时段氛围为 0.76...0.96 秒，每次独立变化均不超过官方两秒上限。
- 两秒上限约束一次系统 Widget 变化，不约束 App 内串联多个独立状态的教学时长。画廊依次展示早间、日间、晚间与完成态，总时长允许超过两秒；每个氛围态必须至少等待上一段氛围过渡完成，完成态必须覆盖对应材料的完整事实变装。不得为了追求短总时长而在动画尚未完成时重新指定下一目标。
- 事实变装只绑定 `snapshot.isCheckedToday`；时段氛围只绑定集中解析的 `snapshot.generatedAt` 与项目时区。两者都不使用随机数或持续 timer。
- Reduce Motion 为真时，Renderer 传入 `allowsMotion = false`，取消插值但保留完全相同的事实终态、层级与颜色；画廊跳过早间 / 日间 / 晚间串联，只呈现当前时段的待办静态等价与完成静态等价。
- Accessory Widget 维持静态事实表达；不为 Lock Screen、StandBy 或 Always-On 另存动效副本。Always-On 的 `isLuminanceReduced` 与 Reduce Motion 都会显式关闭 Renderer 动效，不能只依赖系统停止播放。
- 画廊每张卡使用独立标准 Button 重播；播放中禁用该按钮，离页或权威事实变化立即取消任务并恢复当前事实。锁定构图可以预览，但购买入口必须是独立 Button，不得嵌套交互。

## 5. 自动化门禁

必须覆盖：

- Timeline 只包含当前 entry、当天剩余的三个集中氛围边界与 `nextDayBoundary` entry，最多五条；
- 零点 entry 重新投影新逻辑日，而非复制旧 snapshot；
- Gallery 与 Extension 初始化同一 Renderer，不存在 legacy variant 参数；
- Gallery 预览投影只改变展示时间与今天状态，过去六日事实保持不变，且不会触发正式签到；
- 源码、token、Asset Catalog、原型和文档均无 sky / cloud / fish、密集 phase keyframe 或持久化视觉状态遗留；
- Always-On 与 Reduce Motion 都向正式 Renderer 传入静态模式；
- Debug、Release、Analyze 与 Widget UI 截图通过。

## 6. 真机验收

自动化只能证明静态终态、布局和代码契约。真机验收必须确认：系统是否在可接受的近似时段交付氛围 entry、签到后是否实际刷新、一次过渡是否自然、Reduce Motion、深浅色、Tinted/Clear、StandBy 与 Always-On。不得把 06:00 / 12:00 / 18:00 的计划边界宣传成系统准点展示；未完成这些检查前，不得把 Widget 宣称为 runtime GO。
