# Pulse · 一日一印

[English](#english) · [简体中文](#简体中文)

## English

Pulse is a local-first daily check-in app for iPhone and iPad. Choose one thing that matters to you, check in each day, and keep an optional daily note or photo alongside your progress.

[Product page](https://fanr.co/pulse/) · [Support](https://fanr.co/pulse/support/) · [Privacy policy](https://fanr.co/pulse/privacy/) · [MIT license](./LICENSE)

### What you can do

- Check in on your iPhone, iPad, supported widgets, or a paired Apple Watch.
- Look back through your check-in history, daily notes, and photos stored on your device.
- See today's status through widgets, Live Activities, and Apple Watch complications.
- Export and restore your records and photos with password-protected `.pulsebackup` files.

### For developers

Pulse uses SwiftUI, SwiftData, Observation, and Swift concurrency. The project uses Swift 6 language mode and treats compiler warnings as errors, with no third-party runtime dependencies. Deployment targets are iOS / iPadOS 18.0 and watchOS 10.0.

The codebase covers shared app and widget storage, logical-day calculations, Watch connectivity, protected media storage, and encrypted backup/restore. Check-in history is the source for progress and statistics; each check-in succeeds only after it has been persisted.

### Run locally

1. Clone the repository and open the Xcode project:

   ```sh
   git clone https://github.com/cooluid/pulse.git
   cd pulse
   open pulse.xcodeproj
   ```

2. Use Xcode with Swift 6 support and the iOS and watchOS SDKs required by the project. Select the `pulse` scheme and an installed iOS Simulator, then run.
3. For a physical device, configure your signing team, bundle identifiers, and matching App Group entitlements for the app and extensions. Debug and Release use separate identities and storage groups.

For tests, select **Product → Test** with the `pulse` scheme. See the [test plan](./docs/TEST_PLAN.md) for command-line checks and device coverage. Camera, Watch connectivity, and other system integrations also need device testing.

### Code and documentation

| Path | Purpose |
| --- | --- |
| `pulse/` | iPhone and iPad app |
| `PulseCore/` | Domain model, persistence, and backup/restore |
| `PulseWidgets/`, `PulseWidgetUI/` | Widgets and Live Activities |
| `PulseWatch/`, `PulseWatchShared/`, `PulseWatchUI/`, `PulseWatchWidgets/` | Watch app, connectivity, shared UI, and complications |
| `pulseTests/`, `pulseUITests/` | Unit and UI tests |

Start with the [documentation index](./docs/README.md), [domain rules](./docs/DOMAIN_CONTRACT.md), or [technical design](./docs/TECHNICAL_DESIGN.md). Detailed engineering documents are maintained in Chinese; the linked documents remain the authoritative references. Coding agents should read [AGENTS.md](./AGENTS.md).

### Contributing

Bug reports and focused pull requests are welcome. Include reproduction steps, device and OS details, and expected versus actual behavior. Discuss substantial changes in an issue first. Changes to check-in, storage, or backup behavior should include relevant tests and updates to the corresponding technical document. Keep the English and Chinese sections of this README aligned.

### License

[MIT](./LICENSE) · Copyright (c) 2026 cooluid.

## 简体中文

一日一印（Pulse）是一款本地优先的 iPhone / iPad 每日签到应用。选定一件对你重要的事，每天签到，也可以留下每日记事或照片，回看自己的积累。

[产品介绍](https://fanr.co/pulse/) · [帮助与支持](https://fanr.co/pulse/support/) · [隐私政策](https://fanr.co/pulse/privacy/) · [MIT 许可证](./LICENSE)

### 可以做什么

- 在 iPhone、iPad、支持签到的小组件或已配对的 Apple Watch 上签到。
- 回看签到历史、每日记事和保存在设备上的照片。
- 通过小组件、实时活动和 Apple Watch 表盘复杂功能查看今日状态。
- 使用口令保护的 `.pulsebackup` 文件导出与恢复记录和照片。

### 面向开发者

Pulse 使用 SwiftUI、SwiftData、Observation 和 Swift 并发，采用 Swift 6 语言模式，将编译警告视为错误，无第三方运行时依赖。最低系统版本为 iOS / iPadOS 18.0、watchOS 10.0。

代码涵盖 App 与小组件共享存储、逻辑日计算、Watch 通信、受保护的照片存储，以及加密备份与恢复。进度和统计由签到记录派生；签到以持久化成功为准。

### 本地运行

1. 克隆仓库并打开 Xcode 工程：

   ```sh
   git clone https://github.com/cooluid/pulse.git
   cd pulse
   open pulse.xcodeproj
   ```

2. 使用支持 Swift 6、具备工程所需 iOS 和 watchOS SDK 的 Xcode，选择 `pulse` scheme 和已安装的 iOS 模拟器，运行应用。
3. 真机运行时，为 App 和扩展配置自己的签名团队、Bundle ID 及匹配的 App Group 权限。Debug 与 Release 使用独立的应用身份和存储组。

在 `pulse` scheme 下选择 **Product → Test** 运行测试。命令行检查和设备覆盖见[测试计划](./docs/TEST_PLAN.md)；相机、Watch 通信等系统能力还需要真机验证。

### 代码与文档

| 路径 | 职责 |
| --- | --- |
| `pulse/` | iPhone / iPad 主应用 |
| `PulseCore/` | 领域模型、持久化、备份与恢复 |
| `PulseWidgets/`、`PulseWidgetUI/` | 小组件与实时活动 |
| `PulseWatch/`、`PulseWatchShared/`、`PulseWatchUI/`、`PulseWatchWidgets/` | Watch 应用、通信、共享界面与表盘复杂功能 |
| `pulseTests/`、`pulseUITests/` | 单元测试与 UI 测试 |

从[文档总览](./docs/README.md)、[签到业务规则](./docs/DOMAIN_CONTRACT.md)或[技术设计](./docs/TECHNICAL_DESIGN.md)开始阅读。详细工程文档以中文维护，各规则以对应文档为准。编码代理先读 [AGENTS.md](./AGENTS.md)。

### 参与贡献

欢迎提交问题和聚焦具体改进的 Pull Request。报告问题时，请附上复现步骤、设备与系统版本，以及预期和实际表现。较大改动先通过 Issue 讨论；签到、存储或备份行为变更应补充相关测试，并更新对应技术文档。修改本 README 时，请同步中英文内容。

### 许可证

[MIT](./LICENSE) · Copyright (c) 2026 cooluid.
