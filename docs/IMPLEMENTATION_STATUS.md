# Pulse 实现与验收状态

更新时间：2026-08-12
当前结论：核心签到、主承诺身份、App 内基础日印与基础 Widget 的自动化工程门禁 GO。Home Screen 已正式实现可持久化的“四式日印”：默认“断层双色”，以及“越界巨环 / 承诺宣言 / 错版撕页”；四式只改变构图，共用唯一 SwiftData 事实、单向 AppIntent、七日状态和隐私边界。保存的权威 HTML 方向稿已与 iOS 26.5 iPhone 17 Pro Simulator 同尺寸并排复核，旧实现四式均判定 `INTERFACE NO-GO` 后完成根因级重构。用户随后提供的真实 iPhone 完成态截图揭示“断层双色”的裂环缺口落在同色左域后形成视觉闭环；当前实现已把该式缺口独立转向右侧状态色场，并在真实 WidgetKit 小号浅色全彩待签到与完成态重新截图复核。2026-08-12 用户又提供真实 iPhone Widget Gallery 截图，证明旧 Accessory 矩形存在错误日期裁切、待办环伪勾、右侧印记越界与七日节点失去时间关系；现已以唯一“节律汇印”替换：圆形使用代码原生开放环，矩形让过去六日轨迹汇入唯一今日印记，待办态整块可点。第一次补入滚动星期后，用户在真实锁屏确认末尾星期与今日大印相互争抢，无法突出今天；当前正式改为“六个历史纯数字 + 今日环内纯数字”。未签到使用开放环与当天数字，已签到使用实心内核与镂空当天数字，Accessory 不再显示勾；全部数字从各自 `LogicalDay` 和当前 Locale 派生，不带“日”等日期后缀、不持久化、不硬编码。此前 107 个单元/集成测试与 Debug Simulator 编译已通过；本次数字修订按用户要求只执行 Widget 定向编译和最小静态检查，不把此前全量证据冒充为本轮结果。当前模拟器未能进入锁屏 Gallery 生成新截图，因此 Accessory 只达到 `INTERFACE CANDIDATE`，真机界面仍为 NO-GO。中号、深色、accented/vibrant/Clear、Lock Screen/StandBy/Always-On、最大动态字体、VoiceOver、Reduce Motion 与修订后真机仍未重新验收，整体验收与发布门禁继续 NO-GO。历史真机共享数据路径证据仍有效，但不能转移为本轮构图的人工作视觉结论。

## 当前生产实现

