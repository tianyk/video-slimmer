import 'package:equatable/equatable.dart';
import 'video_model.dart';

/// 视频压缩状态枚举
enum VideoCompressionStatus {
  /// 等待中（队列中）
  waiting,

  /// 压缩中
  compressing,

  /// 已完成
  completed,

  /// 已取消
  cancelled,

  /// 压缩失败
  error,
}

/// 单个视频的压缩信息
class VideoCompressionInfo extends Equatable {
  /// 视频信息
  final VideoModel video;

  /// 压缩状态
  final VideoCompressionStatus status;

  /// 压缩进度 (0.0-1.0)
  final double progress;

  /// 错误信息（当状态为error时）
  final String? errorMessage;

  /// 预估剩余时间（秒）
  final int? estimatedTimeRemaining;

  /// 压缩后文件大小（字节）
  final int? compressedSize;

  /// 压缩后文件路径
  final String? outputPath;

  const VideoCompressionInfo({
    required this.video,
    this.status = VideoCompressionStatus.waiting,
    this.progress = 0.0,
    this.errorMessage,
    this.estimatedTimeRemaining,
    this.compressedSize,
    this.outputPath,
  });

  VideoCompressionInfo copyWith({
    VideoModel? video,
    VideoCompressionStatus? status,
    double? progress,
    String? errorMessage,
    int? estimatedTimeRemaining,
    int? compressedSize,
    String? outputPath,
  }) {
    return VideoCompressionInfo(
      video: video ?? this.video,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      estimatedTimeRemaining:
          estimatedTimeRemaining ?? this.estimatedTimeRemaining,
      compressedSize: compressedSize ?? this.compressedSize,
      outputPath: outputPath ?? this.outputPath,
    );
  }

  /// 获取状态显示文本
  String get statusText {
    switch (status) {
      case VideoCompressionStatus.waiting:
        return '等待中';
      case VideoCompressionStatus.compressing:
        return '压缩中';
      case VideoCompressionStatus.completed:
        return '已完成';
      case VideoCompressionStatus.cancelled:
        return '已取消';
      case VideoCompressionStatus.error:
        return '压缩失败';
    }
  }

  /// 获取操作按钮文本
  String get actionButtonText {
    switch (status) {
      case VideoCompressionStatus.waiting:
        return '取消排队';
      case VideoCompressionStatus.compressing:
        return '取消压缩';
      case VideoCompressionStatus.completed:
        return '预览';
      case VideoCompressionStatus.cancelled:
        return '重新压缩';
      case VideoCompressionStatus.error:
        return '重试';
    }
  }

  /// 格式化剩余时间显示
  String get formattedTimeRemaining {
    if (estimatedTimeRemaining == null) return '';

    final minutes = estimatedTimeRemaining! ~/ 60;
    final seconds = estimatedTimeRemaining! % 60;

    if (minutes > 0) {
      return '$minutes 分 $seconds 秒';
    } else {
      return '$seconds 秒';
    }
  }

  /// 格式化压缩后大小显示
  String get formattedCompressedSize {
    if (compressedSize == null) return '';

    final size = compressedSize!;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  /// 计算压缩比例
  String get compressionRatio {
    if (compressedSize == null || video.sizeBytes == 0) return '';

    final ratio = (video.sizeBytes - compressedSize!) / video.sizeBytes;
    return '${(ratio * 100).toStringAsFixed(0)}%';
  }

  @override
  List<Object?> get props => [
        video,
        status,
        progress,
        errorMessage,
        estimatedTimeRemaining,
        compressedSize,
        outputPath,
      ];
}

/// 整体压缩任务状态
enum CompressionTaskStatus {
  /// 准备中
  preparing,

  /// 进行中
  inProgress,

  /// 已暂停（所有视频都被取消或完成）
  paused,

  /// 已完成
  completed,

