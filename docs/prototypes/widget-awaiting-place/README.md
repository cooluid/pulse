# Widget 正式免费默认：待落之处

正式方向：**待落之处**是 Home Screen 的唯一免费默认构图；**落印**与另外六式由同一个高阶权益解锁。本页是待落之处的小号/中号、待办/完成、浅色/深色像素构图真源。

- 物件名：**待落之处**（Awaiting Place）
- 任务：今天这里还空着吗 · 现有今日快照
- 叙事：免费是等印落下的位置；收费的落印是印本身
- 命名：刻意不用两字格，避免和另外七式硬齐成「XX」词牌
- 尺寸：小号 `158×158`、中号 `338×158`
- 状态：待签到 / 已签到 · 浅色 / 深色

八式完整清单以 [widget-ritual-objects](../widget-ritual-objects/) 为准；正式权益合同与共享渲染器均使用 `place` 作为逐实例默认值。此 HTML 是方向与像素对照，不代替真实 Widget host 的 `INTERFACE GO`。

## 打开

```sh
cd docs/prototypes/widget-awaiting-place
python3 -m http.server 8767
```

浏览器打开 `http://127.0.0.1:8767/pulse-widget-awaiting-place.html`。

## 不要用它做什么

- 不要用开放日环当主角（那是落印）。
- 不要加七日轨迹、分数、连续天数或仪表盘指标。
- 不要引入渐变、独立颜色值、全局样式存储或第二套 SwiftUI 预览渲染器。
