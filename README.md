# Pulse

Pulse 是一个本地优先的 iPhone / iPad 日签到应用。当前产品阶段聚焦一件事：让用户每天快速、可靠地记录一次签到，并能准确查看连续天数和历史记录。

当前仓库已经完成本地优先日签到的产品级实现。需求、规则、技术方案、测试标准和当前验收状态统一整理在 [`docs`](./docs/README.md) 中。

## 当前状态

- 产品阶段：核心功能与 B 方向视觉工程完成；真实设备核心流程曾通过，新 Bundle ID 的安装与通知聚焦复验待完成
- App target：`pulse`
- 测试 target：`pulseTests`、`pulseUITests`
- 最低系统版本：iOS / iPadOS 17.0
- 数据策略：本地优先，支持版本化 JSON 导出和全量恢复
- 自动化状态：31 项单元、集成与 UI 测试通过

## 文档入口

- [文档总览](./docs/README.md)
- [产品需求](./docs/PRODUCT_REQUIREMENTS.md)
- [1.0 发布范围合同](./docs/RELEASE_SCOPE_1_0.md)
- [签到业务规则](./docs/DOMAIN_CONTRACT.md)
- [技术设计](./docs/TECHNICAL_DESIGN.md)
- [开发计划](./docs/DEVELOPMENT_PLAN.md)
- [测试与验收计划](./docs/TEST_PLAN.md)
- [实现与验收状态](./docs/IMPLEMENTATION_STATUS.md)
- [视觉方向评审](./design/README.md)

## 开发原则

1. `CheckInRecord` 是签到事实的唯一来源，页面状态和统计结果不得另存一份。
2. 同一签到项目、同一逻辑日最多存在一条记录。
3. 签到成功以持久化成功为准，不以按钮动画或内存状态为准。
4. 日期、连续天数和提醒都依赖同一套逻辑日规则。
5. 先保证可靠、可测试，再增加积分、勋章、小组件或云同步。
