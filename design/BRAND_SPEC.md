# 一日一印（Pulse）1.1 品牌与界面规范

更新日期：2026-08-20
适用范围：App（今日 / 历史 / 设置 / 权益 / 入镜）、Widget、AppIcon、商店素材

## 全局原则（全产品）

1. **美术自由**：构图、配色、渐变、材质、卡片与否、装饰、动效外观、字体表现均可探索。看不好就重画。
2. **人工验收**：外观以截图 / 真机为准；满意稿不等于永久画法锁。
3. **改画不必写长文**：默认只改代码与必要短说明；不为同步文档停工。
4. **硬边界只有**：领域事实、签到成功时序、隐私、可访问性语义、权益与 StoreKit 诚实、颜色工程入口、系统控件可预期行为。

### 参考驱动，不凭空发挥

外观探索先读 [`REFERENCE_BOARD.md`](./REFERENCE_BOARD.md)。Pinterest 只作发现入口：每个页面须由 2–4 个已审参考提炼出具体的构图、层级、材质与节奏关系，非 App UI 参考至少占一半；不得把通用 Habit Tracker 模板、Pinterest 图片或某个成品界面直接搬进 App。

参考板中的反参考是当前纠偏边界。静野下一轮须移除笑脸山形、对白气泡和无意义彩屑，不再沿用多习惯游戏化吉祥物路线。参考与成品完整页面截图并排人工通过之前，不得以“符合 token”“构建成功”或“功能齐全”宣称视觉完成。

探索稿不是设计权威；获准结论进入正式实现与本规范后，临时原型必须清理。

## 0. 品牌名称

- 简体中文正式名称：一日一印。
- 英文及其他语言正式名称：Pulse。
- 简体中文界面与中文商店素材使用“一日一印”，不把 Pulse 当中文显示名。
- 工程名 / Bundle ID 保持 Pulse。

## 1. 产品立场（非画法锁）

可靠、私密、没有压力的每日记录。当前常见记忆点是草叶生长与日环，**可改画**；立场不变的是：不制造断签焦虑、不伪造成功、不偷用户数据。

今日入镜是照片内容 + Pulse 身份语境，不是第二套相机 App。怎么画由迭代决定。

## 2. 颜色工程真源

正式颜色在 `design/brand-tokens.json` 定义；`scripts/build_brand_assets.py` 生成 Color Set / AccentColor / AppIcon 相关资产。SwiftUI 优先按语义名消费。

新增或改色：先改令牌，再生成并 `--check`。**允许**为新氛围扩展令牌；不是“禁止新画法”。

常见语义角色：`background`、`surface`、`grass` / `grassForeground`、`action` / `actionForeground`、`ink` / `secondary`、`field`、`separator` / `shadow`。静野统一使用 `quietCanvas` / `quietSurface`、`quietInk` / `quietMuted`、`quietDivider`、`quietGreen` / `quietGreenDeep` / `quietGreenSoft`、`quietChrome` / `quietChromeForeground` / `quietOnGreen` 与三种节奏点色；纸页手记只使用 `editorialAccent` 标记编辑与完成线索；晴昼统一使用 `sunlitCanvas` / `sunlitCanvasDeep`、`sunlitSurface`、`sunlitInk` / `sunlitMuted`、`sunlitDivider`、`sunlitAccent` / `sunlitAccentSoft`、`sunlitMap` / `sunlitMapDeep` 与 `sunlitChrome` / `sunlitChromeForeground` / `sunlitOnAccent`。页面不得继续引用旧橙铜 / 蓝黑令牌，也不得私写第二套色板。Widget 的纸张、天光与水面分别使用 `widgetPaper`、`widgetSkyGlow`、`widgetWater`，不以局部 RGB 模拟材质。萤火日晕按系统表面拆分为 `activityIslandFirefly` 与 `activityLockScreenFirefly`：灵动岛 compact / minimal / expanded 印记只使用琥珀色光源，不画开口环；萤火点须明显大于系统隐私指示点，光晕是日晕本身。岛内「签到」用低调的白字深胶囊，不借用纸面或草绿。锁屏保留开口弧与琥珀色萤火点；标题与时间成组，时间不使用独立色胶囊，「签到」仍用草绿实心键。提醒时间只出现在 expanded 与锁屏，不进入 compact。

完成 / 漏签 / 今天等状态不能**只靠颜色**到不可辨（形状、文案或无障碍标签须有等价）。

## 3. 字体与数字（工程偏好）

