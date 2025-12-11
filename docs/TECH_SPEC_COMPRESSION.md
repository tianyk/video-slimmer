# 视频压缩技术方案

| 文档版本 | V1.0 |
|---------|------|
| 创建日期 | 2025-12-11 |
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

```dart
Future<void> initializeTask({
  required List<VideoModel> videos,
  required CompressionConfig config,
}) async {
  // 1. 保存压缩配置
  _compressionConfig = config;
  
  // 2. 并行检查每个视频的本地可用性
  final videoInfos = await Future.wait(videos.map((video) async {
    final isLocallyAvailable = await isVideoLocallyAvailable(video.id);
    return VideoCompressionInfo(
      video: video,
      status: isLocallyAvailable
          ? VideoCompressionStatus.waiting
          : VideoCompressionStatus.waitingDownload,
    );
  }));
  
  // 3. 将视频 ID 添加到对应队列
  _videoIdsToCompress.addAll(/* waiting 状态的视频 */);
  _videoIdsToDownload.addAll(/* waitingDownload 状态的视频 */);
}
```

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

**调度下载任务：**

```dart
Future<void> _scheduleDownloads() async {
  while (!isClosed) {
    String? videoId;
    try {
      videoId = await _videoIdsToDownload.take(timeout: Duration(seconds: 1));
    } on TimeoutException {
      continue;  // 超时，继续检查 while 条件
    } on StateError {
      continue;  // 队列被清空，继续检查 while 条件
    }
    
    final videoInfo = state.getVideoCompressionInfoByVideoId(videoId);
    if (videoInfo.status == VideoCompressionStatus.waitingDownload) {
      _updateVideoStatus(videoId, VideoCompressionStatus.downloading);
      await _ensureVideoFilePath(videoId);  // 触发 iCloud 下载
      _updateVideoStatus(videoId, VideoCompressionStatus.waiting);
      _videoIdsToCompress.add(videoId);  // 添加到压缩队列
    }
  }
}
```

**调度压缩任务：**

```dart
Future<void> _scheduleCompression() async {
  while (!isClosed) {
    String? videoId;
    try {
      videoId = await _videoIdsToCompress.take(timeout: Duration(seconds: 1));
    } on TimeoutException {
      continue;
    } on StateError {
      continue;
    }
    
    final videoInfo = state.getVideoCompressionInfoByVideoId(videoId);
    if (videoInfo.status == VideoCompressionStatus.waiting) {
      _updateVideoStatus(videoId, VideoCompressionStatus.compressing);
      final outputPath = await _runFfmpegForVideo(videoInfo);
      _updateVideoStatus(videoId, VideoCompressionStatus.completed, outputPath: outputPath);
    }
  }
}
```

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

### 5.1 核心实现

```dart
class AsyncQueue<T> {
  final Queue<T> _queue = Queue<T>();
  final Queue<Completer<T>> _waiters = Queue<Completer<T>>();

  void add(T item) {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete(item);
    } else {
      _queue.add(item);
    }
  }

  Future<T> take({Duration? timeout}) {
    if (_queue.isNotEmpty) {
      return Future.value(_queue.removeFirst());
    } else {
      final completer = Completer<T>();
      _waiters.add(completer);
      
      if (timeout != null) {
        return completer.future.timeout(timeout, onTimeout: () {
          _waiters.remove(completer);
          throw TimeoutException('Queue take timed out', timeout);
        });
      }
      
      return completer.future;
    }
  }

  void clear() {
    _queue.clear();
    while (_waiters.isNotEmpty) {
      _waiters.removeFirst().completeError(StateError('Queue cleared'));
    }
  }
}
```

### 5.2 特性

- **阻塞式 take()**：队列为空时阻塞等待，不占用 CPU
- **可选超时**：支持定期检查外部条件
- **清空触发异常**：`clear()` 会让所有等待的 `take()` 抛出 `StateError`

---

## 6. FFmpeg 压缩策略

### 6.1 编码器选择

根据原始视频编码自动选择硬件加速编码器：

| 原始编码 | iOS 编码器 | 标签 |
|---------|-----------|------|
| HEVC/H.265 | `hevc_videotoolbox` | `hvc1` |
| H.264 | `h264_videotoolbox` | `avc1` |

### 6.2 FFmpeg 命令构建

```dart
Future<String> _buildFfmpegCommand({
  required String inputPath,
  required String outputPath,
  required CompressionConfig config,
}) async {
  final args = <String>[];
  
  // 全局参数
  args.addAll(['-y', '-hide_banner']);
  
  // 硬件加速
  args.addAll(['-hwaccel', 'videotoolbox']);
  
  // 输入
  args.addAll(['-i', inputPath]);
  
  // 流映射（视频、音频、data streams）
  args.addAll(['-map', '0:v:0', '-map', '0:a:0?', '-map', '0:d?']);
  
  // 元数据保留（GPS、拍摄时间等）
  args.addAll(['-map_metadata', '0', '-movflags', 'faststart']);
  
  // 视频编码
  args.addAll(['-c:v', videoCodec, '-b:v', '${bitrate}k', '-quality', 'high']);
  
  // 音频编码
  args.addAll(['-c:a', 'aac', '-b:a', '${audioKbps}k', '-ac', '2']);
  
  // 输出格式
  args.addAll(['-tag:v', videoTag, '-f', 'mov', outputPath]);
  
  return args.join(' ');
}
```

### 6.3 进度计算

