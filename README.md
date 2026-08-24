# 一日一印（Pulse）

一日一印（英文名 Pulse）是一个本地优先的 iPhone / iPad 私人日印应用：用户为一个重要承诺每天可靠签到，并可在签到后自愿留下一张只保存在本机的“今日入镜”。

当前仓库已经完成本地优先日签到的产品级实现。需求、规则、技术方案、测试标准和当前验收状态统一整理在 [`docs`](./docs/README.md) 中。

## 当前状态

- 产品阶段：核心功能进入发布前工程收口；外观可继续迭代、人工验收。自动化结果见实现状态，真机、通知、最终视觉与分发仍是独立门禁
- 共享业务 target：`PulseCore`（静态、extension-safe，领域、schema、Repository 与导入导出唯一实现）
- App target：`pulse`
- 测试 target：`pulseTests`、`pulseUITests`
- 最低系统版本：iOS / iPadOS 18.0
- 数据策略：App Group store 使用 iOS Data Protection；只支持口令保护的版本化 `.pulsebackup` 导出与全量恢复
- 工程基线：Swift 6 严格并发、所有 target 警告即错误

## 文档入口

- [代理须知](./AGENTS.md)：编码代理的工作人格与合同入口
- [文档总览](./docs/README.md)
- [产品需求](./docs/PRODUCT_REQUIREMENTS.md)
- [1.1 发布范围合同](./docs/RELEASE_SCOPE_1_1.md)
- [签到业务规则](./docs/DOMAIN_CONTRACT.md)
- [技术设计](./docs/TECHNICAL_DESIGN.md)
- [测试与验收计划](./docs/TEST_PLAN.md)
- [实现与验收状态](./docs/IMPLEMENTATION_STATUS.md)
- [1.x–3.0 产品战略与商业化规划](./docs/PRODUCT_STRATEGY_2_X.md)
- [日印仪式：Widget、灵动岛、Apple Watch 与系统提醒合同](./docs/PULSE_RITUAL_CONTRACT.md)
- [基础 Widget、App Group 与共享 Store 合同](./docs/WIDGET_SHARED_STORE_CONTRACT.md)
- [生产设计](./design/README.md)

## 开发原则

1. `CheckInRecord` 是签到事实的唯一来源；`ImprintMedia` 是独立影像事实，二者不得互相伪造。
2. 同一签到项目、同一逻辑日最多存在一条记录。
3. 签到成功以持久化成功为准，不以按钮动画或内存状态为准。
4. 日期、连续天数和提醒都依赖同一套逻辑日规则。
5. 先保证可靠、可测试，再增加积分、勋章、小组件或云同步。
6. 主承诺身份与签到事实共用同一个 `Habit` 真源；确认、编辑、导入和清除不得另存 onboarding 或名称副本。
