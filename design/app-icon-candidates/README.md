# Pulse AppIcon 候选

状态：B2 已由用户选定；B1 / B3 仅保留为设计决策记录。

- `B1-quiet-seal.png`：实心日印，以负形勾表达一次完成。
- `B2-open-day-ring.png`：开放日环，环与勾为同一连续记号。
- `B3-horizon-mark.png`：日落地平记号，把每日结束与完成合并。

共同约束来自 [`../BRAND_SPEC.md`](../BRAND_SPEC.md)：无文字、无渐变、无阴影、不预切系统圆角，并审查 1024 / 180 / 60 / 40 / 29 尺寸。正式资源的外观透明度遵循 Apple 的 Default / Dark / Tinted 要求。

生成模式：三个独立的 `logo-brand` 文生图候选；生成源保留在 Codex 的 generated_images 目录，本目录保存项目评审副本。B2 的生成稿只承担图形决策证据，生产资源使用独立的单色遮罩真源，不直接消费生成稿的渐变像素。
