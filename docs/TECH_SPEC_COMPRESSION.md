# 视频压缩技术方案

| 文档版本 | V1.1 |
|---------|------|
| 创建日期 | 2025-12-11 |
| 更新日期 | 2025-12-11 |
| 文档状态 | 已实现 |

## 1. 概述

本文档描述视频压缩功能的技术实现方案，包括架构设计、核心流程、状态管理和关键技术点。

### 1.1 功能范围

- 批量视频压缩（队列处理）
- iCloud 视频自动下载
- 压缩进度实时展示
- 任务取消/重试
- 压缩后保存到相册并删除原视频

### 1.2 技术栈

| 技术组件 | 用途 |
|---------|------|
| `flutter_bloc` (Cubit) | 状态管理 |
| `ffmpeg_kit_flutter_new` | 视频压缩引擎 |
| `photo_manager` | 相册访问与管理 |
| `MethodChannel` | Flutter 与 iOS 原生通信 |
| `AsyncQueue` | 自定义异步任务队列 |

---

## 2. 架构设计

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                   CompressionProgressScreen                     │
│                         (UI 层)                                  │
└─────────────────────┬───────────────────────────────────────────┘
                      │ BlocProvider
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                CompressionProgressCubit                         │
│                    (状态管理层)                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  AsyncQueue<String>     AsyncQueue<String>               │   │
│  │  _videoIdsToDownload    _videoIdsToCompress              │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────┬───────────────────────────────────────────┘
                      │
      ┌───────────────┴───────────────┐
      ▼                               ▼
┌─────────────────┐         ┌─────────────────────┐
│  MethodChannel  │         │   FFmpegKit         │
│  (iOS 原生通信)  │         │   (视频压缩引擎)     │
└─────────────────┘         └─────────────────────┘
```

### 2.2 核心类

| 类名 | 职责 |
|-----|------|
| `CompressionProgressCubit` | 管理压缩任务状态、调度下载/压缩队列 |
| `CompressionProgressState` | 保存所有视频的压缩信息列表 |
| `VideoCompressionInfo` | 单个视频的压缩状态信息 |
| `AsyncQueue<T>` | 异步阻塞队列，支持超时机制 |

---

## 3. 状态流转

### 3.1 视频压缩状态枚举

```dart
enum VideoCompressionStatus {
  waitingDownload,  // 等待下载（iCloud 视频）
  downloading,      // 正在下载
  waiting,          // 等待压缩
  compressing,      // 正在压缩
  completed,        // 压缩完成
  saved,            // 已保存到相册
  cancelled,        // 已取消
  error,            // 失败
}
```

### 3.2 状态流转图

```
启动任务
    │
    ├── 需要下载 ──▶ waitingDownload ──▶ downloading ──┐
    │                                                  │
    └── 无需下载 ──────────────────────────────────────┘
                                                       │
                                                       ▼
                                              waiting ──▶ compressing ──▶ completed ──▶ saved
                                                  │              │              
                                                  ├──────────────┘
                                                  ├──▶ error (可重试)
                                                  └──▶ cancelled (可重试)
