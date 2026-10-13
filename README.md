# 视频瘦身器 (Video Slimmer)

Flutter 视频压缩应用，当前主要面向 **iOS 17.0+**。支持相册浏览与筛选、批量压缩、iCloud 视频下载、压缩进度、取消 / 重试和保存到相册；包含 Pro 内购和灵动岛 / 锁屏实时活动实现，设备与外部服务验收状态见 [TODO.md](TODO.md)。

当前使用 Cubit / flutter_bloc、Navigator、`ffmpeg_kit_flutter_new`、`photo_manager`、`in_app_purchase` 和 `live_activities`。仓库保留其他平台目录，但完整兼容性需要单独验证。

## 开发环境

- Flutter stable，所带 Dart 必须满足 `pubspec.yaml` 的 `^3.6.2` 约束；解析依赖以 `pubspec.lock` 为准。
- iOS 开发需要 macOS、支持 iOS 17 SDK 的 Xcode（15 或更新版本）和 CocoaPods；具体插件要求以当前锁定版本和 `flutter doctor -v` 为准。
- 2026-10-13 文档整理时，本机版本为 Flutter 3.41.4 / Dart 3.11.1。这是环境记录，未设置强制 SDK 版本锁定。
- 真机运行需要 Runner 与 CompressionWidgetExtension 的签名和 App Groups 配置。

## 快速开始

```bash
flutter doctor -v
flutter pub get
flutter devices
flutter run -d <device-id>
```

模拟器可先执行 `open -a Simulator`，再从 `flutter devices` 选择设备 ID。

真机签名在 Xcode 中配置：

```bash
open ios/Runner.xcworkspace
```

检查 Runner 与 CompressionWidgetExtension 的 Signing & Capabilities，并确认二者使用 `group.cc.kekek.videoslimmer`。本地 StoreKit 测试配置已存在于 `ios/Runner/StoreKitConfig.storekit` 并关联到 Runner Scheme；商品 ID 为 `cc.kekek.videoslimmer.pro`。

## 常用验证

```bash
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --simulator --debug --no-pub
```

根据改动选择验证，不需要每次任务都清理缓存或构建 iOS。详细命令、设备验证与测试选择见 [验证指南](docs/guide/verification.md)，环境问题见 [故障排查](TROUBLESHOOTING.md)。

## AI 开发

[AGENTS.md](AGENTS.md) 是统一规则入口，适用于 Codex 和其他读取该文件的工具。Claude Code 通过 [CLAUDE.md](CLAUDE.md) 导入同一份约定。

- 规则与任务文档索引：`AGENTS.md`。
- 按需阅读的架构、编码和验证指导：`docs/guide/`。
- 跨任务记忆：`.memory/SUMMARY.md`、`.memory/daily/`、`.memory/PLAYBOOKS.md`。
- 模型、供应商、凭据和个人界面偏好由工具的全局配置管理，仓库不绑定特定模型或账户。

## 文档导航

| 文档 | 内容 |
| --- | --- |
| [开发指南](docs/guide/README.md) | 当前架构、Flutter 约定、验证与交付 |
| [产品需求](PRD.md) | 产品功能、业务规则和用户流程 |
| [待办与验收](TODO.md) | 当前未完成项与外部配置确认 |
| [压缩方案](docs/TECH_SPEC_COMPRESSION.md) | 队列、FFmpeg、Photos 原生桥接 |
| [内购方案](docs/TECH_SPEC_IAP.md) | Pro 权益、StoreKit、本地与沙盒测试 |
| [实时活动方案](docs/TECH_SPEC_LIVE_ACTIVITY.md) | 灵动岛、锁屏、App Groups 和 Widget |
| [故障排查](TROUBLESHOOTING.md) | 权限、插件注册和开发环境问题 |

功能技术方案包含历史设计示例，按文首的当前实现说明核对源代码，不直接复制旧 SDK 调用。