```dart
// FFmpeg 统计回调
(Statistics statistics) {
  final int timeMs = statistics.getTime();        // 已处理时长（毫秒）
  final double totalMs = videoInfo.video.duration * 1000.0;
  final double progress = (timeMs / totalMs).clamp(0.0, 1.0);
  final double speed = statistics.getSpeed();     // 处理速度倍率
  
  // 预估剩余时间 = 剩余视频时长 / 处理速度
  final Duration remaining = speed > 0
      ? Duration(milliseconds: ((totalMs - timeMs) / speed).round())
      : Duration.zero;
      
  _updateVideoProgress(videoId, progress, remaining.inSeconds);
}
```

### 6.4 进度更新优化

使用整数百分比比对，避免频繁的 UI 更新：

```dart
void _updateVideoProgress(String videoId, double progress, int remainingSeconds) {
  final currentVideo = state.getVideoCompressionInfoByVideoId(videoId);
  
  // 将进度转为整数百分比比较
  final currentPercent = (currentVideo.progress * 100).toInt();
  final newPercent = (progress * 100).toInt();
  
  // 只有进度百分比或剩余时间变化时才更新
  if (currentPercent == newPercent && 
      currentVideo.estimatedTimeRemaining == remainingSeconds) {
    return;
  }
  
  // ... 执行更新
}
```

---

## 7. iOS 原生通信

### 7.1 MethodChannel 接口

| 方法 | 参数 | 返回值 | 说明 |
|-----|------|-------|------|
| `getVideoMetadata` | `assetId` | 元数据字典 | 获取视频基本信息 |
| `getVideoFilePath` | `assetId` | 文件路径 | 获取视频文件路径，触发 iCloud 下载 |
| `cancelDownload` | `assetId` | `bool` | 取消正在进行的下载 |

### 7.2 iCloud 下载实现

```swift
private func getVideoFilePath(call: FlutterMethodCall, result: @escaping FlutterResult) {
  let options = PHVideoRequestOptions()
  options.version = .original
  options.deliveryMode = .highQualityFormat
  options.isNetworkAccessAllowed = true  // 允许从 iCloud 下载
  
  // 进度回调
  options.progressHandler = { progress, error, stop, info in
    self.progressHandler.sendProgress(videoId: assetId, progress: progress)
  }
  
  // 请求视频
  let requestId = PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { ... }
  
  // 保存 requestId 用于取消
  activeDownloadRequests[assetId] = requestId
}

private func cancelDownload(call: FlutterMethodCall, result: @escaping FlutterResult) {
  if let requestId = activeDownloadRequests[assetId] {
    PHImageManager.default().cancelImageRequest(requestId)
    activeDownloadRequests.removeValue(forKey: assetId)
    result(true)
  } else {
    result(false)
  }
}
```

---

## 8. 任务控制

### 8.1 取消单个视频

```dart
Future<void> cancelVideo(String videoId) async {
  final video = state.getVideoCompressionInfoByVideoId(videoId);

  switch (video.status) {
    case VideoCompressionStatus.waitingDownload:
      _videoIdsToDownload.remove(videoId);
      break;
    case VideoCompressionStatus.downloading:
      await _cancelDownload(videoId);  // 调用原生取消
      break;
    case VideoCompressionStatus.compressing:
      FFmpegKit.cancel(video.sessionId);  // 按 sessionId 取消
      break;
    case VideoCompressionStatus.waiting:
      _videoIdsToCompress.remove(videoId);
      break;
  }

  _updateVideoStatus(videoId, VideoCompressionStatus.cancelled);
}
```

### 8.2 取消所有任务

```dart
void cancelAllCompression() {
  // 只取消正在运行的 FFmpeg 会话（按 sessionId）
  for (final video in state.videos) {
    if (video.sessionId != null &&
        video.status == VideoCompressionStatus.compressing) {
      FFmpegKit.cancel(video.sessionId);
    }
  }

  // 清空队列（循环会捕获 StateError 并 continue）
  _videoIdsToCompress.clear();
  _videoIdsToDownload.clear();

  // 更新所有活跃状态为已取消
  final updatedVideos = state.videos.map((video) {
    if (video.status.isActive || video.status == VideoCompressionStatus.waiting) {
      return video.copyWith(status: VideoCompressionStatus.cancelled);
    }
    return video;
  }).toList();

  emit(state.copyWith(videos: updatedVideos));
}
```

### 8.3 重试视频

```dart
Future<void> retryVideo(String videoId) async {
  final isLocallyAvailable = await isVideoLocallyAvailable(videoId);
  
  // 重置状态
  final newStatus = isLocallyAvailable
      ? VideoCompressionStatus.waiting
      : VideoCompressionStatus.waitingDownload;
  
  _updateVideoStatus(videoId, newStatus, progress: 0.0);
  
  // 添加到对应队列
  if (isLocallyAvailable) {
    _videoIdsToCompress.add(videoId);
  } else {
    _videoIdsToDownload.add(videoId);
  }
}
```

---

## 9. 资源清理

### 9.1 Cubit 关闭

```dart
@override
Future<void> close() async {
  _progressSubscription?.cancel();

  // 清理未保存的临时压缩文件
  for (final video in state.videos) {
    if (video.outputPath != null &&
        video.status != VideoCompressionStatus.saved) {
      try {
        final file = File(video.outputPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  // 先调用 super.close()，设置 isClosed = true
  await super.close();

  // 再清空队列，触发循环退出
  _videoIdsToCompress.clear();
  _videoIdsToDownload.clear();
}
```

### 9.2 循环退出流程

```
Widget.dispose() 调用 cubit.close()
         │
         ▼
┌────────────────────────────────────────┐
│  close() 方法                          │
│  1. 清理临时文件                        │
│  2. await super.close()  ──▶ isClosed = true
│  3. clear() 队列         ──▶ StateError
└────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────┐
│  while (!isClosed)                     │
│  条件为 false，循环退出 ✅              │
│  Cubit 可被 GC 回收                    │
└────────────────────────────────────────┘
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
