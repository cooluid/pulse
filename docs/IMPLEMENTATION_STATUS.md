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

- 品牌颜色由 `design/brand-tokens.json` 生成；主导航为状态式悬浮底栏等现行结构。全 App 外观可持续改画，以代码与人工截图为准。
- 今日主动作支持单击签到与 0.45 秒长按“签到并拍照”；长按先权威签到再请求相机，VoiceOver 提供独立动作。待签到进入时最多一次有限呼吸；权威提交后才播放成功反馈；Reduce Motion 使用静态等价。
- 高阶权益在独立权益页；价格只读 StoreKit，已交付能力只读 `PulseEnhancementContract.currentCapabilities`。Widget 画廊收费卡以标题行“锁 + 高级功能”徽标作为唯一购买页入口，不再保留卡片底部的重复查看按钮。末项权益与恢复购买须能完整滚到购买条上方。
- Home Screen 八式产品枚举与共享渲染源 `PulseWidgetHomeRenderer` 已落地（待落之处免费，其余收费）。事实边界：纸层不映射历史、画廊预览不写权威 store、未解锁明确拒绝。
- scheduled Live Activity 已 clean-break 为 standard 生命周期与唯一“萤火日晕”共享构图；Activity attributes 明确携带逻辑日、提醒日期、时区与语言，不再包含或持久化样式。Lock Screen / Dynamic Island 直接调用同一个幂等留印 Intent。App、Home Screen Widget 或 Live Activity 留印后都会结束当天 Activity 并重建提醒计划。ActivityKit 只接受部分计划时保留已接受日期，以免费本地通知补齐其余 60 日窗口且同日不双发。
- Debug 构建保留真实 ActivityKit 工程测试台，支持唯一正式构图的立即请求、30 秒 scheduled 请求、视觉状态切换、权威留印和结束全部活动；它使用独立 App、Widget、App Group 与 URL Scheme 身份，不读写正式数据，且整页与设置入口均由编译条件排除于 Release。
- Home Screen 为 `AppIntentConfiguration`，构图由系统逐实例持有；Lock Screen“节律汇印”为无构图参数的独立 kind。未签到整块是唯一签到按钮；Extension 在 timeline 边界独立验证权益。
- Widget 动效为“稀疏时段氛围 + 权威签到事件”：`PulseWidgetTimelineSchedule` 每天最多五条（当前 + 剩余 06/12/18 + 下一逻辑日）；氛围不报时、不承诺准点。单次动画 ≤ 两秒由 `PulseWidgetMotionPresentation.systemMaximumAnimationDuration` 与测试门禁持有。签到 reload 后各式用自有主物件做一次有限变装；画廊与 Extension 共用 Renderer，预览不写 store。Reduce Motion / Always-On 走静态终态。正式枚举只含现行八式；未知旧标识失败关闭。
- 今日与记录照片详情共用同一系统 Sheet 骨架与独立删除事务；含照片用 `.large`，只签到用语义紧凑 detent 并保留 `.large`；无障碍大字号直接 `.large`。
- 根页可有低幅环境动效（scene active 且未开 Reduce Motion）；不得伪装进度或驱动按钮闪烁。
- 状态、操作、错误与购买文案保持直接短句；Widget 画廊的八式卡片例外采用与主物件唯一对应的双语意境短文，精确正文只由 String Catalog 持有，不把装饰解释成历史事实。运行时不再保留“低压力、面向所有用户免费、不是为了打分作证”等解释性废话或旧功能式样式描述。
- “我的一件事”名称统一由领域层约束为 4...12 个 Swift `Character`，首启、设置、恢复校验、Widget 与错误提示不再各自维护长度；加密备份密码统一降为至少 4 个字符，不要求字符组合，仍保留导出二次确认、1024-byte 上限与无法找回提示。
- 删除旧 `CheckInRepositoryProtocol` / `SwiftDataCheckInRepository` 名称，统一为 `PulseRepositoryProtocol` / `SwiftDataPulseRepository`。
- 删除旧 `PulseBackupDocument` 路径，系统导出统一使用 `PulseBackupExport: Transferable`；单张原图导出使用独立 JPEG Transferable。
- 删除 1.0 发布范围与“1.0 后再说”的路线图权威，建立 1.1 发布合同和连续产品路线图。
- schema 1.0、备份 v1、旧内部 store、旧 decoder 和旧生成物不承担兼容责任；首次公开发布 1.1 后才建立显式迁移合同与兼容测试。
- 开发和确定性工程门禁不依赖“先完成 30 名用户”。真实用户用于验证理解、留存与付费价值，样本按决策、风险、最小有意义效应和停止规则预登记。

