# Pulse 开发文档

本目录是 Pulse 日签到功能的开发依据。为了避免规则重复和漂移，各文档各自承担一类职责。

## 文档职责

| 文档 | 唯一职责 | 主要读者 |
| --- | --- | --- |
| [PRODUCT_REQUIREMENTS.md](./PRODUCT_REQUIREMENTS.md) | 定义用户价值、功能范围、交互状态和产品验收 | 产品、设计、开发、测试 |
| [RELEASE_SCOPE_1_1.md](./RELEASE_SCOPE_1_1.md) | 冻结 1.1 正式范围、排除项、发布身份和上线门禁 | 产品、发布负责人、开发、测试 |
| [DOMAIN_CONTRACT.md](./DOMAIN_CONTRACT.md) | 定义逻辑日、签到/影像事实、唯一性、连续天数和删除语义 | 开发、测试 |
| [TECHNICAL_DESIGN.md](./TECHNICAL_DESIGN.md) | 定义架构、数据模型、服务边界和失败处理 | 开发、评审 |
| [TEST_PLAN.md](./TEST_PLAN.md) | 定义自动化、手工、设备与发布前验证 | 开发、测试 |
| [IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md) | 记录当前实现范围、验证证据和发布门槛 | 全员 |
| [PRODUCT_STRATEGY_2_X.md](./PRODUCT_STRATEGY_2_X.md) | 定义长期定位、功能组合、收费边界与验证方法 | 产品、设计、商业、开发 |
| [PULSE_RITUAL_CONTRACT.md](./PULSE_RITUAL_CONTRACT.md) | 定义 Widget、Live Activity、灵动岛、锁屏、Apple Watch、系统动效和提醒通道的统一产品语义 | 产品、设计、开发、测试 |
| [WIDGET_SHARED_STORE_CONTRACT.md](./WIDGET_SHARED_STORE_CONTRACT.md) | 定义基础 Widget、唯一 App Group store、跨进程签到、隐私与能力准入门禁 | 产品、开发、测试、发布负责人 |
| [DATA_ENCRYPTION_CONTRACT.md](./DATA_ENCRYPTION_CONTRACT.md) | 定义设备内文件保护、加密备份容器、口令/KDF、失败语义与内购边界 | 产品、安全、开发、测试、发布负责人 |

逐构建证据不承担产品合同职责：Build 1/2/4/5 的历史候选证据保留在对应 `RELEASE_CANDIDATE_*` 文件；首次公开的 `1.1 (9)` 事实与源码追踪缺口记录在 [RELEASE_BASELINE_1_1_9.md](./RELEASE_BASELINE_1_1_9.md)。当前结论始终以 [IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md) 为准。

## 优先级定义

- `P0`：MVP 必须完成；缺失时不能认为日签到功能可用。
- `P1`：首个可发布版本应完成；可以在核心链路稳定后开发。
- `P2`：后续增强；不得阻塞 MVP。

## 当前已确认的产品假设

- 首版服务单用户、单签到项目。
- 首版不需要账号和网络即可完整签到、拍照、查看和备份。
- 签到是个人记录，不承担考勤、防作弊或合规证明用途。
- 首版不支持补签，但允许用户删除错误记录。
- 历史、首页和统计全部从持久化签到记录派生。
- 首版固定一个签到时区和 00:00 日界线，系统时区变化不会自动改写历史。

## 后续版本仍需确认

`1.1 (9)` 已经公开。当前开发线的每次新构建仍必须关闭以下门禁：

1. 当前最低系统版本统一为 18.0；发布前必须完成 iOS / iPadOS 18 可用最旧运行时与对应真机覆盖，不能只验证较新系统。
2. 1.1 已选择本地优先、iOS Data Protection 与包含照片的口令加密备份恢复；发布文案必须明确卸载和密码不可找回边界，CloudKit 不进入 1.1。
3. App 的正式版本号、商店文案与截图；Bundle ID、中英文显示名称、隐私说明和支持入口已经冻结。

生产设计见 [`design`](../design/README.md)。颜色与 AppIcon 走令牌生成链。商店素材仍需独立确认。

## 变更规则

- 签到规则发生变化时，先修改 `DOMAIN_CONTRACT.md`，再改实现和测试。
- 产品范围发生变化时，先修改 `PRODUCT_REQUIREMENTS.md` 与 `RELEASE_SCOPE_1_1.md`。
- Widget、Live Activity、灵动岛、Apple Watch 或提醒通道语义变化时，先修改 `PULSE_RITUAL_CONTRACT.md`，再改实现和测试。
- Widget 的共享数据位置、schema 或跨进程写入变化时，先修改 `WIDGET_SHARED_STORE_CONTRACT.md`，不得在 Widget target 内另建数据路径。
- 不在多个文档复制完整算法；其他文档通过链接引用业务规则。
- 完成一项任务时，必须同时满足对应自动化测试和手工验收，不以“能编译”代替完成。
