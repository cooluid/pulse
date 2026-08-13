# Pulse 1.1 实现与验收状态

更新时间：2026-08-13

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
- Home Screen Widget 与 App 内画廊统一消费同一 `PulseWidgetHomeRenderer`，正式构图收敛为“呼吸环、数影、深景、静序、七日谱”五式。旧八式、独立近似预览、硬编码假日期和重复七日摘要已删除；五式分别承担均衡、时间剪影、纵深节律、极简秩序和七日直读任务。
- Home Screen Widget 已改为 `AppIntentConfiguration`，构图由系统逐实例持有；App Group 全局 `widget.style` 及 App 内伪“已选择”路径已删除。未签到 Home Screen 整块是唯一签到按钮，Extension 在 timeline 边界独立解析权益。
- 记录详情在标准 Dynamic Type 下把“导出原图 / 删除照片 / 删除签到记录”合并为一个横向三分动作坞；Accessibility Dynamic Type 下改为导出跨首行、两个删除动作并列次行。三个动作仍是独立事务、独立确认和独立辅助功能入口，不把照片与签到事实合并。
- 根页面常态背景加入 18 秒低振幅呼吸与细线漂移，今日页额外使用三层低透明潮面增强可感知性，最高 12 fps；仅在 scene active 且未开启 Reduce Motion 时推进，后台与 Reduce Motion 使用静态相位。该环境层不得驱动按钮持续闪烁或伪装成进度反馈。
- 首启、今日、记录、设置与购买文案统一为短句；删除运行时“低压力、面向所有用户免费、不是为了打分作证”等解释性废话。
- 删除旧 `CheckInRepositoryProtocol` / `SwiftDataCheckInRepository` 名称，统一为 `PulseRepositoryProtocol` / `SwiftDataPulseRepository`。
- 删除旧 `PulseBackupDocument` 路径，系统导出统一使用 `PulseBackupExport: Transferable`；单张原图导出使用独立 JPEG Transferable。
- 删除 1.0 发布范围与“1.0 后再说”的路线图权威，建立 1.1 发布合同和连续产品路线图。
- schema 1.0、备份 v1、旧内部 store、旧 decoder 和旧生成物不承担兼容责任；首次公开发布 1.1 后才建立显式迁移合同与兼容测试。
- 开发和确定性工程门禁不依赖“先完成 30 名用户”。真实用户用于验证理解、留存与付费价值，样本按决策、风险、最小有意义效应和停止规则预登记。

## 当前自动化与构建证据

验证环境：macOS 26.6、Xcode 26.6（17F113）、iPhone 17 Pro / iOS 26.5 Simulator（arm64）。

- 本轮五式重构需以当前全量测试结果为准；旧“八式选择后重启持久化”结论已失效并从门禁删除。工程状态在本轮 build、单测、UI 回归与残留扫描完成前保持 **ENGINEERING CANDIDATE**，不沿用旧计数冒充当前证据。
- 媒体自动化覆盖独立删除/重新关联、同日替换、文件安装/读取/审计、缩略图损坏、无相册回退、v2 归档往返、随机性、错误口令、篡改、v1 拒绝、缺条目与缩略图身份不匹配。
- 本轮需重新取得五式 App 画廊原始像素截图并逐张复审。即使通过，结果也仅是 **INTERFACE CANDIDATE**；App 内画廊不能替代真实 Home Screen 小号/中号 Widget host，也不能证明逐实例系统配置、accented/vibrant/Clear、Reduce Motion 或人体体验 GO。
- Release `generic/platform=iOS` 无签名构建通过；Release 静态分析通过；Swift 警告按错误处理。
- 19 项品牌生成资产检查通过，包含由同一令牌确定性产出的 AppIcon 三外观与小尺寸评审图；App、InfoPlist 与 Widget String Catalog 可解析；App/Widget plist 可解析。
- `git diff --check` 通过；生产 Swift 源码没有 TODO/FIXME/HACK、相册回退、样例照片或演示数据路径。

## 仍为 NO-GO 的证据

- 真实 iPhone：首次授权、拒绝后从设置恢复、前后镜头、方向、取消、重拍、低存储、写入中断、杀进程、重启、跨日与设备锁定。
- 真实 iPad：相机能力差异、横竖屏、分屏、大字号和文件导入/导出。
- 数据恢复：从真实设备导出带多张原图的 v2 归档，在另一清洁安装恢复并逐张核对；清除与卸载后确认无非预期残留。
- 系统与无障碍：真人 VoiceOver、最大 Dynamic Type、Reduce Motion、提高对比度、通知、Widget host、iOS 26 Live Activity / Dynamic Island 和 StoreKit Sandbox/TestFlight。
- 分发：当前源码的不可变提交、Apple Distribution Archive、签名/entitlement/dSYM/隐私清单核验、TestFlight 处理与清洁安装、App Store 商品/隐私答案/截图/文案和公开支持/隐私站点一致性。

## 历史证据边界

Build 2 曾生成、上传并由内部 TestFlight 验证；Apple Delivery UUID 为 `0373b760-05e0-4299-bb50-6bd6ec3d2959`。该证据只属于 Pulse 1.0 (2)，不包含 schema 1.1、媒体仓储或归档 v2，不得外推到当前 checkout。

历史记录见 [Pulse 1.0 (2) 发布候选证据](./RELEASE_CANDIDATE_1_0_2.md)。

## 下一步顺序

1. 在真实 iPhone / iPad 关闭媒体、权限、低存储、恢复和无障碍门禁，记录设备、系统版本、步骤与结果。
2. 回归通知、Widget、scheduled Live Activity 与 StoreKit Sandbox；这些能力与照片事实互不兜底。
3. 完成当前 `1.1 (4)` 的签名 Archive 和完整产物审计，再进入 TestFlight 清洁安装。
4. 用小规模真实使用先发现理解和摩擦问题；留存或“岁月流影”付费判断按预登记实验扩大样本，不等待某个通用整数才继续工程开发。