优先系统字体与 Dynamic Type，降低授权与多语言成本。若引入展示用第三方字体，须自行处理授权、回退与可访问性。

日期与统计数字建议 `monospacedDigit` 等宽，避免布局跳动——这是体验工程，不是审美禁令。

## 4. 今日页：产品与事实

美术自由。以下为**任务与事实**：

- 用户须能完成：看清今天、主承诺语境、签到 / 已签到、最近七日回看、次级连续节奏（若展示）。
- 最近七日事实只投影一份，不重复两套“近 7 天”。
- 主承诺只读正式 `Habit`，页面不另存副本；可选备注不进 Widget。
- 单击签到；长按「签到并拍照」：先权威签到成功再请求相机；相机失败不回滚签到。
- VoiceOver：标准「签到」+ 独立「签到并拍照」，不要求模拟长按。
- 成功视觉 / 触觉只在 Repository 权威提交之后；短写入可不闪加载器。
- Reduce Motion：有限呼吸与环境动效停止，终态仍正确。
- 今日入镜是签到后的伴生入口，不是第三套底栏；真实照片在详情 Sheet，与历史共用详情骨架与管理菜单语义。
- 每日记事是签到记录的可选内容；所有主题都在签到前提供可选输入并与签到原子保存，在签到后提供同一查看与编辑能力。主题只改变输入区的构图、字体与材质，不改变入口和时序。
- Accessibility 大字号下主动作须可完整阅读与操作（可改布局，不可裁切到不可用）。
- 内容变长时顺序下移，不重叠、不靠设备特判硬修。

## 5. 主导航：产品与结构

- 根界面使用 `PulsePrimaryNavigation`（今日 / 记录），不保留旧 Tab 兼容分支。
- 选中态须表达今日是否已完成等真实状态；两入口等宽、命中 ≥ 44 pt。
- 可滚动根内容末端须能滚出底栏遮挡（用实测底栏高度）。
- 设置是次级导航：进入时隐藏根底栏并释放安全区；两层导航不同时抢底。
- 不可见根页不响应触控 / 焦点。
- **外观**（材质、阴影、动效曲线）自由迭代。

## 5A. Home Screen Widget

见既有条款：产品枚举、权益、整块签到、事实诚实。八式各有一段与主物件唯一对应的双语意境文案，以“物件 + 时间变化 + 未尽动作”连接一日与留痕；精确正文只由 String Catalog 持有。叠印纸层等装饰不得被文案解释成历史事实。外观以渲染器与人工截图为准。

材质分工：`field` 是低彩度等待场，`grass` 是完成后的生长色；叠印与手札用暖纸面，潮痕用独立水面色。残影只承担时间或运动信息，不作为八式共用装饰。

## 5B. 高阶权益页：产品与诚实

- 独立页面，不埋设置分组、不用弹窗假商店。
- 价格 / 可购状态只读 StoreKit；能力目录只读 `PulseEnhancementContract.currentCapabilities`。
- 不预售未交付能力；不硬编码价格、假折扣、倒计时稀缺。
- 购买 / 恢复 / 待批准 / 已解锁 / 不可用状态明确。
- **版式与装饰**自由；不靠文案压迫购买。

## 5C. Apple Watch

- Watch 只使用“今日日印”和“七日脉冲”两种基础构图：圆形/Inline complication 表达今日状态，矩形 complication 与 Smart Stack 用六个历史节点连接一个今日印记；Watch App 以今日印为表盘中心，六个历史节点按日序环绕成周环，日期贴在上方，完成/待签由印的形状表达。不复制 iPhone Home Screen 八式。
- 黑色系统底、`PulseWatchInk` 暖白信息、`PulseWatchField` 空心待签到、`PulseWatchPending` 缺口待同步、`PulseWatchCommitted` 实心已确认；Watch App 主印内部以 `PulseWatchCommittedForeground` 显示“已签到” / “Done”，不另加底部完成状态栏。失败恢复为空心并显示警示符号。状态必须同时由形状和无障碍文案表达。
- Watch App 项目日期必须来自项目逻辑日与项目时区，不复述或猜测设备日。界面不显示星期或自定义顶栏日期，只保留右上系统时钟；本地化项目月份数字作为左下偏轴、可部分出屏的低对比大字，项目日显示在中央主印内部，下面保留“签到 / 已签到”。1.1 不传主承诺、记事、照片或缺席说明到 Watch。
- complication 与 Always-On 使用静态终态；只有 Watch App 从 `pendingSync`/`submitting` 收到 iPhone Repository 正式回执时播放一次成功触觉。打开一个已经完成的 Watch App 不重复播放成功。
- Watch App 普通待签与已确认状态在主印背后使用两层可辨识的深绿流体场：18–24 秒低频循环，只在前台活跃、屏幕高亮且 Reduce Motion 关闭时运行；后台、Always-On、低亮度、Reduce Motion 与异常状态显示同一静态或纯黑终态。流体不得覆盖日期、系统时间或周环，也不进入 complication / Smart Stack。
- 全部 Watch 颜色只读 `brand-tokens.json` 的 `watch` 语义组，经 `build_brand_assets.py` 生成到正式 Watch Asset Catalog；Watch Catalog 只保留实际消费的 Watch 颜色、AccentColor 与 AppIcon，不复制 iPhone 全色板。几何只读 `PulseWatchDesign`，不得在消费者散落第二套色板或魔法比例。
- Watch App 页级几何由实际容器与 safe area 连续求值，不按设备型号或表径分支；标准字号把日期、今日日印与环绕历史收进一屏表盘构图，只有 Accessibility Dynamic Type 或几何放不下时才纵向滚动。

