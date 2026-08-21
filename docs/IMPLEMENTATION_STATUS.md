# Pulse 1.1 实现与验收状态

更新时间：2026-08-20

当前 checkout 结论：**1.1 (4) ENGINEERING CANDIDATE / INTERFACE CANDIDATE / DISTRIBUTION NO-GO**。

领域、持久化、媒体、归档、提醒、三主题、iPhone/iPad 系统表面和 Watch 基础工程路径已收敛；真实相机、磁盘压力、真机无障碍、真实 Widget / Live Activity host、StoreKit Sandbox、配对 WatchConnectivity/complication/Smart Stack、Apple Distribution Archive、TestFlight 清洁安装和 App Store Connect 仍没有本轮完整证据，因此不能写成公开发布 GO。

## 当前唯一生产基线

- 最低 iOS / iPadOS 18.0，App 与 Widget 统一为 `1.1 (4)`；1.1 只支持单 Scene，不声明尚未设计的 iPad 多窗口能力。
- `SwiftDataPulseRepository` 独占 Habit、CheckInRecord 与 ImprintMedia 事实写入；App、Widget 和页面只消费不可变快照。
- `CheckInRecord` 是签到、统计、今天状态和月历的唯一真源；记事是其可编辑注释；`ImprintMedia` 是独立影像事实。
- 唯一 store 是 App Group `Library/Application Support/Pulse/Pulse.store`，只接受 `PulseSchema 1.1.1` 精确 marker。首次公开发布前不迁移实验性旧 store。
- 媒体只存在于 `Media/originals`、`Media/thumbnails` 与事务 `Media/staging`；持久化路径统一为小写 UUID JPEG。文件和三个受管目录的符号链接、路径穿越、非规范文件名、缺失、损坏、超限和孤儿均失败关闭或由审计收敛。
- `.pulsebackup` 只接受 container v2 / payload v3；Manifest、签到、记事、原图和缩略图逐条 PBKDF2 + AES-256-GCM 认证。旧 payload / container、缺字段、未知字段、错误口令、篡改、缺失、额外、重复和尾随均拒绝。
- 拍照、查看、删除、原图导出、完整加密备份与恢复永久免费；静野/晴昼、七种额外 Home Screen Widget 样式和支持设备上的 scheduled Live Activity 只由同一已验证 StoreKit entitlement 控制。
- App Group UserDefaults 只由 `PulseSharedSettings` 管理语言、提醒开关和提醒时间；不保存签到、构图、权益或统计副本。
- 正式 Widget 产品枚举只在 `PulseWidgetStyle` 与 String Catalog，外观只在共享 `PulseWidgetHomeRenderer`；旧 HTML 原型和并行样式来源已删除。
- `PulseWatchShared` 统一 Watch 协议、project revision、codec、`nextDayBoundary` 新鲜度与单文件本地状态；`PulseWatch` 和 `PulseWatchWidgetsExtension` 只保存最新快照、durable outbox 和最后回执。坏快照、旧快照、项目变化和乱序回执不再隐式删除命令；命令只由匹配回执或用户明确重试/清除收敛。
- Watch App、Watch Widget Intent 和 timeline 共用各自进程级唯一 WCSession runtime；Intent 使用系统精确动作时间，返回前完成异步激活，并取得即时回执或正式排队同一 `operationID` 的后台用户信息。iPhone 进程启动即建立接收器，所有命令仍只进入 `PulseAppModel` 与同一 `SwiftDataPulseRepository`。
- Watch 写入入口使用 `throws(PulseWatchRejectionReason)` 的单一类型化失败合同；协议、项目、时区、动作时间、暂时不可用和持久化失败均返回正式回执。Watch 以失败状态和一次告警触觉呈现，并提供新命令重试；`pendingSync` 与 `committed` 继续严格分离。
- Watch App 可向 iPhone 请求由当前 Repository 即时重建的快照；iPhone Widget / Live Activity 提交后只发送不携带业务事实的进程内刷新信号，使 App 与 Watch 快照跟随同一正式写入。信号不是第二状态源。
- Watch 颜色只来自 `brand-tokens.json` 的 `watch` 语义组；Watch App 使用深蓝全幅状态场、三层波面与右侧日轴，complication 继续适配 full-color / accented 渲染组。iPhone Asset Catalog 只复制同源 Watch 状态场颜色用于设置页真实预览。
- Watch App 页级尺寸只由 `PulseWatchLayoutMetrics` 读取实际容器连续求值，不保留表径/型号分支。标准字号统一使用无滚动单屏：左侧显示「今日」与真实动作/状态，右侧节点使用离散位置且不可拖动，异常恢复态保留真实状态与 44 pt 重试动作；Accessibility Dynamic Type 进入明确滚动路径。
- 三层波面仅在 Scene 活跃、屏幕非低亮、Reduce Motion 关闭且 iPhone“波浪动态”设置开启时，以 10 / 13 / 17 秒、12 fps 错速漂移。设置随正式 Watch 快照同步；需要同步、失败、后台、Always-On、Reduce Motion 与用户关闭开关时使用无时间线的静态终态。
- iPhone 设置已有 Apple Watch 独立入口、蓝色状态场预览、WCSession 配对/安装状态与“波浪动态”开关；基础 Watch 查看与签到保持免费。

