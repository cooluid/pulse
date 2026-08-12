# 一日一印（Pulse）1.0 发布范围合同

文档版本：1.5
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
- App 内有限日印仪式：待签到只进行一次有限呼吸，保存成功后完成空心到实心落印，Reduce Motion 使用静态等价表达；不包含 Live Activity。
- 免费基础 Widget：Home Screen 小号/中号、Lock Screen 圆形/矩形；Home Screen 免费提供“断层双色 / 越界巨环 / 承诺宣言 / 错版撕页”四种构图。Widget 事实只读取同一个 App Group SwiftData store，未签到时提供单向签到 AppIntent；App Group 只保存类型化的 `interface.language` 与 `widget.style` 展示偏好。Home Screen 显示当前主承诺名称，Lock Screen 只显示品牌“印记”和抽象状态，任何 Widget 都不显示“为什么重要”。
- 最近 7 天、月历历史、当前连续、最长连续和累计签到。
- 删除单条签到记录和清除全部数据。
- 每日本地提醒；提醒遵循签到项目固定时区，以滚动 60 个日历日的一次性计划运行并在 App 活跃时刷新。
- 一周起始日、触觉反馈和签到时区设置。
- Pulse JSON v1 导出和校验后的全量恢复。
- English / 简体中文应用内切换并同步 App 与 Widget 内容；跟随系统 / 浅色 / 深色主题模式，动态字体、VoiceOver、iPhone 和 iPad 布局。Widget Gallery 与 AppIntent 等系统托管元数据仍按 iOS 的语言规则显示。

JSON 是 1.0 唯一恢复协议。CSV 不承担恢复职责，也不进入 1.0。

## 3. 明确不进入 1.0

- 多个签到项目。
- 补签或历史空白日期编辑。
- 登录、账号和服务器后端。
- CloudKit 或其他自动多设备同步。
- Live Activity、灵动岛长期占用、Apple Watch、Control 与 Shortcuts 高级入口。
- 备注、心情、图片、积分、勋章和里程碑。
- 社交、排行榜、好友监督和团队考勤。
- 第三方分析、广告 SDK 和远程行为跟踪。

这些能力不是“暂时隐藏的半成品”，而是正式排除。未来若进入范围，必须先更新产品需求、领域合同、迁移策略和测试矩阵。

## 4. 数据与隐私承诺

- 签到数据默认只保存在 App 与 Widget 共用的本地 App Group 容器；它仍属于本机应用沙盒边界，不上传到服务器或 iCloud。
- 用户主动导出后，导出文件的保管责任转移给用户。
- 未启用云同步时，卸载应用会删除沙盒内数据；发布文案必须明确说明。
- 应用不上传签到记录，不集成广告或第三方分析 SDK。
- 除用户主动开启的本地通知外，不请求其他系统权限。
- App 内设置页与 App Store Connect 必须引用同一份公开隐私政策，并提供公开产品支持入口。

## 5. 当前发布参数

| 参数 | 工程当前值 | 发布状态 |
| --- | --- | --- |
| 显示名称 | 简体中文 `一日一印`；英文及其他语言 `Pulse` | 已确认并由系统本地化 |
| Bundle ID | `co.fanr.pulse` | 已确认；命名空间来自用户持有的 `fanr.co` |
| Marketing Version | `1.0` | 可作为首版候选 |
| Build Number | `1` | 当前首个候选；上传前确认 App Store Connect 未占用，若冲突则在源码统一递增 App 与 Widget 后重新走完整候选流程 |
| 最低系统版本 | iOS / iPadOS 18.0 | 已在全部 target 统一；当前 iOS 18.6 Simulator 工程验证通过，可用最旧 18.x 与真机仍是发布门禁 |
| Development Team | `6N3D8YA2FY` | App 与 Widget 的正式 Archive 和 App Store Connect 导出已通过；Cloud Managed Apple Distribution、Store profile、App Group 与 `get-task-allow=false` 已核验，TestFlight/商店提交仍待执行 |
| Widget 身份 | `co.fanr.pulse.widgets` / `group.co.fanr.pulse` | 两个开发描述文件均含正式 App Group；当前共享 store 已重定为首发唯一 schema，既有真机证据不能自动转移到本次 clean-break 候选，必须刷新系统表面与压力矩阵 |
| 数据策略 | 本地优先 + Pulse JSON 恢复 | 1.0 推荐方案 |
| AppIcon | “开放日环”，草绿 Default / Dark / Tinted | 几何与生成合同已录用；当前版本待最终视觉确认 |
| 隐私政策 | `https://fanr.co/pulse/privacy/` | 已公开，并由 App 设置页直接链接 |
| 产品支持 | `https://fanr.co/pulse/support/` | 已公开，联系邮箱为 `400822@163.com` |
| 真实设备 | iPhone / iPad 核心真机矩阵 | 产品负责人于 2026-08-12 确认真机及其余人工验收无问题；仓库记录验收来源，但没有补造设备型号、精确 OS、逐项日志或截图 |

Bundle ID 一旦用于正式分发，就成为安装、钥匙串、通知和后续升级身份的一部分，不能把临时字符串带入发布后再随意更换。

历史人工验收只证明当时构建中明确观察到的结果。本次候选的产品负责人确认、自动化、Archive 与 Apple Distribution 证据分别记录在 `IMPLEMENTATION_STATUS.md` 和 `RELEASE_CANDIDATE_1_0_1.md`；它们仍不能替代尚未执行的 App Store Connect 处理、TestFlight 和商店提交。

## 6. 1.0 发布门禁

只有以下条件全部满足，才能把公开发布结论改为 GO：

1. 正式视觉系统与 AppIcon 通过产品验收。
2. 真实 iPhone 以正式 Bundle ID 完成安装、签到、重启持久化、触觉、通知与小组件全流程。
3. 真实 iPad 完成安装、持久化、横竖屏、分屏和小组件验证。
4. 签名 Archive、TestFlight 安装、升级和恢复流程通过。
5. 已公开的隐私说明与支持页面持续可达，商店文案和截图完成。
6. Bundle ID、显示名称、版本号和支持设备范围正式签字确认。（Bundle ID 与显示名称已通过）
7. 至少完成一轮跨多个自然日的内部试用。
8. 真实设备覆盖 Widget 清洁安装、Widget 先于 App 加载、App 未运行、锁屏、跨午夜、快速双击和 App/Widget 同日竞争；任何失败都不能显示虚假完成态、创建空白第二库或产生重复记录。

## 7. 变更控制

- 1.0 范围变更必须修改本文档和 `PRODUCT_REQUIREMENTS.md`。
- 日期、补签、唯一性或同步规则变更必须先修改 `DOMAIN_CONTRACT.md`。
- 发布身份参数只在一个受控变更中修改工程、文档和签名配置，不能分散修改。
- 未通过的门禁必须保持 NO-GO，不得以模拟器截图、未签名构建或单次演示替代。