- 单用户、单签到项目；`CheckInRecord` 是历史、日历和统计的唯一事实源。
- `Habit` 是唯一主承诺身份真源；名称、可选“为什么重要”和确认状态不在页面、设置或通知中保存副本。未确认前不进入签到主界面，编辑身份不改写签到事实。
- 主承诺输入统一经过 `HabitIdentity` 规范化和验证，Repository 独占写入；名称到说明具备明确键盘焦点链，失败保留输入并显示真实错误。
- 今日页在日号与签到主动作之间读取 `HabitSnapshot.name`，以“今天守住 / Today’s Commitment”轻量投影主承诺名称；可选“为什么重要”仍只由首次确认与设置编辑页消费。提示无容器、无交互且不保存副本，签到按钮辅助功能状态同时包含承诺对象。周轨迹后只保留沿同一中轴居中的连续状态；零连续使用“从今天开始”，不再把 `0 天` 表达为负向计分。
- 项目 slot、记录 ID 和逻辑日唯一性由持久化层与导入校验共同约束。
- 1.0 日界线固定为签到时区当地 00:00；不保留非零日界线字段或兼容分支。
- Repository 独占权威 Clock 和所有 SwiftData 写入；无补签日期参数，保存失败回滚。
- 起始逻辑日、创建时区、当前签到时区和每条记录的发生时区均显式保存，时区变化不改写历史事实。
- JSON 导出当前只写 `co.fanr.pulse.export` v2；读取按精确版本分派，正式 v1 单向升级到 v2 内存模型，未知版本与缺失格式标识失败关闭。导入在任何删除前完成身份、大小、时区、来源、时间顺序及唯一性校验。
- 签到、删除、导入、清除和时区变更由单一操作状态串行化，失败不会提前关闭界面或报告成功。
- Repository 签到写入返回只描述本次 `created` / `alreadyPresent` 的瞬时提交回执；`CheckInRecord` 仍是完成状态唯一持久化事实，App 在重新载入权威快照后才允许触觉和成功呈现。
- SwiftData managed object 不再离开 Repository；AppModel、Today 与 History 只持有不可变、`Sendable` 的 `HabitSnapshot` / `CheckInRecordSnapshot`，页面无法绕过 Repository 修改持久化模型。
- 领域、schema/migration、Repository、验证、导入导出合同和类型化 `PulseWidgetStylePreferences` 只由 extension-safe 静态 `PulseCore` 编译；App 通过模块依赖消费，不再把同一源码或偏好键编进两个宿主。Core 不依赖页面、通知、触觉或宿主本地化资源；唯一 UserDefaults 消费只保存不含业务事实的 `widget.style`。
- Repository 在快照越过模块边界前统一验证身份规范、起始日来源、当前/创建/记录时区、recordKey、时间顺序和逻辑日唯一性；对外快照的逻辑日与时区是已验证的非可空值，损坏事实诚实失败。
- Repository 新建签到保存失败后会 rollback、丢弃原 ModelContext 并按同一 `recordKey` 从正式 store 回读；只有查到另一写入者已经提交的记录才返回 `alreadyPresent`，其他持久化错误继续诚实失败。
- App 与 Widget 的正式 store 只位于系统返回的 `group.co.fanr.pulse` 容器下 `Library/Application Support/Pulse/Pulse.store`。App 私有路径只作为旧版本迁移源；完成后主文件、WAL/SHM 被精确清理，不保留私有读取 fallback、双写或事实副本。
- `PulseSharedStoreBootstrapper` 与 `PulseSharedStoreMigrator` 以 journal v2 统一旧私有 V1/V2 store 搬迁和全新安装 staging admission：模式、阶段、确定性 SHA-256 迁移摘要、Repository 值写入和精确清理都可中断恢复。迁移摘要只验证切换事务；`ready` 后共享目标是可变真源，正常签到或身份编辑不会在下次启动被旧摘要拒绝。冲突源、空源、漂移、删除失败、损坏 journal、符号链接同路径和旧源复现均失败关闭。
- `PulseWidgetSnapshot` 只读投影今日、实际签到时间、最近七日和项目时区下一个零点，并从七日数组派生过去六日已留印数量；该数量不持久化，也不把今天重复计入。未确认身份不产生可签到快照，读取不会创建项目。
- `PulseWidgetsExtension` 支持 Home Screen 小号/中号和 Accessory Circular/Rectangular。未签到只提供单向 `PulseCheckInIntent`，已签到无撤销入口；迁移未完成或身份未确认显示明确“打开 App 完成设置”，读取失败不伪装为待签到。
- Home Screen Widget 关闭系统默认内容边距并实现四套独立小/中号比例：断层双色按用户后续明确选择将圆点节律固定左下，越界巨环只保留一个受控裁切的主环，承诺宣言以主承诺为第一读，错版撕页使用 18% 状态顶带与超大日期。四式都消费同一日/月、规范化主承诺、七日事实与单向 AppIntent，但按原型分别用文字、日印内核、色场和七日末点表达今日状态，不强塞通用顶栏或重复状态文案。所有 Widget 日印都由同一代码原语绘制，独立右下补形与 Accessory 位图副本已删除，保留干净的 312° 开口；断层双色通过独立方向参数把缺口固定到右侧状态色场，其他三式和 Accessory 显式保持原方向。七日圆点或方块由低强调线连接为单一时间轨迹，线条只连接节点外缘且不穿过空心内部。Accessory 使用“节律汇印”：圆形在今日印记内部显示本地化当日日号；矩形在过去六日节点上方显示各自逻辑日的本地化日号，并由真实连接线汇入右侧唯一今日印记，今日日号只显示在大印内部。待办态是开放环与日号，完成态是实心内核与镂空日号，不显示勾；尺寸从系统边距后的可用容器推导，待办态整块绑定同一 AppIntent，完成态静态。Lock Screen、StandBy 与 Always-On 不渲染主承诺正文或 Home Screen 样式，任何 Widget 都不显示“为什么重要”。事实或样式变化成功后请求 timeline reload。
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
- 删除主承诺占据日期英雄区或周轨迹后方的卡片式重复投影，以及旧节奏胶囊、摘要容器、左右分栏、栏目标签、通用鼓励语、今日页说明副本和旧辅助功能标识；正式路径只在日期与主动作之间保留无容器名称提示，并在周轨迹后保留居中的连续状态。
- 删除视图根据按钮点击或局部布尔值猜测签到成功的路径；成功、触觉和日印仪式统一消费 Repository 提交回执与重新载入后的权威记录。
- 删除旧整控件弹跳、持续背景场呼吸和 `repeatForever` 待签到光环；动效参数集中到一个设计合同并受两秒上限测试约束。
- 删除编辑表单依赖点击坐标切换字段的隐式行为；键盘“下一项/完成”现在驱动明确焦点状态，避免表单重排时误触保存。
- 删除提醒并发中的陈旧结果覆盖、跨异步边界持有可变模型和调度失败残留。
- 删除启动代码依赖 SwiftData 隐式默认路径的假设；生产只走系统 App Group locator，私有路径仅作为一次性显式迁移源。
- 删除把迁移摘要当作共享 store 永久内容校验的错误语义；摘要在所有权切换完成后不再追赶可变业务事实。
- 删除 WidgetKit 的第二份位图标记及其 256 × 256 生成路径；所有 Widget 直接消费同一代码原生开放环，避免小尺寸栅格把断口抗锯齿成伪勾或产生重复视觉真源。
- 删除 `widget.showsHabitName` 和快照中的可选名称分支；名称继续直接读取 `Habit` 真源。新增的设置页 Widget 分组只写四值 `widget.style` 构图偏好，未知值失败关闭，不复活名称开关或签到投影副本。
- 删除迁移读取借用“读取时自动创建主项目”的可能性；`existingPrimaryHabit()` 是严格只读入口，缺失事实不会被默认项目掩盖。
- 删除重复统计扫描、历史时间使用当前时区重解释、清除过程无恢复日志等隐性一致性债务。
- 删除固定大字号下会裁切的主操作形态、纯颜色完成状态、无条件动画和散落视觉常量。
- 删除 iPad 居中手机稿、Accessibility 比例底栏、历史页仅靠隐式滑动翻月，以及设置页保留隐藏根内容辅助功能焦点的旧布局假设。
- 删除品牌生成器对像素未变化 PNG 的无条件重编码；正式生成只更新真正漂移的产物。
- 删除旧方向 HTML、候选图标、过期截图与重复设计说明；Git 历史承担追溯，不在生产树中保留第二套设计真源。
- 删除已完成且持续漂移的开发计划；剩余工作只记录为可验证发布门禁。

