import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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

  /// 模拟压缩进度的定时器（FFmpeg接入后仅用于兜底）
  Timer? _progressTimer;

  /// 当前压缩视频的开始时间
  DateTime? _currentVideoStartTime;

  /// 当前FFmpeg会话是否在运行（用于取消）
  bool _isRunningSession = false;

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

    print('========== 初始化压缩任务 ==========');
    print('视频数量: ${videos.length}');
    print('压缩预设: ${_getPresetDisplayName(config.preset)}');
    print('CRF值: ${config.customCRF ?? "默认"}');
    print('码率: ${config.customBitrate ?? "默认"}kbps');
    print('帧率: ${config.keepOriginalFrameRate ? "保持原帧率" : "${config.customFrameRate ?? "默认"}fps"}');
    print('音频: ${config.keepOriginalAudio ? "保持原音频" : "压缩音频 ${config.audioQuality}kbps"}');
    final totalSize = videos.fold(0, (sum, v) => sum + v.sizeBytes);
    print('总原始大小: ${_formatBytes(totalSize)}');
    print('===================================');

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

    print('========== 开始执行压缩任务 ==========');
    print('任务开始时间: ${DateTime.now()}');
    print('====================================');

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
    final waitingVideos = state.taskInfo.videos.where((video) => video.status == VideoCompressionStatus.waiting).toList();

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

    print('======== 开始压缩视频 ========');
    print('视频: ${videoInfo.video.title}');
    print('原始大小: ${videoInfo.video.fileSize}');
    print('时长: ${videoInfo.video.duration}秒');
    print('分辨率: ${videoInfo.video.width}x${videoInfo.video.height}');
    print('==============================');

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

    // 使用 FFmpeg 开始真实压缩
    _runFfmpegForVideo(videoInfo);
  }

  /// （兼容保留）模拟压缩进度
  void _startProgressSimulation(VideoCompressionInfo videoInfo) {
    _progressTimer?.cancel();

    // 根据视频大小估算压缩时间（模拟）
    final estimatedDuration = _estimateCompressionDuration(videoInfo.video);
    const updateInterval = Duration(milliseconds: 500);
    final totalSteps = estimatedDuration.inMilliseconds ~/ updateInterval.inMilliseconds;
    int currentStep = 0;

    _progressTimer = Timer.periodic(updateInterval, (timer) {
      currentStep++;
      final progress = min(currentStep / totalSteps, 1.0);

      // 计算剩余时间
      final elapsed = DateTime.now().difference(_currentVideoStartTime!);
      final remaining = progress > 0 ? Duration(milliseconds: ((elapsed.inMilliseconds / progress) - elapsed.inMilliseconds).round()) : Duration.zero;

      _updateVideoProgress(videoInfo.video.id, progress, remaining.inSeconds);

      if (progress >= 1.0) {
        timer.cancel();
        _completeVideoCompression(videoInfo);
      }
    });
  }

  /// 使用 FFmpegKit 压缩单个视频
  Future<void> _runFfmpegForVideo(VideoCompressionInfo videoInfo) async {
    if (_compressionConfig == null) {
      _failCurrentVideo(videoInfo, '无有效的压缩配置');
      return;
    }

    _isRunningSession = true;

    try {
      final String inputPath = videoInfo.video.path;
      final String outputPath = await _buildOutputPath(videoInfo.video);

      final String command = _buildFfmpegCommand(
        inputPath: inputPath,
        outputPath: outputPath,
        config: _compressionConfig!,
      );

      print('[FFmpeg 命令] $command');

      // 运行FFmpeg，并追踪进度
      FFmpegKit.executeAsync(
        command,
        (session) async {
          _isRunningSession = false;
          final ReturnCode? returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            final int compressedSize = await _readFileSize(outputPath);
            final Duration elapsed = DateTime.now().difference(_currentVideoStartTime ?? DateTime.now());

            print('======== 压缩成功 ========');
            print('视频: ${videoInfo.video.title}');
            print('原始大小: ${videoInfo.video.fileSize}');
            print('压缩后大小: ${_formatBytes(compressedSize)}');
            print('压缩比: ${((videoInfo.video.sizeBytes - compressedSize) / videoInfo.video.sizeBytes * 100).toStringAsFixed(1)}%');
            print('耗时: ${elapsed.inMinutes}分${elapsed.inSeconds % 60}秒');
            print('输出路径: $outputPath');
            print('=======================');

            _markVideoCompleted(videoInfo, compressedSize, outputPath);
            _processNextVideo();
          } else if (ReturnCode.isCancel(returnCode)) {
            print('[FFmpeg] 压缩被取消: ${videoInfo.video.title}');
            // 已在取消逻辑里更新状态，这里确保队列继续
            _processNextVideo();
          } else {
            final String logs = (await session.getAllLogsAsString()) ?? '未知错误';
            print('======== 压缩失败 ========');
            print('视频: ${videoInfo.video.title}');
            print('返回码: ${returnCode?.getValue()}');
            print('错误日志: $logs');
            print('========================');

            _failCurrentVideo(videoInfo, logs);
            _processNextVideo();
          }
        },
        (log) {
          // FFmpeg 日志输出
          final String logMessage = log.getMessage() ?? '';
          final int logLevel = log.getLevel();
          final String levelStr = _getLogLevelString(logLevel);
          print('[FFmpeg $levelStr] $logMessage');
        },
        (Statistics statistics) {
          // 进度：统计的time单位为毫秒
          final int timeMs = statistics.getTime();
          final double totalMs = max(videoInfo.video.duration * 1000.0, 1.0);
          final double progress = (timeMs / totalMs).clamp(0.0, 1.0);
          final Duration elapsed = DateTime.now().difference(_currentVideoStartTime ?? DateTime.now());
          final Duration remaining = progress > 0 ? Duration(milliseconds: ((elapsed.inMilliseconds / progress) - elapsed.inMilliseconds).round()) : Duration.zero;

          // 详细的统计信息日志
          final double speed = statistics.getSpeed();
          final double bitrate = statistics.getBitrate();
          final int frame = statistics.getVideoFrameNumber();
          final double fps = statistics.getVideoFps();
          final String size = statistics.getSize().toString();

          print('[FFmpeg 统计] 进度: ${(progress * 100).toStringAsFixed(1)}% | '
              '时间: ${(timeMs / 1000).toStringAsFixed(1)}s/${(totalMs / 1000).toStringAsFixed(1)}s | '
              '帧数: $frame | '
              '速度: ${speed.toStringAsFixed(2)}x | '
              '码率: ${bitrate.toStringAsFixed(0)}kbps | '
              '输出大小: $size | '
              'FPS: ${fps.toStringAsFixed(1)} | '
              '预计剩余: ${remaining.inMinutes}分${remaining.inSeconds % 60}秒');

          _updateVideoProgress(videoInfo.video.id, progress, remaining.inSeconds);
        },
      );
    } catch (e) {
      _isRunningSession = false;
      _failCurrentVideo(videoInfo, e.toString());
      _processNextVideo();
    }
  }

  Future<String> _buildOutputPath(VideoModel video) async {
    final Directory dir = await getTemporaryDirectory();
    final String baseName = p.basenameWithoutExtension(video.path);
    final String fileName = '${baseName}_compressed.mp4';
    return p.join(dir.path, fileName);
  }

  String _buildFfmpegCommand({
    required String inputPath,
    required String outputPath,
    required CompressionConfig config,
  }) {
    // 视频编码参数（使用libx264 + CRF）
    final int crf = config.customCRF ?? 23;
    final int videoBitrate = config.customBitrate ?? 0; // 可选
    final bool keepFps = config.keepOriginalFrameRate;
    final double? customFps = config.customFrameRate;
    final int audioKbps = config.audioQuality;

    final List<String> args = [];
    args.addAll(['-y', '-hide_banner', '-i', _q(inputPath)]);
    args.addAll(['-c:v', 'libx264', '-preset', 'medium', '-crf', crf.toString()]);
    if (videoBitrate > 0) {
      args.addAll(['-b:v', '${videoBitrate}k']);
    }
    if (!keepFps && customFps != null && customFps > 0) {
      args.addAll(['-r', customFps.toStringAsFixed(0)]);
    }
    args.addAll(['-c:a', 'aac', '-b:a', '${audioKbps}k', '-ac', '2']);
    args.addAll(['-movflags', '+faststart']);
    args.add(_q(outputPath));

    return args.join(' ');
  }

  String _q(String path) => '"$path"';

  Future<int> _readFileSize(String path) async {
    try {
      final File f = File(path);
      final bool exists = await f.exists();
      if (!exists) return 0;
      return await f.length();
    } catch (_) {
      return 0;
    }
  }

  void _markVideoCompleted(VideoCompressionInfo videoInfo, int compressedSize, String outputPath) {
    final List<VideoCompressionInfo> updatedVideos = state.taskInfo.videos.map((video) {
      if (video.video.id == videoInfo.video.id) {
        return video.copyWith(
          status: VideoCompressionStatus.completed,
          progress: 1.0,
          estimatedTimeRemaining: null,
          compressedSize: compressedSize,
          outputPath: outputPath,
        );
      }
      return video;
    }).toList();

    final double overallProgress = _calculateOverallProgress(updatedVideos);
    final CompressionTaskInfo updatedTaskInfo = state.taskInfo.copyWith(
      videos: updatedVideos,
      overallProgress: overallProgress,
    );
    emit(state.copyWith(taskInfo: updatedTaskInfo));
  }

  void _failCurrentVideo(VideoCompressionInfo videoInfo, String message) {
    final List<VideoCompressionInfo> updatedVideos = state.taskInfo.videos.map((video) {
      if (video.video.id == videoInfo.video.id) {
        return video.copyWith(
          status: VideoCompressionStatus.error,
          progress: 0.0,
          estimatedTimeRemaining: null,
          errorMessage: message,
        );
      }
      return video;
    }).toList();

    final double overallProgress = _calculateOverallProgress(updatedVideos);
    final CompressionTaskInfo updatedTaskInfo = state.taskInfo.copyWith(
      videos: updatedVideos,
      overallProgress: overallProgress,
    );
    emit(state.copyWith(taskInfo: updatedTaskInfo));
  }

  /// 更新视频压缩进度
  void _updateVideoProgress(String videoId, double progress, int remainingSeconds) {
    final updatedVideos = state.taskInfo.videos.map((video) {
      if (video.video.id == videoId) {
        return video.copyWith(
          progress: progress,
          estimatedTimeRemaining: remainingSeconds > 0 ? remainingSeconds : null,
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
    final video = state.taskInfo.videos.firstWhere((v) => v.video.id == videoId);

    if (video.status == VideoCompressionStatus.compressing) {
      // 如果是正在压缩的视频，停止当前压缩
      _progressTimer?.cancel();
      if (_isRunningSession) {
        // 取消所有进行中的会话（当前只有一个）
        FFmpegKit.cancel();
      }
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
    if (_isRunningSession) {
      FFmpegKit.cancel();
    }

    final updatedVideos = state.taskInfo.videos.map((video) {
      if (video.status == VideoCompressionStatus.waiting || video.status == VideoCompressionStatus.compressing) {
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
    final endTime = DateTime.now();
    final duration = state.taskInfo.startTime != null ? endTime.difference(state.taskInfo.startTime!) : Duration.zero;

    final completedVideos = state.taskInfo.videos.where((v) => v.status == VideoCompressionStatus.completed).toList();
    final failedVideos = state.taskInfo.videos.where((v) => v.status == VideoCompressionStatus.error).toList();
    final cancelledVideos = state.taskInfo.videos.where((v) => v.status == VideoCompressionStatus.cancelled).toList();

    final totalOriginalSize = state.taskInfo.videos.fold(0, (sum, v) => sum + v.video.sizeBytes);
    final totalCompressedSize = completedVideos.fold(0, (sum, v) => sum + (v.compressedSize ?? 0));
    final totalSavings = totalOriginalSize - totalCompressedSize;

    print('========== 压缩任务完成 ==========');
    print('任务结束时间: $endTime');
    print('总耗时: ${duration.inHours}小时${duration.inMinutes % 60}分${duration.inSeconds % 60}秒');
    print('成功视频: ${completedVideos.length}');
    print('失败视频: ${failedVideos.length}');
    print('取消视频: ${cancelledVideos.length}');
    print('总视频数: ${state.taskInfo.videos.length}');
    print('原始总大小: ${_formatBytes(totalOriginalSize)}');
    if (totalCompressedSize > 0) {
      print('压缩后总大小: ${_formatBytes(totalCompressedSize)}');
      print('节省空间: ${_formatBytes(totalSavings)} (${((totalSavings / totalOriginalSize) * 100).toStringAsFixed(1)}%)');
    }
    print('=================================');

    final updatedTaskInfo = state.taskInfo.copyWith(
      status: CompressionTaskStatus.completed,
      endTime: endTime,
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

  /// 获取日志级别字符串
  String _getLogLevelString(int level) {
    // FFmpeg 日志级别定义
    switch (level) {
      case 0:
        return 'QUIET';
      case 8:
        return 'PANIC';
      case 16:
        return 'FATAL';
      case 24:
        return 'ERROR';
      case 32:
        return 'WARNING';
      case 40:
        return 'INFO';
      case 48:
        return 'VERBOSE';
      case 56:
        return 'DEBUG';
      case 64:
        return 'TRACE';
      default:
        return 'UNKNOWN($level)';
    }
  }

  /// 格式化字节大小
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  /// 获取压缩预设显示名称
  String _getPresetDisplayName(CompressionPreset preset) {
    switch (preset) {
      case CompressionPreset.highQuality:
        return '高画质模式';
      case CompressionPreset.balanced:
        return '平衡模式';
      case CompressionPreset.maxCompression:
        return '极限压缩';
    }
  }
}
