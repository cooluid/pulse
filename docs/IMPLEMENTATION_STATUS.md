# Pulse 1.1 实现与验收状态

更新时间：2026-08-15

当前 checkout 结论：**1.1 (4) ENGINEERING CANDIDATE / INTERFACE CANDIDATE / DISTRIBUTION NO-GO**。

“今日入镜”领域、文件、界面、归档与自动化已经进入当前唯一生产基线；真实相机、低存储、真机无障碍、签名 Archive、TestFlight 清洁安装和 App Store Connect 仍没有本轮证据，因此不能把工程完成写成公开发布 GO。

## 当前唯一生产基线

- 最低部署版本为 iOS / iPadOS 18.0；App 与 Widget 版本统一为 `1.1 (4)`。
- `PulseRepository` 独占 Habit、CheckInRecord 与 ImprintMedia 的事实写入；页面和 Widget 只消费不可变快照。
- SwiftData 只接受 `PulseSchema 1.1.0` 精确 marker。当前仍处于首次公开发布前，旧内部安装要求清洁安装，不保留 schema 1.0 迁移分支或双轨消费者。
- 正式 store 只有 App Group 下 `Library/Application Support/Pulse/Pulse.store`；媒体只有 `Media/originals`、`Media/thumbnails` 与事务用 `Media/staging`。
- 每个逻辑日最多一条媒体。签到与媒体是独立事实：删除媒体不影响签到；删除签到保留媒体并解除关联；同日重新签到重新关联。
- 图片处理只接受用户主动拍摄，统一去元数据并生成 JPEG 原图与缩略图；相机不可用、拒绝或失败时明确报错，不回退相册、样例图或占位图。
- 原图和缩略图各自保存 byteCount 与 SHA-256；不可变 UUID 路径、路径穿越、符号链接、尺寸上限、孤儿文件与损坏文件都由正式仓储和启动审计处理。
- `.pulsebackup` 只有 container v2 / payload v2。Manifest、签到、原图与缩略图逐条 AES-256-GCM 认证；错误口令、篡改、缺失、额外、重复、未知版本或超限均失败关闭，v1 不读取。
- 恢复先在受保护隔离目录完成解密和全部身份验证，再经用户确认替换正式数据；提交前失败回收新文件，提交后的孤儿清理由启动审计收敛，不能误删已提交文件。
- 照片从不进入 Widget、Live Activity、Lock Screen、StandBy、通知或共享偏好。

权威合同为 [1.1 发布范围](./RELEASE_SCOPE_1_1.md)、[产品需求](./PRODUCT_REQUIREMENTS.md)、[领域合同](./DOMAIN_CONTRACT.md)、[数据加密合同](./DATA_ENCRYPTION_CONTRACT.md)、[技术设计](./TECHNICAL_DESIGN.md)、[路线图](./PRODUCT_ROADMAP.md) 与 [测试计划](./TEST_PLAN.md)。

## 产品与收费边界

- 永久免费：签到、拍摄、查看、重拍、删除、关闭邀请、原图单独导出、照片空间查看，以及包含全部原图/缩略图的加密备份与完整恢复。
- 当前一次买断高阶权益授予类型化能力目录中的高级 Widget 构图和支持设备上的 scheduled Live Activity，不把用户自己的照片或数据主权重新收费。未来能力只有实际发布后才加入同一目录和权益页。
- 未来可收费：本地智能对齐、长区间岁月流影、年度影片、4K、跨阶段比较与高级档案排版；权益结束不能锁住、删除或降质既有原图和已导出成果。
- 不做考勤证明、补签照片、位置水印、年龄/颜值/身份/健康推断，也不静默上传面貌照片。

## 本轮 clean break