## 自动化证据

当前验证环境：Xcode 26.4（17E192），iOS 18.6 iPhone 16 Pro Simulator。此前 Xcode 26.6 / iOS 26.5 iPhone 17 Pro 与 iOS 18.6 iPad Pro 11-inch（M4）证据保留为历史基线；部署目标仍为 iOS / iPadOS 17.0，当前没有 iOS 17.x 运行证据，因此不把 17.x 行为标记为已验证。

- Accessory “节律汇印”重构后曾重新执行 107 个单元/集成测试，全部通过；其中 7 个 Widget 快照测试独立定向通过，新增断言证明过去六日计数不会重复包含今天。日号修订后，本轮 `PulseWidgetsExtension` Debug Simulator 定向编译与 `git diff --check` 通过，未重跑全量测试；此前 107 项与 12 个 UI 测试不冒充本轮日号源码的验证结果。
- Release iOS Simulator 构建与 Xcode 静态分析：通过，无 Swift 编译器或静态分析告警。
- Debug `iphoneos` 通用设备构建：App 与 Widget 在自动开发签名下通过，嵌入扩展校验通过。
- 品牌资产生成器：18 项生成结果与仓库一致；Accessory 不再生成或消费第二份 `PulseWidgetMark` 位图。
- String Catalog、品牌令牌 JSON 与 Asset Catalog：解析/编译通过。
- 隐私清单 plist 校验通过并由 Xcode 复制进 App 包；生产站三条路由和分享图均返回 HTTPS 200，线上文件与本地静态构建 SHA-256 一致。
- 十年逐日记录统计保持单一连续段；导入的跨时区起始日倒退、记录日映射错误和重复事实均失败关闭；通知权限被系统外撤后不保留虚假启用状态。
- 单元与集成自动化覆盖主承诺规范化、Emoji/不可见控制字符、幂等编辑、事实不变、JSON v1→v2 和真实 SQLite SwiftData v1→v2 迁移；本轮将共享位置 journal 升为 v2，覆盖旧库/新安装两种模式、三个持久化中断点恢复、确定性迁移摘要、精确旧源/staging 清理、`ready` 后业务事实正常演进，以及源/目标篡改、删除失败、损坏或未知 journal、缺源/空源、模式冲突、符号链接同路径和旧源复现等失败关闭门禁。UI 自动化继续覆盖首次确认、重启保持、设置编辑、清除后重入确认和无效边界。
- Widget 自动化覆盖七日状态、过去六日完成计数、规范化主承诺名称投影、身份确认门、实际提交回执、DST/项目时区零点和空 store 只读；另覆盖四值偏好往返、默认 `faultField`、未知值失败关闭，以及样式变化只触发一次 timeline reload。锁屏不渲染名称、整块命中、Accessory 完成态实心内核与镂空日号、VoiceOver 单元素朗读及当前真机视觉仍需独立人工证据。
- 本轮新增两个独立 `ModelContainer` 访问同一磁盘 store 的集成测试：两端读取同一主项目，同日调用最终只有一个 `recordKey`，后调用返回同一记录 ID 的 `alreadyPresent`。该测试证明磁盘共享与回读基础，不替代 Widget/App 两个真实进程同时抢写的真机证据。
- `PulseCore` 独立 Debug/Release 编译、App 静态链接和 extension-safe API 检查通过；另有两个损坏持久化事实测试证明非法主承诺与错误 recordKey 不能逃出 Repository 成为部分有效快照。
- UI 自动化继续覆盖首次签到、重启后静态实心态、历史同步、显式双向翻月、漏签非颜色语义、设置辅助功能隔离、主题与语言即时切换/跨重启保持，以及 Accessibility XXXL 主操作、连续状态与等宽底栏几何；此前用真实 Picker 验证四个样式名称、选择“错版撕页”并在重启后保持。真实桌面另行逐一检查四种小号浅色未签到全彩构图，并把模拟器最终恢复到默认“断层双色”。本轮确认新 Widget 扩展已安装且模拟器可进入真实锁屏，但该 iOS 18.6 实例没有暴露锁屏墙纸/小组件自定义页，未取得新 Accessory Gallery 截图；此前四层版、校正前四式与 Accessory 旧图只作历史或失败证据。
- Debug `iphoneos` 通用设备构建在自动 provisioning 下通过：App 与 Widget 分别使用正式开发 profile，实际签名 entitlement 的 application identifier 为 `6N3D8YA2FY.co.fanr.pulse` / `6N3D8YA2FY.co.fanr.pulse.widgets`，两者都包含 `group.co.fanr.pulse`。本机只有 Apple Development identity；Apple Distribution 仍未建立。
- 用户已在当前运行界面确认本轮承诺提示与签到球间距可接受；该 `HUMAN` 证据只验收本次布局方向，不等同于完整设备矩阵、长期抗淡忘效果或发布视觉 GO。
- 用户于 2026-08-11 确认在真实 iPhone/iPad 完成全新安装、旧数据升级、杀进程重启、跨时区与 Widget 交互，且当时版本的主屏幕、锁屏、Always-On、深浅模式、最大动态字体、VoiceOver 和 Reduce Motion 未发现问题；多日实际使用中的签到节奏、提醒可靠性、误触恢复与 Widget 隐私设置理解也未发现问题。该声明是正式 `HUMAN` 验收证据，但只绑定当时实现；后续 Widget 视觉重设计需要重新验收，且不能补写未提供的设备型号、OS 版本、时区组合、试用天数或录屏。
- 产品验收继续坚持当前 1.0 边界：真实使用没有给出新增 Live Activity、Watch 或社交能力的必要性，因此这些排除项不因“增加功能数量”而进入当前范围。