## 当前自动化与构建证据

验证环境：macOS 26.6、Xcode 26.6（17F113）、iPhone 17 Pro / iOS 26.5 Simulator（arm64）。

- 八式 Home Screen Widget 共享渲染器与唯一“萤火日晕”Live Activity 共享渲染器已落地；锁屏圆弧端点与萤火点由同一极坐标几何计算，compact / expanded 显示 attributes 中的真实提醒时间。本轮 153 项单元/集成测试与 22 项 UI 测试全部通过；锁屏明暗态、完成态、compact、expanded 与无障碍大字号均有确定性快照。真实 Lock Screen / Dynamic Island、最大 Dynamic Type、通知到达、设备锁定 Intent 认证和 StoreKit Sandbox 仍需真机取证。在这些证据完成前保持 **ENGINEERING CANDIDATE / INTERFACE CANDIDATE**。
- 媒体自动化覆盖独立删除/重新关联、同日替换、文件安装/读取/审计、缩略图损坏、无相册回退、v2 归档往返、随机性、错误口令、篡改、v1 拒绝、缺条目与缩略图身份不匹配。
- 本轮有八式画廊待办/完成共 16 张原始截图及部分 ImageRenderer 附件；单卡变化预览约 5 秒（早/日/晚/完成串联），各段 ≤ 两秒。这只证明 App 内共享 Renderer 预览，仍为 **INTERFACE CANDIDATE**；不能代替真实 Widget host、系统 reload、Lock Screen kind、Clear/vibrant、Reduce Motion 或真机体验 GO。
- 本轮未签名 Release `generic/platform=iOS Simulator` 构建通过；Debug 静态分析通过；Swift 警告按错误处理。
- 24 项品牌生成资产检查通过（含 AppIcon 三外观、小尺寸评审图与 Live Activity 语义色）。App、InfoPlist 与 Widget String Catalog / plist 可解析。
- `git diff --check` 通过；生产 Swift 源码没有 TODO/FIXME/HACK、相册回退、样例照片或演示数据路径。

## 仍为 NO-GO 的证据

- 真实 iPhone：首次授权、拒绝后从设置恢复、前后镜头、方向、取消、重拍、低存储、写入中断、杀进程、重启、跨日与设备锁定。
- 真实 iPad：相机能力差异、横竖屏、分屏、大字号和文件导入/导出。
- 数据恢复：从真实设备导出带多张原图的 v2 归档，在另一清洁安装恢复并逐张核对；清除与卸载后确认无非预期残留。
- 系统与无障碍：真人 VoiceOver、最大 Dynamic Type、Reduce Motion、提高对比度、通知、Widget host、iOS 26 Live Activity / Dynamic Island 和 StoreKit Sandbox/TestFlight。Home Screen 外观以同设备、同尺寸真机复拍为准；模拟器安全区 / 静态渲染 / 构建通过不能写成主屏视觉 GO。
- 分发：当前源码的不可变提交、Apple Distribution Archive、签名/entitlement/dSYM/隐私清单核验、TestFlight 处理与清洁安装、App Store 商品/隐私答案/截图/文案和公开支持/隐私站点一致性。

## 历史证据边界

Build 2 曾生成、上传并由内部 TestFlight 验证；Apple Delivery UUID 为 `0373b760-05e0-4299-bb50-6bd6ec3d2959`。该证据只属于 Pulse 1.0 (2)，不包含 schema 1.1、媒体仓储或归档 v2，不得外推到当前 checkout。

历史记录见 [Pulse 1.0 (2) 发布候选证据](./RELEASE_CANDIDATE_1_0_2.md)。

## 下一步顺序

1. 在真实 iPhone / iPad 关闭媒体、权限、低存储、恢复和无障碍门禁，记录设备、系统版本、步骤与结果。
2. 回归通知、Widget、scheduled Live Activity 与 StoreKit Sandbox；这些能力与照片事实互不兜底。
3. 完成当前 `1.1 (4)` 的签名 Archive 和完整产物审计，再进入 TestFlight 清洁安装。
4. 用小规模真实使用先发现理解和摩擦问题；留存或“岁月流影”付费判断按预登记实验扩大样本，不等待某个通用整数才继续工程开发。
