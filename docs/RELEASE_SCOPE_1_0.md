# 一日一印（Pulse）1.0 发布范围合同

文档版本：1.7
状态：Canonical Release Contract
更新时间：2026-08-12

## 1. 冻结原则

Pulse 1.0 只解决一个问题：让单个用户每天可靠地记录一次签到，并能理解自己的历史和连续状态。

功能范围冻结后，任何新增能力都必须先证明它解决 1.0 的发布阻断问题。不能因为“以后可能需要”而把多项目、补签、账号、云同步或激励系统提前塞入首版。

## 2. 1.0 正式范围

- 单用户、单一主签到项目。
- 首次确认主承诺名称、可选“为什么重要”，并可在设置中编辑；修改不影响签到事实。
- 固定签到时区和 00:00 日界线。
- 今日签到、当日唯一性、重复点击保护和跨日刷新。
- App 内有限日印仪式：待签到只进行一次有限呼吸，保存成功后完成空心到实心落印，Reduce Motion 使用静态等价表达。
- 免费基础 Widget：Home Screen 小号/中号、Lock Screen 圆形/矩形；Home Screen 免费提供“断层双色 / 越界巨环 / 承诺宣言 / 错版撕页”四种构图。Widget 事实只读取同一个 App Group SwiftData store，未签到时提供单向签到 AppIntent；App Group 只保存类型化的 `interface.language` 与 `widget.style` 展示偏好。Home Screen 显示当前主承诺名称，Lock Screen 只显示品牌“印记”和抽象状态，任何 Widget 都不显示“为什么重要”。
- 最近 7 天、月历历史、当前连续、最长连续和累计签到。
- 删除单条签到记录和清除全部数据。
- 一次买断的“提醒增强”权益；权益只来自 StoreKit 2 已验证的非消耗型购买 `co.fanr.pulse.reminder.lifetime`，不保存 `isPro` 或其他购买事实副本。商品展示名称、价格与可用性只显示 App Store 返回值；版本通道说明由本合同与 App String Catalog 统一提供。
- 已购买的提醒遵循签到项目固定时区，且同一逻辑日只使用一个通道：iOS / iPadOS 26 及以后、系统允许 Live Activities 时滚动安排最多 7 个 transient Live Activity；支持灵动岛的 iPhone 同时获得 Dynamic Island 表面，其他设备使用 Lock Screen 表面。iOS / iPadOS 18–25，或 iOS 26 关闭 Live Activities 时，回退为滚动 60 个日历日的一次性本地通知。
- 未购买时不请求通知权限、不安排本地通知或 Live Activity，今日签到、历史、统计、Widget、加密备份恢复和其他基础体验不受影响。
- 一周起始日、触觉反馈和签到时区设置。
- Pulse 加密备份 v1 导出和校验后的全量恢复；用户设置独立口令，密码无法找回。
- English / 简体中文应用内切换并同步 App 与 Widget 内容；跟随系统 / 浅色 / 深色主题模式，动态字体、VoiceOver、iPhone 和 iPad 布局。Widget Gallery 与 AppIntent 等系统托管元数据仍按 iOS 的语言规则显示。

`.pulsebackup` 是 1.0 唯一恢复协议。预发布明文 JSON 与 CSV 均不承担恢复职责，也不进入 1.0。

## 3. 明确不进入 1.0

- 多个签到项目。
- 补签或历史空白日期编辑。
- 登录、账号和服务器后端。
- CloudKit 或其他自动多设备同步。
- 除上述定时提醒外的 Live Activity、灵动岛长期占用、Apple Watch、Control 与 Shortcuts 高级入口。
- 备注、心情、图片、积分、勋章和里程碑。
- 社交、排行榜、好友监督和团队考勤。
- 第三方分析、广告 SDK 和远程行为跟踪。

这些能力不是“暂时隐藏的半成品”，而是正式排除。未来若进入范围，必须先更新产品需求、领域合同、迁移策略和测试矩阵。

## 4. 数据与隐私承诺

- 签到数据默认只保存在 App 与 Widget 共用、受 iOS Data Protection 保护的本地 App Group 容器；它仍属于本机应用沙盒边界，不上传到服务器或 iCloud。
- 用户主动创建的备份使用独立口令加密；App 不保存或上传口令。导出后，备份文件和密码的保管责任转移给用户。
- 未启用云同步时，卸载应用会删除沙盒内数据；发布文案必须明确说明。
- 应用不上传签到记录，不集成广告或第三方分析 SDK。
- 只有已购买用户在实际落入本地通知通道并主动开启提醒时才请求通知权限；iOS 26 定时 Live Activity 不触发通知权限请求。Pulse 不请求与核心功能无关的权限。
- App 内设置页与 App Store Connect 必须引用同一份公开隐私政策，并提供公开产品支持入口。

## 5. 当前发布参数