Xcode 26.4 的 `appintentsmetadataprocessor` 在未使用 AppIntents 的 target 上仍可能输出“未发现相关 App Intents 符号，跳过输出”的工具信息。它不是源码或分析告警；项目没有通过全局过滤隐藏该输出，以免同时遮蔽未来真实工具告警。

## 版本迁移基线

产品尚未上线不等于可以无条件删除已经形成的稳定数据合同。仓库中的 SwiftData v1 和带正式格式标识的 JSON v1 现在作为受控基线保留：

- SwiftData 使用冻结的 `PulseSchemaV1`、当前 `PulseSchemaV2` 和单向轻量迁移；原项目 ID、起始日、时区与签到记录保持不变，新增说明为空、身份为未确认。
- JSON v1 只通过精确 `format` / `schemaVersion` 分派映射到 v2；运行时和新导出只存在 v2 一条路径，不保留双模型、别名或猜测回退。
- 无正式格式标识的早期开发 JSON 继续明确拒绝；不能因为“兼容”而恢复不可验证内容。
- 迁移测试会创建真实 v1 SQLite 存储再由 v2 打开，防止只验证内存模型却漏掉实体名或持久化映射问题。

这类显式、单向、有测试的迁移是数据完整性合同，不是应当清理的旧兼容债务。未来每次 schema 变化继续要求上一正式版本 fixture、迁移阶段和回归测试。

