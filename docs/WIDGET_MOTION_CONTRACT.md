# Pulse Widget 动效合同

文档版本：2.0
状态：Canonical Implemented Contract
更新日期：2026-08-14

本文定义 Home Screen Widget 的产品级动效边界。签到事实、逻辑日与唯一 store 以 [DOMAIN_CONTRACT.md](./DOMAIN_CONTRACT.md) 为准；共享 store 与跨进程边界以 [WIDGET_SHARED_STORE_CONTRACT.md](./WIDGET_SHARED_STORE_CONTRACT.md) 为准。

## 1. 第一原则

Widget 不是持续运行的动画画布。它首先必须准确表达“今天是否已经签到”，其次才允许在系统交付新 entry 时，用一次有限过渡表现物件发生了什么。

| 级别 | 名称 | 机制 | 允许范围 |
| --- | --- | --- | --- |
| L0 | 静态终态 | 单一事实画面 | Reduce Motion、Accessory、错误态 |
| L1 | 事实变装 | 权威事实保存并 reload 后的有限过渡 | Home Screen 八式 |
| L1P | 变化预览 | App 内瞬时投影待签到帧，再播放完成帧 | 构图画廊逐卡重播 |

禁止无限循环、按时段制造装饰变化、用 Timeline 模拟帧动画、伪造签到事实、持久化纯视觉状态，以及用运动掩盖布局或可读性问题。

## 2. 正式数据流

1. `PulseWidgetSnapshotReader` 从唯一 Repository 投影不可变 snapshot。
2. `PulseWidgetTimelineSchedule` 只生成“当前事实 + 下一逻辑日零点”两条 entry。
3. App Intent 保存签到事实后，reload 两个正式 Widget kind。
4. `PulseWidgetHomeRenderer` 仅根据 `snapshot.isCheckedToday` 选择物件终态。
5. `PulseWidgetMotionPresentation` 为各物件提供一次、有限、可关闭的过渡曲线。

不存在 `PulseWidgetVisualVariant`、时段 phase、ornament seed 或持久化的第二套预览状态。Gallery 与 Widget Extension 使用同一 Renderer；画廊重播只允许从当前权威 snapshot 瞬时投影今天的待签到/已签到外观，生命周期限于单张卡片，不写 Repository、App Group、UserDefaults 或 Widget Timeline。

## 3. 八式物件变化

| 构图 | 材料语法 | 待签到 → 已签到 |
| --- | --- | --- |
| 待落之处 | 留白 / 印位 | 空位收束并落下日印 |
| 落印 | 墨 / 印泥 | 开放印记闭合并略微压实 |
| 叠印 | 纸张 | 松散纸层压紧，顶层完成落印 |
| 数影 | 数字 / 雾影 | 今日数影显色并稳定，印记闭合 |
| 手札 | 信纸 / 封缄 | 封缄闭合，纸面轻微归位 |
| 静场 | 回声 / 场 | 开放回声收束为完成场 |
| 来路 | 足迹 / 路径 | 今日节点闭合并出现确认标记 |
| 潮痕 | 潮面 / 岸线 | 潮面一次上移，开放日环闭合 |

每式只保留一个主物件。潮痕禁止天空、云、太阳、鱼、气象隐喻、黑色装饰块和独立天空色 token。

## 4. 曲线与 Reduce Motion

- 每种材料的 duration、spring 或 easing 统一由 `PulseWidgetMotionPresentation` 管理；Renderer 不散落自定义曲线。正常材料变化控制在 0.90...1.25 秒，画廊含 0.22 秒待签到准备帧后总时长仍小于 2 秒。
- 运动只绑定 `snapshot.isCheckedToday`，不绑定时钟、随机数或持续 timer。
- Reduce Motion 为真时，Renderer 传入 `allowsMotion = false`，取消插值但保留完全相同的事实终态、层级与颜色。
- Accessory Widget 维持静态事实表达；不为 Lock Screen、StandBy 或 Always-On 另存动效副本。
- 画廊每张卡使用独立标准 Button 重播；播放中禁用该按钮，离页或权威事实变化立即取消任务并恢复当前事实。锁定构图可以预览，但购买入口必须是独立 Button，不得嵌套交互。

## 5. 自动化门禁

必须覆盖：

- Timeline 只有当前 entry 与 `nextDayBoundary` entry；
- 零点 entry 重新投影新逻辑日，而非复制旧 snapshot；
- Gallery 与 Extension 初始化同一 Renderer，不存在 legacy variant 参数；
- Gallery 预览投影只改变今天状态，过去六日事实保持不变，且不会触发正式签到；
- 源码、token、Asset Catalog、原型和文档均无 sky / cloud / fish / phase keyframe 遗留；
- Debug、Release、Analyze 与 Widget UI 截图通过。

## 6. 真机验收

自动化只能证明静态终态、布局和代码契约。真机验收必须确认：签到后系统实际刷新、一次过渡是否自然、Reduce Motion、深浅色、Tinted/Clear、StandBy 与 Always-On。未完成这些检查前，不得把 Widget 宣称为 runtime GO。