- 品牌按产品确认从“断层海报 + 贴边双页签”干净切换为“草野脉冲 + 状态式悬浮底栏”；颜色仍只由 `design/brand-tokens.json` 生成，不保留断层海报运行时分支。底栏两个入口稳定等宽，根内容按实测底栏高度清空滚动末端。
- 今日深草行动印支持单击签到与 0.45 秒长按“签到并拍照”；长按先完成权威签到提交，再请求相机，且 VoiceOver 提供独立动作。待签到进入时只有一次有限呼吸，权威提交后才播放收缩、落印和低强调回波，Reduce Motion 使用静态形状替换。
- 高阶权益从设置内嵌分组迁到独立权益页；商品价格只读 StoreKit，当前已交付权益只读 `PulseEnhancementContract.currentCapabilities`。权益页使用轻量身份区、横向构图预览、等宽满行权益卡和紧凑购买条，末项权益与恢复购买必须能完整滚到购买条上方。
- Home Screen Widget 八式产品枚举与共享渲染源 `PulseWidgetHomeRenderer` 已落地（待落之处免费，其余收费）。外观为持续美术迭代，以代码与人工截图为准；原型 HTML 仅为探索参考，不以长文档锁死画法。事实边界仍成立：纸层不映射历史、画廊预览不写权威 store、未解锁明确拒绝。
- Home Screen Widget 已改为 `AppIntentConfiguration`，构图由系统逐实例持有；Lock Screen“节律汇印”拆为无构图参数的独立 Widget kind。App Group 全局 `widget.style` 及 App 内伪“已选择”路径已删除。未签到 Home Screen 整块是唯一签到按钮；Extension 在 timeline 边界独立验证权益，未授权收费构图明确报未解锁，不静默替换。
- Widget 动效已 clean-break 为“稀疏时段氛围 + 权威签到事件”双层合同：`PulseWidgetTimelineSchedule` 从单一集中边界生成当前状态、当天剩余的 06:00 / 12:00 / 18:00 氛围状态与下一逻辑日，每天最多五条；早间 / 日间 / 晚间只改变同一事实的低幅构图，不承担准确报时，也不承诺 iOS 准点展示。Apple 官方规定 Widget / Live Activity 单次动画最长两秒；这一上限现由 `PulseWidgetMotionPresentation.systemMaximumAnimationDuration` 唯一持有并由测试逐材料失败关闭。签到事实保存并 reload 后，八式分别由印位、开口环与单星、纸叠压痕、大号日数、带日号主日戳、回响核心、今日鞋底与岸尺刻度完成自己的物件变装，不再依赖共享签到圈；完成曲线按材料为 1.45...1.90 秒，时段氛围为 0.76...0.96 秒，八种时段姿态也由同一规格集中定义，不再共享同一个左右横移模板。App 画廊仍使用同一正式 Renderer，但多个独立状态不再错误压缩到两秒内：每个时段先完成再进入下一状态，完成态覆盖完整材料变装；预览只瞬时投影展示时间和今天状态，不写 Repository、App Group 或正式 Timeline。Reduce Motion 跳过三时段串联，只呈现当前时段待办与完成的静态等价；Always-On 由 `isLuminanceReduced` 显式进入同一静态 Renderer 路径。预览控件保留在标题信息行内的轻量圆形播放/重播按钮；只有锁定构图显示状态徽章，已包含/已解锁的重复勾号和对应文案已删除，收费构图的购买入口仍为独立动作。已删除通用仪式圈、旧 `.seal` 定向墨迹、旧潮痕日环、旧复选框式纸封、旧独立蜡封、旧温度计式潮位标、脚趾足印、`PulseWidgetVisualVariant`、ornament seed 与旧 Motion Contract，不保留兼容入口。潮痕外观可迭代，不以文档禁止题材。
- 今日与记录照片详情已 clean-break 为同一个内容优先的系统 Sheet 骨架：统一导航栏、关闭、真实像素比例照片和尾侧管理菜单，不再重复 App 标志、保留三栏动作坞或建立两套详情实现。含照片状态统一使用 `.large`；只签到状态使用集中定义的语义紧凑 detent 并保留 `.large`，Accessibility 字号与紧凑高度直接使用 `.large`。已删除内容高度反馈循环、设备型号分支和散落 detent 数值；两种删除仍是独立事务与独立确认。
- 根页面常态背景加入 18 秒低振幅呼吸与细线漂移，今日页额外使用三层低透明潮面增强可感知性，最高 12 fps；仅在 scene active 且未开启 Reduce Motion 时推进，后台与 Reduce Motion 使用静态相位。该环境层不得驱动按钮持续闪烁或伪装成进度反馈。
- 首启、今日、记录、设置与购买文案统一为短句；删除运行时“低压力、面向所有用户免费、不是为了打分作证”等解释性废话。
- “我的一件事”名称统一由领域层约束为 4...12 个 Swift `Character`，首启、设置、恢复校验、Widget 与错误提示不再各自维护长度；加密备份密码统一降为至少 4 个字符，不要求字符组合，仍保留导出二次确认、1024-byte 上限与无法找回提示。
- 删除旧 `CheckInRepositoryProtocol` / `SwiftDataCheckInRepository` 名称，统一为 `PulseRepositoryProtocol` / `SwiftDataPulseRepository`。
- 删除旧 `PulseBackupDocument` 路径，系统导出统一使用 `PulseBackupExport: Transferable`；单张原图导出使用独立 JPEG Transferable。
- 删除 1.0 发布范围与“1.0 后再说”的路线图权威，建立 1.1 发布合同和连续产品路线图。
- schema 1.0、备份 v1、旧内部 store、旧 decoder 和旧生成物不承担兼容责任；首次公开发布 1.1 后才建立显式迁移合同与兼容测试。
- 开发和确定性工程门禁不依赖“先完成 30 名用户”。真实用户用于验证理解、留存与付费价值，样本按决策、风险、最小有意义效应和停止规则预登记。

