import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/compression_progress_model.dart';
import '../models/video_model.dart';
import '../models/compression_model.dart';

/// 压缩进度状态
class CompressionProgressState extends Equatable {
  /// 任务信息
  final CompressionTaskInfo taskInfo;

  const CompressionProgressState({
    this.taskInfo = const CompressionTaskInfo(),
  });

  CompressionProgressState copyWith({
    CompressionTaskInfo? taskInfo,
  }) {
    return CompressionProgressState(
      taskInfo: taskInfo ?? this.taskInfo,
    );
  }

  @override
  List<Object?> get props => [taskInfo];
}

/// 压缩进度状态管理
class CompressionProgressCubit extends Cubit<CompressionProgressState> {
  CompressionProgressCubit() : super(const CompressionProgressState());

  /// 当前压缩配置
  CompressionConfig? _compressionConfig;

  /// 模拟压缩进度的定时器
  Timer? _progressTimer;

  /// 当前压缩视频的开始时间
  DateTime? _currentVideoStartTime;

  @override
  Future<void> close() {
    _progressTimer?.cancel();
    return super.close();
  }

  /// 初始化压缩任务
  void initializeTask({
    required List<VideoModel> videos,
    required CompressionConfig config,
  }) {
    _compressionConfig = config;

    final videoInfos = videos
        .map((video) => VideoCompressionInfo(
              video: video,
              status: VideoCompressionStatus.waiting,
              progress: 0.0,
            ))
        .toList();

    final taskInfo = CompressionTaskInfo(
      status: CompressionTaskStatus.preparing,
      videos: videoInfos,
      overallProgress: 0.0,
    );

    emit(state.copyWith(taskInfo: taskInfo));
  }

  /// 开始压缩任务
  void startCompression() {
    if (!state.taskInfo.canStart) return;

    final updatedTaskInfo = state.taskInfo.copyWith(
      status: CompressionTaskStatus.inProgress,
      startTime: DateTime.now(),
    );

    emit(state.copyWith(taskInfo: updatedTaskInfo));

    // 开始处理队列中的第一个视频
    _processNextVideo();
  }

  /// 处理队列中的下一个视频
  void _processNextVideo() {
    final waitingVideos = state.taskInfo.videos
        .where((video) => video.status == VideoCompressionStatus.waiting)
        .toList();

    if (waitingVideos.isEmpty) {
      // 所有视频都已处理，完成任务
      _completeTask();
      return;
    }

    // 开始压缩第一个等待中的视频
    final videoToCompress = waitingVideos.first;
    _startVideoCompression(videoToCompress);
  }

  /// 开始压缩指定视频
  void _startVideoCompression(VideoCompressionInfo videoInfo) {
    _currentVideoStartTime = DateTime.now();

    // 更新视频状态为压缩中
    final updatedVideos = state.taskInfo.videos.map((video) {
      if (video.video.id == videoInfo.video.id) {
        return video.copyWith(
          status: VideoCompressionStatus.compressing,
          progress: 0.0,
        );
      }
      return video;
    }).toList();

    final updatedTaskInfo = state.taskInfo.copyWith(videos: updatedVideos);
    emit(state.copyWith(taskInfo: updatedTaskInfo));

    // 开始模拟压缩进度
    _startProgressSimulation(videoInfo);
  }

  /// 模拟压缩进度（实际项目中这里会调用FFmpeg）
  void _startProgressSimulation(VideoCompressionInfo videoInfo) {
    _progressTimer?.cancel();

    // 根据视频大小估算压缩时间（模拟）
    final estimatedDuration = _estimateCompressionDuration(videoInfo.video);
    const updateInterval = Duration(milliseconds: 500);
    final totalSteps =
        estimatedDuration.inMilliseconds ~/ updateInterval.inMilliseconds;
    int currentStep = 0;

    _progressTimer = Timer.periodic(updateInterval, (timer) {
      currentStep++;
      final progress = min(currentStep / totalSteps, 1.0);

      // 计算剩余时间
      final elapsed = DateTime.now().difference(_currentVideoStartTime!);
      final remaining = progress > 0
          ? Duration(
              milliseconds:
                  ((elapsed.inMilliseconds / progress) - elapsed.inMilliseconds)
                      .round())
          : Duration.zero;

      _updateVideoProgress(videoInfo.video.id, progress, remaining.inSeconds);

      if (progress >= 1.0) {
        timer.cancel();
        _completeVideoCompression(videoInfo);
      }
    });
  }

  /// 更新视频压缩进度
  void _updateVideoProgress(
      String videoId, double progress, int remainingSeconds) {
    final updatedVideos = state.taskInfo.videos.map((video) {
      if (video.video.id == videoId) {
        return video.copyWith(
          progress: progress,
          estimatedTimeRemaining:
              remainingSeconds > 0 ? remainingSeconds : null,
        );
      }
      return video;
    }).toList();

    // 计算整体进度
    final overallProgress = _calculateOverallProgress(updatedVideos);

    final updatedTaskInfo = state.taskInfo.copyWith(
      videos: updatedVideos,
      overallProgress: overallProgress,
    );

    emit(state.copyWith(taskInfo: updatedTaskInfo));
  }

