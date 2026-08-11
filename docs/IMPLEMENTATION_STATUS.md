# Pulse 实现与验收状态

更新时间：2026-08-11  
当前结论：核心签到、主承诺身份与 App 内基础日印仪式的自动化工程门禁 GO；唯一静态 `PulseCore` target 已落地并由 App 正式消费，纯值边界、持久化语义校验和写入竞争回读基础 GO。基础 Widget / App Group 的产品、共享 store 搬迁和跨进程合同已完成设计评审；App Group entitlement、正式共享 store、Widget extension 与真实跨进程交互仍保持 NO-GO。公开隐私/支持入口与既有开发签名 Archive 仍只作为历史工程证据。真机动态手感、iOS 17.x、完整可访问性、最终视觉、连续使用与 App Store 分发身份仍为独立 NO-GO，当前不能宣称可上线。

## 当前生产实现

- 单用户、单签到项目；`CheckInRecord` 是历史、日历和统计的唯一事实源。
- `Habit` 是唯一主承诺身份真源；名称、可选“为什么重要”和确认状态不在页面、设置或通知中保存副本。未确认前不进入签到主界面，编辑身份不改写签到事实。
- 主承诺输入统一经过 `HabitIdentity` 规范化和验证，Repository 独占写入；名称到说明具备明确键盘焦点链，失败保留输入并显示真实错误。
- 今日页将主承诺放入“保持自己的节奏，不与别人比较”的节奏容器，不再作为日期与签到之前的第二个页面标题；Accessibility 字号下容器改为纵向布局。
- 项目 slot、记录 ID 和逻辑日唯一性由持久化层与导入校验共同约束。
- 1.0 日界线固定为签到时区当地 00:00；不保留非零日界线字段或兼容分支。
- Repository 独占权威 Clock 和所有 SwiftData 写入；无补签日期参数，保存失败回滚。
- 起始逻辑日、创建时区、当前签到时区和每条记录的发生时区均显式保存，时区变化不改写历史事实。
- JSON 导出当前只写 `co.fanr.pulse.export` v2；读取按精确版本分派，正式 v1 单向升级到 v2 内存模型，未知版本与缺失格式标识失败关闭。导入在任何删除前完成身份、大小、时区、来源、时间顺序及唯一性校验。
- 签到、删除、导入、清除和时区变更由单一操作状态串行化，失败不会提前关闭界面或报告成功。
- Repository 签到写入返回只描述本次 `created` / `alreadyPresent` 的瞬时提交回执；`CheckInRecord` 仍是完成状态唯一持久化事实，App 在重新载入权威快照后才允许触觉和成功呈现。
- SwiftData managed object 不再离开 Repository；AppModel、Today 与 History 只持有不可变、`Sendable` 的 `HabitSnapshot` / `CheckInRecordSnapshot`，页面无法绕过 Repository 修改持久化模型。
- 领域、schema/migration、Repository、验证和导入导出合同只由 extension-safe 静态 `PulseCore` 编译；App 通过模块依赖消费，不再把同一源码编进宿主 target。Core 不依赖页面、通知、UserDefaults、触觉或宿主本地化资源。
- Repository 在快照越过模块边界前统一验证身份规范、起始日来源、当前/创建/记录时区、recordKey、时间顺序和逻辑日唯一性；对外快照的逻辑日与时区是已验证的非可空值，损坏事实诚实失败。
- Repository 新建签到保存失败后会 rollback、丢弃原 ModelContext 并按同一 `recordKey` 从正式 store 回读；只有查到另一写入者已经提交的记录才返回 `alreadyPresent`，其他持久化错误继续诚实失败。
- 完整清除使用持久化操作日志；跨 SwiftData、UserDefaults 和通知中心中断后，下次启动幂等续做。
- 提醒调度只消费不可变值快照；单调 revision 防止旧权限或旧任务覆盖最新用户意图，权限外撤或部分调度失败会关闭虚假启用状态并清理已提交请求。
- 提醒计划由纯值计划器生成，从今天起滚动覆盖 60 个日历日并预留 4 个系统待处理名额；已过时刻、已签到日与 DST 不存在时间均有显式测试，超过窗口且 App 未再次打开时不承诺继续送达。
- 主题模式以 `AppSettings` 为唯一持久化状态，支持跟随系统、浅色、深色并由根窗口即时应用；应用语言支持跟随系统、English、简体中文。
- 语言切换同时覆盖 SwiftUI 文案、日期/星期/时间、时区名称、错误与辅助功能标签，并以 Locale 快照重新排期通知；代码生成字符串显式选择语言资源包，不依赖进程级系统语言猜测。
- UI 采用语义字体、Dynamic Type、Reduce Motion、VoiceOver 状态文本，以及签到勾选、漏签减号和今天边框等非纯颜色日历标记；Accessibility 最大字号下主操作改为可扩展胶囊。
- iPad 常规字号使用今日与历史各自的双区构图，不再复用居中的 iPhone 单列；脉冲场几何、环距与渐隐按宽度环境响应。
- 主导航在常规字号使用共享选中背景与根内容过渡，在 Accessibility 字号切换为等宽数字入口；滚动内容按底栏实测高度保留末端清空区，设置入栈后根页从辅助功能树隔离。
- 待签到页每次成为当前页最多进行一次 1.4 秒有限呼吸，背景场保持静态；生产 Swift 源码不存在无限循环动画。
- 签到保存中只显示中性状态；新建事实后运行 `ready → saving → contracting → imprinting → imprinted` 的 0.62 秒瞬时呈现，空心印记收缩后形成实心印记，再更新周轨迹和连续数字。启动时已有记录直接显示静态完成态，不重播仪式；失败恢复待签到并保留真实错误。
- Reduce Motion 下不进行缩放、回弹、扩散或呼吸，只以 0.18 秒淡入和形状替换表达同一已提交事实；快速本地写入不闪现加载器。
- 历史月份提供可见按钮、滑动和辅助功能动作的单一状态入口，日历按方向切换；宽屏统计区保持固有高度。
- Swift 6 严格并发与警告即错误应用于 `PulseCore`、App、单元测试和 UI 测试配置；Core 另启用 `APPLICATION_EXTENSION_API_ONLY`。
- `PrivacyInfo.xcprivacy` 声明 UserDefaults 的 `CA92.1` 必要原因以及不跟踪、不收集；设置页直接链接 `https://fanr.co/pulse/privacy/` 与 `https://fanr.co/pulse/support/`，支持邮箱为 `400822@163.com`。