```

---

## 4. 核心流程

### 4.1 初始化阶段

> 方法：`initializeTask(videos, config)`

1. 保存压缩配置
2. 并行检查每个视频的本地可用性（`isVideoLocallyAvailable`）
3. 根据可用性设置初始状态：本地可用 → `waiting`，需下载 → `waitingDownload`
4. 将视频 ID 添加到对应队列

### 4.2 双队列调度系统

采用**生产者-消费者模式**，下载队列是压缩队列的「生产者」：

```
┌─────────────────────────────────────────────────────────────────────┐
│                        调度循环 while(!isClosed)                     │
│                                                                     │
│   ┌─────────────┐    take(timeout: 1s)    ┌─────────────┐           │
│   │ 下载循环     │ ◀────────────────────── │  下载队列    │           │
│   └─────────────┘                         └─────────────┘           │
│          │                                                          │
│          │ 下载完成后 add() 到压缩队列                                │
│          ▼                                                          │
│   ┌─────────────┐    take(timeout: 1s)    ┌─────────────┐           │
│   │ 压缩循环     │ ◀────────────────────── │  压缩队列    │           │
│   └─────────────┘                         └─────────────┘           │
└─────────────────────────────────────────────────────────────────────┘
```

**调度逻辑：**

两个循环结构相同，核心模式：

```dart
while (!isClosed) {
  try {
    videoId = await queue.take(timeout: Duration(seconds: 1));
  } on TimeoutException { continue; }  // 超时，检查 isClosed
  on StateError { continue; }          // 队列被清空
  
  // 执行下载/压缩任务...
}
```

| 循环 | 队列 | 任务完成后 |
|:---|:---|:---|
| `_scheduleDownloads` | `_videoIdsToDownload` | 添加到 `_videoIdsToCompress` |
| `_scheduleCompression` | `_videoIdsToCompress` | 更新状态为 `completed` |

### 4.3 循环退出机制

使用 Cubit 内置的 `isClosed` 属性 + 超时机制实现优雅退出：

```
┌─────────────────────────────────────────────────────────────────┐
│  while (!isClosed) {                                            │
│      try {                                                      │
│          videoId = await take(timeout: 1秒);                    │
│      } on TimeoutException {                                    │
│          continue;  ──▶ 每秒检查一次 isClosed                   │
│      } on StateError {                                          │
│          continue;  ──▶ 队列被清空时触发                        │
│      }                                                          │
│  }                                                              │
└─────────────────────────────────────────────────────────────────┘
```

**双重保障：**

| 机制 | 作用 |
|-----|------|
| `clear()` | 立即打断阻塞的 `take()`，触发 `StateError` |
| `timeout` | 防御性保障，最多 1 秒后检查 `isClosed` |

---

## 5. AsyncQueue 设计

> 文件路径：`lib/src/libs/async_queue.dart`

### 5.1 核心方法

| 方法 | 说明 |
|:---|:---|
| `add(item)` | 添加元素，如有等待者则直接交付 |
| `take({timeout})` | 阻塞获取元素，支持超时 |
| `clear()` | 清空队列，所有等待的 `take()` 抛出 `StateError` |

### 5.2 特性

- **阻塞式 take()**：队列为空时阻塞等待，不占用 CPU
- **可选超时**：支持定期检查外部条件（如 `isClosed`）
- **清空触发异常**：`clear()` 会让所有等待的 `take()` 抛出 `StateError`，用于退出循环

---

## 6. FFmpeg 压缩策略

### 6.1 编码器选择

根据原始视频编码自动选择硬件加速编码器：

| 原始编码 | iOS 编码器 | 标签 |
|---------|-----------|------|
| HEVC/H.265 | `hevc_videotoolbox` | `hvc1` |
| H.264 | `h264_videotoolbox` | `avc1` |

### 6.2 FFmpeg 命令结构

| 参数类别 | 示例 | 说明 |
|:---|:---|:---|
| 全局参数 | `-y -hide_banner` | 覆盖输出、隐藏版本信息 |
| 硬件加速 | `-hwaccel videotoolbox` | iOS VideoToolbox 硬件加速 |
| 流映射 | `-map 0:v:0 -map 0:a:0? -map 0:d?` | 视频、音频、data streams |
| 元数据 | `-map_metadata 0 -movflags faststart` | 保留 GPS、拍摄时间等 |
| 视频编码 | `-c:v hevc_videotoolbox -b:v 2000k` | 编码器 + 目标码率 |
| 音频编码 | `-c:a aac -b:a 128k -ac 2` | AAC 编码、立体声 |
| 输出格式 | `-tag:v hvc1 -f mov` | 视频标签 + MOV 容器 |

### 6.3 进度计算

| 指标 | 计算方式 |
|:---|:---|
| **进度** | `已处理时长 / 视频总时长` |
| **剩余时间** | `剩余视频时长 / 处理速度倍率` |

### 6.4 进度更新优化

使用**整数百分比比对**，避免频繁的 UI 更新：

- 将 `progress` 转为 `0-100` 整数
- 只有百分比或剩余时间变化时才触发 `emit()`

---

## 7. iOS 原生通信

### 7.1 MethodChannel 接口

| 方法 | 参数 | 返回值 | 说明 |
|-----|------|-------|------|
| `getVideoMetadata` | `assetId` | 元数据字典 | 获取视频基本信息 |
| `getVideoFilePath` | `assetId` | 文件路径 | 获取视频文件路径，触发 iCloud 下载 |
| `cancelDownload` | `assetId` | `bool` | 取消正在进行的下载 |

### 7.2 iCloud 下载实现

> 文件路径：`ios/Runner/AppDelegate.swift`

**关键配置：**

| 配置项 | 值 | 说明 |
|:---|:---|:---|
| `version` | `.original` | 获取原始视频 |
| `deliveryMode` | `.highQualityFormat` | 高质量格式 |
| `isNetworkAccessAllowed` | `true` | 允许从 iCloud 下载 |

**取消机制：** 保存 `requestId` 到 `activeDownloadRequests` 字典，取消时调用 `PHImageManager.cancelImageRequest(requestId)`

---

## 8. 任务控制

### 8.1 取消单个视频

> 方法：`cancelVideo(videoId)`

| 当前状态 | 取消操作 |
|:---|:---|
| `waitingDownload` | 从下载队列移除 |
| `downloading` | 调用原生 `cancelDownload` |
| `waiting` | 从压缩队列移除 |
| `compressing` | 调用 `FFmpegKit.cancel(sessionId)` |

最后更新状态为 `cancelled`。

### 8.2 取消所有任务

> 方法：`cancelAllCompression()`

1. 遍历所有 `compressing` 状态的视频，按 `sessionId` 取消 FFmpeg
2. 清空两个队列（触发循环捕获 `StateError` 并退出）
3. 将所有活跃状态更新为 `cancelled`

### 8.3 重试视频

> 方法：`retryVideo(videoId)`

1. 检查视频本地可用性
2. 重置状态和进度（`progress: 0.0`）
3. 添加到对应队列（下载或压缩）

---

## 9. 资源清理

### 9.1 Cubit 关闭

> 方法：`close()`

| 步骤 | 操作 | 说明 |
|:---|:---|:---|
| 1 | 取消进度订阅 | `_progressSubscription?.cancel()` |
| 2 | 清理临时文件 | 删除未保存的压缩输出文件 |
| 3 | `super.close()` | 设置 `isClosed = true` |
| 4 | 清空队列 | 触发 `StateError`，循环退出 |

### 9.2 循环退出流程

```
Widget.dispose() → cubit.close()
    │
    ▼
