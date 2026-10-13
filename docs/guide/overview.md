# 当前架构

本指南描述仓库当前实现。依赖约束以 `pubspec.yaml` 为准，解析版本以 `pubspec.lock` 为准，平台最低版本以原生构建配置为准。

## 应用启动与主流程

`lib/main.dart` 先初始化 Flutter 和 `LocalizationService`，设置框架 / 异步错误日志，再创建 `VideoSlimmerApp`。全局 `PurchaseCubit` 包裹 `MaterialApp`；应用当前固定使用深色主题。

`HomeScreenWrapper` 请求权限，展示加载、错误、拒绝权限或首页。主流程为：

```text
HomeScreen → CompressionConfigScreen → CompressionProgressScreen
浏览 / 过滤 / 选择     参数 / 大小估算           下载 / 压缩 / 保存
```

页面使用 Navigator 和 MaterialPageRoute；不要仅凭依赖声明推断使用 go_router。

## 模块入口

| 模块 | 主要文件（相对 `lib/src/`） | 职责 |
| --- | --- | --- |
| 视频数据 | `cubits/video_data_cubit.dart`、`models/video_model.dart` | 分页读取相册、并发加载元数据 |
| 筛选 / 选择 | `cubits/video_filter_cubit.dart`、`cubits/video_selection_cubit.dart` | 排序、分辨率筛选、选中集合 |
| 参数 / 估算 | `cubits/compression_cubit.dart`、`models/compression_config.dart`、`models/compression_model.dart` | 压缩预设、结果大小估算 |
| 执行进度 | `cubits/compression_progress_cubit.dart`、`models/compression_progress_model.dart` | iCloud 下载、FFmpeg、取消、重试、相册保存 |
| 内购 | `services/purchase_service.dart`、`cubits/purchase_cubit.dart`、`models/purchase_event.dart`、`models/purchase_state.dart` | 商品查询、购买事件、权益与 UI 状态 |
| 实时活动 | `services/live_activity_service.dart`、`models/live_activity_data.dart` | 插件初始化、进度数据和活动生命周期 |
| 权限 | `services/permission_service.dart` | 相册权限请求 |
| 文案 | `services/localization_service.dart`、`libs/localization.dart` | JSON 语言包加载与 `tr` |
| 公共能力 | `libs/async_queue.dart`、`libs/logger.dart`、`utils.dart` | 队列、日志和辅助函数 |

当前压缩执行逻辑集中在 `CompressionProgressCubit`，已有代码直接调用 FFmpeg / Photos。新功能沿用边界；确有复用或测试隔离需求时再抽取服务，不因模板要求大规模分层。

## iOS 原生契约

- 主应用与 Widget Extension 当前均配置 iOS 17.0，`ios/Podfile` 也为 17.0。ActivityKit 自身的 16.1 门槛不等于本应用支持 iOS 16.1。
- `ios/Runner/AppDelegate.swift` 在 `cc.kekek.videoslimmer` 通道处理 `getVideoMetadata`、`getVideoFilePath`、`cancelDownload`。参数使用 Photos `assetId`。
- `ios/Podfile` 的权限宏与 `ios/Runner/Info.plist` 的权限说明共同决定相册权限行为。
- `LiveActivityService` 与 `ios/CompressionWidget/CompressionWidget.swift` 通过 App Group UserDefaults 共享数据，suite 为 `group.cc.kekek.videoslimmer`，键带活动 UUID 前缀。
- `ios/CompressionWidget/AppIntent.swift` 中的 `LiveActivitiesAppAttributes.ContentState` 当前包含 `appGroupId`，业务进度从共享 UserDefaults 读取。升级插件时核对插件原生定义。
- App Group 的代码和 entitlements 已存在；Apple 开发者账户的 capability / provisioning 配置仍需在对应环境确认。
- IAP 商品为 `cc.kekek.videoslimmer.pro`，本地配置位于 `ios/Runner/StoreKitConfig.storekit`；App Store Connect / 沙盒状态无法仅凭仓库文件判断。

## 已知文档边界

`docs/TECH_SPEC_*.md` 包含早期设计与示例代码，不是可直接复制的 SDK 文档。优先看文首的当前实现说明，再读取相关源文件。`TODO.md` 区分代码存在、外部配置确认和设备验收，不能把已写代码当作已验证发布。

Android 和其他平台尚未在本次文档整理中验收。Photos MethodChannel 与 VideoToolbox 是 iOS 实现，不能据此宣称完整跨平台支持。