权威合同为 [1.1 发布范围](./RELEASE_SCOPE_1_1.md)、[产品需求](./PRODUCT_REQUIREMENTS.md)、[领域合同](./DOMAIN_CONTRACT.md)、[数据加密合同](./DATA_ENCRYPTION_CONTRACT.md)、[技术设计](./TECHNICAL_DESIGN.md)、[系统仪式合同](./PULSE_RITUAL_CONTRACT.md) 与 [测试计划](./TEST_PLAN.md)。

## 2026-08-19 产品级收口

- App、Widget Intent 和 Live Activity 结束逻辑统一消费 Repository 提交回执的逻辑日，不再用调用前缓存日期或二次猜测日期。
- Live Activity 完成态使用 ActivityKit 的延迟 dismissal policy，不再以 1.7 秒 sleep 阻塞 App 或系统签到结果返回。
- 提醒重排读取真实 active Activity 逻辑日；保留的当天 Activity 会从新计划排除，改提醒时间不会生成同日第二条触达。
- 日期边界或 Scene 激活若撞上导出、恢复、媒体等互斥操作，会登记一次待处理激活并在操作结束后正式重载，不再丢失跨日刷新。
- 纸页手记、静野、晴昼共用同一个签到、长按拍照、成功状态机、完成时间、媒体缩略影和无障碍控件；主题只保留构图差异。隐藏根页会暂停环境 Timeline，晴昼历史已移除重复月份水印。
- 媒体相对路径由 `PulseMediaPath` 单一合同生成和校验；Repository、归档、恢复和文件仓储不再各写一份字符串规则。
- Widget 样式合同、设计常量和共享 Renderer 已分离；无引用颜色、常量、组件和全部旧 Widget HTML 探索稿已删除。
- 运行时文案统一使用“签到”；通知和 Live Activity 只写事实与动作，不再出现“准备好时回来”或“打卡”等并行人格。
- 测试从格式敏感的源码片段断言转向类型化策略、几何、渲染附件和真实 UI 流程；源码扫描只保留旧符号禁入、敏感词和构建配置门禁。
- `site` 子模块只剩三条正式 URL 跳转和 Sites 必需构建骨架；旧产品 CSS、CSS 图标、认证模板、OG 图片、图片优化和无用 Tailwind/PostCSS 依赖已删除。
- Watch 快照过期、outbox 生命周期、App Intent 进程生命周期、失败恢复、触觉、日期与颜色已收敛为单一实现；旧的快照清空命令行为、临时 WCSession client、重复状态文案映射和通用 Watch 色板已删除。
- container v2 / payload v3 的 App Store 加密出口分类仍待正式问卷或文档审查；结论冻结前 App / Widget Info.plist 不预填 `ITSAppUsesNonExemptEncryption`。

## 当前自动化与构建证据

验证环境：macOS 26.6、Xcode 26.4（17E192）、iPhone 16 Pro / iOS 18.6 Simulator（arm64）、watchOS 26.4 Simulator runtime（23T240b）。