详细规则以 [领域合同](./DOMAIN_CONTRACT.md)、[技术设计](./TECHNICAL_DESIGN.md) 和 [品牌合同](../design/BRAND_SPEC.md) 为准，本文件不复制算法或视觉像素参数。

## 本次删除的债务

- 删除未发布旧数据模型中的 `dayStartMinutes`、归档状态和签到来源等无消费者字段。
- 删除可由调用方注入日期的补签式接口，以及无效日期/时区的静默默认值。
- 删除旧开发 JSON 的猜测解码路径；缺少当前格式标识或完整来源字段时失败关闭。
- 删除 onboarding、设置和今日页各自保存主承诺的可能性；统一为一个 `Habit` 身份和一个 Repository 写入口。
- 删除主承诺占据日期英雄区的竞争层级；承诺与连续天数统一进入节奏容器，并补齐 Accessibility 纵向布局。
- 删除视图根据按钮点击或局部布尔值猜测签到成功的路径；成功、触觉和日印仪式统一消费 Repository 提交回执与重新载入后的权威记录。
- 删除旧整控件弹跳、持续背景场呼吸和 `repeatForever` 待签到光环；动效参数集中到一个设计合同并受两秒上限测试约束。
- 删除编辑表单依赖点击坐标切换字段的隐式行为；键盘“下一项/完成”现在驱动明确焦点状态，避免表单重排时误触保存。
- 删除提醒并发中的陈旧结果覆盖、跨异步边界持有可变模型和调度失败残留。
- 删除重复统计扫描、历史时间使用当前时区重解释、清除过程无恢复日志等隐性一致性债务。
- 删除固定大字号下会裁切的主操作形态、纯颜色完成状态、无条件动画和散落视觉常量。
- 删除 iPad 居中手机稿、Accessibility 比例底栏、历史页仅靠隐式滑动翻月，以及设置页保留隐藏根内容辅助功能焦点的旧布局假设。
- 删除品牌生成器对像素未变化 PNG 的无条件重编码；正式生成只更新真正漂移的产物。
- 删除旧方向 HTML、候选图标、过期截图与重复设计说明；Git 历史承担追溯，不在生产树中保留第二套设计真源。
- 删除已完成且持续漂移的开发计划；剩余工作只记录为可验证发布门禁。

