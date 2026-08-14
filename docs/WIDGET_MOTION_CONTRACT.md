# Pulse Widget 动效合同

文档版本：3.0
状态：Canonical Implemented Contract
更新日期：2026-08-14

本文定义 Home Screen Widget 的产品级动效边界。签到事实、逻辑日与唯一 store 以 [DOMAIN_CONTRACT.md](./DOMAIN_CONTRACT.md) 为准；共享 store 与跨进程边界以 [WIDGET_SHARED_STORE_CONTRACT.md](./WIDGET_SHARED_STORE_CONTRACT.md) 为准。

## 1. 第一原则

Widget 不是持续运行的动画画布。它首先必须准确表达“今天是否已经签到”，其次才允许在系统交付新 entry 时，用一次有限过渡表现物件发生了什么。早间、日间、晚间只是同一事实在一天中的三种低幅构图状态，不承担报时语义，也不承诺准点切换。

| 级别 | 名称 | 机制 | 允许范围 |
| --- | --- | --- | --- |
| L0 | 静态终态 | 单一事实画面 | Reduce Motion、Accessory、错误态 |
| L1A | 时段氛围 | 早间 / 日间 / 晚间三种稀疏静态 entry | Home Screen 八式 |
| L1 | 事实变装 | 权威事实保存并 reload 后的有限过渡 | Home Screen 八式 |
| L1P | 变化预览 | App 内依次投影三种时段氛围，再播放完成帧 | 构图画廊逐卡重播 |

禁止无限循环、密集 Timeline 帧、准点承诺、气象叙事、伪造签到事实、持久化纯视觉状态，以及用运动掩盖布局或可读性问题。

## 2. 正式数据流

1. `PulseWidgetSnapshotReader` 从唯一 Repository 投影不可变 snapshot。
2. `PulseWidgetTimelineSchedule` 生成当前 entry、当天剩余的 06:00 / 12:00 / 18:00 氛围边界，以及下一逻辑日零点；每天最多五条，边界只由一个集中定义持有。
3. App Intent 保存签到事实后，reload 两个正式 Widget kind。
4. `PulseWidgetHomeRenderer` 根据 `snapshot.generatedAt` 与项目时区推导氛围状态，根据 `snapshot.isCheckedToday` 选择事实终态；氛围状态不能改变日期、签到、历史或文案。
5. `PulseWidgetMotionPresentation` 为各物件提供一次、有限、可关闭的过渡曲线。

不存在持久化的 `PulseWidgetVisualVariant`、ornament seed 或第二套预览状态。Gallery 与 Widget Extension 使用同一 Renderer；画廊重播只允许从当前权威 snapshot 瞬时投影早间 / 日间 / 晚间与今天的待签到 / 已签到外观，生命周期限于单张卡片，不写 Repository、App Group、UserDefaults 或正式 Widget Timeline。

## 3. 八式物件变化

| 构图 | 时段氛围 | 待签到 → 已签到的主物件变化 |
| --- | --- | --- |
| 待落之处 | 印垫与空坑轻微横移 | 空坑被独立墨迹填满并出现勾 |
| 落印 | 印面轻微转向 | 不规则开放墨迹收束为完整印面 |
| 叠印 | 纸叠桌面轻移 | 纸层压紧，顶纸出现纸张专属封口印 |
| 数影 | 数字雾影轻移 | 大号日数本身显色、缩放归稳，不附加统计或通用完成徽记 |
| 手札 | 信纸与桌面轻移 | 信纸归位，独立封缄折页闭合 |
| 静场 | 回响场轻移 | 多层残影收束成回声核心，不使用通用圆环 |
| 来路 | 地面与足迹轻移 | 今日鞋印由轮廓压成实印并出现确认纹 |
| 潮痕 | 岸线与潮面轻移 | 潮面一次上移，潮位刻度由开放转为完成 |

每式只保留一个主物件。潮痕禁止天空、云、太阳、鱼、气象隐喻、黑色装饰块和独立天空色 token。

## 4. 曲线与 Reduce Motion

- 每种材料的 duration、spring 或 easing 统一由 `PulseWidgetMotionPresentation` 管理；Renderer 不散落自定义曲线。正常材料变化控制在 0.90...1.25 秒；画廊完整串联三种时段与签到变化仍小于 2 秒。
- 事实变装只绑定 `snapshot.isCheckedToday`；时段氛围只绑定集中解析的 `snapshot.generatedAt` 与项目时区。两者都不使用随机数或持续 timer。
- Reduce Motion 为真时，Renderer 传入 `allowsMotion = false`，取消插值但保留完全相同的事实终态、层级与颜色。
- Accessory Widget 维持静态事实表达；不为 Lock Screen、StandBy 或 Always-On 另存动效副本。
- 画廊每张卡使用独立标准 Button 重播；播放中禁用该按钮，离页或权威事实变化立即取消任务并恢复当前事实。锁定构图可以预览，但购买入口必须是独立 Button，不得嵌套交互。

## 5. 自动化门禁

必须覆盖：

- Timeline 只包含当前 entry、当天剩余的三个集中氛围边界与 `nextDayBoundary` entry，最多五条；
- 零点 entry 重新投影新逻辑日，而非复制旧 snapshot；
- Gallery 与 Extension 初始化同一 Renderer，不存在 legacy variant 参数；
- Gallery 预览投影只改变展示时间与今天状态，过去六日事实保持不变，且不会触发正式签到；
- 源码、token、Asset Catalog、原型和文档均无 sky / cloud / fish、密集 phase keyframe 或持久化视觉状态遗留；
- Debug、Release、Analyze 与 Widget UI 截图通过。

## 6. 真机验收

自动化只能证明静态终态、布局和代码契约。真机验收必须确认：系统是否在可接受的近似时段交付氛围 entry、签到后是否实际刷新、一次过渡是否自然、Reduce Motion、深浅色、Tinted/Clear、StandBy 与 Always-On。不得把 06:00 / 12:00 / 18:00 的计划边界宣传成系统准点展示；未完成这些检查前，不得把 Widget 宣称为 runtime GO。