## 尚未关闭的发布门禁

- 补录目标设备型号与系统版本，并覆盖最低部署基线 iOS / iPadOS 17.x；当前用户真机验收没有提供这些元数据。
- 继续单独验证本次用户反馈未明确枚举的通知异常矩阵：首次拒绝后恢复、系统外撤权限、改时后旧请求清理与系统重启后的调度恢复。
- 继续单独验收本次未明确枚举的 English / 简体中文组合、高对比度、降低透明度、旋转和 iPad 分屏；VoiceOver、最大字号、深浅模式与 Reduce Motion 的历史真机确认只绑定改版前 Widget，当前 Widget 仍需重验。
- 真机整体使用与 Reduce Motion 已获用户确认；发布视觉归档仍需在 1× 真机逐帧记录基础日印的空心收缩、成印、回弹、周轨迹与连续数字时序，并同时留存 Reduce Motion 静态等价证据，不能把“未发现问题”扩写成尚未提供的逐帧素材。
- 对当前生产源码重新完成最终视觉与 AppIcon Default / Dark / Tinted 验收；历史截图不能代替当前版本证据。
- 隐私与支持页面已经公开；开发者账号审核已完成，App/Widget 开发签名与 App Group 已验证。商店文案/截图、App Store Connect provider、Apple Distribution、分发描述文件、Archive、TestFlight 与 App Store 校验仍按产品决策后置；开发设备构建不是分发就绪证据。

## Widget / App Group 状态

