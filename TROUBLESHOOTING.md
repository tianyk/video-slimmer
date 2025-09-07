# iOS开发环境修复指南

## 核心问题
- CocoaPods同步失败
- FLUTTER_ROOT缺失
- Bundle identifier冲突
- iOS相册权限不弹窗
- 权限插件未注册 (MissingPluginException)

---

## 修复记录

### 问题1: FLUTTER_ROOT缺失 ❌
**首次发现时症状**:
```
[!] Invalid Podfile: FLUTTER_ROOT not found
```

---

### 问题2: Bundle标识冲突 ❌
**症状**: 
```
Ambiguous organization: {cc.kekek, com.example}
```

---

### 问题3: iOS 相册权限不弹窗 ❌
**症状**:
```log
📋 尝试请求相册权限...
📋 相册权限状态: PermissionStatus.permanentlyDenied
```
- 启动 App 后，iOS 系统 **没有弹出相册权限请求**  
- 在 **设置 → 隐私与安全性 → 照片** 中也看不到当前 App  

**确认原因**:
- `permission_handler >= 11.x` 不再使用 `pod 'Permission-XXX'` 引入子模块  
- 必须在 `Podfile` 中配置 **GCC_PREPROCESSOR_DEFINITIONS 宏**，明确启用/禁用权限  
- 如果未启用权限宏，则 `request()` 永远返回 `permanentlyDenied` ✅  

**解决方案**:

1. **修改 `ios/Podfile` 的 `post_install` 配置**  
   仅启用相册读取/写入，关闭其他权限：
   ```ruby
   post_install do |installer|
     installer.pods_project.targets.each do |target|
       flutter_additional_ios_build_settings(target)
       target.build_configurations.each do |config|
         config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
           '$(inherited)',

           ## ✅ 启用相册
           'PERMISSION_PHOTOS=1',
           'PERMISSION_PHOTOS_ADD_ONLY=1',

           ## ❌ 禁用不需要的权限
           'PERMISSION_CAMERA=0',
           'PERMISSION_MICROPHONE=0',
           'PERMISSION_LOCATION=0',
           'PERMISSION_LOCATION_WHENINUSE=0',
           'PERMISSION_CONTACTS=0',
           'PERMISSION_NOTIFICATIONS=0',
           'PERMISSION_MEDIA_LIBRARY=0',
           'PERMISSION_SENSORS=0',
           'PERMISSION_BLUETOOTH=0',
           'PERMISSION_APP_TRACKING_TRANSPARENCY=0',
           'PERMISSION_CRITICAL_ALERTS=0',
           'PERMISSION_ASSISTANT=0',
           'PERMISSION_EVENTS=0',
           'PERMISSION_EVENTS_FULL_ACCESS=0',
           'PERMISSION_REMINDERS=0',
           'PERMISSION_SPEECH_RECOGNIZER=0',
         ]
       end
     end
   end
   ```

2. **确认 `ios/Runner/Info.plist` 中已添加描述**：
   ```xml
   <key>NSPhotoLibraryUsageDescription</key>
   <string>视频瘦身器需要访问相册以选择和处理视频文件</string>

   <key>NSPhotoLibraryAddUsageDescription</key>
   <string>视频瘦身器需要将压缩后的视频保存到相册</string>
   ```

3. **清理并重建环境**
   ```bash
   cd ios
   pod deintegrate
   rm -rf Pods Podfile.lock
   pod install
   cd ..
   flutter clean
   flutter pub get
   flutter run
   ```

**验证结果**:
- ✅ 首次运行 APP 会弹出「允许访问照片」对话框  
- ✅ `Permission.photos.request()` 返回正确状态 (granted / limited 等)  
- ✅ 系统设置可正确显示/切换相册权限  

---

### 问题4: 权限插件未注册 (MissingPluginException) ✅
**症状**:
```
flutter: snapshot.error: MissingPluginException(No implementation found for method requestPermissions on channel flutter.baseflow.com/permissions/methods)
```