| 参数 | 工程当前值 | 发布状态 |
| --- | --- | --- |
| 显示名称 | 简体中文 `一日一印`；英文及其他语言 `Pulse` | 已确认并由系统本地化 |
| Bundle ID | `co.fanr.pulse` | 已确认；命名空间来自用户持有的 `fanr.co` |
| Marketing Version | `1.0` | 可作为首版候选 |
| Build Number | `3` | 当前源码开发候选；App 与 Widget 已统一递增。已上传并完成内部 TestFlight 核心验收的 Build 2 是不含本轮内购/定时 Live Activity 的历史候选，不能代表 Build 3，也不能复用其分发证据 |
| 最低系统版本 | iOS / iPadOS 18.0 | 已在全部 target 统一；当前 iOS 18.6 Simulator 工程验证通过，可用最旧 18.x 与真机仍是发布门禁 |
| Development Team | `6N3D8YA2FY` | Build 2 的正式 Archive、Cloud Managed Apple Distribution、Store profile、App Group、Data Protection entitlement、`get-task-allow=false`、出口合规声明和上传结果均已核验；Delivery UUID 为 `0373b760-05e0-4299-bb50-6bd6ec3d2959` |
| Widget 身份 | `co.fanr.pulse.widgets` / `group.co.fanr.pulse` | 两个开发描述文件均含正式 App Group；当前共享 store 已重定为首发唯一 schema，既有真机证据不能自动转移到本次 clean-break 候选，必须刷新系统表面与压力矩阵 |
| 数据策略 | iOS Data Protection + Pulse 加密备份恢复 | 1.0 正式方案；备份/恢复不进入未来付费墙 |
| AppIcon | “开放日环”，草绿 Default / Dark / Tinted | 几何与生成合同已录用；当前版本待最终视觉确认 |
| 隐私政策 | `https://fanr.co/pulse/privacy/` | 已公开，并由 App 设置页直接链接 |
| 产品支持 | `https://fanr.co/pulse/support/` | 已公开，联系邮箱为 `400822@163.com` |
| 真实设备 | iPhone / iPad 核心真机矩阵 | 产品负责人于 2026-08-12 确认内部 TestFlight Build 2 的全新安装、签到与 Widget 一致性、加密导出、错误密码失败关闭、清除后完整恢复、中英文、深浅色和双设备基本布局通过；没有补造设备型号、精确 OS、逐项日志或截图，未记录的无障碍与压力矩阵仍保持待验收 |

Bundle ID 一旦用于正式分发，就成为安装、钥匙串、通知和后续升级身份的一部分，不能把临时字符串带入发布后再随意更换。

历史人工验收只证明当时构建中明确观察到的结果。Build 1 与 Build 2 的上传历史分别保留在 `RELEASE_CANDIDATE_1_0_1.md` 和 `RELEASE_CANDIDATE_1_0_2.md`；Build 3 引入新的 StoreKit、ActivityKit、通知与系统表面合同，必须形成新的自动化、真机、Sandbox/TestFlight 和分发证据，不能继承 Build 2 的发布结论。

## 6. 1.0 发布门禁

只有以下条件全部满足，才能把公开发布结论改为 GO：

1. 正式视觉系统与 AppIcon 通过产品验收。
2. 真实 iPhone 以正式 Bundle ID 完成安装、签到、重启持久化、触觉、通知与小组件全流程。
3. 真实 iPad 完成安装、持久化、横竖屏、分屏和小组件验证。
4. 签名 Archive、TestFlight 全新安装和恢复流程通过；Build 3 是当前首发 clean-break 候选，不以 Build 1/2 预发布数据兼容作为门禁，首个公开版本之后的升级必须另行验证迁移。
5. 已公开的隐私说明与支持页面持续可达，商店文案和截图完成。
6. Bundle ID、显示名称、版本号和支持设备范围正式签字确认。（Bundle ID 与显示名称已通过）
7. 至少完成一轮跨多个自然日的内部试用。
8. 真实设备覆盖 Widget 清洁安装、Widget 先于 App 加载、App 未运行、锁屏、跨午夜、快速双击和 App/Widget 同日竞争；任何失败都不能显示虚假完成态、创建空白第二库或产生重复记录。
9. App Store Connect 中非消耗型商品 ID 与工程一致，商品、价格、税务/协议、商店文案和审核状态有效；StoreKit Configuration、Sandbox、TestFlight 与生产购买/恢复/撤销链分别通过。
10. 真机分别验证 iOS 18–25 本地通知、iOS 26 无灵动岛 Lock Screen Live Activity、iOS 26 支持设备 Dynamic Island、关闭 Live Activities 的通知回退，以及签到/关提醒/清数据后的取消。系统是否实际展示由 iOS 决定，产品不得承诺“到点必现”。

## 7. 变更控制

- 1.0 范围变更必须修改本文档和 `PRODUCT_REQUIREMENTS.md`。
- 日期、补签、唯一性或同步规则变更必须先修改 `DOMAIN_CONTRACT.md`。
- 发布身份参数只在一个受控变更中修改工程、文档和签名配置，不能分散修改。
- 未通过的门禁必须保持 NO-GO，不得以模拟器截图、未签名构建或单次演示替代。
