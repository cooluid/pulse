# Pulse 测试与验收合同

文档版本：1.0  
状态：Canonical Gate

## 1. 自动化门禁

每次发布候选必须通过：

1. Swift 6 警告即错误的 Debug 与 Release 构建；
2. Xcode 静态分析；
3. 全量单元、集成与 UI 测试；
4. `python3 scripts/build_brand_assets.py --check`；
5. String Catalog 和 Asset Catalog 编译。

测试使用内存 SwiftData 容器、独立 UserDefaults suite、显式时区和可变/固定 Clock，不依赖运行测试当天的真实日期。

## 2. 领域与数据对抗矩阵

| 范围 | 必须证明 |
| --- | --- |
| 日期 | 零点、跨月、跨年、闰年、DST；存储格式不受 Locale 影响 |
| 项目 | 主 slot 唯一；起始日在创建后稳定；当前时区变化不改写起始日 |
| 签到 | Repository 权威 Clock；同日幂等；跨日新增；起始日前拒绝；无补签 API |
| 删除/清除 | 删除只影响目标；失败不提前关闭；清除日志可在下次启动完成 |
| 统计 | 空集合、今天/昨天、多段连续、乱序、重复、删除后重算 |
| 导入 | format/schema、文件/数量上限、名称、时区、起始日来源、记录时区映射、时间顺序、ID/日期唯一 |
| 原子性 | 无效导入不删除现有数据；保存失败 rollback |
| 提醒 | 权限拒绝；旧权限结果不能覆盖新意图；快照与最新记录一致；失败无部分计划 |

首个公开版本之后，任何 SwiftData 或 JSON schema 变化都必须增加上一发布版本 fixture 和迁移测试。

## 3. UI 自动化

- 首次启动显示可签到状态。
- 签到后按钮不可重复触发并显示真实时间。
- 终止重启后事实仍存在。
- 历史页统计与月历同步。
- 设置入栈时根导航隐藏，返回后恢复。
- 7 个星期标题身份稳定。
- 测试通过 UUID store 与 `PULSE_UI_TEST_RESET` 隔离数据，通过 `PULSE_UI_TEST_NOW` 固定业务时间。

## 4. 独立人工门禁

自动化不能替代以下证据：

- iPhone / iPad 真机安装、重启持久化、删除与完整清除；
- 通知首次授权、拒绝后恢复、设定时间到达、签到后取消、修改时间无旧请求；
- 浅色/深色、高对比度、降低透明度、Reduce Motion；
- Dynamic Type 默认至 Accessibility 最大字号、VoiceOver 主流程；
- iPad 竖横屏和分屏；
- AppIcon 的 Default / Dark / Tinted 与商店素材；
- 签名、Archive、TestFlight 和 App Store 校验；
- 跨多个自然日的连续使用。

## 5. 阻断标准

- P0：记录丢失/重复、错误逻辑日、统计事实错误、清除错误目标、无效导入破坏现有数据。
- P1：通知持续错误、关键布局不可用、删除失败假成功、VoiceOver 无法完成主流程。
- P2：不阻断主流程的视觉、动效或文案问题。

任何未关闭 P0 阻止工程 GO；工程 GO 也不能替代真机、通知、视觉和发布门禁。
