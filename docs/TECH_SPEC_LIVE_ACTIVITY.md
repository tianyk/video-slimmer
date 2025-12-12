# 灵动岛进度显示技术方案

| 文档版本 | V1.2 |
|---------|------|
| 创建日期 | 2025-12-12 |
| 更新日期 | 2025-12-12 |
| 文档状态 | Flutter 端已实现，iOS Widget Extension 需在 Xcode 中配置 |
| 参考规范 | [Apple HIG - 实时活动](https://developer.apple.com/cn/design/human-interface-guidelines/live-activities) |

## 1. 概述

本文档描述 iOS 灵动岛（Dynamic Island）压缩进度显示功能的技术实现方案，对应 PRD 中的 F7.1 需求。

### 1.1 功能范围

- 压缩任务开始时启动 Live Activity
- 在灵动岛/锁屏实时显示压缩进度
- 显示当前视频进度、剩余视频数量、预估剩余时间
- 支持用户从灵动岛快速返回 App
- 压缩完成或取消时结束 Live Activity

### 1.2 Apple HIG 设计原则

根据 [Apple Human Interface Guidelines](https://developer.apple.com/cn/design/human-interface-guidelines/live-activities)，实时活动的核心设计原则：

| 原则 | 应用到本功能 |
|------|-------------|
| **提供实时、一目了然的信息** | 显示当前压缩进度百分比和剩余视频数量 |
| **仅展示最重要的内容** | 紧凑视图只显示进度和数量，不堆砌信息 |
| **让用户轻松返回 App** | 点击灵动岛/锁屏活动可直接跳转到压缩进度页 |
| **任务完成时优雅结束** | 压缩完成后短暂显示"完成"状态，然后自动消失 |
| **避免频繁更新** | 进度更新采用整数百分比比对，减少不必要的刷新 |
| **使用系统提供的呈现方式** | 遵循灵动岛的紧凑/最小/扩展三种模式规范 |

### 1.3 技术栈

| 技术组件 | 用途 |
|---------|------|
| `ActivityKit` | iOS Live Activities 框架 |
| `SwiftUI` | Widget Extension UI 开发 |
| `live_activities` | Flutter 插件，管理 Live Activity 生命周期 |
| `App Groups` | Flutter 与 Widget Extension 数据共享 |
| `UserDefaults` | 跨进程数据存储 |

### 1.4 系统要求

| 要求 | 说明 |
|------|------|
| 最低 iOS 版本 | iOS 16.1+ |
| 灵动岛支持设备 | iPhone 14 Pro、iPhone 14 Pro Max、iPhone 15 系列及更新机型 |
| 锁屏活动 | 所有 iOS 16.1+ 设备支持（包括无灵动岛设备） |
| 最长持续时间 | 8 小时（系统限制，超时自动结束） |

---

## 2. 架构设计

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Flutter App                                  │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │              CompressionProgressCubit                           │ │
│  │  - 管理压缩状态                                                  │ │
│  │  - 压缩进度变化时调用 LiveActivityService                        │ │
│  └──────────────────────────┬─────────────────────────────────────┘ │
│                             │                                        │
│  ┌──────────────────────────▼─────────────────────────────────────┐ │
│  │              LiveActivityService (Dart)                         │ │
│  │  - 封装 live_activities 插件                                     │ │
│  │  - startActivity() / updateActivity() / endActivity()           │ │
│  └──────────────────────────┬─────────────────────────────────────┘ │
│                             │                                        │
│                             │ live_activities 插件                   │
│                             │ (MethodChannel + UserDefaults)         │
└─────────────────────────────┼───────────────────────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │    App Groups     │
                    │ UserDefaults 共享  │
                    │                   │
                    │ group.cc.kekek.   │
                    │   videoslimmer    │
                    └─────────┬─────────┘
                              │
┌─────────────────────────────┼───────────────────────────────────────┐
│              iOS Widget Extension                                    │
│  ┌──────────────────────────▼─────────────────────────────────────┐ │
│  │        CompressionLiveActivity (SwiftUI)                        │ │
│  │  - 定义 ActivityAttributes（静态+动态属性）                       │ │
│  │  - 渲染灵动岛 UI（Compact / Minimal / Expanded）                 │ │
│  │  - 渲染锁屏 UI                                                   │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 核心组件

| 组件 | 位置 | 职责 |
|------|------|------|
| `LiveActivityService` | Flutter (Dart) | 管理 Live Activity 生命周期 |
| `LiveActivityData` | Flutter (Dart) | 传递给原生的数据模型 |
| `CompressionActivityAttributes` | iOS (Swift) | Live Activity 属性定义 |
| `CompressionLiveActivity` | iOS (SwiftUI) | UI 渲染组件 |

### 2.3 数据流

```
压缩进度更新
     │
     ▼
CompressionProgressCubit._updateVideoProgress()
     │
     ▼
LiveActivityService.updateActivity(LiveActivityData)
     │
     ▼
live_activities 插件 (写入 UserDefaults)
     │
     ▼
Widget Extension (读取 UserDefaults)
     │
     ▼
SwiftUI 视图刷新
```

---

## 3. UI 设计

> **Apple HIG 指导**: 实时活动应当提供简洁的信息展示，避免信息过载。灵动岛的紧凑视图空间极其有限，应只显示最关键的状态信息。

### 3.1 品牌色应用

| 元素 | 颜色代码 | 用途 | HIG 考虑 |
|------|----------|------|----------|
| 背景 | 系统黑色 | 与灵动岛融合 | 遵循系统外观，不突兀 |
| 主图标/进度条 | `#B89B6E` (prosperity-gold) | 品牌识别 | 保持品牌一致性 |
| 进度条背景 | `#3A3A3A` | 未完成部分 | 低对比度，不抢眼 |
| 主文字 | `#FFFFFF` | 高对比度显示 | 确保可读性 |
| 辅助文字 | `#8F7A50` (prosperity-dark-gold) | 次要信息 | 视觉层次分明 |

### 3.2 紧凑模式 (Compact View)

> **Apple HIG 指导**: 紧凑视图是灵动岛的默认展示形态，空间极其有限。应只显示最关键的一两项信息，让用户一眼就能了解当前状态。

紧凑模式分为左侧（Leading）和右侧（Trailing）两部分，**不要**在此视图中塞入过多内容。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│                          灵 动 岛 区 域                                  │
│                                                                         │
│   ┌───────────┐                                         ┌─────────────┐ │
│   │           │                                         │             │ │
│   │    🎬     │                                         │    75%      │ │
│   │   金色    │                                         │    1/3      │ │
│   │           │                                         │             │ │
│   └───────────┘                                         └─────────────┘ │
│                                                                         │
│      Leading                                               Trailing     │
│    (视频图标)                                            (进度+数量)    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

视觉元素说明：
┌────────────────────────────────────────────────────────────────────────┐
│                                                                        │
│  Leading 区域:                    Trailing 区域:                       │
│  ┌─────────┐                      ┌───────────┐                        │
│  │  ┌───┐  │                      │   75%     │ ← SF Pro Bold 14pt    │
│  │  │ ▶ │  │ ← 视频图标           │   ───     │                        │
│  │  └───┘  │   24pt 金色          │   1/3     │ ← SF Pro 11pt 灰色    │
│  └─────────┘                      └───────────┘                        │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### 3.3 最小模式 (Minimal View)

> **Apple HIG 指导**: 当有多个实时活动同时运行时，系统会将部分活动缩小为最小视图。这种情况下只能显示一个极小的圆形区域，应使用图标或进度指示器来传达状态。

当有多个 Live Activity 同时运行时，系统会将活动缩小为最小模式。**环形进度方案**可在极小空间内同时传达"正在压缩"和"进度百分比"两个信息。

**方案 A - 纯图标：**

```
┌───────────────────────────────────────────────────────────────────────┐
│                                                                       │
│                              ┌─────────┐                              │
│                              │         │                              │
│                              │   🎬    │  ← 金色视频图标              │
│                              │         │    SF Symbol 12pt            │
│                              └─────────┘                              │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

**方案 B - 环形进度（推荐）：**

```
┌───────────────────────────────────────────────────────────────────────┐
│                                                                       │
│                              ┌─────────┐                              │
│                              │  ╭───╮  │                              │
│                              │ ╱     ╲ │  ← 金色进度环 (75%)          │
│                              ││  🎬   ││    包裹视频图标              │
│                              │ ╲     ╱ │                              │
│                              │  ╰───╯  │                              │
│                              └─────────┘                              │
│                                                                       │
│                          进度环 + 中心图标                             │
│                          直观展示压缩进度                              │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘

结构分解：
        ┌─────────────┐
        │    ████     │  ← 进度环（已完成 75%）
        │  ██    ██   │    颜色：#B89B6E
        │ █   🎬   █  │  ← 中心图标
        │  ██    ░░   │    颜色：#B89B6E
        │    ░░░░     │  ← 进度环（未完成 25%）
        └─────────────┘    颜色：#3A3A3A
```

### 3.4 扩展模式 (Expanded View)

> **Apple HIG 指导**: 用户长按灵动岛时会展开查看更多详情。此时可以显示更丰富的内容，但仍应保持简洁，不要试图在此视图中复刻完整的 App UI。可考虑添加深层链接，让用户点击后直接跳转到 App 的相关页面。

用户长按灵动岛时展开的完整视图，提供最详细的压缩信息。点击任意区域可跳转回 App。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│                          灵 动 岛 展 开 视 图                            │
│                                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                                                                 │   │
│   │   ┌──────────┐                                    ┌──────────┐  │   │
│   │   │          │                                    │          │  │   │
│   │   │    🎬    │    Video Slimmer                   │   1/3    │  │   │
│   │   │   金色   │    正在压缩视频...                  │  白色字  │  │   │
│   │   │          │                                    │          │  │   │
│   │   └──────────┘                                    └──────────┘  │   │
│   │     Leading              Center                     Trailing    │   │
│   │                                                                 │   │
│   │   ┌─────────────────────────────────────────────────────────┐   │   │
│   │   │                                                         │   │   │
│   │   │   ████████████████████████████████████░░░░░░░░░░░░░░░   │   │   │
│   │   │   ←──────── 金色渐变进度条 ────────→                75%  │   │   │
│   │   │                                                         │   │   │
│   │   │   📹 IMG_1234.MOV                      ⏱️ 剩余 2:15     │   │   │
│   │   │                                                         │   │   │
│   │   └─────────────────────────────────────────────────────────┘   │   │
│   │                           Bottom                                │   │
│   │                                                                 │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

区域职责：
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  ┌────────────┐  ┌─────────────────────────────┐  ┌────────────────┐   │
│  │   LEADING  │  │           CENTER            │  │    TRAILING    │   │
│  │            │  │                             │  │                │   │
│  │  App 图标  │  │  App 名称                   │  │   当前/总数    │   │
│  │  44x44pt   │  │  状态描述文字               │  │    "1/3"       │   │
│  │  金色填充  │  │                             │  │                │   │
│  └────────────┘  └─────────────────────────────┘  └────────────────┘   │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                           BOTTOM                                  │  │
│  │                                                                   │  │
│  │  • 进度条（金色渐变，圆角 4pt，高度 8pt）                          │  │
│  │  • 当前文件名（左对齐，白色）                                      │  │
│  │  • 剩余时间（右对齐，暗金色）                                      │  │
│  │                                                                   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.5 锁屏视图 (Lock Screen View)

> **Apple HIG 指导**: 锁屏视图在所有 iOS 16.1+ 设备上显示（包括无灵动岛的设备），提供比灵动岛更大的展示空间。应充分利用这一空间展示进度详情，同时保持视觉简洁。

锁屏视图适用于所有 iOS 16.1+ 设备，包括 iPhone SE、iPhone 13 等无灵动岛机型。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│                            锁 屏 视 图                                   │
│                                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                                                                 │   │
│   │   ┌──────────┐                                                  │   │
│   │   │          │                                                  │   │
│   │   │    🎬    │   Video Slimmer                         75%      │   │
│   │   │   金色   │   正在压缩 1/3 个视频                    大字    │   │
│   │   │          │                                                  │   │
│   │   └──────────┘                                                  │   │
│   │                                                                 │   │
│   │   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━░░░░░░░░░░░░░░░░░░   │   │
│   │   ←────────────── 金色渐变进度条 ──────────────→                │   │
│   │                                                                 │   │
│   │   ┌─────────────────────────────────────────────────────────┐   │   │
│   │   │                                                         │   │   │
│   │   │  📹 IMG_1234.MOV                         ⏱️ 剩余 2:15   │   │   │
│   │   │                                                         │   │   │
│   │   └─────────────────────────────────────────────────────────┘   │   │
│   │                                                                 │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

布局结构：
┌─────────────────────────────────────────────────────────────────────────┐
│  padding: 16pt                                                          │
│                                                                         │
│  ┌─ HStack ───────────────────────────────────────────────────────────┐ │
│  │  ┌────────┐  ┌──────────────────────────────┐  ┌────────────────┐  │ │
│  │  │ 图标   │  │ VStack                       │  │ 百分比         │  │ │
│  │  │ 40x40  │  │ - App名称 (16pt Bold 金色)   │  │ 24pt Bold 白色 │  │ │
│  │  │        │  │ - 状态描述 (13pt 灰色)       │  │                │  │ │
│  │  └────────┘  └──────────────────────────────┘  └────────────────┘  │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  ┌─ ProgressView ─────────────────────────────────────────────────────┐ │
│  │  高度: 8pt    圆角: 4pt    渐变: #8F7A50 → #B89B6E                  │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  ┌─ HStack ───────────────────────────────────────────────────────────┐ │
│  │  ┌──────────────────────────────┐  ┌────────────────────────────┐  │ │
│  │  │ 📹 文件名 (12pt 白色)        │  │ ⏱️ 剩余时间 (12pt 暗金色) │  │ │
│  │  └──────────────────────────────┘  └────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.6 状态变化设计

不同压缩状态下的视觉反馈：

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  状态: downloading (下载中)                                              │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  ☁️↓   正在从 iCloud 下载...                            45%     │   │
│  │  蓝色  ━━━━━━━━━━━━━━━━━━━░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░         │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  状态: compressing (压缩中)                                              │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  🎬    正在压缩视频...                                  75%     │   │
│  │  金色  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━░░░░░░░░░░░░░░░░         │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  状态: completed (已完成)                                                │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  ✓     压缩完成！                              节省 60%         │   │
│  │  绿色  3 个视频已压缩，点击打开 App 保存                         │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  状态: cancelled (已取消)                                                │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  ✕     已取消                                                   │   │
│  │  灰色                                                            │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

状态图标对照表：
┌──────────────┬─────────────────────────┬──────────┬───────────┐
│    状态      │      SF Symbol          │   颜色   │   文案    │
├──────────────┼─────────────────────────┼──────────┼───────────┤
│ downloading  │ icloud.and.arrow.down   │  蓝色    │ 正在下载  │
│ compressing  │ video.fill              │  金色    │ 正在压缩  │
│ completed    │ checkmark.circle.fill   │  绿色    │ 压缩完成  │
│ cancelled    │ xmark.circle.fill       │  灰色    │ 已取消    │
└──────────────┴─────────────────────────┴──────────┴───────────┘
```

---

## 4. 数据模型

### 4.1 iOS 端 - ActivityAttributes

```swift
import ActivityKit

/// 压缩进度 Live Activity 属性
struct CompressionActivityAttributes: ActivityAttributes {
    
    /// 动态变化的内容状态（会实时更新）
    public struct ContentState: Codable, Hashable {
        /// 当前压缩进度 (0.0 - 1.0)
        var progress: Double
        /// 当前处理的视频索引 (1-based)
        var currentIndex: Int
        /// 总视频数量
        var totalCount: Int
        /// 预估剩余时间（秒），nil 表示未知
        var remainingSeconds: Int?
        /// 当前视频文件名
        var currentVideoName: String?
        /// 状态：downloading / compressing / completed / cancelled
        var status: String
    }
    
    /// 静态属性（活动创建时设置，不变）
    var activityId: String
    var startTime: Date
}
```

### 4.2 Flutter 端 - LiveActivityData

```dart
/// Live Activity 数据模型
class LiveActivityData {
  /// 当前压缩进度 (0.0 - 1.0)
  final double progress;
  
  /// 当前处理的视频索引 (1-based)
  final int currentIndex;
  
  /// 总视频数量
  final int totalCount;
  
  /// 预估剩余时间（秒）
  final int? remainingSeconds;
  
  /// 当前视频文件名
  final String? currentVideoName;
  
  /// 状态：downloading / compressing / completed / cancelled
  final String status;

  const LiveActivityData({
    required this.progress,
    required this.currentIndex,
    required this.totalCount,
    this.remainingSeconds,
    this.currentVideoName,
    required this.status,
  });

  /// 转换为 Map，用于传递给原生端
  Map<String, dynamic> toMap() => {
    'progress': progress,
    'currentIndex': currentIndex,
    'totalCount': totalCount,
    'remainingSeconds': remainingSeconds,
    'currentVideoName': currentVideoName,
    'status': status,
  };
}
```

---

## 5. 实现步骤

### 5.1 iOS 原生端配置

#### Step 1: 配置 Info.plist

在 `ios/Runner/Info.plist` 中添加：

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

#### Step 2: 创建 Widget Extension

1. 在 Xcode 中打开 `ios/Runner.xcworkspace`
2. File → New → Target → Widget Extension
3. Product Name: `CompressionWidget`
4. 勾选 "Include Live Activity"
5. 不勾选 "Include Configuration App Intent"

#### Step 3: 配置 App Groups

1. 选择 Runner Target → Signing & Capabilities
2. 点击 "+ Capability" → 添加 "App Groups"
3. 创建 App Group: `group.cc.kekek.videoslimmer`
4. 同样为 CompressionWidgetExtension 添加相同的 App Group

#### Step 4: 实现 Live Activity 视图

创建 `CompressionLiveActivity.swift`：

```swift
import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - 品牌颜色扩展
extension Color {
    static let prosperityGold = Color(red: 184/255, green: 155/255, blue: 110/255)
    static let prosperityDarkGold = Color(red: 143/255, green: 122/255, blue: 80/255)
    static let prosperityGray = Color(red: 58/255, green: 58/255, blue: 58/255)
}

// MARK: - 金色进度条样式
struct GoldProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.prosperityGray)
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.prosperityDarkGold, .prosperityGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geo.size.width * (configuration.fractionCompleted ?? 0),
                        height: 8
                    )
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Live Activity Widget
struct CompressionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CompressionActivityAttributes.self) { context in
            // 锁屏视图
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded - Leading
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: iconName(for: context.state.status))
                        .font(.system(size: 28))
                        .foregroundColor(iconColor(for: context.state.status))
                        .frame(width: 44, height: 44)
                        .background(Color.prosperityGray)
                        .cornerRadius(10)
                }
                
                // Expanded - Center
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Video Slimmer")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.prosperityGold)
                        Text(statusText(for: context.state.status))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                // Expanded - Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.currentIndex)/\(context.state.totalCount)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Expanded - Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        ProgressView(value: context.state.progress)
                            .progressViewStyle(GoldProgressStyle())
                        
                        HStack {
                            Label(
                                context.state.currentVideoName ?? "处理中",
                                systemImage: "film"
                            )
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            
                            Spacer()
                            
                            if let remaining = context.state.remainingSeconds, remaining > 0 {
                                Label(formatTime(remaining), systemImage: "clock")
                                    .font(.system(size: 12))
                                    .foregroundColor(.prosperityDarkGold)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
            } compactLeading: {
                // Compact Leading
                Image(systemName: iconName(for: context.state.status))
                    .foregroundColor(iconColor(for: context.state.status))
                    .font(.system(size: 14, weight: .semibold))
                    
            } compactTrailing: {
                // Compact Trailing
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(context.state.currentIndex)/\(context.state.totalCount)")
                        .font(.system(size: 10))
                        .foregroundColor(.prosperityDarkGold)
                }
                
            } minimal: {
                // Minimal - 环形进度
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(Color.prosperityGold, lineWidth: 2)
                        .frame(width: 22, height: 22)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "video.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.prosperityGold)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func iconName(for status: String) -> String {
        switch status {
        case "downloading": return "icloud.and.arrow.down"
        case "compressing": return "video.fill"
        case "completed": return "checkmark.circle.fill"
        case "cancelled": return "xmark.circle.fill"
        default: return "video.fill"
        }
    }
    
    private func iconColor(for status: String) -> Color {
        switch status {
        case "downloading": return .blue
        case "compressing": return .prosperityGold
        case "completed": return .green
        case "cancelled": return .gray
        default: return .prosperityGold
        }
    }
    
    private func statusText(for status: String) -> String {
        switch status {
        case "downloading": return "正在从 iCloud 下载..."
        case "compressing": return "正在压缩视频..."
        case "completed": return "压缩完成！"
        case "cancelled": return "已取消"
        default: return "处理中..."
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return "剩余 \(mins):\(String(format: "%02d", secs))"
        } else {
            return "剩余 \(secs) 秒"
        }
    }
}

// MARK: - 锁屏视图
struct LockScreenView: View {
    let context: ActivityViewContext<CompressionActivityAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部
            HStack(spacing: 12) {
                Image(systemName: iconName(for: context.state.status))
                    .font(.system(size: 24))
                    .foregroundColor(iconColor(for: context.state.status))
                    .frame(width: 40, height: 40)
                    .background(Color.prosperityGray)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Video Slimmer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.prosperityGold)
                    Text("正在压缩 \(context.state.currentIndex)/\(context.state.totalCount) 个视频")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // 进度条
            ProgressView(value: context.state.progress)
                .progressViewStyle(GoldProgressStyle())
            
            // 底部信息
            HStack {
                Label(
                    context.state.currentVideoName ?? "处理中",
                    systemImage: "film"
                )
                .font(.system(size: 12))
                .foregroundColor(.white)
                .lineLimit(1)
                
                Spacer()
                
                if let remaining = context.state.remainingSeconds, remaining > 0 {
                    Label(formatTime(remaining), systemImage: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.prosperityDarkGold)
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.8))
    }
    
    // 复用 helper 函数...
    private func iconName(for status: String) -> String { /* ... */ }
    private func iconColor(for status: String) -> Color { /* ... */ }
    private func formatTime(_ seconds: Int) -> String { /* ... */ }
}
```

### 5.2 Flutter 端实现

#### Step 1: 添加依赖

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  live_activities: ^2.4.2
```

#### Step 2: 创建 LiveActivityService

创建 `lib/src/services/live_activity_service.dart`：

```dart
import 'dart:io';

import 'package:live_activities/live_activities.dart';

import '../models/live_activity_data.dart';

/// Live Activity 服务
/// 
/// 负责管理 iOS Live Activity 的生命周期，
/// 在压缩任务进行时显示灵动岛/锁屏进度。
class LiveActivityService {
  static const _appGroupId = 'group.cc.kekek.videoslimmer';
  
  final LiveActivities _liveActivities = LiveActivities();
  String? _currentActivityId;
  bool _isInitialized = false;
  
  /// 初始化 Live Activity 服务
  Future<void> init() async {
    if (!Platform.isIOS) return;
    if (_isInitialized) return;
    
    await _liveActivities.init(appGroupId: _appGroupId);
    _isInitialized = true;
  }
  
  /// 开始 Live Activity
  Future<void> startActivity(LiveActivityData data) async {
    if (!await _isSupported()) return;
    
    // 如果已有活动，先结束
    if (_currentActivityId != null) {
      await endActivity();
    }
    
    _currentActivityId = await _liveActivities.createActivity(
      data.toMap(),
      removeWhenAppIsKilled: true,
    );
  }
  
  /// 更新进度
  Future<void> updateActivity(LiveActivityData data) async {
    if (_currentActivityId == null) return;
    
    await _liveActivities.updateActivity(
      _currentActivityId!,
      data.toMap(),
    );
  }
  
  /// 结束 Live Activity
  Future<void> endActivity() async {
    if (_currentActivityId == null) return;
    
    await _liveActivities.endActivity(_currentActivityId!);
    _currentActivityId = null;
  }
  
  /// 结束所有 Live Activity
  Future<void> endAllActivities() async {
    await _liveActivities.endAllActivities();
    _currentActivityId = null;
  }
  
  /// 检查是否支持 Live Activity
  Future<bool> _isSupported() async {
    if (!Platform.isIOS) return false;
    return await _liveActivities.areActivitiesEnabled();
  }
  
  /// 是否有活跃的 Activity
  bool get hasActiveActivity => _currentActivityId != null;
}
```

#### Step 3: 集成到 CompressionProgressCubit

修改 `lib/src/cubits/compression_progress_cubit.dart`：

```dart
class CompressionProgressCubit extends Cubit<CompressionProgressState> {
  final LiveActivityService _liveActivityService = LiveActivityService();
  
  CompressionProgressCubit() : super(const CompressionProgressState()) {
    _listenToProgress();
    _liveActivityService.init(); // 初始化 Live Activity
  }
  
  /// 开始压缩任务
  void startCompression() {
    // 启动 Live Activity
    _startLiveActivity();
    
    _scheduleDownloads();
    _scheduleCompression();
  }
  
  /// 启动 Live Activity
  void _startLiveActivity() {
    final data = _buildLiveActivityData();
    _liveActivityService.startActivity(data);
  }
  
  /// 更新视频压缩进度（已有方法，添加 Live Activity 更新）
  void _updateVideoProgress(String videoId, double progress, int remainingSeconds) {
    // ... 原有逻辑 ...
    
    // 同步更新 Live Activity
    _updateLiveActivity();
  }
  
  /// 更新 Live Activity
  void _updateLiveActivity() {
    if (!_liveActivityService.hasActiveActivity) return;
    
    final data = _buildLiveActivityData();
    _liveActivityService.updateActivity(data);
  }
  
  /// 构建 Live Activity 数据
  LiveActivityData _buildLiveActivityData() {
    // 查找当前活跃的视频
    final activeVideo = state.videos.firstWhere(
      (v) => v.status == VideoCompressionStatus.compressing ||
             v.status == VideoCompressionStatus.downloading,
      orElse: () => state.videos.first,
    );
    
    // 计算当前索引
    final currentIndex = state.videos.indexOf(activeVideo) + 1;
    
    // 确定状态字符串
    String status;
    switch (activeVideo.status) {
      case VideoCompressionStatus.downloading:
      case VideoCompressionStatus.waitingDownload:
        status = 'downloading';
        break;
      case VideoCompressionStatus.compressing:
      case VideoCompressionStatus.waiting:
        status = 'compressing';
        break;
      case VideoCompressionStatus.completed:
      case VideoCompressionStatus.saved:
        status = 'completed';
        break;
      case VideoCompressionStatus.cancelled:
        status = 'cancelled';
        break;
      default:
        status = 'compressing';
    }
    
    return LiveActivityData(
      progress: activeVideo.progress,
      currentIndex: currentIndex,
      totalCount: state.videos.length,
      remainingSeconds: activeVideo.estimatedTimeRemaining,
      currentVideoName: activeVideo.video.title,
      status: status,
    );
  }
  
  /// 所有任务完成时结束 Live Activity
  void _checkAndEndLiveActivity() {
    final allDone = state.videos.every((v) =>
      v.status == VideoCompressionStatus.completed ||
      v.status == VideoCompressionStatus.saved ||
      v.status == VideoCompressionStatus.cancelled ||
      v.status == VideoCompressionStatus.error
    );
    
    if (allDone) {
      _liveActivityService.endActivity();
    }
  }
  
  @override
  Future<void> close() async {
    await _liveActivityService.endAllActivities();
    // ... 原有清理逻辑 ...
    await super.close();
  }
}
```

---

## 6. 状态流转

```
┌──────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│   ┌────────────┐                                                         │
│   │   空闲     │  用户未开始压缩任务                                      │
│   │   (Idle)   │  无 Live Activity                                       │
│   └─────┬──────┘                                                         │
│         │                                                                │
│         │ startCompression()                                             │
│         ▼                                                                │
│   ┌────────────┐                                                         │
│   │  活动中    │  Live Activity 已启动                                   │
│   │  (Active)  │  显示在灵动岛/锁屏                                      │
│   └─────┬──────┘                                                         │
│         │                                                                │
│         ├───────────────────┬───────────────────┬───────────────────┐    │
│         │                   │                   │                   │    │
│         ▼                   ▼                   ▼                   ▼    │
│   ┌───────────┐       ┌───────────┐       ┌───────────┐       ┌─────────┐│
│   │  更新进度  │       │  全部完成  │       │  用户取消  │       │  出错   ││
│   │  (Update)  │       │(Completed)│       │(Cancelled)│       │ (Error) ││
│   └─────┬─────┘       └─────┬─────┘       └─────┬─────┘       └────┬────┘│
│         │                   │                   │                  │     │
│         │                   ▼                   ▼                  ▼     │
│         │             ┌─────────────────────────────────────────────┐    │
│         └────────────►│              结束 Live Activity              │    │
│         (继续更新)     │             endActivity()                   │    │
│                       └─────────────────────────────────────────────┘    │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 7. 文件结构

```
ios/
├── Runner/
│   ├── AppDelegate.swift
│   └── Info.plist                          # 添加 NSSupportsLiveActivities
├── CompressionWidget/                       # 新增 Widget Extension
│   ├── CompressionWidget.swift
│   ├── CompressionActivityAttributes.swift  # Activity 属性定义
│   ├── CompressionLiveActivity.swift        # Live Activity UI
│   ├── Info.plist
│   └── CompressionWidget.entitlements       # App Group 配置
├── Runner.entitlements                      # App Group 配置
└── Runner.xcodeproj

lib/
├── src/
│   ├── services/
│   │   ├── purchase_service.dart
│   │   └── live_activity_service.dart       # 新增
│   ├── models/
│   │   ├── ...
│   │   └── live_activity_data.dart          # 新增
│   └── cubits/
│       └── compression_progress_cubit.dart  # 修改（集成 Live Activity）
```

---

## 8. 注意事项与限制

### 8.1 Apple HIG 合规要点

| 要点 | 说明 | 本方案应对 |
|------|------|-----------|
| **不要滥用实时活动** | 只有真正需要实时跟踪的任务才应使用 | ✅ 视频压缩是典型的长时间后台任务 |
| **及时结束活动** | 任务完成后应主动结束，不要让用户手动关闭 | ✅ 压缩完成/取消后自动调用 `endActivity()` |
| **提供有意义的更新** | 每次更新都应有实质性变化 | ✅ 使用整数百分比比对，避免无意义更新 |
| **支持用户返回 App** | 点击活动应能回到相关页面 | ✅ 配置深层链接跳转到压缩进度页 |
| **处理系统终止** | App 被杀死时活动应能优雅结束 | ✅ 设置 `removeWhenAppIsKilled: true` |

### 8.2 技术限制

| 事项 | 说明 |
|------|------|
| 系统版本检测 | 运行时检测 iOS 版本，低于 16.1 时跳过 Live Activity 功能 |
| 设备兼容性 | 灵动岛仅 iPhone 14 Pro+；锁屏活动所有 iOS 16.1+ 设备支持 |
| 更新频率 | 建议每秒不超过 1 次更新，避免性能问题和系统限制 |
| 活动时长 | Live Activity 最长持续 8 小时，超时系统自动结束 |
| 后台保活 | 需确保 App 有后台运行能力（Audio/Background Tasks） |
| App Groups | 必须正确配置，否则 Flutter 与 Widget Extension 无法通信 |
| 隐私 | 不在 Live Activity 中显示敏感用户信息（如视频内容预览） |
| 推送更新 | 如需在 App 未运行时更新活动，需配置 ActivityKit 推送通知 |

---

## 9. 开发计划

| 阶段 | 任务 | 预估时间 |
|------|------|----------|
| Phase 1 | iOS Widget Extension 配置 + App Groups | 0.5 天 |
| Phase 2 | SwiftUI 灵动岛/锁屏 UI 实现 | 1 天 |
| Phase 3 | Flutter `live_activities` 插件集成 | 0.5 天 |
| Phase 4 | CompressionProgressCubit 集成 | 0.5 天 |
| Phase 5 | 真机测试与调优 | 1 天 |
| **总计** | | **3.5 天** |

---

## 10. 测试要点

### 10.1 功能测试

| 测试场景 | 预期行为 |
|----------|----------|
| 开始压缩 | 灵动岛/锁屏显示初始进度 (0%) |
| 压缩进行中 | 进度实时更新，剩余时间显示 |
| 多个视频 | 当前视频完成后自动切换到下一个 |
| 用户取消 | Live Activity 显示"已取消"后消失 |
| 全部完成 | 显示"压缩完成"，短暂停留后消失 |
| App 被杀死 | Live Activity 自动结束 |
| 长按灵动岛 | 展开显示详细进度和文件名 |
| 点击 Live Activity | 返回 App 压缩进度页 |

### 10.2 HIG 合规测试

| 测试场景 | 预期行为 | HIG 依据 |
|----------|----------|----------|
| 紧凑视图信息量 | 只显示进度百分比和视频数量，不超载 | 仅展示最重要的内容 |
| 最小视图可辨识性 | 环形进度清晰可见，能区分进度 | 即使在最小视图也要传达状态 |
| 任务结束后行为 | 活动在 3-5 秒内自动消失 | 任务完成时优雅结束 |
| 无灵动岛设备 | 锁屏视图正常显示，功能完整 | 兼容所有 iOS 16.1+ 设备 |
| 多个活动并存 | 最小视图仍能传达压缩状态 | 正确处理系统降级显示 |
| 暗色/亮色模式 | 两种模式下视觉效果良好 | 适应系统外观 |

### 10.3 边缘情况

| 测试场景 | 预期行为 |
|----------|----------|
| 压缩超过 8 小时 | 系统自动结束活动，App 内进度不受影响 |
| 网络断开（iCloud 视频） | 显示下载失败状态，活动继续显示 |
| 快速连续更新 | 节流机制生效，不超过每秒 1 次更新 |
| 用户禁用 Live Activity 权限 | App 正常运行，只是不显示灵动岛 |

---

## 11. 参考资料

- [Apple Human Interface Guidelines - 实时活动](https://developer.apple.com/cn/design/human-interface-guidelines/live-activities)
- [ActivityKit Documentation](https://developer.apple.com/documentation/activitykit)
- [live_activities Flutter 插件](https://pub.dev/packages/live_activities)

---

**文档结束**

