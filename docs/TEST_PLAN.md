# Pulse 1.0 测试计划

文档版本：1.5
状态：Canonical Acceptance Plan
更新日期：2026-08-12

## 1. 判定原则

测试从事实风险出发，不从页面数量出发：

- 自动化证明当前代码在当前环境中的工程行为；
- Simulator 截图证明指定模拟环境中的界面结果；
- 真机、无障碍、系统通知、Widget 系统表面与分发分别需要真实证据；
- 单项 GO 不能外推到未覆盖门禁。

任何记录丢失、重复、错误逻辑日、无效导入破坏现有事实或虚假签到完成态都是 P0，并阻止工程 GO。

## 2. 自动化矩阵

| 范围 | 必须覆盖 |
| --- | --- |
| 身份 | 名称/说明规范化、长度、Emoji、控制字符、不可见格式字符、首次确认、幂等编辑、编辑不改变事实 |
| 逻辑日 | Gregorian、时区、DST、稳定起始日、未来/起始日前拒绝、记录时区保持 |
| Repository | 唯一主项目、同日幂等、保存回执、删除、清除、rollback、双容器并发回读 |
| 当前 schema | `PulseSchema 1.0.0` 真实磁盘读写、唯一键和目录创建；工程中不得出现预发布 schema 迁移器 |
| JSON v1 | 唯一 JSON UTType、精确 format/version、完整 round-trip、大小/数量上限、身份/时区/来源/时间顺序/ID/日期唯一、旧开发 JSON 和未知版本失败关闭 |
| Store | 只解析 App Group 正式路径；非法 group ID、group URL 缺失失败；不得存在私有路径、journal、staging 或 fallback |
| 设置 | 主题、应用内语言、周起始日、触觉、提醒时间、Widget 样式持久化；损坏值失败关闭 |
| 提醒 | 60 日计划、平台预算、DST、已签到跳过、revision 竞态、关闭/清除取消、切语言重新协调 |
| AppModel | 操作互斥、失败不提前改 UI、成功后刷新、导航复位、清除恢复日志 |
| Widget | store 缺失/身份未确认不可写；七日投影、跨午夜刷新、样式偏好、隐私裁决、AppIntent 成功后刷新 |
| 本地化 | English/简体中文即时切换且重启保持；同一活动界面不能混用；中文历史标题和二级返回按钮必须跟随应用语言 |
| 品牌资产 | token schema、18 项正式资产、解码像素、AppIcon alpha、生成器幂等、仓库 diff |

## 3. UI 自动化主流程

- 首次启动确认主承诺，进入 Today；
- 签到落盘，重启后保持，并在 History 出现；
- Settings 隐藏一级品牌导航，返回后恢复；
- 主承诺编辑、时区选择、导入、清除与失败表达；
- 主题和语言即时应用并跨重启保持；
- English Settings 的返回按钮必须为 `Back`，不得出现 `返回`；中文对应 `返回`；
- 中文 History 年度标题必须为 `记录 / 年份`，不得出现 `ARCHIVE`；
- Dynamic Type/布局几何、底部导航、Today 主动作、History 月历和详情；
- Widget 四种样式可选择并持久化。

UI 测试使用固定 Clock 与 UUID 隔离磁盘 store；无效测试配置直接失败。截图 attachment 是指定运行环境的证据，不替代真机验收。

## 4. 构建与静态门禁

每个发布候选至少执行：

```bash
xcodebuild -project pulse.xcodeproj -scheme pulse \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' test

xcodebuild -project pulse.xcodeproj -scheme pulse \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project pulse.xcodeproj -scheme pulse \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO analyze

python3 scripts/build_brand_assets.py --check
git diff --check
```

还必须检查：

- 所有 target 的 deployment target 都是 18.0；
- App / Widget entitlement 与 App Group 一致；
- `PrivacyInfo.xcprivacy` 被 App 和扩展正确打包；
- `site` 是 `.gitmodules` 声明的正式 submodule，`git submodule status` 可解析；
- 代码和权威文档不存在旧 schema、旧 JSON 升级、私有 store、journal 或 staging 的活引用。

## 5. 真机与体验门禁

自动化不能替代：

- iPhone / iPad iOS 18 可用最旧运行时上的安装、启动、签到、设置、历史、重启和清除；
- 通知首次授权、拒绝后恢复、实际到达、签到后取消和修改时间无旧请求；
- 跟随系统/浅色/深色与 English/简体中文组合；
- Dynamic Type 到最大 Accessibility 字号、VoiceOver、提高对比度、降低透明度、Reduce Motion；
- iPad 竖横屏、分屏和 regular-width 构图；
- 签到落印、触觉、周轨迹、连续天数和月份切换节奏；
- AppIcon Default / Dark / Tinted 与商店素材；
- 多个自然日的连续使用。

## 6. Widget 独立门禁

- 工程门：共享 store、跨进程唯一性、快照、隐私、构建、entitlement 自动化通过；
- Simulator 门：画廊识别、Home Screen、Lock Screen 和 AppIntent 在系统宿主中运行；
- 真机门：App 未运行、设备锁定、跨午夜、快速双击、App/Widget 同日竞争、杀进程和卸载重装；
- 视觉/无障碍门：四式小中号、圆形/矩形、深浅、accented/vibrant、StandBy、Always-On、最大字号、VoiceOver、Reduce Motion。

Preview、未签名构建或单进程测试不能替代上述门禁。

## 7. 发布门禁

工程 GO 之后仍需单独取得：

- Apple Distribution 签名和 Archive 验证；
- TestFlight 安装与升级路径；
- App Store Connect 元数据、隐私问卷、截图、支持与隐私页面；
- 发布候选真机矩阵和多日试用结论。

任一未完成项都必须以 NO-GO 或待验收记录，不能用“构建成功”替代。
