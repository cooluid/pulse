# iOS 原生视觉事实基线

核对日期：2026-08-10

## Apple 官方设计事实

- iOS / iPadOS 的系统字体是 SF Pro；系统文本样式原生支持 Dynamic Type，应优先使用系统字体与内置文本样式。
- 系统提供 `label`、`secondaryLabel` 等语义文字颜色，应按信息层级使用，而不是硬编码近似灰色。
- iOS 提供 system 与 grouped 两套动态背景色；普通内容使用 system 背景，分组列表使用 grouped 背景。
- 动态系统颜色会适配浅色、深色以及增加对比度等辅助功能设置；不应复制它们当前版本的固定 RGB 数值。
- Tab bar 用于顶层导航，标签应简短明确；工具栏用于当前页面操作。

## 对一日一印的约束

- 页面背景由系统背景 API 决定：浅色为系统白，深色为系统黑。
- 用户要求的“纯黑”用于深色模式与核心签到图形；浅色模式保持系统纯白，避免大面积强制黑底影响日间阅读。
- 中文、英文均使用系统字体和系统文本样式，不再使用 serif 设计变体。
- 状态不能只靠颜色：已签到继续同时使用勾形与文案。
- 不引入自定义渐变、暖纸、朱砂、茶绿、毛玻璃或装饰阴影。

## 官方来源

- https://developer.apple.com/design/human-interface-guidelines/color
- https://developer.apple.com/design/human-interface-guidelines/labels
- https://developer.apple.com/design/human-interface-guidelines/typography
- https://developer.apple.com/design/human-interface-guidelines/tab-bars
- https://developer.apple.com/design/human-interface-guidelines/toolbars
