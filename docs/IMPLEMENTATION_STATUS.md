# Pulse 1.1 实现与验收状态

更新时间：2026-10-27

当前结论：**PUBLIC BASELINE GO — 1.1 (9) / BUILD 10 ENGINEERING GO / INTERFACE CANDIDATE / NEXT DISTRIBUTION NOT STARTED**。

`1.1 (9)` 已于 2026-08-30 公开发布。产品负责人确认当前 `main` 的 `814c1e9` 是发布后的未上线改动；工程已统一进入 `1.1 (10)` 开发线。Build 9 缺少本地 Archive / IPA 和远程 tag，精确二进制源码映射仍是追踪缺口，详见 [RELEASE_BASELINE_1_1_9.md](./RELEASE_BASELINE_1_1_9.md)。

## 已公开生产基线

- 最低 iOS / iPadOS 18.0，最低 watchOS 10.0，iOS 只支持单 Scene。
- `CheckInRecord` 是签到、统计、今天状态和月历唯一真源；记事是其可编辑注释；`ImprintMedia` 是独立影像事实。
- 唯一 store 是 App Group `Library/Application Support/Pulse/Pulse.store`，公开 schema marker 为 `1.1.1`。
- 加密归档公开基线为 container v2 / payload v3；Watch 公开基线为协议 v2 / 本地状态 v2。未来版本必须显式迁移，不得再断代。
- `SwiftDataPulseRepository` 独占 Habit、CheckInRecord 与 ImprintMedia 写入；Widget 和 Watch 不建立第二事实。
- StoreKit 已验证交易与 `PulseEnhancementContract.currentCapabilities` 是高级功能唯一来源。

## 当前 Build 10 开发内容

- 外观重做（未发布）：三套主题统一为同一张“纸与印”页面，朱砂（`editorialJournal`）免费，静野、晴昼付费；月汐、棱镜刻度、沉浸已移除，持久化的旧值回到朱砂。Home Screen 八种样式、Lock Screen Widget、定时实时活动、Apple Watch 与 complication 统一改用日印；样式 ID、Watch 协议 v2 与波浪动态设置不变。
- App Store 评价采用系统 `RequestReviewAction`：累计签到 7 / 30 / 100 次、App 内真实签到成功且任务结束后才尝试；设置“关于”提供主动评价链接。
- 评价尝试记录只在 App 本机持久化，不进入签到事实、App Group、备份、诊断或权益。
- App、Widget、Watch App 与 Watch Widget 的正式构建号统一为 `1.1 (10)`。

## 当前验证

- 环境：macOS 27.2、Xcode 27.1（27A9275）、iPhone 18 Pro / iOS 27.0 Simulator。
- 203 项 unit / integration 全部通过，含主题合同、评价里程碑、持久化、损坏状态和正式 App Store URL。
- 27 项 Simulator UI 流程全部通过；设计巡游在中文浅色/深色、英文、AX 超大字号与 iPad 上完成截图人工验收。设置评价入口已在正式帮助/反馈流程中验证可达，UI test 环境明确不呈现系统评价弹窗。
- Release 全 target 无签名 Build 与 Analyze 通过；正式构建号为 `1.1 (10)`，Debug 测试台由 `#if DEBUG` 在 Release 排除。
- 53 项生成品牌资产检查通过；六份 String Catalog 可解析，四份 Info.plist 校验通过，`git diff --check` 通过。
- 自动化只证明功能、事实、可达结果和平台硬限制；系统评价弹窗的生产展示仍由 App Store 决定。

## 仍未关闭

- 在开发签名真机验证第 7 次 App 内签到后的系统评价界面不会抢占落印或拍照；TestFlight 按系统规则不会展示该弹窗。
- 在已支持店面验证设置主动评价链接直达 App Store 评价页；中国大陆店面当前公开 Lookup 仍无结果。
- 为下一次候选建立不可变源码提交、tag、Archive、IPA、dSYM UUID、上传回执与精确 TestFlight 证据，避免再次丢失二进制源码映射。
- 新外观（印章今日页、三套主题、八个小组件样式、实时活动、Watch 与 complication）已在模拟器完成整页与 Dynamic Type 验收；真机触觉、实时活动、Watch 与 iPad 的人工体验验收仍未做。

## 下一步

1. 在真机完成评价请求、App Store 主动入口和新外观（含 Widget、实时活动、Watch）的人工作业验收。
2. 在 App Store Connect 核对中国大陆店面可用性。
3. 仅从冻结的 Build 10 候选生成 Archive，并同时记录 commit、tag、产物和上传回执。
