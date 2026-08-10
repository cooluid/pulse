# Pulse 设计评审

本目录保存正式视觉进入生产资产前的设计依据和评审材料。

- [品牌现状与资产清单](./BRAND_CONTEXT.md)
- [已冻结的品牌与界面规范](./BRAND_SPEC.md)
- [iOS 原生设计事实基线](./IOS_NATIVE_PRODUCT_FACTS.md)
- [历史：iOS 原生黑白方案画布](./ios-native-variations.html)（已退出生产方向）
- [历史视觉方向评审画布](./visual-directions.html)
- [草绿“今天”导航方向与可交互原型](./today-navigation-grass-directions.html)（C 脉冲场 × A 状态底栏的决策证据）
- [正式 AppIcon 多外观与小尺寸评审图](./app-icon-review.png)
- [`brand-tokens.json`](./brand-tokens.json)：所有正式颜色的唯一真源。
- `app-icon-source/`：正式开放日环遮罩真源。
- `app-icon-candidates/`：B1 / B2 / B3 生成候选和决策证据，不是运行时资源。
- `reference/`：从真实应用运行结果提取的评审截图，不是重新绘制的假界面。

当前唯一视觉方向为“草野脉冲”：C 脉冲场今日页 × A 状态式底栏。正式 SwiftUI 界面、AccentColor、品牌标记和 AppIcon 共用一份品牌令牌与同一开放日环遮罩，并由 `scripts/build_brand_assets.py` 确定性生成。最终界面视觉验收与 App Store 素材验收仍是独立门禁。

HTML 原型只保留为方向决策证据，不参与运行时、构建或资产生成；生产合同只认 `BRAND_SPEC.md`、`brand-tokens.json` 与对应 SwiftUI 实现。历史画布不能作为当前视觉验收证据。