- 设计合同 GO：四式小号/中号方向、断层双色默认与左下圆点、Accessory “节律汇印”的六个历史日号与今日环内日号、代码原生日印、系统字体/语义色、默认隐私、不可用态和单向签到边界已冻结在 [Widget 共享 Store 合同](./WIDGET_SHARED_STORE_CONTRACT.md)、[系统仪式合同](./PULSE_RITUAL_CONTRACT.md) 与 [品牌合同](../design/BRAND_SPEC.md)；合同冻结不等同于新 Accessory 实机界面通过。
- 工程 GO：工程已有 `PulseCore`、`pulse`、`PulseWidgetsExtension`、`pulseTests`、`pulseUITests` 五个 target；旧库/新安装 journal v2、共享路径、纯值投影、AppIntent 与 timeline reload 均已接入且无私有 fallback。
- Apple 开发能力 GO：通用 iOS 设备构建使用 Team `6N3D8YA2FY` 成功；App 与 Widget 分别取得开发 provisioning profile，签名 entitlement 都包含 `group.co.fanr.pulse`。这不是 Apple Distribution 或 TestFlight 证据。
- Simulator 小号部分 GO：iOS 26.5 真实桌面已通过正式设置路径逐一渲染四种小号的浅色未签到全彩状态，并与保存的 HTML 原型同尺寸并排复核；断层斜切与用户指定的左下圆点、越界巨环裁切、承诺宣言编辑式层级、错版撕页完整日/月与越界环均成立。用户进一步拒绝圆环独立鼓包并要求七日节点形成连续轨迹后，四式已重新逐一刷新和放大复核：裂环保持干净断口，圆点/方块连接线位于节点下层且未穿过空心中心。真实 iPhone 完成态截图暴露同色左域造成的视觉闭环后，断层双色已把同一 312° 环段独立旋转 180°；模拟器经小组件待签到、AppIntent 签到、返回桌面刷新完整链路复核，两个状态的 48° 缺口都清楚落在右侧状态色场。中号、深色、accented/vibrant/Clear 尚未绑定本轮最终构图，不能沿用旧四层版或校正前四式结论。
- 真机界面 NO-GO：用户提供的真实 iPhone 截图分别构成旧断层双色完成态与旧 Accessory 待办态的有效失败证据；后者明确出现错误日期裁切、待办环伪勾、右侧印记越界与节律失联。当前 Accessory 修订只有编译、自动化与几何合同证据，必须在同一真机系统外观下安装新版后复验圆形/矩形待办与完成态，不能用模拟器或旧截图替代。旧版 Widget 曾由用户在真实 iPhone/iPad 确认的锁屏、Always-On、深浅模式、最大动态字体、VoiceOver、Reduce Motion 与隐私表达同样不能绑定当前实现。
- 真机体验部分 GO：用户历史确认的全新安装、旧数据升级、杀进程重启、跨时区、共享数据写入、误触恢复与多日提醒仍是数据路径证据；当前重设计的可读性、触达性与系统表面体验需要重新人工验收。
- 压力/版本矩阵 NO-GO：本次没有记录设备型号和 OS 版本，也没有明确声明 App 未运行、快速双击、App/Widget 同日竞争、卸载重装与 iOS / iPadOS 17.x 的逐项结果；不能从正常交互 GO 推导这些项目已通过。

## 下一步顺序

1. 在真实 iPhone Widget Gallery 与已安装锁屏先复验新 Accessory 圆形/矩形的待办和完成态：开放环无伪勾、完成态无勾且实心成立、前六个本地化日号与节点同轴、今日日号只位于大印内部、`1 / 10 / 11 / 31` 不裁切或碰撞、六日轨迹汇入今日印记、右侧无裁切、整块可点且 VoiceOver 只朗读一个元素；同时补录设备型号与 OS 版本。
2. 若仍支持 17.0，单独补齐 iOS / iPadOS 17.x 行为；并补 Accessory 的 StandBy / Always-On、深色、accented、vibrant、Clear 与降低透明度矩阵。
3. 只补尚未明确覆盖的压力与异常路径：App 未运行、快速双击、App/Widget 同日竞争、卸载重装、通知拒绝/外撤/重启，以及高对比度、旋转和 iPad 分屏。
4. 完成当前生产 AppIcon 与商店截图的最终视觉验收；不以历史截图或真机功能通过替代商店表面验收。
5. 上述产品与运行门禁关闭后，再处理 Apple Distribution、Archive、TestFlight、商店资料和 App Store 校验，最后做上线 GO 决策。