## 6. 布局与工程常量

- 建议间距阶梯与水平边距可集中在 `PulseDesignSystem`（改画时可改令牌，避免页面散落魔法数）。
- 最小点击 44 × 44 pt。
- 设置优先系统 `Form` / `List` 语义。
- **是否卡片、是否全屏场、阴影多少**：美术决定。

## 7. 历史与设置：事实与平台

- 月历日期状态须区分：已签到、有影像、今天待签到、漏签、未来 / 开始前；有影像≠已签到。
- 已签到用真实 Button 打开详情。
- 详情：日期、签到状态、真实照片为主体；照片按真实宽高比显示，不歪曲事实裁切成“好看但假”。
- 删除照片与删除签到：独立事务、独立确认；destructive 语义清楚。
- 月份切换：可见按钮 / 滑动 / VoiceOver 同一状态函数；月历 / 记事模式入口在三个主题中能力、命名和可访问性标识一致。
- 明暗外观：跟随系统 / 浅 / 深；界面主题：静野 / 纸页手记 / 晴昼。两条轴独立、全局持久化；纸页手记是唯一免费默认，静野与晴昼由统一高级功能 entitlement 解锁。收费只控制构图选择，三套主题必须保留签到、记事、照片、月历、漏签与统计的能力等价；未购买卡片保留真实预览并以“锁 + 高级功能”明确权益，不能伪装已启用。界面主题统一驱动共享背景、品牌标、主导航、今日与历史构图，不能只做局部换色。静野以暖奶油纸底、草绿山形伙伴、深色控制条、圆润重字和少量彩色节奏碎屑形成视觉语法，彩色碎屑只作氛围而不承载事实；纸页手记以编辑线、衬线标题和短手记形成视觉语法；晴昼以暖白基底、顶部日照色场、局部浅黄层和克制路径线形成空间层级，黑色只承担签到主动作与必要强标题，主导航使用低对比独立圆钮，路径不放置伪装成控件的节点。成功外观只能在签到事实提交后推进，Reduce Motion 与非活动场景使用正确静态终态。设置主页只显示当前界面主题并进入独立主题选择页；手机端主题卡纵向排列，禁止用固定宽度横排预览挤压 Form。语言：跟随系统 / English / 简体中文；App 与 Widget 内容 Locale 一致。
- Sheet / `confirmationDialog` 使用系统来源锚定与可预期 detent 行为（工程稳定），不锁视觉皮肤。

## 8. AppIcon 工程

- 生成链：`brand-tokens.json` + `app-icon-source/` + `scripts/build_brand_assets.py`。
- Default / Dark / Tinted 由生成器产出；小尺寸须可识别。
- **图形题材可改**：改遮罩与令牌后重生。

## 9. 工程禁用

- 运行时复活已删除的产品壳或旧 Tab 兼容分支冒充当前产品。
- 页面内私写 RGB/Hex 第二套色板、绕过令牌的重复 AppIcon 调色。
- 无限循环呼吸耗电且无静态等价。
- 用动画 / UI 伪造成功、伪造价格、伪造权益。
- 用颜色单独作为成功 / 漏签 / 今天的**唯一**通道到不可辨。

## 10. 验收

构建与测试证明工程与事实；**不能**代替人工视觉确认。真机、Dynamic Type、VoiceOver、Reduce Motion、Widget host、商店素材各自验收。
