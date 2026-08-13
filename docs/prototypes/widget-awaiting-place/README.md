# Widget 免费默认：待落之处

探索方向：把 **落印** 收进高阶权益后，Home Screen 需要一个新的 **唯一免费默认构图**。本页只画这一件，不从现有七式里挑选。

- 物件名：**待落之处**（Awaiting Place）
- 任务：今天这里还空着吗 · 现有今日快照
- 叙事：免费是等印落下的位置；收费的落印才是印本身
- 命名：刻意不用两字格，避免和七式硬齐成「XX」词牌
- 尺寸：小号 `158×158`、中号 `338×158`
- 状态：待签到 / 已签到 · 浅色 / 深色

七式仪式物件仍以 [widget-ritual-objects](../widget-ritual-objects/) 的正式清单为准。本页是免费默认的方向探索，**尚未**写入正式权益合同；定稿前不得当成 `INTERFACE GO`。

## 打开

```sh
cd docs/prototypes/widget-awaiting-place
python3 -m http.server 8767
```

浏览器打开 `http://127.0.0.1:8767/pulse-widget-awaiting-place.html`。

## 不要用它做什么

- 不要用开放日环当主角（那是落印）。
- 不要加七日轨迹、分数、连续天数或仪表盘指标。
- 不要覆盖 `design/brand-tokens.json` 或未迁移的 SwiftUI 渲染器。