close(): super.close() → isClosed = true
    │
    ▼
clear() 队列 → StateError
    │
    ▼
while(!isClosed) 条件为 false → 循环退出 ✅
```

---

## 10. 关键设计决策

### 10.1 为什么使用双队列？

- **下载和压缩解耦**：下载可能耗时较长（网络依赖），不应阻塞压缩
- **生产者-消费者模式**：下载完成自动触发压缩
- **独立状态管理**：每个阶段有清晰的状态

### 10.2 为什么使用 isClosed 而不是自定义标志？

- **利用 Cubit 内置机制**：`isClosed` 是 BlocBase 的内置属性
- **语义清晰**：表示"Cubit 是否已关闭"
- **减少代码**：不需要维护额外的状态变量

### 10.3 为什么 take() 需要 timeout？

- **防御性编程**：即使 `clear()` 机制失效，也能在 1 秒内退出
- **定期检查条件**：确保 `while (!isClosed)` 被定期评估
- **开销可忽略**：每秒一次的超时检查对性能影响极小

### 10.4 为什么按 sessionId 取消 FFmpeg？

- **精确控制**：只取消当前管理的会话
- **避免副作用**：`FFmpegKit.cancel()` 全局取消会影响其他地方的 FFmpeg 使用

---

## 11. 未来优化方向

| 优化项 | 说明 | 优先级 |
|-------|------|-------|
| 预检查机制 | 压缩前检查存储空间、视频完整性 | P2 |
| 压缩质量验证 | 压缩完成后验证输出文件 | P2 |
| 灵动岛支持 | 后台压缩时在灵动岛显示进度 | P2 |

---

## 12. 相关文件

| 文件 | 说明 |
|-----|------|
| `lib/src/cubits/compression_progress_cubit.dart` | 压缩进度状态管理 |
| `lib/src/screens/compression_progress_screen.dart` | 压缩进度 UI |
| `lib/src/models/compression_progress_model.dart` | 压缩状态模型 |
| `lib/src/libs/async_queue.dart` | 异步队列实现 |
| `ios/Runner/AppDelegate.swift` | iOS 原生通信 |