**确认原因**:
- `pubspec.yaml` 中包含 `module` 配置导致 Flutter 将项目视为模块而非完整应用
- 插件注册文件 `ios/Runner/GeneratedPluginRegistrant.m` 为空
- Flutter 没有生成正确的插件注册代码

**解决方案**:

1. **移除 pubspec.yaml 中的 module 配置**:
   ```yaml
   # 删除这部分配置
   flutter:
     uses-material-design: true
     # module:                    ← 删除
     #   iosBundleIdentifier: ... ← 删除
   ```

2. **完全清理并重新生成**:
   ```bash
   # 清理 Flutter 缓存
   flutter clean
   
   # 清理 iOS 依赖
   cd ios
   rm -rf Pods Podfile.lock
   cd ..
   
   # 重新获取依赖并生成插件注册
   flutter pub get
   
   # 重新安装 iOS Pods
   cd ios && pod install && cd ..
   ```

3. **验证插件注册文件**:
   检查 `ios/Runner/GeneratedPluginRegistrant.m` 应包含:
   ```objc
   + (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
     [PermissionHandlerPlugin registerWithRegistrar:[registry registrarForPlugin:@"PermissionHandlerPlugin"]];
     [PhotoManagerPlugin registerWithRegistrar:[registry registrarForPlugin:@"PhotoManagerPlugin"]];
     // ... 其他插件
   }
   ```

**验证结果**:
- ✅ 权限插件正确注册
- ✅ 应用启动不再报 MissingPluginException 错误
- ✅ 权限请求功能正常工作

---

## 一步解决

```bash
# 完全重置iOS开发环境
flutter clean
rm -rf ios/
flutter create . --platforms ios --org cc.kekek --overwrite --project-name videoslimmer
flutter pub get
cd ios && pod install
```

---

## Apple Silicon首执阻塞问题 🚫
**症状**:
- flutter命令首次启动阻塞10分钟+ 
- 仅显示 `Unable to locate Android SDK.` 无其他输出

**确认原因**:
- ✅ Rosetta 2 已安装且启用
- ✅ `arch -arm64` 绕过无效
- ✅ 所有 Flutter 版本均已更新
- ⚠️ **确认为 Flutter 在 M 系列 Mac 上的已知间歇性问题**

**当前状态**: 暂无可靠解决方案，需等待 Flutter 官方修复  
**临时替代**: 使用 Android Studio IDE 运行可绕过 CLI 阻塞  

---

### 问题5: VM Service 连接问题 ⚠️
**症状**:
```
vm-service: Error: Unhandled exception:
WebSocketException: Invalid WebSocket upgrade request
[ERROR:flutter/runtime/dart_isolate.cc(1380)] Unhandled exception:
WebSocketException: Invalid WebSocket upgrade request
Connecting to the VM Service is taking longer than expected...
Still attempting to connect to the VM Service...
```

**确认原因**:
- Flutter 调试器与 iOS 模拟器/设备的 VM Service 连接异常
- WebSocket 升级请求格式不正确
- 可能与网络配置或防火墙设置相关

**临时解决方案**:
1. **使用指定端口运行**:
   ```bash
   flutter run --host-vmservice-port 8080
   ```

2. **重启模拟器和 Flutter**:
   ```bash
   # 关闭模拟器
   xcrun simctl shutdown all
   
   # 重启模拟器
   open -a Simulator
   
   # 重新运行
   flutter run
   ```

3. **使用 Release 模式**:
   ```bash
   flutter run --release
   ```

**当前状态**: 应用可以正常构建和运行，但调试连接不稳定  
**影响**: 不影响应用功能，仅影响热重载和调试体验  

---

## 验证

```bash
# 遇阻 - CLI阻塞问题待官方解决
flutter run --simulator
```

---

## 状态记录

- ✅ FLUTTER_ROOT 已包含
- ✅ bundle 统一为 `cc.kekek.videoslimmer`  
- ✅ CocoaPods 正常运行
- ✅ iOS 相册权限弹窗 & 设置入口正常
- ✅ 权限插件注册问题已解决 (移除 module 配置)
- ❌ CLI 阻塞：Apple Silicon Flutter 已知问题
- ⚠️ VM Service 连接问题：WebSocket 升级请求无效