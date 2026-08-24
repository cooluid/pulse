# Pulse Widget 运行与动效边界

文档版本：4.0
状态：Canonical System Contract
更新日期：2026-08-24

本文只定义 Widget 的事实和系统行为，不定义构图、材质、物件、颜色、图层、动画风格或设计意图。外观由当前 Renderer 自由实现并由人验收。

## 1. 事实

- Widget 只从唯一 Repository 投影签到事实，不持久化视觉状态或第二份签到状态。
- 任何完成表现只能在权威签到提交成功并由 WidgetKit 交付新 timeline 后出现。
- Gallery 可以用内存投影预览变化，但不得写 Repository、App Group、UserDefaults 或正式 Widget Timeline。
- 氛围、装饰和动画不得改变日期、签到、历史、权益或文案事实。

## 2. 系统行为

- Home / Accessory Widget Intent 提交后使用 WidgetKit 保证的 timeline reload；Live Activity 通过其正式 App 进程路径刷新相关系统表面。
- Timeline 必须覆盖下一逻辑日边界，不能跨日继续投影昨天的“今天”。是否增加其他纯视觉 entry 由实现决定，不写进产品合同。
- 单次 Widget / Live Activity 动画遵守 Apple 当前平台上限；Reduce Motion 和 Always-On / 低亮度场景提供可用静态结果。
- 系统不保证 timeline 准点展示，产品文案不得承诺精确出现时刻。

## 3. 测试边界

自动化可以验证：

- 事实提交、幂等、失败和跨日投影；
- 预览不写业务事实；
- Reduce Motion、Always-On 和平台动画上限；
- AppIntent 进程、reload 和共享 store 的功能结果。

自动化不得验证具体物件、构图、颜色、图层、View 层级、SwiftUI 条件分支、动画材料/曲线、氛围时段数量、像素差或截图哈希。渲染附件只供人工查看。

## 4. 人工验收

在真实 Widget host 上检查操作、刷新、可读性、Reduce Motion、深浅外观、Tinted/Clear、StandBy 与 Always-On。人工可以要求重画，但不能把本次审美结论写成未来测试门禁。
