# Pulse 1.1 测试与验收计划

文档版本：2.3
状态：Canonical Acceptance Plan
更新时间：2026-08-18

## 1. 证据边界

- Unit test 证明领域、文件与归档规则；不证明真实相机、磁盘压力、系统权限或视觉质量。
- Simulator UI test/截图证明指定 runtime 的流程和静态结果；不证明真机相机、触觉、通知、Live Activity、Always-On 或 StoreKit 生产链。
- Build/Analyze 证明当前源码可编译与静态分析通过；不证明发布签名、TestFlight 安装或人工体验。
- 发布 GO 需要自动化、真机、系统表面、无障碍、视觉和分发六类证据分别关闭。

任何记录/记事/照片丢失、重复事实、错逻辑日、无效恢复覆盖当前数据、明文临时物泄漏、记事或照片进入系统表面、主题隐藏能力或虚假成功都是 P0。

## 2. 自动化矩阵

| 范围 | 必须覆盖 |
| --- | --- |
| Habit / 逻辑日 | 名称/说明规范化；Gregorian、时区、DST、稳定起始日；时区变更不改历史 |
| Repository | 唯一主承诺、同日幂等、rollback、跨容器并发；记事签到时写入、外部先签到后补写、编辑、清空、非法输入不变更；签到/媒体独立删除和重新关联 |
| Schema 1.1.1 | Habit / CheckInRecord / ImprintMedia 真实磁盘读写；精确 marker；实验性 1.1.0 与更旧 marker 失败关闭；无迁移分支 |
| 媒体文件 | 安装前 staging、不可变小写 UUID 路径、路径穿越、文件及 `originals` / `thumbnails` / `staging` 中间目录符号链接拒绝、24 MiB/2 MiB 上限、原图和缩略图 byteCount + SHA-256、孤儿审计、清除 |
| 图片处理 | 方向归一、最大 4096、缩略图最大 720、JPEG 输出、元数据剥离、无效图片拒绝 |
| 归档 payload v3 | 唯一 UTType；container v2；PBKDF2 600k；随机 salt/nonce；分条目 AES-256-GCM；签到+记事+媒体 round-trip；显式记事空字段；原/缩略图身份；缺字段/缺失/额外/重复、篡改、截断、尾随、错误口令、未知版本、超限失败关闭；payload v1/v2 与 container v1 不读取 |
| 恢复事务 | 全部解密/认证后才确认；文件先安装、数据库单次 replace；提交前失败回收新文件；提交后清理失败不得误删新文件；取消清理解密 staging |
| AppModel | 操作互斥；单击签到；系统表面只消费提交回执的逻辑日；记事更新不改签到/统计；长按先提交签到再请求相机；相机/媒体失败不撤销签到；跨日事件与激活事件在长操作结束后必须补执行；重置日志；完整备份 |
| Settings / Store | 今日入镜邀请、空间、主题、语言、提醒；独立高阶权益页；StoreKit 动态价格；类型化能力目录；独立 Widget 画廊；重置后清理；损坏偏好失败关闭 |
| Widget / 系统表面 | 只读 Habit + CheckInRecord；不查询或暴露 ImprintMedia；AppIntent 幂等签到；语言/样式/权益双边检查 |
| 本地化/无障碍 | 简中/英文完整字符串；格式参数；日期 Locale；照片/按钮/进度有 VoiceOver 语义；状态不只靠颜色 |
| 资产 | 品牌 token schema、资源解码、AppIcon alpha、生成器幂等、仓库 diff |

## 3. UI 自动化

