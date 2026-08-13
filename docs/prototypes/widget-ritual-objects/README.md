# Widget 仪式物件方向实验室

这是 Home Screen Widget 六式物件的 **DIRECTION** HTML 原型，用来留档和继续改构图。它不是 1.1 生产真源。

正式 Home Screen 仍只消费 `PulseWidgetHomeRenderer` 的冻结五式：呼吸环、数影、深景、静序、七日谱。本页里的落印 / 叠印 / 数影 / 手札 / 静场 / 来路若要进 1.1，需要单独决定是新增收费构图，还是替换现有式。

## 打开

```sh
cd docs/prototypes/widget-ritual-objects
python3 -m http.server 8766
```

浏览器打开 `http://127.0.0.1:8766/pulse-widget-ritual-objects.html`。

画布按真实小号 `158×158`、中号 `338×158`。可切换待签到 / 已签到、浅色 / 深色。

## 不要用它做什么

- 不要覆盖 `design/BRAND_SPEC.md`、`design/brand-tokens.json` 或正式 SwiftUI 渲染器。
- 不要当商店图、画廊截图或 INTERFACE GO 证据。
- 不要把照片、备注、连续天数或 4/7 分数加进这六式。
