import 'package:equatable/equatable.dart';

import '../libs/localization.dart';
import '../utils.dart';
import 'video_model.dart';

/// 视频压缩状态枚举
///
/// 状态流转概览：
/// ```
///   启动任务
///      │
///      ├── 需要下载 ──▶ waitingDownload ──▶ downloading ──▶┐
///      │                                                   │
///      └── 无需下载 ────────────────────────────────────────┘
///                                                         │
///                                                         ▼
///                                                    waiting ──▶ compressing ──▶ completed ──▶ saved
///                                                       │                 │              （保存到相册）
///                                                       ├───────────────┘
///                                                       ├──▶ error (压缩失败，可重试回 waiting)
///                                                       └──▶ cancelled (用户取消，可回 waiting)
/// ```
///
/// 终态（不可逆）：completed, saved, cancelled, error
/// 可重试：error, cancelled -> waiting
enum VideoCompressionStatus {
  /// 等待下载（初始状态，排队等待占用下载并发）
  ///
  /// 下一步:
  /// - downloading: 轮到该任务开始下载
  /// - cancelled: 用户取消
  waitingDownload,

  /// 正在从 iCloud 下载
  ///
  /// 下一步:
  /// - waiting: 下载完成，转换为等待压缩
  /// - error: 下载失败
  /// - cancelled: 用户取消
  downloading,

  /// 下载完成，等待开始压缩
  ///
  /// 下一步:
  /// - compressing: 开始压缩
  /// - cancelled: 用户取消
  waiting,

  /// 正在压缩
  ///
  /// 下一步:
  /// - completed: 压缩成功 ✅
  /// - error: 压缩失败 ⚠️
  /// - cancelled: 用户取消 ❌
  compressing,

  /// 已完成（终态）✅
  completed,

  /// 已保存到相册（终态）📁
  ///
  /// - 已成功将压缩后的视频写入系统相册
  /// - 临时输出文件路径可以安全清理
  /// - 不再显示「保存到相册」操作
  saved,

  /// 已取消（终态）❌
  ///
  /// 可操作:
  /// - 重新压缩 -> waiting
  cancelled,

  /// 失败（终态）⚠️
  ///
  /// 可操作:
  /// - 重试 -> waiting
  error,
}

/// 单个视频的压缩信息
class VideoCompressionInfo extends Equatable {
  /// 视频信息
  final VideoModel video;

  /// 压缩状态
  final VideoCompressionStatus status;

  /// 压缩会话 ID
  final int? sessionId;

  /// 压缩进度 (0.0-1.0)
  final double progress;

  /// 错误信息（当状态为error时）
  final String? errorMessage;

  /// 预估剩余时间（秒）
  final int? estimatedTimeRemaining;

  /// 压缩后文件大小（字节）
  final int? compressedSize;

  // 原始文件路径
  final String? originalFilePath;

  /// 压缩后文件路径
  final String? outputPath;

  const VideoCompressionInfo({
    required this.video,
    this.status = VideoCompressionStatus.waiting,
    this.sessionId,
    this.progress = 0.0,
    this.errorMessage,
    this.estimatedTimeRemaining,
    this.compressedSize,
    this.originalFilePath,
    this.outputPath,
  });

  VideoCompressionInfo copyWith({
    VideoModel? video,
    VideoCompressionStatus? status,
    double? progress,
    int? sessionId,
    String? errorMessage,
    int? estimatedTimeRemaining,
    int? compressedSize,
    String? originalFilePath,
    String? outputPath,
  }) {
    return VideoCompressionInfo(
      video: video ?? this.video,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      sessionId: sessionId ?? this.sessionId,
      errorMessage: errorMessage ?? this.errorMessage,
      estimatedTimeRemaining:
          estimatedTimeRemaining ?? this.estimatedTimeRemaining,
      compressedSize: compressedSize ?? this.compressedSize,
      originalFilePath: originalFilePath ?? this.originalFilePath,
      outputPath: outputPath ?? this.outputPath,
    );
  }

  /// 获取状态显示文本
  String get statusText {
    switch (status) {
      case VideoCompressionStatus.waitingDownload:
        return tr('等待下载');
      case VideoCompressionStatus.waiting:
        return tr('等待压缩');
      case VideoCompressionStatus.downloading:
        return tr('下载中');
      case VideoCompressionStatus.compressing:
        return tr('压缩中');
      case VideoCompressionStatus.completed:
        return tr('已完成');
      case VideoCompressionStatus.saved:
        return tr('已保存');
      case VideoCompressionStatus.cancelled:
        return tr('已取消');
      case VideoCompressionStatus.error:
        return tr('失败');
    }
  }

  /// 获取操作按钮文本
  String get actionButtonText {
    switch (status) {
      case VideoCompressionStatus.waitingDownload:
        return tr('取消排队');
      case VideoCompressionStatus.waiting:
        return tr('取消排队');
      case VideoCompressionStatus.downloading:
        return tr('取消下载');
      case VideoCompressionStatus.compressing:
        return tr('取消压缩');
      case VideoCompressionStatus.completed:
        return tr('保存到相册');
      case VideoCompressionStatus.saved:
        return tr('已保存');
      case VideoCompressionStatus.cancelled:
        return tr('重新压缩');
      case VideoCompressionStatus.error:
        return tr('重试');
    }
  }

  /// 格式化剩余时间显示
  String get formattedTimeRemaining {
    if (estimatedTimeRemaining == null) return '';

    final minutes = estimatedTimeRemaining! ~/ 60;
    final seconds = estimatedTimeRemaining! % 60;

    if (minutes > 0) {
      return '$minutes ${tr('分')} $seconds ${tr('秒')}';
    }
    return '$seconds ${tr('秒')}';
  }

  /// 格式化压缩后大小显示
  String get formattedCompressedSize {
    if (compressedSize == null) return '';
    return formatFileSize(compressedSize!);
  }

  @override
  List<Object?> get props => [
        video,
        status,
        sessionId,
        progress,
        errorMessage,
        estimatedTimeRemaining,
        compressedSize,
        originalFilePath,
        outputPath,
      ];
}

/// VideoCompressionStatus 扩展
extension VideoCompressionStatusExtension on VideoCompressionStatus {
  /// 是否是终态（不会再改变）
  bool get isFinal =>
      this == VideoCompressionStatus.completed ||
      this == VideoCompressionStatus.saved ||
      this == VideoCompressionStatus.cancelled ||
      this == VideoCompressionStatus.error;

  /// 是否是活跃状态（正在处理中）
  bool get isActive =>
      this == VideoCompressionStatus.downloading ||
      this == VideoCompressionStatus.compressing;

  /// 优先级（用于排序，数值越大优先级越高）
  int get priority {
    switch (this) {
      case VideoCompressionStatus.compressing:
        return 100;
      case VideoCompressionStatus.downloading:
        return 90;
      case VideoCompressionStatus.waiting:
        return 60;
      case VideoCompressionStatus.waitingDownload:
        return 50;
      case VideoCompressionStatus.completed:
        return 20;
      case VideoCompressionStatus.saved:
        return 15;
      case VideoCompressionStatus.cancelled:
        return 5;
      case VideoCompressionStatus.error:
        return 1;
    }
  }
}
