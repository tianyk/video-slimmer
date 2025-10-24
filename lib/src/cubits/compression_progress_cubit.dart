import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/media_information_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/compression_model.dart';
import '../models/compression_progress_model.dart';
import '../models/video_model.dart';
import '../utils.dart';

/// 压缩进度状态
class CompressionProgressState extends Equatable {
  /// 视频压缩信息列表
  final List<VideoCompressionInfo> videos;

  const CompressionProgressState({
    this.videos = const [],
  });

  CompressionProgressState copyWith({
    List<VideoCompressionInfo>? videos,
  }) {
    return CompressionProgressState(
      videos: videos ?? this.videos,
    );
  }

  /// 总体进度 (0.0-1.0)
  double get overallProgress {
    if (videos.isEmpty) return 0.0;
    double totalProgress = 0.0;
    for (final video in videos) {
      if (video.status == VideoCompressionStatus.completed) {
        totalProgress += 1.0;
      } else if (video.status == VideoCompressionStatus.compressing) {
        totalProgress += video.progress;
      }
    }
    return totalProgress / videos.length;
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
  int get waitingCount => videos.where((v) => v.status == VideoCompressionStatus.waiting).length;

  /// 获取等待下载的视频数量
  int get waitingDownloadCount => videos.where((v) => v.status == VideoCompressionStatus.waitingDownload).length;

  /// 获取已完成的视频数量
  int get completedCount => videos.where((v) => v.status == VideoCompressionStatus.completed).length;

  /// 获取已取消的视频数量
  int get cancelledCount => videos.where((v) => v.status == VideoCompressionStatus.cancelled).length;

  /// 获取失败的视频数量
  int get errorCount => videos.where((v) => v.status == VideoCompressionStatus.error).length;

  /// 获取正在下载的视频数量
  int get downloadingCount => videos.where((v) => v.status == VideoCompressionStatus.downloading).length;

  /// 获取正在下载的视频列表
  List<VideoCompressionInfo> get downloadingVideos => videos.where((v) => v.status == VideoCompressionStatus.downloading).toList();

  /// 是否有下载任务
  bool get hasDownloading => downloadingCount > 0;

  /// 总视频数量
  int get totalCount => videos.length;

  /// 是否所有视频都已处理
  bool get isAllProcessed {
    return videos.every((video) => video.status == VideoCompressionStatus.completed || video.status == VideoCompressionStatus.cancelled || video.status == VideoCompressionStatus.error);
  }

  /// 是否有正在进行的压缩
  bool get hasActiveCompression => currentCompressingVideo != null;

  /// 进度文本
  String get progressText => '$completedCount / $totalCount';

  /// 计算总原始大小
  int get totalOriginalSize => videos.fold(0, (sum, video) => sum + video.video.sizeBytes);

  /// 计算总压缩后大小
  int get totalCompressedSize => videos.where((video) => video.compressedSize != null).fold(0, (sum, video) => sum + video.compressedSize!);

  /// 格式化总节省空间
  String get formattedTotalSavings {
    final int savings = totalOriginalSize - totalCompressedSize;
    if (savings <= 0) return '0 B';
    if (savings < 1024) return '$savings B';
    if (savings < 1024 * 1024) {
      return '${(savings / 1024).toStringAsFixed(1)} KB';
    }
    if (savings < 1024 * 1024 * 1024) {
      return '${(savings / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(savings / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  @override
  List<Object?> get props => [videos];
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

  /// 存储所有下载任务的 Future
  final Map<String, Future<void>> _downloadTasks = {};

  @override
  Future<void> close() {
    _progressTimer?.cancel();
    _downloadTasks.clear();
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
              status: video.isLocallyAvailable ? VideoCompressionStatus.waiting : VideoCompressionStatus.waitingDownload,
              progress: 0.0,
            ))
        .toList();

    emit(state.copyWith(videos: videoInfos));
  }

  /// 开始压缩任务
  void startCompression() {
    if (state.videos.isEmpty) return;

    print('========== 开始执行压缩任务 ==========');
    print('任务开始时间: ${DateTime.now()}');
    print('====================================');

    // 第一步：调度所有需要下载的视频（具体实现由调用方补充）
    _scheduleDownloads();

    // 第二步：开始处理可压缩的视频
    _processNextVideo();
  }

  /// 调度下载任务（占位，等待后续实现）
  void _scheduleDownloads() {
    // 留空：下载调度逻辑由后续实现负责。
  }

  /// 标记视频下载开始（占位，供调用方手动触发）
  void markVideoDownloadStarted(String videoId) {
    _updateVideoStatus(videoId, VideoCompressionStatus.downloading, progress: 0.0);
  }

  /// 标记视频下载完成（占位，供调用方手动触发）
  void markVideoDownloaded({
    required String videoId,
    required String localPath,
  }) {
    final updatedVideos = state.videos.map((info) {
      if (info.video.id == videoId) {
        final VideoModel updatedVideo = info.video.copyWith(
          isLocallyAvailable: true,
        );
        return info.copyWith(
          video: updatedVideo,
          status: VideoCompressionStatus.waiting,
          progress: 0.0,
        );
      }
      return info;
    }).toList();

    emit(state.copyWith(videos: updatedVideos));

    if (!state.hasActiveCompression) {
      _processNextVideo();
    }
  }

  /// 标记视频下载失败（占位，供调用方手动触发）
  void markVideoDownloadFailed(String videoId, String message) {
    _updateVideoStatus(
      videoId,
      VideoCompressionStatus.error,
      errorMessage: message,
      progress: 0.0,
    );

    if (!state.hasActiveCompression) {
      _processNextVideo();
    }
  }

  /// 处理队列中的下一个视频
  void _processNextVideo() {
    final List<VideoCompressionInfo> readyVideos = state.videos.where((VideoCompressionInfo video) => video.status == VideoCompressionStatus.waiting).toList();

    if (readyVideos.isEmpty) {
      // 检查是否还有下载任务
      final bool hasPendingDownload = state.videos.any((v) => v.status == VideoCompressionStatus.waitingDownload || v.status == VideoCompressionStatus.downloading);

      if (hasPendingDownload) {
        print('[等待] 正在等待下载任务完成...');
        return;
      }

      _completeTask();
      return;
    }

    // 开始压缩第一个准备好的视频
    final videoToCompress = readyVideos.first;
    _startVideoCompression(videoToCompress);
  }

  /// 辅助方法：更新视频状态
  void _updateVideoStatus(
    String videoId,
    VideoCompressionStatus status, {
    double? progress,
    String? errorMessage,
  }) {
    final updatedVideos = state.videos.map((v) {
      if (v.video.id == videoId) {
        return v.copyWith(
          status: status,
          progress: progress ?? v.progress,
          errorMessage: errorMessage,
        );
      }
      return v;
    }).toList();

    emit(state.copyWith(videos: updatedVideos));
  }

  /// 开始压缩指定视频
  void _startVideoCompression(VideoCompressionInfo videoInfo) {
    _currentVideoStartTime = DateTime.now();

    print('======== 开始压缩视频 ========');
    print('视频: ${videoInfo.video.id}');
    print('原始大小: ${videoInfo.video.fileSize}');
    print('时长: ${videoInfo.video.duration}秒');
    print('分辨率: ${videoInfo.video.width}x${videoInfo.video.height}');
    print('==============================');

    // 更新视频状态为压缩中
    final updatedVideos = state.videos.map((video) {
      if (video.video.id == videoInfo.video.id) {
        return video.copyWith(
          status: VideoCompressionStatus.compressing,
          progress: 0.0,
        );
      }
      return video;
    }).toList();

    emit(state.copyWith(videos: updatedVideos));

    // 使用 FFmpeg 开始真实压缩
    _runFfmpegForVideo(videoInfo);
  }

  /// 从视频 ID 获取文件路径
  ///
  /// 使用 originFile 以保留完整的元数据信息：
  /// - GPS 坐标（拍摄地点）
  /// - 拍摄时间
  /// - 相机信息
  /// - EXIF 数据
  ///
  /// 注意：会将文件复制到应用临时目录
  Future<String?> _getVideoFilePath(String videoId) async {
    final assetEntity = await AssetEntity.fromId(videoId);
    if (assetEntity == null) {
      throw Exception('无法找到视频资源: $videoId');
    }

    // 检查是否本地可用
    final isLocallyAvailable = await assetEntity.isLocallyAvailable();
    if (!isLocallyAvailable) {
      throw Exception('视频未下载到本地，无法压缩');
    }

    // 使用 originFile 获取包含完整元数据的文件
    final file = await assetEntity.originFile;
    if (file == null) {
      throw Exception('无法获取视频文件');
    }

    return file.absolute.path;
  }

  /// 使用 FFmpegKit 压缩单个视频
  Future<void> _runFfmpegForVideo(VideoCompressionInfo videoInfo) async {
    if (_compressionConfig == null) {
      _failCurrentVideo(videoInfo, '无有效的压缩配置');
      return;
    }

    _isRunningSession = true;

    try {
      // 从 videoId 获取文件路径
      final String? inputPath = await _getVideoFilePath(videoInfo.video.id);
      if (inputPath == null) {
        throw Exception('无法获取视频文件路径');
      }

      final String outputPath = await _buildOutputPath(inputPath);

      // 压缩前：打印原视频元数据
      await _printVideoMetadata(inputPath, '原视频');

      final String command = await _buildFfmpegCommand(
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
            final Duration elapsed = _currentVideoStartTime != null ? DateTime.now().difference(_currentVideoStartTime!) : Duration.zero;

            print('======== 压缩成功 ========');
            print('视频: ${videoInfo.video.id}');
            print('原始大小: ${videoInfo.video.fileSize}');
            print('压缩后大小: ${_formatBytes(compressedSize)}');
            print('压缩比: ${((videoInfo.video.sizeBytes - compressedSize) / videoInfo.video.sizeBytes * 100).toStringAsFixed(1)}%');
            print('耗时: ${elapsed.inMinutes}分${elapsed.inSeconds % 60}秒');
            print('输出路径: $outputPath');
            print('=======================');

            // 压缩后：打印新视频元数据并对比
            await _printVideoMetadata(outputPath, '压缩后');

            _markVideoCompleted(videoInfo, compressedSize, outputPath);
            _processNextVideo();
          } else if (ReturnCode.isCancel(returnCode)) {
            print('[FFmpeg] 压缩被取消: ${videoInfo.video.id}');
            // 已在取消逻辑里更新状态，这里确保队列继续
            _processNextVideo();
          } else {
            final String logs = (await session.getAllLogsAsString()) ?? '未知错误';
            print('======== 压缩失败 ========');
            print('视频: ${videoInfo.video.id}');
            print('返回码: ${returnCode?.getValue()}');
            print('错误日志: $logs');
            print('========================');

            _failCurrentVideo(videoInfo, logs);
            _processNextVideo();
          }
        },
        (log) {
          // FFmpeg 日志输出
          final String logMessage = log.getMessage();
          final int logLevel = log.getLevel();
          final String levelStr = _getLogLevelString(logLevel);
          print('[FFmpeg $levelStr] $logMessage');
        },
        (Statistics statistics) {
          // 进度：统计的time单位为毫秒
          final int timeMs = statistics.getTime();
          final double totalMs = max(videoInfo.video.duration * 1000.0, 1.0);
          final double progress = (timeMs / totalMs).clamp(0.0, 1.0);
          final Duration elapsed = _currentVideoStartTime != null ? DateTime.now().difference(_currentVideoStartTime!) : Duration.zero;
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

  /// 构建输出文件路径
  ///
  /// 使用 UUID 生成唯一文件名，保留原视频的文件扩展名。
  /// 例如：
  /// - 原视频：'/path/to/IMG_1234.MOV' → '/tmp/xxx/a3f2b1c4-5d6e-7f8a-9b0c-1d2e3f4a5b6c.MOV'
  /// - 原视频：'/path/to/video.mp4' → '/tmp/xxx/b4c3d2e1-6f7a-8b9c-0d1e-2f3a4b5c6d7e.mp4'
  Future<String> _buildOutputPath(String inputPath) async {
    final Directory dir = await Directory.systemTemp.createTemp('video_compression_');

    // 使用 path 包提取扩展名（包含点号，如 '.mov'）
    String ext = path.extension(inputPath);
    // 使用 UUID 生成唯一文件名，保留原扩展名
    const uuid = Uuid();
    final String fileName = '${uuid.v4()}${ext.isNotEmpty ? ext : '.mp4'}';

    return '${dir.path}/$fileName';
  }

  /// 检测原视频的编码格式
  ///
  /// 返回视频编码器名称，如 'hevc', 'h264', 'vp9' 等
  Future<String?> _detectVideoCodec(String videoPath) async {
    try {
      final MediaInformationSession session = await FFprobeKit.getMediaInformation(videoPath);
      final mediaInformation = session.getMediaInformation();

      if (mediaInformation == null) {
        return null;
      }

      // 查找视频流
      final streams = mediaInformation.getStreams();
      for (final stream in streams) {
        final codecType = stream.getAllProperties()?['codec_type'];
        if (codecType == 'video') {
          return stream.getAllProperties()?['codec_name'];
        }
      }

      return null;
    } catch (e) {
      print('⚠️  检测视频编码失败: $e');
      return null;
    }
  }

  /// 使用 FFprobe 打印视频元数据信息（调试用）
  ///
  /// 通过 FFprobe 获取视频的完整元数据，包括：
  /// - 文件信息（大小、格式、时长）
  /// - 视频流信息（编码、分辨率、帧率、码率）
  /// - 音频流信息（编码、采样率、码率）
  /// - 元数据标签（GPS、拍摄时间、设备信息等）
  Future<void> _printVideoMetadata(String videoPath, String label) async {
    try {
      print('\n========== 📹 $label 元数据 ==========');
      print('📂 路径: $videoPath');

      // 使用 FFprobe 获取媒体信息
      final MediaInformationSession session = await FFprobeKit.getMediaInformation(videoPath);
      final mediaInformation = session.getMediaInformation();

      if (mediaInformation == null) {
        print('⚠️  无法获取媒体信息');
        print('===================================\n');
        return;
      }

      // 文件基本信息
      final fileSize = await File(videoPath).length();
      print('📦 文件大小: ${formatFileSize(fileSize)}');
      print('📄 格式: ${mediaInformation.getFormat()}');
      print('⏱️  时长: ${_formatDuration(mediaInformation.getDuration())}');
      print('📊 码率: ${_formatBitrate(mediaInformation.getBitrate())}');

      // 视频流信息
      final streams = mediaInformation.getStreams();
      for (final stream in streams) {
        final codecType = stream.getAllProperties()?['codec_type'];

        if (codecType == 'video') {
          print('\n🎬 视频流:');
          print('   编码: ${stream.getAllProperties()?['codec_name']}');
          print('   分辨率: ${stream.getAllProperties()?['width']} × ${stream.getAllProperties()?['height']}');
          print('   帧率: ${stream.getAllProperties()?['r_frame_rate']}');
          print('   码率: ${_formatBitrate(stream.getAllProperties()?['bit_rate'])}');
          print('   像素格式: ${stream.getAllProperties()?['pix_fmt']}');

          // 色彩空间信息
          final colorSpace = stream.getAllProperties()?['color_space'];
          final colorPrimaries = stream.getAllProperties()?['color_primaries'];
          final colorTransfer = stream.getAllProperties()?['color_transfer'];
          if (colorSpace != null) print('   色彩空间: $colorSpace');
          if (colorPrimaries != null) print('   色域: $colorPrimaries');
          if (colorTransfer != null) print('   传输特性: $colorTransfer');
        } else if (codecType == 'audio') {
          print('\n🔊 音频流:');
          print('   编码: ${stream.getAllProperties()?['codec_name']}');
          print('   采样率: ${stream.getAllProperties()?['sample_rate']} Hz');
          print('   声道: ${stream.getAllProperties()?['channels']}');
          print('   码率: ${_formatBitrate(stream.getAllProperties()?['bit_rate'])}');
        }
      }

      // 元数据标签（GPS、拍摄时间等）
      final tags = mediaInformation.getTags();
      if (tags != null && tags.isNotEmpty) {
        print('\n📝 元数据标签:');

        // 拍摄时间
        final creationTime = tags['creation_time'] ?? tags['com.apple.quicktime.creationdate'];
        if (creationTime != null) print('   📅 拍摄时间: $creationTime');

        // GPS 信息
        final location = tags['location'] ?? tags['com.apple.quicktime.location.ISO6709'];
        if (location != null) print('   📍 GPS: $location');

        // 设备信息
        final make = tags['make'] ?? tags['com.apple.quicktime.make'];
        final model = tags['model'] ?? tags['com.apple.quicktime.model'];
        if (make != null) print('   📱 制造商: $make');
        if (model != null) print('   📱 型号: $model');

        // 软件版本
        final software = tags['software'] ?? tags['com.apple.quicktime.software'];
        if (software != null) print('   💿 软件: $software');
      }

      print('===================================\n');
    } catch (e) {
      print('⚠️  获取元数据失败: $e');
      print('===================================\n');
    }
  }

  /// 格式化时长
  String _formatDuration(String? durationStr) {
    if (durationStr == null) return '未知';
    try {
      final duration = double.parse(durationStr);
      final minutes = (duration / 60).floor();
      final seconds = (duration % 60).floor();
      return '${minutes}分${seconds}秒';
    } catch (e) {
      return durationStr;
    }
  }

  /// 格式化码率
  String _formatBitrate(dynamic bitrate) {
    if (bitrate == null) return '未知';
    try {
      final bitrateInt = int.parse(bitrate.toString());
      if (bitrateInt < 1000) return '$bitrateInt bps';
      if (bitrateInt < 1000000) return '${(bitrateInt / 1000).toStringAsFixed(1)} Kbps';
      return '${(bitrateInt / 1000000).toStringAsFixed(2)} Mbps';
    } catch (e) {
      return bitrate.toString();
    }
  }

  /// 构建 FFmpeg 压缩命令
  ///
  /// 保留完整元数据和流信息，确保保存回相册后显示正常：
  /// - `-map 0`: 复制所有流（视频、音频、字幕、章节等）
  /// - `-map_metadata 0`: 复制所有元数据
  /// - `-movflags use_metadata_tags`: 保留 MP4 元数据标签
  /// - 自动检测并使用原视频的编码格式（HEVC 保持 HEVC，H.264 保持 H.264）
  /// - 保留：GPS、拍摄时间、相机信息、方向、色彩空间等
  Future<String> _buildFfmpegCommand({
    required String inputPath,
    required String outputPath,
    required CompressionConfig config,
  }) async {
    // 视频编码参数
    final int crf = config.customCRF ?? 23;
    final int videoBitrate = config.customBitrate ?? 0; // 可选
    final bool keepFps = config.keepOriginalFrameRate;
    final double? customFps = config.customFrameRate;
    final int audioKbps = config.audioQuality;

    // 检测原视频编码格式
    final String? originalCodec = await _detectVideoCodec(inputPath);
    print('[视频编码] 原始编码: $originalCodec');

    // 根据原视频编码选择编码器
    final String videoCodec;
    final String videoTag;
    // 是否是 HEVC 编码
    final bool isHevc = originalCodec == 'hevc' || originalCodec == 'h265';

    if (isHevc) {
      // 原视频是 HEVC，保持 HEVC（支持 HDR）
      videoCodec = 'libx265';
      videoTag = 'hvc1'; // iOS HEVC 标签
      print('[编码器] 使用 HEVC (libx265) 保留 HDR');
    } else {
      // 原视频是 H.264 或其他，使用 H.264（兼容性最好）
      videoCodec = 'libx264';
      videoTag = 'avc1'; // iOS H.264 标签
      print('[编码器] 使用 H.264 (libx264)');
    }

    final List<String> args = [];
    args.addAll(['-y', '-hide_banner']);

    // ✅ 禁止自动旋转（保留原始方向元数据）
    args.addAll(['-noautorotate']);

    args.addAll(['-i', _q(inputPath)]);

    // ✅ 复制所有流（包括字幕、章节等）
    args.addAll(['-map', '0']);

    // ✅ 保留所有元数据
    args.addAll(['-map_metadata', '0']);
    args.addAll(['-map_metadata:s:v', '0:s:v']); // 保留视频流元数据
    args.addAll(['-map_metadata:s:a', '0:s:a']); // 保留音频流元数据

    // 视频编码
    args.addAll(['-c:v', videoCodec, '-preset', 'medium', '-crf', crf.toString()]);

    // ✅ 色彩空间处理
    if (isHevc) {
      // HEVC：不强制转换色彩空间，保留原始 HDR/SDR
      // FFmpeg 会自动保留原视频的色彩空间（bt2020/bt709）
      print('[色彩空间] 保留原始色彩空间（HDR/SDR）');
    } else {
      // H.264：强制使用 bt709（SDR），因为 H.264 不支持 HDR
      args.addAll(['-colorspace', 'bt709']);
      args.addAll(['-color_primaries', 'bt709']);
      args.addAll(['-color_trc', 'bt709']);
      print('[色彩空间] 使用 bt709 (SDR)');
    }

    if (videoBitrate > 0) {
      args.addAll(['-b:v', '${videoBitrate}k']);
    }
    if (!keepFps && customFps != null && customFps > 0) {
      args.addAll(['-r', customFps.toStringAsFixed(0)]);
    }

    // 音频编码
    args.addAll(['-c:a', 'aac', '-b:a', '${audioKbps}k', '-ac', '2']);

    // ✅ 保留字幕流（如果有）
    args.addAll(['-c:s', 'mov_text']);

    // ✅ iOS 兼容性优化
    args.addAll(['-tag:v', videoTag]); // 视频标签（avc1 或 hvc1）
    args.addAll(['-movflags', 'use_metadata_tags+faststart']); // 元数据 + 流式播放

    // 像素格式：HEVC 支持 10-bit，H.264 使用 8-bit
    if (isHevc) {
      // HEVC：保留原始像素格式（可能是 yuv420p10le for HDR）
      // FFmpeg 会自动选择合适的像素格式
    } else {
      // H.264：使用 yuv420p (8-bit)
      args.addAll(['-pix_fmt', 'yuv420p']);
    }

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
    final List<VideoCompressionInfo> updatedVideos = state.videos.map((video) {
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

    emit(state.copyWith(videos: updatedVideos));
  }

  void _failCurrentVideo(VideoCompressionInfo videoInfo, String message) {
    final List<VideoCompressionInfo> updatedVideos = state.videos.map((video) {
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

    emit(state.copyWith(videos: updatedVideos));
  }

  /// 更新视频压缩进度
  void _updateVideoProgress(String videoId, double progress, int remainingSeconds) {
    final updatedVideos = state.videos.map((video) {
      if (video.video.id == videoId) {
        return video.copyWith(
          progress: progress,
          estimatedTimeRemaining: remainingSeconds > 0 ? remainingSeconds : null,
        );
      }
      return video;
    }).toList();

    emit(state.copyWith(videos: updatedVideos));
  }

  /// 取消视频（包括下载和压缩）
  void cancelVideo(String videoId) {
    final video = state.videos.firstWhere((v) => v.video.id == videoId);

    if (video.status == VideoCompressionStatus.downloading) {
      // 取消下载：移除任务引用（Future 会自然完成或失败）
      _downloadTasks.remove(videoId);
      print('[取消下载] ${video.video.id}');
    } else if (video.status == VideoCompressionStatus.compressing) {
      // 取消压缩
      _progressTimer?.cancel();
      if (_isRunningSession) {
        FFmpegKit.cancel();
      }
      print('[取消压缩] ${video.video.id}');
    }

    _updateVideoStatus(
      videoId,
      VideoCompressionStatus.cancelled,
      progress: 0.0,
    );

    // 如果取消的是正在处理的，继续下一个
    if (video.status == VideoCompressionStatus.downloading || video.status == VideoCompressionStatus.compressing) {
      _processNextVideo();
    }
  }

  /// 重新压缩视频
  void retryVideo(String videoId) {
    final updatedVideos = state.videos.map((video) {
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

    emit(state.copyWith(videos: updatedVideos));

    // 如果当前没有正在压缩的视频，立即开始处理
    if (!state.hasActiveCompression) {
      _processNextVideo();
    }
  }

  /// 取消所有压缩
  void cancelAllCompression() {
    _progressTimer?.cancel();

    // 取消所有下载
    _downloadTasks.clear();

    // 取消 FFmpeg
    if (_isRunningSession) {
      FFmpegKit.cancel();
    }

    final updatedVideos = state.videos.map((video) {
      if (video.status == VideoCompressionStatus.waiting || video.status == VideoCompressionStatus.downloading || video.status == VideoCompressionStatus.compressing) {
        return video.copyWith(
          status: VideoCompressionStatus.cancelled,
          progress: 0.0,
          estimatedTimeRemaining: null,
        );
      }
      return video;
    }).toList();

    emit(state.copyWith(videos: updatedVideos));
  }

  /// 完成整个压缩任务
  void _completeTask() {
    final completedVideos = state.videos.where((v) => v.status == VideoCompressionStatus.completed).toList();
    final failedVideos = state.videos.where((v) => v.status == VideoCompressionStatus.error).toList();
    final cancelledVideos = state.videos.where((v) => v.status == VideoCompressionStatus.cancelled).toList();

    final totalOriginalSize = state.videos.fold(0, (sum, v) => sum + v.video.sizeBytes);
    final totalCompressedSize = completedVideos.fold(0, (sum, v) => sum + (v.compressedSize ?? 0));
    final totalSavings = totalOriginalSize - totalCompressedSize;

    print('========== 压缩任务完成 ==========');
    print('成功视频: ${completedVideos.length}');
    print('失败视频: ${failedVideos.length}');
    print('取消视频: ${cancelledVideos.length}');
    print('总视频数: ${state.videos.length}');
    print('原始总大小: ${_formatBytes(totalOriginalSize)}');
    if (totalCompressedSize > 0) {
      print('压缩后总大小: ${_formatBytes(totalCompressedSize)}');
      print('节省空间: ${_formatBytes(totalSavings)} (${((totalSavings / totalOriginalSize) * 100).toStringAsFixed(1)}%)');
    }
    print('=================================');
  }

  /// 调整视频在队列中的优先级
  void moveVideoInQueue(String videoId, int newIndex) {
    final videos = List<VideoCompressionInfo>.from(state.videos);
    final videoIndex = videos.indexWhere((v) => v.video.id == videoId);

    if (videoIndex != -1 && newIndex != videoIndex) {
      final video = videos.removeAt(videoIndex);
      videos.insert(newIndex, video);

      emit(state.copyWith(videos: videos));
    }
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
  String _formatBytes(int bytes) => formatFileSize(bytes);

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
