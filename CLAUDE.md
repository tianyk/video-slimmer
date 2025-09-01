# CLAUDE.md

该文件为 Claude Code（claude.ai/code）在该代码库中工作时提供指导。

## 概述
这是一个基于 Flutter 的视频压缩应用，主要针对 iOS 设备，代码库兼容 Android。应用使用 Riverpod 进行状态管理，并提供预设质量选项的视频压缩功能。

## 代码规则
本项目遵循 `.cursor/rules` 目录下的代码规则文件，当前包含以下规则：
- `FLUTTER.mdc` - Flutter/Dart 编码规范和最佳实践
- 所有代码生成都应严格遵循这些规则中的命名规范、函数长度限制、类设计原则等
- 在修改或创建新文件时，请参考这些规则确保代码一致性

## 架构
- **框架**: Flutter 3.6.2+ 搭配 Riverpod 状态管理
- **平台**: iOS（主要），兼容 Android
- **结构**: 使用 src/ 文件夹组织的清晰架构

## 关键目录
- `lib/` - Flutter Dart 代码
  - `src/constants/` - 应用常量和主题
  - `src/models/` - 数据模型（VideoModel、CompressionConfig、CompressionResult）
  - `src/screens/` - UI 界面（HomeScreen）
  - `src/services/` - 业务逻辑（PermissionService）
  - `src/widgets/` - 可复用小部件（PermissionDeniedScreen）
- `ios/` - iOS 特定配置
- `android/` - Android 配置
- `test/` - Flutter 小部件测试

## 依赖项
- **视频处理**: [flutter_ffmpeg](https://pub.dev/packages/flutter_ffmpeg)
- **状态管理**: [flutter_riverpod](https://pub.dev/packages/flutter_riverpod)
- **存储访问**: [photo_manager](https://pub.dev/packages/photo_manager)
- **权限管理**: [permission_handler](https://pub.dev/packages/permission_handler)
- **路由**: [go_router](https://pub.dev/packages/go_router)
- **视频播放**: [video_player](https://pub.dev/packages/video_player)

## 命令

### 开发设置
```bash
flutter pub get
```

### 运行应用
- **iOS 设备**: `flutter run --device-id="设备名称" --allow-provisioning-updates`
- **iOS 模拟器**: `flutter run`
- **Android**: `flutter run`

### 构建与测试
```bash
flutter build ios --simulator
flutter test
flutter analyze
```

### 调试
```bash
flutter clean
flutter pub get
```

## 文件命名规范
- Dart 文件使用小写加下划线（snake_case）
- 类名使用 PascalCase
- 常量放在 `app_constants.dart` 中
- 主题配置放在 `app_theme.dart` 中

## 核心功能
- 从系统相册选择视频
- 实时压缩大小估算
- 压缩过程中的进度跟踪
- 保存到相机胶卷功能
- 分享功能