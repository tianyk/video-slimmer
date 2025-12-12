# 待办事项

## 灵动岛进度显示功能

### ✅ 已完成

- [x] 添加 `live_activities` 依赖到 pubspec.yaml
- [x] 创建 `LiveActivityData` 数据模型 (`lib/src/models/live_activity_data.dart`)
- [x] 创建 `LiveActivityService` 服务 (`lib/src/services/live_activity_service.dart`)
- [x] 修改 `CompressionProgressCubit` 集成 Live Activity
- [x] 配置 iOS `Info.plist` 启用 Live Activities
- [x] 创建 iOS Widget Extension 代码文件
  - [x] `CompressionWidget.swift` - 灵动岛 & 锁屏 UI
  - [x] `AppIntent.swift` - ActivityAttributes 定义

### 📋 待完成（需在 Xcode 中手动操作）

- [ ] **配置 App Groups**
  - [ ] Runner Target → Signing & Capabilities → + Capability → App Groups
  - [ ] 添加 App Group: `group.cc.kekek.videoslimmer`
  - [ ] CompressionWidgetExtension Target → 同样添加相同的 App Group

- [ ] **验证 Widget Extension 配置**
  - [ ] 确保 Bundle Identifier 正确: `cc.kekek.videoslimmer.CompressionWidget`
  - [ ] 确保 Deployment Target 设置为 iOS 16.1+

- [ ] **真机测试**
  - [ ] 在真机上测试灵动岛显示效果
  - [ ] 测试锁屏视图显示效果
  - [ ] 测试进度更新是否正常
  - [ ] 测试任务完成后 Live Activity 是否正确结束

---

## 其他待办

（暂无）
