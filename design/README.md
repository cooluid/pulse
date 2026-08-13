# Pulse 生产设计合同

本目录只保存当前生产视觉的权威合同与生成真源：

- [已冻结的品牌与界面规范](./BRAND_SPEC.md)
- [正式 AppIcon 多外观与小尺寸评审图](./app-icon-review.png)
- [`brand-tokens.json`](./brand-tokens.json)：所有正式颜色的唯一真源。
- `app-icon-source/`：正式开放日环遮罩真源。

当前唯一视觉方向为“草野脉冲”：轻量日期 × 同心场 × 深草行动印 × 状态式悬浮底栏。正式 SwiftUI 界面、AccentColor、品牌标记和 AppIcon 共用一份品牌令牌与同一开放日环遮罩，并由 `scripts/build_brand_assets.py` 生成。生成检查按 JSON 字节与 PNG 解码像素判断一致性，不受本机 PNG 压缩器版本影响。

生产合同只认 `BRAND_SPEC.md`、`brand-tokens.json`、`app-icon-source/` 与对应 SwiftUI 实现。方向候选和旧实现已经退出本目录；历史由版本控制承担，不能成为第二套设计真源。最终界面视觉验收与 App Store 素材验收仍是独立门禁。

Home Screen Widget 的构图方向真源是 [`docs/prototypes/widget-ritual-objects/`](../docs/prototypes/widget-ritual-objects/) 的六式：落印、叠印、数影、手札、静场、来路。[`BRAND_SPEC.md`](./BRAND_SPEC.md) §5A 跟该页。颜色仍只认 `brand-tokens.json`；未迁移的 `PulseWidgetHomeRenderer` 旧五式不能反过来否决这六式。
