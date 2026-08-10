# Pulse

Pulse 是一个本地优先的 iPhone / iPad 日签到应用。当前产品阶段聚焦一件事：让用户每天快速、可靠地记录一次签到，并能准确查看连续天数和历史记录。

当前仓库仍是 SwiftUI 初始工程，尚未进入业务实现。开发前的需求、规则、技术方案和验收标准已经整理在 [`docs`](./docs/README.md) 中。

## 当前状态

- 产品阶段：需求与技术设计已准备，等待进入实现
- 现有 target：`pulse`
- 现有测试 target：无，必须在功能开发前补建
- 当前最低系统版本：iOS / iPadOS 26.4
- 建议发布基线：评估后调整为 iOS / iPadOS 17.0 或更高
- 数据策略：MVP 本地优先，不依赖账号和服务器

## 文档入口

- [文档总览](./docs/README.md)
- [产品需求](./docs/PRODUCT_REQUIREMENTS.md)
- [签到业务规则](./docs/DOMAIN_CONTRACT.md)
- [技术设计](./docs/TECHNICAL_DESIGN.md)
- [开发计划](./docs/DEVELOPMENT_PLAN.md)
- [测试与验收计划](./docs/TEST_PLAN.md)

## 开发原则

1. `CheckInRecord` 是签到事实的唯一来源，页面状态和统计结果不得另存一份。
2. 同一签到项目、同一逻辑日最多存在一条记录。
3. 签到成功以持久化成功为准，不以按钮动画或内存状态为准。
4. 日期、连续天数和提醒都依赖同一套逻辑日规则。
5. 先保证可靠、可测试，再增加积分、勋章、小组件或云同步。

