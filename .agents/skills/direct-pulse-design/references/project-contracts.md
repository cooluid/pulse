# Pulse 项目合同与证据路由

先确认文档责任边界，避免把路线图、探索草稿和领域事实混成一份真源。

## 每次必读

从技能目录到仓库根目录为 `../../..`。

- `../../../docs/RELEASE_SCOPE_1_1.md`：发布范围
- `../../../docs/IMPLEMENTATION_STATUS.md`：实现与证据状态（报告，不是视觉锁）
- `../../../design/brand-tokens.json`：颜色工程入口
- `../../../design/BRAND_SPEC.md`：产品/工程规范；**§5A Widget 美术不锁死**
- 本次目标对应的 SwiftUI / 字符串 / 测试

**美术探索不以合同否决。** 事实、权益、隐私、无障碍才是硬合同。

## 按问题类型

| 问题 | 权威 |
| --- | --- |
| 日期、签到、统计、删除、导入 | `DOMAIN_CONTRACT.md` |
| 产品任务与 P0 | `PRODUCT_REQUIREMENTS.md` |
| 1.1 范围 | `RELEASE_SCOPE_1_1.md` |
| 颜色工程 | `brand-tokens.json` |
| Widget 产品/事实 | `BRAND_SPEC.md` §5A、共享 store / ritual 合同中的事实条款 |
| Widget 外观 | 代码 + 截图；原型 HTML 仅参考 |
| 仪式时序 | `PULSE_RITUAL_CONTRACT.md`（事实时序，不是画法） |

## 冲突

- 业务事实只由领域合同决定
- 美术与事实冲突时，**改正事实表达**，不是用文档禁止某画法
- `IMPLEMENTATION_STATUS` 不能把未人工验收的外观写成 GO