## 当前自动化与构建证据

验证环境：macOS 26.6、Xcode 26.6（17F113）、iPhone 17 Pro / iOS 26.5 Simulator（arm64）。

- 当前生产渲染器已 clean-break 为八种仪式物件；本轮 Debug Simulator 的 App 与 Widget Extension 编译通过，133 项单元/集成测试全部通过。名称 4 / 12 字符边界、3 字符密码失败关闭、4 字符密码完整归档往返、12 字符首页投影、设置编辑持久化、密码按钮门禁、画廊预览投影不改变权威快照，以及 Widget 时段解析、最多五条 entry、零点重投影、官方两秒上限和八式时段姿态唯一性均已覆盖；星环 clean-break 门禁要求正式枚举只保留 `orbit`、正式原型只保留 ORBIT，并为四种代表尺寸生成待办与完成共八张原始渲染附件；几何门禁覆盖十种响应式尺寸、早间 / 日间 / 晚间两态共 60 组，要求环上只有一颗星、这颗星落在圆环中线且完整位于安全区，同时拒绝旧气态主星、六颗伴星、`starTrail`、`case seal`、旧墨迹物件与旧原型标题。手札结构门禁明确要求代码只消费过去六日、原型小号/中号各恰好六枚邮路印，并拒绝旧 `PulseLetterClosureMark`、第七枚今天邮戳和重复日号。新增混合历史事实 Renderer 门禁，以项目开始前 / 已签到 / 漏签的真实状态枚举分别生成小号与中号原始截图，确认已签到投影为浅受压底、断续指腹残纹与偏压墨屑组成的半实印泥残印，而非硬实圆点、规则三弧图标或第二层今天外圈。本轮免费/收费画廊边界和八种构图两态可达流程两条定向 UI 测试通过，并保存预览完成态与最终 16 张构图附件；视觉复审后删除了会把数影误读成统计图的柱状完成符号，并继续清除了曲线图式纸角、脚趾/爪印式足迹及十字/温度计式潮位标。Release Simulator build、Analyze 与 19 项生成品牌资产一致性检查通过。对应首启、首页与加密备份定向 UI 流程的既有原始截图证据仍在；统一记录详情的标准字号与 Accessibility XXXL 两条定向 UI 测试此前通过。当前只签到状态的稳定紧凑 Sheet、全高无障碍结构与来源锚定菜单均已按当前原始像素截图复审；对抗测试还证明仅设置 `destructive` role 会让菜单图标继承品牌绿，因此最终实现以集中 `UIColor.systemRed` 语义 tint 同步图标和文字，复跑截图通过。本轮完整 scheme UI runner 在模拟器启动 App 时进入 Xcode 等待态并被主动中止，因此不把它记作 UI 通过或产品失败；没有本轮真实 Home Screen Widget host 或真机时段交付证据，也不把 App 画廊模拟器截图冒充系统表面证明。整个 1.1 仍受媒体真机、系统表面与分发门禁约束，保持 **ENGINEERING CANDIDATE / INTERFACE CANDIDATE**。
- 媒体自动化覆盖独立删除/重新关联、同日替换、文件安装/读取/审计、缩略图损坏、无相册回退、v2 归档往返、随机性、错误口令、篡改、v1 拒绝、缺条目与缩略图身份不匹配。
- 本轮新增取得八种 App 画廊待办/完成两态共 16 张当前原始像素截图，并以共用正式渲染器复审；星环另以小号/中号待办与完成四张 ImageRenderer 原始附件复审。待落之处坑心只写“空着”且已有环境留位场；星环使用品牌开口环与环上唯一的一颗星；待办时这颗星空心带芯并落在开口里，完成时开口合上、这颗星以亮过环壁的填色点亮并由行动色连续转为草绿，环心有低透明色场且与环壁留沟槽；叠印铺满画布的四页纸叠，今日印为顶纸压痕印面，完成后吃墨并折角；数影保持大日号主角；手札为单张笺纸，左上只显示月份，右上唯一主日戳在待办开口与完成压实两态都保留清晰日号，小号/中号下沿均恰好六枚过去邮路印且无日期重复；补充的混合历史原始截图进一步确认已签到为带浅受压底、断续指腹残纹和两处深浅偏压墨屑的半实印泥残印，漏签为细空心、项目开始前为更淡更小空心，旧硬实墨点与“七枚日印”用户文案均已清理；静场加深回响核心但不压暗整卡；来路使用真实六日计数、鞋底轮廓和今日实印；潮痕已无黑色装饰块、天空、云和鱼，以潮面上移和岸尺高低刻度表达完成。最终 UI 流程实测单卡变化预览约 5 秒，是早间、日间、晚间与完成态四个独立变化的串联；各段动画仍分别小于官方两秒上限。这只证明 App 内共享 Renderer 的预览链路，结果仍仅是 **INTERFACE CANDIDATE**。App 内画廊不能替代真实 Home Screen 小号/中号 Widget host，也不能证明系统实际 reload 动画、逐实例配置、独立 Lock Screen kind、accented/vibrant/Clear、Reduce Motion 或人体体验 GO；当前 `simctl ui` 也不提供 Reduce Motion 切换，未伪造该项模拟器证据。
- 本轮未签名 Release `generic/platform=iOS Simulator` 构建通过；Debug 静态分析通过；Swift 警告按错误处理。
- 19 项品牌生成资产检查通过，包含由同一令牌确定性产出的 AppIcon 三外观与小尺寸评审图；已删除潮痕两项天空语义色。App、InfoPlist 与 Widget String Catalog 可解析；App/Widget plist 可解析。
- `git diff --check` 通过；生产 Swift 源码没有 TODO/FIXME/HACK、相册回退、样例照片或演示数据路径。