  /// 完成视频压缩
  void _completeVideoCompression(VideoCompressionInfo videoInfo) {
    // 估算压缩后的文件大小
    final compressedSize = _estimateCompressedSize(videoInfo.video);

    final updatedVideos = state.taskInfo.videos.map((video) {
      if (video.video.id == videoInfo.video.id) {
        return video.copyWith(
          status: VideoCompressionStatus.completed,
          progress: 1.0,
          estimatedTimeRemaining: null,
          compressedSize: compressedSize,
          outputPath: '/path/to/compressed/${video.video.id}_compressed.mp4',
        );
      }
      return video;
    }).toList();

    final overallProgress = _calculateOverallProgress(updatedVideos);

    final updatedTaskInfo = state.taskInfo.copyWith(
      videos: updatedVideos,
      overallProgress: overallProgress,
    );

    emit(state.copyWith(taskInfo: updatedTaskInfo));

    // 继续处理下一个视频
    _processNextVideo();
  }

  /// 取消视频压缩
  void cancelVideo(String videoId) {
    final video =
        state.taskInfo.videos.firstWhere((v) => v.video.id == videoId);

    if (video.status == VideoCompressionStatus.compressing) {
      // 如果是正在压缩的视频，停止当前压缩
      _progressTimer?.cancel();
    }

    final updatedVideos = state.taskInfo.videos.map((v) {
      if (v.video.id == videoId) {
        return v.copyWith(
          status: VideoCompressionStatus.cancelled,
          progress: 0.0,
          estimatedTimeRemaining: null,
        );
      }
      return v;
    }).toList();

    final overallProgress = _calculateOverallProgress(updatedVideos);

    final updatedTaskInfo = state.taskInfo.copyWith(
      videos: updatedVideos,
      overallProgress: overallProgress,
    );

    emit(state.copyWith(taskInfo: updatedTaskInfo));

    // 如果取消的是正在压缩的视频，继续处理下一个
    if (video.status == VideoCompressionStatus.compressing) {
      _processNextVideo();
    }
  }

  /// 重新压缩视频
  void retryVideo(String videoId) {
    final updatedVideos = state.taskInfo.videos.map((video) {
      if (video.video.id == videoId) {
        return video.copyWith(
          status: VideoCompressionStatus.waiting,
          progress: 0.0,
          errorMessage: null,
          estimatedTimeRemaining: null,
          compressedSize: null,
          outputPath: null,
        );
      }
      return video;
    }).toList();

    final updatedTaskInfo = state.taskInfo.copyWith(videos: updatedVideos);
    emit(state.copyWith(taskInfo: updatedTaskInfo));

    // 如果当前没有正在压缩的视频，立即开始处理
    if (!updatedTaskInfo.hasActiveCompression) {
      _processNextVideo();
    }
  }

  /// 取消所有压缩
  void cancelAllCompression() {
    _progressTimer?.cancel();

    final updatedVideos = state.taskInfo.videos.map((video) {
      if (video.status == VideoCompressionStatus.waiting ||
          video.status == VideoCompressionStatus.compressing) {
        return video.copyWith(
          status: VideoCompressionStatus.cancelled,
          progress: 0.0,
          estimatedTimeRemaining: null,
        );
      }
      return video;
    }).toList();

    final updatedTaskInfo = state.taskInfo.copyWith(
      status: CompressionTaskStatus.cancelled,
      videos: updatedVideos,
      endTime: DateTime.now(),
    );

    emit(state.copyWith(taskInfo: updatedTaskInfo));
  }

  /// 完成整个压缩任务
  void _completeTask() {
    final updatedTaskInfo = state.taskInfo.copyWith(
      status: CompressionTaskStatus.completed,
      endTime: DateTime.now(),
      overallProgress: 1.0,
    );

    emit(state.copyWith(taskInfo: updatedTaskInfo));
  }

  /// 调整视频在队列中的优先级
  void moveVideoInQueue(String videoId, int newIndex) {
    final videos = List<VideoCompressionInfo>.from(state.taskInfo.videos);
    final videoIndex = videos.indexWhere((v) => v.video.id == videoId);

    if (videoIndex != -1 && newIndex != videoIndex) {
      final video = videos.removeAt(videoIndex);
      videos.insert(newIndex, video);

      final updatedTaskInfo = state.taskInfo.copyWith(videos: videos);
      emit(state.copyWith(taskInfo: updatedTaskInfo));
    }
  }

  /// 估算压缩时长（模拟）
  Duration _estimateCompressionDuration(VideoModel video) {
    // 基于文件大小的简单估算：1GB大约需要2分钟
    final sizeInGB = video.sizeBytes / (1024 * 1024 * 1024);
    final minutes = (sizeInGB * 2).clamp(0.5, 10.0); // 最少30秒，最多10分钟
    return Duration(milliseconds: (minutes * 60 * 1000).round());
  }

  /// 估算压缩后文件大小
  int _estimateCompressedSize(VideoModel video) {
    if (_compressionConfig == null) return video.sizeBytes;

    return CompressionPresetConfig.estimateCompressedSize(
      originalSize: video.sizeBytes,
      config: _compressionConfig!,
      videoDuration: video.duration,
      originalBitrate: 5000, // 简化的默认值
    );
  }

  /// 计算整体进度
  double _calculateOverallProgress(List<VideoCompressionInfo> videos) {
    if (videos.isEmpty) return 0.0;

    double totalProgress = 0.0;
    for (final video in videos) {
      switch (video.status) {
        case VideoCompressionStatus.completed:
          totalProgress += 1.0;
          break;
        case VideoCompressionStatus.compressing:
          totalProgress += video.progress;
          break;
        case VideoCompressionStatus.waiting:
        case VideoCompressionStatus.cancelled:
        case VideoCompressionStatus.error:
          totalProgress += 0.0;
          break;
      }
    }

    return totalProgress / videos.length;
  }
}