- 首启确认承诺、签到落盘、重启保持、History 出现。
- 同一开放日环的单击只签到；0.45 秒长按只提交一次签到并在成功后请求相机；VoiceOver 自定义动作可达。
- 签到成功后出现今日入镜邀请；关闭邀请后不出现，已有照片仍可管理。
- 无相机的 Simulator 明确报不可用，不打开相册作隐式兜底。
- History 可打开“仅签到 / 签到+影像 / 仅影像”详情；两种删除确认独立。
- 静野、纸页手记、晴昼均可查看和编辑记事；纸页手记签到前输入可原子保存，签到后可再编辑；Widget 先签到后仍可补写；三主题都保留照片、月历、漏签和统计。
- Settings 显示媒体空间、完整加密备份与照片数量恢复确认；高阶权益购买和 Widget 构图选择使用各自独立页面。
- Settings 使用“反馈与建议 / 帮助中心 / 隐私政策”三个明确入口，不保留旧“产品支持”混合入口。反馈验证问题/建议分类、空内容、2000/2001 字、换行与 Emoji、诊断可展开查看且关闭后完全移除、邮件未配置、取消、保存草稿、进入系统发送队列和失败。界面和邮件正文不列举未附带数据。诊断可含逻辑日、今日布尔状态与数量规模，但不得包含“我的一件事”正文、签到时间/历史明细、记事正文、媒体内容、备份、口令或设备 ID。
- 可选截图覆盖选择、取消、替换、移除、损坏、40 MiB 输入上限、2048 px 缩放、8 MiB 输出上限、方向、透明图黑底合成和来源元数据移除；App 只能接触用户选中的单张图片，邮件只能附加处理后 JPEG。
- English / 简体中文、深浅色、最大可自动化字号、Reduce Motion 下结构稳定。
- 既有提醒、StoreKit、Widget 样式、App/Widget 同日竞争和清除流程无回归。

相机内容注入只能是 `#if DEBUG` 且由显式 UI test 环境开启的测试 seam；正式构建中不得存在相册兜底、样例照片或演示数据库。

## 4. 构建与静态门禁

每个候选至少执行，并记录实际 Xcode、SDK 与 destination：

```bash
xcodebuild -project pulse.xcodeproj -scheme pulse \
  -destination '<当前已安装的 iOS Simulator>' test

xcodebuild -project pulse.xcodeproj -scheme pulse \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project pulse.xcodeproj -scheme pulse \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO analyze

python3 scripts/build_brand_assets.py --check
plutil -lint Config/Pulse-Info.plist
git diff --check
```

同时确认：

- App / Widget 版本、deployment target、App Group、Data Protection 和 Privacy manifest 一致；
- 1.1 的 Info.plist 明确关闭多 Scene；在建立正式进程级协调合同前不得开启 iPad 多窗口模板能力；
- `PulseSupportContract` 是 App 内支持邮箱、帮助/隐私 URL、反馈长度和版本展示的唯一来源；生产源码不得保留 `PulseExternalLinks`、第二支持邮箱、隐藏反馈上传或第三方反馈 SDK。公开隐私正文必须说明用户主动邮件与可选技术信息；App Store Connect 隐私答案按最终行为复核。界面和邮件不靠否定清单证明未收集。
- App Store Connect 按支持邮件的实际行为复核 Customer Support / Other User Content、Photos or Videos、Other Diagnostic Data 与 Product Interaction；不得因提交频率低或用户主动就自动继续回答“未收集”。用途只允许 App Functionality / Customer Support，不跟踪；是否与用户关联按发件地址与实际留存方式保守回答。
- App Store Connect 按 container v2 / payload v3 的实际 PBKDF2 + AES-GCM 用途完成加密出口判断；分类冻结前 App / Widget Info.plist 均不预填 `ITSAppUsesNonExemptEncryption`，不得把历史 Build 2 的豁免答案外推到 1.1。
- Debug App 必须显示“一日一印 Dev”并使用 `co.fanr.pulse.dev`、Debug Widget 使用 `co.fanr.pulse.dev.widgets`、Debug App Group 使用 `group.co.fanr.pulse.dev`、URL Scheme 使用 `pulse-dev`；Debug 不加载生产 `InfoPlist.xcstrings`，防止本地化名称重新覆盖 Dev 标识。Release 继续且只使用对应生产身份。Debug 灵动岛测试台源码与 Settings 入口必须由 `#if DEBUG` 关闭，Release 产物不得包含 `ReminderActivityDebugView` 或“灵动岛测试台”；
- `NSCameraUsageDescription` 简中/英文均存在；
- 生产源码没有 schema v1、archive v1 decoder、旧 Repository、旧 FileDocument、绝对媒体路径或第二个媒体目录；
- `ArchiveWork` 启动即清理崩溃遗留并使用 Data Protection；
- `/Users/fanr/Documents/work/coco-web` 是公开隐私、支持与产品正文的唯一权威；`site` submodule 只能保留到正式 URL 的跳转。发布时分别验证 canonical 仓库提交、生产部署、三个 HTTPS 200 页面、1.1 关键正文、跳转目标与商店材料。