  /// 已取消
  cancelled,
}

/// 压缩任务信息
class CompressionTaskInfo extends Equatable {
  /// 任务状态
  final CompressionTaskStatus status;

  /// 视频压缩信息列表
  final List<VideoCompressionInfo> videos;

  /// 任务开始时间
  final DateTime? startTime;

  /// 任务完成时间
  final DateTime? endTime;

  /// 总体进度 (0.0-1.0)
  final double overallProgress;

  const CompressionTaskInfo({
    this.status = CompressionTaskStatus.preparing,
    this.videos = const [],
    this.startTime,
    this.endTime,
    this.overallProgress = 0.0,
  });

  CompressionTaskInfo copyWith({
    CompressionTaskStatus? status,
    List<VideoCompressionInfo>? videos,
    DateTime? startTime,
    DateTime? endTime,
    double? overallProgress,
  }) {
    return CompressionTaskInfo(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      overallProgress: overallProgress ?? this.overallProgress,
    );
  }

  /// 获取当前正在压缩的视频
  VideoCompressionInfo? get currentCompressingVideo {
    try {
      return videos.firstWhere(
        (video) => video.status == VideoCompressionStatus.compressing,
      );
    } catch (e) {
      return null;
    }
  }

  /// 获取等待中的视频数量
  int get waitingCount {
    return videos
        .where((video) => video.status == VideoCompressionStatus.waiting)
        .length;
  }

  /// 获取已完成的视频数量
  int get completedCount {
    return videos
        .where((video) => video.status == VideoCompressionStatus.completed)
        .length;
  }

  /// 获取已取消的视频数量
  int get cancelledCount {
    return videos
        .where((video) => video.status == VideoCompressionStatus.cancelled)
        .length;
  }

  /// 获取失败的视频数量
  int get errorCount {
    return videos
        .where((video) => video.status == VideoCompressionStatus.error)
        .length;
  }

  /// 总视频数量
  int get totalCount => videos.length;

  /// 任务状态文本
  String get statusText {
    switch (status) {
      case CompressionTaskStatus.preparing:
        return '准备中...';
      case CompressionTaskStatus.inProgress:
        return '压缩进行中';
      case CompressionTaskStatus.paused:
        return '已暂停';
      case CompressionTaskStatus.completed:
        return '压缩完成';
      case CompressionTaskStatus.cancelled:
        return '已取消';
    }
  }

  /// 进度文本
  String get progressText {
    return '$completedCount / $totalCount';
  }

  /// 计算总原始大小
  int get totalOriginalSize {
    return videos.fold(0, (sum, video) => sum + video.video.sizeBytes);
  }

  /// 计算总压缩后大小
  int get totalCompressedSize {
    return videos
        .where((video) => video.compressedSize != null)
        .fold(0, (sum, video) => sum + video.compressedSize!);
  }

  /// 格式化总节省空间
  String get formattedTotalSavings {
    final savings = totalOriginalSize - totalCompressedSize;
    if (savings <= 0) return '0 B';

    if (savings < 1024) return '$savings B';
    if (savings < 1024 * 1024)
      return '${(savings / 1024).toStringAsFixed(1)} KB';
    if (savings < 1024 * 1024 * 1024) {
      return '${(savings / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(savings / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  /// 是否可以开始压缩
  bool get canStart {
    return status == CompressionTaskStatus.preparing && videos.isNotEmpty;
  }

  /// 是否有正在进行的压缩
  bool get hasActiveCompression {
    return currentCompressingVideo != null;
  }

  /// 是否所有视频都已处理（完成、取消或失败）
  bool get isAllProcessed {
    return videos.every((video) =>
        video.status == VideoCompressionStatus.completed ||
        video.status == VideoCompressionStatus.cancelled ||
        video.status == VideoCompressionStatus.error);
  }

  @override
  List<Object?> get props => [
        status,
        videos,
        startTime,
        endTime,
        overallProgress,
      ];
}