- 当前 213 项单元/集成测试与 27 项 Simulator UI 测试全部通过；Watch 新增覆盖物理设备形态的系统 file URL 标准化、非 file URL 拒绝、快照过期、旧快照拒绝、项目变化保留 outbox、正式协议拒绝回执、明确重试、Repository 即时快照与 iPhone 系统表面提交后的 Watch 刷新，并继续覆盖跨午夜 `occurredAt`、幂等命令和既有领域/归档/StoreKit/Widget/三主题矩阵。
- Release `pulse` 全 target Build 与 Analyze 通过，未排除 Watch Asset Catalog；实际编译并校验 iPhone App、Home Screen Widget、Watch App、Watch Widget、AppIcon、颜色资产、Privacy manifest 和嵌入结构。
- Apple Watch Ultra 3 49 mm 与 SE 40 mm / watchOS 26.4 Simulator 已对当前蓝色状态场复核待签到、已确认和需要同步状态；文字、三层波面、日轴和 44 pt 重试无裁切。Simulator 录屏证明三层波面错速移动，但不外推为真实配对 Watch、Always-On、Reduce Motion 或电量验收。
- Apple Watch Series 10 / watchOS 26.6 的 Debug 签名安装、App Group profile/运行时 URL、真实前台启动与快照读取证据仍成立；此前真表视觉截图属于已替换构图，当前蓝色状态场必须重新真表截图验收。
- iPhone 17 Pro / iOS 26.4 Simulator 已从设置首页直接进入 Apple Watch 页面，显示蓝色预览、WCSession 安装状态并实际关闭“波浪动态”；设置持久化、快照发布与旧快照默认值有自动化覆盖。watchOS Simulator 不支持通过 `simctl ui content_size` 切换 Dynamic Type，因此最大字号仍保留为真机门禁。
- 当前 74 项品牌生成输出、App/Widget/Watch plist、Privacy manifest、entitlement 和五份 String Catalog 静态解析通过；`git diff --check` 通过。
- `site` production build、lint、三条 redirect 测试与依赖审计通过；正式产品、隐私和支持 URL 当前均返回 HTTPS 200。子模块提交仍须单独推送并用全新 clone 验证可获取性。
- Simulator 截图证明三主题当前构图和交互候选，不代替真实设备、Widget host、Dynamic Island、Always-On 或人工最终视觉接受。

## 仍为 NO-GO 的证据

- 真实 iPhone：首次授权、拒绝后从设置恢复、前后镜头、方向、取消、重拍、低存储、写入中断、杀进程、重启、跨日和设备锁定。
- 真实 iPad：相机能力差异、横竖屏、分屏、最大字号和文件导入/导出。
- 恢复：真实设备导出带多张原图的 v2 归档，在另一清洁安装完整恢复并逐张核对；清除和卸载后确认无非预期残留。
- 系统与无障碍：真人 VoiceOver、Switch Control、最大 Dynamic Type、Reduce Motion、提高对比度、通知、真实 Home / Lock Screen Widget、iOS 26 Live Activity / Dynamic Island 和 StoreKit Sandbox。
- Apple Watch：真实配对设备验证即时/后台传输、失联恢复、强退/重启/飞行模式、跨午夜、重复/乱序命令、Always-On、VoiceOver、Reduce Motion、complication、Smart Stack 和 14 天电量。
- 分发：当前源码不可变提交、站点子模块可获取提交、Apple Distribution Archive、签名/entitlement/dSYM/Privacy manifest 产物核验、加密出口分类、App Store 隐私答案、TestFlight 处理与清洁安装。

## 历史证据边界

Build 2 的上传和内部 TestFlight 证据只属于 Pulse 1.0 (2)，不包含 schema 1.1、媒体仓储、归档 v2 或本轮架构收口，不得外推。历史记录见 [Pulse 1.0 (2) 发布候选证据](./RELEASE_CANDIDATE_1_0_2.md)。

## 下一步顺序

1. 在真实 iPhone / iPad 关闭三主题、媒体、权限、低存储、恢复和无障碍门禁。
2. 回归真实通知、Widget、scheduled Live Activity 和 StoreKit Sandbox，确认同日只有一个触达。
3. 在真实配对 iPhone / Apple Watch 关闭即时/后台传输、失联恢复、重启、飞行模式、跨午夜、乱序、complication/Smart Stack、Always-On、VoiceOver、Reduce Motion 与 14 天电量门禁。
4. 完成加密出口与 App Store 隐私答案，再生成当前 `1.1 (4)` 的 Apple Distribution Archive 并做完整产物审计。
5. 推送并 fresh-clone 验证 `site` 子模块提交，随后进入 TestFlight 清洁安装。
