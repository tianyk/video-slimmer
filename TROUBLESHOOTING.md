# 开发环境故障排查

先保留报错、命令和版本，再按症状检查。本文是排查步骤，不能据此判断当前环境已经验证通过。

## 先检查环境

在仓库根目录执行：

```bash
flutter --version
flutter doctor -v
flutter devices
git status --short
```

缺少依赖或修改了 `pubspec.yaml` 时执行 `flutter pub get`。iOS 依赖安装需要先完成 Flutter 依赖初始化，再在 `ios/` 执行 `pod install`；打开 Xcode 时使用 `ios/Runner.xcworkspace`。

## 相册权限不弹窗或一直被拒绝

1. 检查 `ios/Runner/Info.plist` 的 `NSPhotoLibraryUsageDescription` 与 `NSPhotoLibraryAddUsageDescription`。
2. 检查 `ios/Podfile` 的 `PERMISSION_PHOTOS=1` 和 `PERMISSION_PHOTOS_ADD_ONLY=1`，不要添加已不适用的 `pod 'Permission-XXX'`。
3. 区分首次请求、limited、拒绝和 permanentlyDenied；已经拒绝后可能需要在系统设置授权，不能期待每次运行都再次弹窗。
4. 修改原生配置后完整重建 / 重启应用，热重载不能重新注册插件或变更原生权限宏。
5. 使用测试设备或专用相册验证读取、写入与删除，避免为排障删除真实用户素材。

## MissingPluginException

检查是否完整重启应用、运行平台是否支持插件，以及 `pubspec.yaml` 是否被误配置为 Flutter module。插件注册文件由 Flutter 生成，不手动补注册代码。

先执行 `flutter pub get`，需要时在 `ios/` 执行 `pod install` 并重新构建。若仍失败，再根据日志决定是否需要 `flutter clean`；不要默认卸载 Pods 或删除锁文件。

## Live Activity 不出现或进度不更新

1. 检查 `ios/Runner/Info.plist` 的 `NSSupportsLiveActivities`、系统是否允许实时活动，以及服务初始化日志。
2. 对照 `LiveActivityService`、Widget UserDefaults 和 entitlements 的 App Group，必须都是 `group.cc.kekek.videoslimmer`；在账户和签名环境确认 capability。
3. `ios/CompressionWidget/AppIntent.swift` 的 `LiveActivitiesAppAttributes` / `ContentState` 必须匹配当前锁定的 `live_activities` 原生实现；历史方案中的结构不能直接替换现有代码。
4. 创建时不能向 UserDefaults 写 null；更新时允许传 null 以移除旧值。可运行现有模型测试：

```bash
flutter test --no-pub test/models/live_activity_data_test.dart
```

5. 检查 Widget Extension 是否参与构建与嵌入，再在支持的设备验证启动、更新与结束。项目 Deployment Target 为 iOS 17.0；插件 / 系统 API 的最低版本不等于本应用支持范围。

## 内购商品不可用

核对 `AppConstants.proProductId` 与 `ios/Runner/StoreKitConfig.storekit`，均应为 `cc.kekek.videoslimmer.pro`。本地测试确认 Runner Scheme 已选择 StoreKit Configuration；沙盒测试还需要 App Store Connect 商品和测试账户配置。

区分本地 StoreKit 与真实商店环境，不把本地购买通过当作上线验收。具体故障模拟和恢复购买流程见 [内购方案](docs/TECH_SPEC_IAP.md)。

## Flutter CLI 阻塞或 VM Service 连接异常

- 保存 `flutter doctor -v` 与 `flutter run -v -d <device-id>` 的日志，确认 Xcode、设备连接、网络代理和调试端口状态。
- VM Service 端口冲突时可尝试 `flutter run --host-vmservice-port 8080 -d <device-id>`。
- 只重启目标测试设备或当前调试任务，避免默认关闭所有模拟器。
- Release 模式不提供正常热重载，不能把切换 Release 当作修复调试连接的结论。
- CLI 持续异常时可用 Xcode 辅助定位原生报错，但不要未经验证归因于 Apple Silicon 的已知缺陷。

## 清理与验证

只有缓存 / 生成产物确实导致问题时才考虑 `flutter clean`，随后重新 `flutter pub get` 并构建。`pod deintegrate` 或移除 Pods 应在普通安装无法解决且目标明确时单独处理，不删除 `pubspec.lock` 或顺带升级依赖。

通用验证方式见 [verification.md](docs/guide/verification.md)。报告实际执行命令、结果和剩余设备验收项，不把历史解决记录视为当前环境的证明。