## 5. 真机媒体门禁

至少一台真实 iPhone 覆盖：

1. 首次相机授权、已授权、拒绝、从系统设置恢复、取消；
2. 后置/前置拍摄、横竖方向、重拍、删除、杀进程重启、跨日；
3. 低可用空间、写入中断、被系统终止、超大输入与损坏文件；
4. 眼镜、暗光、逆光、多人、宠物、环境照片——1.1 应真实保存，不做容貌评价；
5. 原图导出和包含全部媒体的加密归档，在另一清洁安装恢复并逐张核对；
6. 删除签到保留照片、删除照片保留签到、清除全部数据无文件残留；
7. App Group 首次解锁后的可读性，以及设备锁定时照片不会进入 Widget/Live Activity。

iPad 需覆盖无后置能力差异、横竖屏、分屏和文件导入/导出；没有相机的设备必须明确不可拍，不改用相册兜底。

## 6. 视觉、动效与无障碍

- Today 须能完成看清今日、签到/已完成、七日回看与入镜入口等任务；入镜不是与底栏竞争的第二套底部主导航。外观以人工截图验收。
- 每日记事须覆盖空白、1/120/121 字、1/4/5 行、中英文、Emoji、换行、编辑、清空、删除签到连带删除；保存与删除焦点、错误和确认不依赖颜色。
- 照片保持真实色彩；已有照片时伴生入口显示真实缩略影。今日与历史复用同一个照片详情骨架、导航栏、照片几何和右上管理菜单，不出现第二套取景器、胶片品牌或并行操作布局；重拍保持次级，删除保持系统 destructive 语义。
- 悬浮底栏命中区只能占用自身真实高度，选中项不得通过宽度挤压改变相邻入口；独立高阶权益页必须在待购买、购买中、待批准、已解锁与不可用状态分别截图审阅。同组权益项必须等宽满行，末项与恢复购买完整位于购买条上方。
- App 构图画廊与真实 Home Screen 小号/中号分别验证八式产品/事实边界：待落之处免费默认；收费式未解锁时明确拒绝；共用 `PulseWidgetHomeRenderer`；未签到整块唯一签到入口；完成态不可撤销；快照事实诚实（叠印纸层不映射历史、来路计数即时派生、无 4/7 分数进 Widget）。画廊八条双语意境文案须与获准正文逐条一致、可由物件辨认且不承担状态说明；收费卡只保留标题行一个可点击的“锁 + 高级功能”入口，命中不小于 44 pt，卡片底部不得再出现重复查看按钮。默认与 Accessibility Dynamic Type 下检查卡片高度、换行、截断和朗读。外观以人工截图验收。
- Home Screen 待签到时整块是唯一 AppIntent 命中面，且按钮标签必须钉死到系统分配的完整可见区域；完成态整块静态且不可撤销。Widget 不使用 App 内那种连续环境动画或密集 Timeline 帧；只允许早间 / 日间 / 晚间三种低幅静态氛围 entry，以及权威签到事实 reload 后的一次有限物件变装（见 [WIDGET_MOTION_CONTRACT.md](./WIDGET_MOTION_CONTRACT.md)）。测试必须证明集中边界最多生成五条 entry、时段不改变业务事实、下一逻辑日重新投影；不得断言 iOS 会准点展示。每次系统 Widget 变化必须逐材料验证不超过 Apple 官方两秒上限。画廊逐卡“预览变化”使用同一 Renderer 串联三种时段与签到变化，每段必须完成后才进入下一状态；可重复播放、播放中不叠加任务、离页取消，且预览前后正式签到事实不变。锁定构图的预览与购买入口不得嵌套。八式必须分别验证自己的主物件和时段姿态，不能只检查共享签到圈或共享横移。Reduce Motion 下跳过三时段串联，直接呈现当前时段待办与完成的静态等价。模拟器画廊录屏只能作为候选证据，真实 Widget host 仍须单独验收。
- 在系统“编辑小组件”中验证逐实例构图：默认构图必须是待落之处；同一主屏至少放置两个不同构图，分别修改后互不影响；权益未验证或撤销时包括星环在内的收费实例明确显示“构图尚未解锁”，不能静默换成待落之处；Lock Screen“节律汇印”不出现无关构图参数；App Group 中不存在 `widget.style`。
- 记录详情必须先显示日期/签到状态和按真实宽高比完整呈现的照片，且不重复 App 标志或常驻动作坞。标准与 Accessibility Dynamic Type 都只显示一个至少 44 pt 的“管理这一天”菜单；分别验证只签到、只影像、二者并存时菜单项的存在性、导出与破坏性操作之间的系统分隔、同一来源锚定的独立确认，以及删除后的事实保留关系。含照片状态默认 `.large`；只签到状态的紧凑 detent 不得缩成胶囊或让菜单大于 Sheet，Accessibility 字号和紧凑高度直接 `.large`。横图、竖图和极长本地化日期不得裁切、缩字、产生大面积内部空框、使用内容高度反馈循环或依赖设备型号常量。
- 今日页前台连续录屏必须能辨认细线漂移与低透明潮面位移；后台、失活与 Reduce Motion 使用同一静态事实表达，不允许按钮循环呼吸或潮面产生加载语义。
- 根背景环境动效需录屏核对 18 秒低振幅周期；进入后台和开启 Reduce Motion 后必须静止。静态截图只能验证构图，不能作为动效已验收证据。
- History 的相机标记与签到状态可同时辨认；仅影像不能被误读为完成。
- 简中/英文、iPhone/iPad、深浅、提高对比度、降低透明度、最大 Dynamic Type、VoiceOver、Switch Control、Reduce Motion 分别验收。
- 相机、保存、重拍、删除、恢复的焦点顺序与提示可理解；触觉和动效不作为唯一反馈。
- 反馈页在 iPhone/iPad、简中/英文、最大 Dynamic Type 与 VoiceOver 下保持正文编辑、分类、截图选择/预览/移除、诊断明细和发送动作可达；真机 Mail 已配置/未配置分别取证，系统返回 `.sent` 只表述为“已交给邮件”，不声称送达。