## 自动化证据

验证环境：Xcode 26.4（17E192），iOS 18.6 iPhone 16 Pro 模拟器。部署目标仍为 iOS / iPadOS 17.0；按用户本次指示未继续下载 iOS 17.5 运行时，因此这里不把 17.x 行为标记为已验证。

- 全量测试：82 / 82 通过，其中单元与集成 70，UI 12。
- Release iOS Simulator 构建：通过。
- Release `iphoneos` 通用真机架构构建（关闭签名）：通过。
- Release Xcode 静态分析：通过，无 Swift 编译器或静态分析告警。
- 品牌资产生成器：18 项生成结果与仓库一致。
- String Catalog、品牌令牌 JSON 与 Asset Catalog：解析/编译通过。
- 隐私清单 plist 校验通过并由 Xcode 复制进 App 包；生产站三条路由和分享图均返回 HTTPS 200，线上文件与本地静态构建 SHA-256 一致。
- 十年逐日记录统计保持单一连续段；导入的跨时区起始日倒退、记录日映射错误和重复事实均失败关闭；通知权限被系统外撤后不保留虚假启用状态。
- 单元与集成自动化覆盖主承诺规范化、Emoji/不可见控制字符、幂等编辑、事实不变、JSON v1→v2 和真实 SQLite SwiftData v1→v2 迁移；本轮新增提交回执新建/幂等语义、失败不产生成功反馈、仪式阶段语义、两秒时长上限和生产源码无无限动画门禁。UI 自动化覆盖首次确认、重启保持、设置编辑、清除后重入确认、无效边界，以及主承诺位于节奏容器内的几何断言。
- 本轮新增两个独立 `ModelContainer` 访问同一磁盘 store 的集成测试：两端读取同一主项目，同日调用最终只有一个 `recordKey`，后调用返回同一记录 ID 的 `alreadyPresent`。该测试证明磁盘共享与回读基础，不替代 Widget/App 两个真实进程同时抢写的真机证据。
- `PulseCore` 独立 Debug/Release 编译、App 静态链接和 extension-safe API 检查通过；另有两个损坏持久化事实测试证明非法主承诺与错误 recordKey 不能逃出 Repository 成为部分有效快照。
- UI 自动化同时覆盖首次签到、重启后静态实心态、历史同步、显式双向翻月、漏签非颜色语义、设置辅助功能隔离、主题与语言即时切换/跨重启保持，以及 Accessibility XXXL 主操作、节奏区与等宽底栏几何。本轮已检查 iPhone 16 Pro 深色默认字号下的签到前空心态、持久化后实心态与历史同步截图；静态截图不能证明 0.62 秒时序的动态手感，该工程检查不替代真机逐帧、VoiceOver、Reduce Motion 与用户最终视觉验收。

Xcode 26.4 的 `appintentsmetadataprocessor` 在未使用 AppIntents 的 target 上仍可能输出“未发现 AppIntents.framework，跳过提取”的工具告警。它不是源码或分析告警；项目没有通过全局过滤隐藏该输出，以免同时遮蔽未来真实工具告警。

## 版本迁移基线

产品尚未上线不等于可以无条件删除已经形成的稳定数据合同。仓库中的 SwiftData v1 和带正式格式标识的 JSON v1 现在作为受控基线保留：

