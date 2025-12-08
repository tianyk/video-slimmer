# 视频瘦身器 (Video Slimmer)

基于 Flutter 开发的 iOS 视频压缩应用，功能简洁强大。

## 快速开始

### 基础运行
```bash
flutter pub get
flutter run
```

### iOS 模拟器运行
```bash
# 启动模拟器
open -a Simulator

# 运行应用
flutter run
```

### iOS 真机运行（免费 Apple ID）
1. 打开 Xcode 项目：
   ```bash
   open ios/Runner.xcworkspace
   ```

2. 在 Xcode 中配置：
   - 选择 **Runner** → **Signing & Capabilities**
   - 设置 **Team** 为你的 Apple ID（无需付费开发者账号）

3. 运行应用：
   ```bash
   flutter run
   ```

### 项目清理与验证
```bash
flutter clean
flutter pub get  
flutter build ios --simulator
```

## 开发环境

### 必备工具
- Flutter 3.27.4 (稳定版)
- Dart 3.6.2
- Xcode 13.0+ (推荐 14.0+)
- CocoaPods 1.10+

### 系统要求
- 最低支持：iOS 17.0+

## 故障排查

如遇到开发环境问题，请参考 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## 相关链接

- [iOS App Store 开发者指南](https://developer.apple.com/cn/support/app-store/)
- [Flutter 官方文档](https://flutter.dev/docs)