## 7. 既有系统能力回归

- 免费本地通知：授权、拒绝、外部撤权、实际到达、改时、签到后取消、跨日。
- iOS 26 scheduled Live Activity：唯一“萤火日晕”在 Lock Screen、Dynamic Island 的 expanded / compact / minimal 形态；开口弧与萤火点只在锁屏共享极坐标路径，灵动岛 compact / minimal / expanded 印记只使用琥珀色光源、不画开口环；萤火点须明显大于系统隐私指示点；岛内「签到」不得使用纸白/草绿实心键；降低亮度时移除光晕但保留等价静态终态；提醒时间只出现在 expanded 与锁屏，compact 不得复述系统时钟；系统表面只出现事实标题、时间和“签到”动作，不出现陪伴式说教文案；系统表面直接签到、锁定认证、App / Widget 签到后的完成态与结束；完整接受、部分接受、首个拒绝、容量竞争、撤权，以及剩余日期由免费通知接续且同日不重复。
- 高级功能页的“萤火日晕”卡必须同时显示 expanded、compact、minimal、完成态和 Lock Screen，并与正式渲染器共用印记、时间及状态组件。全部预览禁用命中与无障碍交互，点击或 VoiceOver 激活不得写入签到事实；中英文、默认与 Accessibility Dynamic Type 下分别截图验收。
- 高级功能页按 `currentCapabilities` 展示静野/晴昼同源标本，与设置主题预览共用 `PulseVisualThemeSpecimen`；标本不可点选、不写入当前主题；纸页手记不作为商品预览。中英文与 Accessibility Dynamic Type 下截图验收。
- 界面主题权益验证：纸页手记是未购买、清洁安装与完整重置后的唯一默认；静野/晴昼在未购买时保留真实预览并显示“锁 + 高级功能”，点击进入唯一购买页且不得改变当前主题。购买或恢复后两者立即可选并跨重启保持；退款/撤销/未验证权益时统一回到纸页手记并明确提示。三套主题分别验证签到、长按拍照、最近七日、当前连续、记事、历史、照片与 Accessibility 能力等价。
- Widget：App 未运行、设备锁定、跨午夜、快速双击、App/Widget 并发、杀进程和卸载重装。
- StoreKit：Configuration 仅作开发 fixture；Sandbox、TestFlight、生产商品、购买/恢复/取消/待处理/退款/撤销各自取证。