- SwiftData 使用冻结的 `PulseSchemaV1`、当前 `PulseSchemaV2` 和单向轻量迁移；原项目 ID、起始日、时区与签到记录保持不变，新增说明为空、身份为未确认。
- JSON v1 只通过精确 `format` / `schemaVersion` 分派映射到 v2；运行时和新导出只存在 v2 一条路径，不保留双模型、别名或猜测回退。
- 无正式格式标识的早期开发 JSON 继续明确拒绝；不能因为“兼容”而恢复不可验证内容。
- 迁移测试会创建真实 v1 SQLite 存储再由 v2 打开，防止只验证内存模型却漏掉实体名或持久化映射问题。

这类显式、单向、有测试的迁移是数据完整性合同，不是应当清理的旧兼容债务。未来每次 schema 变化继续要求上一正式版本 fixture、迁移阶段和回归测试。

## 尚未关闭的发布门禁

- 使用正式 Bundle ID `co.fanr.pulse` 在真实 iPhone 与 iPad 上安装，验证全新沙盒、签到、重启持久化、删除和完整清除；覆盖 iOS / iPadOS 17.x 设备或运行时。
- 在真机验证通知首次授权、拒绝后恢复、按时到达、签到后取消、改时无旧请求，以及系统重启后的行为。
- 人工完成 VoiceOver、最大字号、三种主题与两种语言组合、高对比度、降低透明度、Reduce Motion、旋转和 iPad 分屏验收。
- 在 1× 真机上逐帧检查基础日印的空心收缩、成印、回弹、周轨迹与连续数字时序；确认 0.62 秒参数没有闪烁、跳变或过度强调，并单独验证 Reduce Motion 静态等价表达。
- 对当前生产源码重新完成最终视觉与 AppIcon Default / Dark / Tinted 验收；历史截图不能代替当前版本证据。
- 隐私与支持页面已经公开；个人开发账号仍在审核，商店文案/截图、App Store Connect provider、分发证书/描述文件、TestFlight 与 App Store 校验按产品决策后置。当前成功的 Archive 使用开发描述文件，不是分发就绪证据。
- 完成跨多个自然日的连续使用，确认时区变更、跨日提醒和连续统计在真实生命周期中一致。

## Widget / App Group 状态

- 设计 GO：正式身份、唯一 group store、`notStarted → copying → verified → sourceRemoved → ready` 搬迁 journal、崩溃恢复、默认隐私和单向签到边界已冻结在 [Widget 共享 Store 合同](./WIDGET_SHARED_STORE_CONTRACT.md)。
- 基础工程 GO：工程已有 `PulseCore`、`pulse`、`pulseTests`、`pulseUITests` 四个 target；App 只链接唯一 `PulseCore`，同日保存竞争具备 rollback + 正式回读语义，双磁盘容器与损坏事实边界测试通过。
- 能力 NO-GO：当前仍使用 App 私有 store；没有 App Group entitlement、共享容器或 Widget extension。`PulseCore` 的存在不等于 App Group 已可用。
- 账号门禁：正式 App Group 需要 Apple Developer Program 能力、同一 Team 下的 App/Widget ID 关联和双 provisioning profile。个人账号审核完成前不加入会破坏现有签名链的半成品 capability。
- 真机 NO-GO：App 未运行、设备锁定、Widget 重载、App/Widget 同时签到、跨午夜、杀进程和升级搬迁均没有真实设备证据。

## 下一步顺序

1. 在不依赖账号能力的范围内，实现可注入目录的 store locator、搬迁 journal、值级复制、确定性摘要验证、旧源清理和每个中断状态的幂等恢复测试；仍不加入 entitlement 或 Widget target。
2. 对主承诺节奏区和 App 内基础日印完成真机逐帧、VoiceOver、Reduce Motion、长文本、浅色/深色与最终视觉验收，并继续跨自然日内部试用；这是当前实现的产品验收，不属于发布系列工作。
3. 个人开发账号审核通过后，注册 `group.co.fanr.pulse` 与 `co.fanr.pulse.widgets`，核验双 provisioning entitlement，再一次性接入正式共享 store、Widget target 和独立进程验收；能力就绪前不写私有 fallback。
4. 补齐 iOS / iPadOS 17.x 行为和真机通知门禁；这些是运行质量验证，不等同于开始发布。
5. 上述产品与运行门禁关闭后，再恢复分发签名、Archive、TestFlight、商店资料和 App Store 校验系列工作，最后做上线 GO 决策。
