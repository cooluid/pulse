# Pulse 产品文案合同

文档版本：1.0  
状态：Canonical Content Design Contract  
更新时间：2026-08-14

## 1. 责任边界

本文约束一日一印 1.1 的全部用户可见文字，包括 App、Widget、Live Activity、通知、权限说明、错误、购买页、AppIntent 与 StoreKit 商品测试配置。

- 中文产品名为“一日一印”，英文产品名为“Pulse”。
- 精确运行时文案以 `pulse/Localizable.xcstrings`、`PulseWidgets/Localizable.xcstrings` 与 `pulse/InfoPlist.xcstrings` 为唯一真源。
- App Store 商品文案由 App Store Connect 持有；仓库内 `Config/PulseEnhancements.storekit` 必须使用同一产品命名和价值描述。
- 设计文档、原型注释、代码类型名和测试术语不是用户文案来源，不能直接复制到界面。

## 2. 正式词汇

| 用户概念 | 简体中文 | English | 不得使用的用户界面替代词 |
| --- | --- | --- | --- |
| 每日核心动作 | 签到 | Check In | 留印、落印、写入事实 |
| 用户设置的目标 | 我的一件事 | My One Thing | 主承诺、Habit、identity |
| Widget 外观选择 | 小组件样式 | Widget Style | 构图、composition、皮肤 |
| 一次买断内容 | 高级功能 | Advanced Features | 高阶权益、Advanced Benefits、Pro 权限 |
| 当日影像 | 照片 / 今日照片 | Photo / Today’s Photo | 媒体事实、入镜资产 |
| 免费 Widget 样式 | 待落之处 | Awaiting Place | 免费构图、基础皮肤 |

“一日一印”“待落之处”“落印”“叠印”“数影”“手札”“静场”“来路”“潮痕”可以作为产品或样式专名。专名不能替代动作、状态或错误说明。

## 3. 写作规则

1. 先写用户事实，再写下一步。状态必须说明是否已签到、是否已保存、是否已购买或是否可重试。
2. 按钮使用动作：签到、拍照、查看照片、删除、重试、恢复购买。标题不承担操作说明。
3. 样式描述只说明展示的信息和阅读特点，不解释设计师如何画它。
4. 错误必须说明未完成的结果和可执行恢复方式；不得暴露数据校验、共享存储、渲染器、fallback、虚构价格等实现术语。
5. 破坏性文案必须明确删除对象、保留对象和不可恢复性，不用品牌语气弱化风险。
6. 收费文案只列已经发布的能力、真实价格和购买类型，不承诺路线图，不制造稀缺性。
7. 中文使用自然书面口语；英文使用 sentence case。不得用全大写口号、翻译腔、无信息量的“高级感”形容词或强行押韵。
8. VoiceOver 文案与视觉文案使用同一事实词汇，可以补充操作后果，但不能发明第二种产品语言。

## 3.1 输入长度

- “我的一件事”使用领域层统一的 4–12 个 Swift `Character`，界面显示同一范围与实时计数，不复制另一套限制。
- 可选备注最多 160 个字符，不进入 Widget、通知或其他系统表面。
- 加密备份密码至少 4 个 Swift `Character`，不要求字符组合；界面必须明确无法找回，导出继续要求二次确认。

## 4. 禁止进入运行时描述的语言

以下词语属于设计或工程内部语言，不得出现在用户可见的说明、状态、错误和购买文案中：

- 大开口日环、开放日环、承印坑、潮唇、巨大剪影、蜡封、邮戳；
- 主承诺、高阶权益、小组件构图、小组件事实、共享存储、数据校验、虚构价格；
- open seal、imprint well、postmarks、widget facts、shared store、Advanced Benefits、Main Commitment。

## 5. 验收

- 每次修改用户文案都要同时检查简体中文与 English，并验证 String Catalog 可解析。
- App 与 Widget 对同一事实必须使用同一词汇；系统托管 AppIntent 文案不得另起一套说法。
- 默认字号、Accessibility 字号、iPhone、iPad、通知、Widget Gallery 和真实 Widget host 分别检查截断与朗读。
- 自动化必须拒绝本合同列出的内部词语重新进入正式字符串资源。