## 仍为 NO-GO 的证据

- 真实 iPhone：首次授权、拒绝后从设置恢复、前后镜头、方向、取消、重拍、低存储、写入中断、杀进程、重启、跨日与设备锁定。
- 真实 iPad：相机能力差异、横竖屏、分屏、大字号和文件导入/导出。
- 数据恢复：从真实设备导出带多张原图的 v2 归档，在另一清洁安装恢复并逐张核对；清除与卸载后确认无非预期残留。
- 系统与无障碍：真人 VoiceOver、最大 Dynamic Type、Reduce Motion、提高对比度、通知、Widget host、iOS 26 Live Activity / Dynamic Island 和 StoreKit Sandbox/TestFlight。用户的当前真实主屏反馈已否决行星式星环：签到伴星不可见、轨道与六颗伴星关系不成立。随后 clean-break 为开口环上唯一一颗星；2026-08-15 同设备完成态主屏截图确认方向成立，但环心空洞、卡片苍白、完成星与环壁同色。本轮已补环心色场、环境场，并把完成星改为亮过环壁；仍须同设备、同尺寸复拍后才能把空洞/苍白写成修复，不得把 Simulator 安全区测试、静态渲染与构建通过写成主屏修复 GO。
- 分发：当前源码的不可变提交、Apple Distribution Archive、签名/entitlement/dSYM/隐私清单核验、TestFlight 处理与清洁安装、App Store 商品/隐私答案/截图/文案和公开支持/隐私站点一致性。

## 历史证据边界

Build 2 曾生成、上传并由内部 TestFlight 验证；Apple Delivery UUID 为 `0373b760-05e0-4299-bb50-6bd6ec3d2959`。该证据只属于 Pulse 1.0 (2)，不包含 schema 1.1、媒体仓储或归档 v2，不得外推到当前 checkout。

历史记录见 [Pulse 1.0 (2) 发布候选证据](./RELEASE_CANDIDATE_1_0_2.md)。

## 下一步顺序

1. 在真实 iPhone / iPad 关闭媒体、权限、低存储、恢复和无障碍门禁，记录设备、系统版本、步骤与结果。
2. 回归通知、Widget、scheduled Live Activity 与 StoreKit Sandbox；这些能力与照片事实互不兜底。
3. 完成当前 `1.1 (4)` 的签名 Archive 和完整产物审计，再进入 TestFlight 清洁安装。
4. 用小规模真实使用先发现理解和摩擦问题；留存或“岁月流影”付费判断按预登记实验扩大样本，不等待某个通用整数才继续工程开发。
