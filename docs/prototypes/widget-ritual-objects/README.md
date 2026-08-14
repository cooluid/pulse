# Widget 仪式物件

这是 Home Screen Widget 的 **正式方向清单真源**：待落之处、落印、叠印、数影、手札、静场、来路、潮痕。

待落之处以 [`widget-awaiting-place/pulse-widget-awaiting-place.html`](../widget-awaiting-place/pulse-widget-awaiting-place.html) 为像素构图真源；落印至来路六式的构图、剪影、待办/完成语言以本目录 HTML 为准；潮痕以 [`01-tide-mark/pulse-widget-tide-mark.html`](../widget-style-experiments/01-tide-mark/pulse-widget-tide-mark.html) 为像素构图真源。[`design/BRAND_SPEC.md`](../../../design/BRAND_SPEC.md) §5A 与仪式/产品合同跟本清单。旧五式（呼吸环、深景、静序、七日谱）不再作为视觉依据。

唯一免费默认是 [widget-awaiting-place · 待落之处](../widget-awaiting-place/)；落印与其余六式统一属于高阶权益。新风格逐个实验见 [widget-style-experiments](../widget-style-experiments/)。

`PulseWidgetHomeRenderer` 已按本清单八式迁入正式共享渲染源；原型仍是方向与像素比对真源，不是商店图，也不是 `INTERFACE GO`。

## 打开

```sh
cd docs/prototypes/widget-ritual-objects
python3 -m http.server 8766
```

浏览器打开 `http://127.0.0.1:8766/pulse-widget-ritual-objects.html`。

画布按真实小号 `158×158`、中号 `338×158`。主屏示意按 iPhone 逻辑宽 `393`，必须完整放下两枚小号和一枚中号。可切换待签到 / 已签到、浅色 / 深色。

## 不要用它做什么

- 不要覆盖 `design/brand-tokens.json` 或未迁移的 SwiftUI 渲染器。
- 不要当商店图、画廊截图或 INTERFACE GO 证据。
- 不要把照片、备注、连续天数或 4/7 分数加进这八式。