### 7.1 Debug 灵动岛测试台操作顺序

测试台只存在于 Debug App 的 Settings 最下方，且直接请求 ActivityKit，不是 App 内仿真。每次真机回归按以下顺序执行：

1. 先核对首页名称为“一日一印 Dev”，测试台中的 App、App Group 与 URL Scheme 全部为 Dev 身份；任何生产标识出现时测试台必须标红并禁用操作。Debug Widget 的 `co.fanr.pulse.dev.widgets` 身份由构建产物门禁核对，不由 App 界面猜测。
2. 打开系统“设置 > 一日一印 Dev”，确认实时活动已允许；返回测试台确认能力状态。
3. 点击“立即启动真实活动”；分别检查“萤火日晕”在 Lock Screen，以及 Dynamic Island 的 compact、minimal、expanded。确认锁屏小圆点落在圆弧路径端点；expanded 与锁屏均为标题下时间、右侧签到，锁屏时间不得使用独立胶囊；compact 不显示该时间。系统决定当前出现哪种形态，不能把 App 内预览当成系统证据。
4. 使用“仅切换为完成态”检查完成构图，再恢复待签到；这一步只验证 Activity content state，不得记录成业务签到通过。
5. 在未签到的 Dev 数据上重新启动活动，分别从 App 测试台和真实灵动岛操作“签到”；确认只生成一条签到事实、Widget 更新、活动先短暂显示“已签到”后结束。锁屏操作必须单独验证认证行为。
6. iOS 26 选择“30 秒后由系统启动”，立刻退出 App 并锁屏；记录系统是否在目标时间后交付。请求成功不等于系统准点展示。
7. 使用“结束全部 Dev 活动”清场。若需重测真实签到，到 Settings 清除 Dev 数据；它不会影响生产 App 数据。
8. 最后用 Release 构建复查无 Developer section、无测试台符号/文案，生产深链仍为 `pulse://today`。

真机记录至少包含：设备型号、iOS build、App build、Activity ID、提醒时间与时区、操作入口、锁定状态、预期/实际状态、截图或录屏文件名。没有这些证据时，状态只能是工程候选，不能标记灵动岛 GO。

## 8. 发布门禁

工程门关闭后仍需：Apple Distribution Archive、TestFlight 清洁安装/升级策略、App Store Connect 商品与隐私答案、截图/文案、支持/隐私页面、真实设备矩阵、多自然日试用和产品负责人视觉接受。

不要求恰好 30 名测试者才允许继续开发；但没有任何真实用户/设备证据也不能把长期价值、付费意愿或公开发布判断为 GO。样本计划必须服务具体决策，而不是替代工程和产品判断。
