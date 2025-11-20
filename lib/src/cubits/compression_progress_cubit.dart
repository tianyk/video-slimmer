import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/media_information_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;
import 'package:photo_manager/photo_manager.dart';
import 'package:uuid/uuid.dart';

import '../libs/async_queue.dart';
import '../libs/logger.dart';
import '../models/compression_model.dart';
import '../models/compression_progress_model.dart';
import '../models/video_model.dart';
import '../utils.dart';

final _logger = Logger.getLogger();

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

  // 根据视频ID获取视频压缩信息
  VideoCompressionInfo getVideoCompressionInfoByVideoId(String videoId) {
    return videos.firstWhere(
      (v) => v.video.id == videoId,
      orElse: () => throw Exception('无法找到视频信息: $videoId'),
    );
  }

  /// 获取已完成的视频数量
  int get completedCount =>
      videos.where((v) => v.status == VideoCompressionStatus.completed).length;

  /// 是否所有视频都已处理
  bool get isAllProcessed {
    return videos.every((video) =>
        video.status == VideoCompressionStatus.completed ||
        video.status == VideoCompressionStatus.cancelled ||
        video.status == VideoCompressionStatus.error);
  }

  /// 是否有正在进行的压缩
  bool get hasActiveCompression =>
      videos.any((video) => video.status == VideoCompressionStatus.compressing);

  /// 计算总原始大小
  int get totalOriginalSize =>
      videos.fold(0, (sum, video) => sum + video.video.sizeBytes);

  /// 计算总压缩后大小
  int get totalCompressedSize => videos
      .where((video) => video.compressedSize != null)
      .fold(0, (sum, video) => sum + video.compressedSize!);

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
  // MethodChannel for iOS native API
  static const _platform = MethodChannel('cc.kekek.videoslimmer');
  // EventChannel for progress updates
  static const _progressChannel =
      EventChannel('cc.kekek.videoslimmer/progress');

  StreamSubscription? _progressSubscription;

  CompressionProgressCubit() : super(const CompressionProgressState()) {
    _listenToProgress();
  }

  /// 监听原生进度事件
  void _listenToProgress() {
    _progressSubscription = _progressChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final videoId = event['videoId'] as String?;
          final progress = event['progress'] as double?;

          if (videoId != null && progress != null) {
            _logger.debug('进度监听', {
              'videoId': videoId,
              'progress': '${(progress * 100).toStringAsFixed(1)}%',
            });
          }
        }
      },
      onError: (error) {
        _logger.error('进度监听错误', error: error);
      },
    );
  }

  /// 当前压缩配置
  CompressionConfig? _compressionConfig;

  // 压缩队列
  final AsyncQueue<String> _videoIdsToCompress = AsyncQueue();
  // 下载队列
  final AsyncQueue<String> _videoIdsToDownload = AsyncQueue();

// 是否正在处理视频压缩
  bool _isRunning = false;

  @override
  Future<void> close() {
    _isRunning = false;
    _videoIdsToCompress.clear();
    _videoIdsToDownload.clear();
    _progressSubscription?.cancel();
    return super.close();
  }

  /// 初始化压缩任务
  Future<void> initializeTask({
    required List<VideoModel> videos,
    required CompressionConfig config,
  }) async {
    _logger.info('开始初始化压缩任务', {'videoCount': videos.length});
    _compressionConfig = config;

    final videoInfos = await Future.wait(videos.map((video) async {
      final isLocallyAvailable = await isVideoLocallyAvailable(video.id);
      _logger.debug('视频信息', {
        'videoId': video.id,
        'locallyAvailable': isLocallyAvailable,
      });
      return VideoCompressionInfo(
        video: video,
        status: isLocallyAvailable
            ? VideoCompressionStatus.waiting
            : VideoCompressionStatus.waitingDownload,
        progress: 0.0,
      );
    }).toList());

    // 将需要压缩和下载的视频 ID 添加到队列中
    _videoIdsToCompress.addAll(videoInfos
        .where((info) => info.status == VideoCompressionStatus.waiting)
        .map((info) => info.video.id)
        .toList());
    _videoIdsToDownload.addAll(videoInfos
        .where((info) => info.status == VideoCompressionStatus.waitingDownload)
        .map((info) => info.video.id)
        .toList());

    emit(state.copyWith(videos: videoInfos));
  }

  /// 开始压缩任务
  void startCompression() {
    _logger.info('开始压缩任务');
    // 设置为正在处理
    _isRunning = true;

    // 调度所有需要下载的视频
    _scheduleDownloads();

    // 开始处理可压缩的视频
    _scheduleCompression();
  }

  /// 调度下载任务
  Future<void> _scheduleDownloads() async {
    while (_isRunning) {
      // 获取一个待下载的视频 ID
      final videoId = await _videoIdsToDownload.take();
      _logger.info('开始下载视频', {'videoId': videoId});
      try {
        final videoInfo = state.getVideoCompressionInfoByVideoId(videoId);
        // 如果视频状态为等待下载，则开始下载
        if (videoInfo.status == VideoCompressionStatus.waitingDownload) {
          // 更新视频状态为正在下载
          _updateVideoStatus(videoId, VideoCompressionStatus.downloading);
          // 获取视频文件路径，触发下载，下载完成后会自动更新视频状态为等待压缩
          await _ensureVideoFilePath(videoInfo.video.id);
          // 更新视频状态为等待压缩
          _updateVideoStatus(videoId, VideoCompressionStatus.waiting,
              progress: 0.0);
          _logger.info('下载视频完成', {'videoId': videoId});
          // 添加到压缩队列
          _videoIdsToCompress.add(videoId);
          _logger.debug('添加到压缩队列', {'videoId': videoId});
        }
      } catch (e) {
        _logger.error('处理下载任务失败', error: e, data: {'videoId': videoId});
        // 如果下载任务失败，则更新视频状态为错误
        _updateVideoStatus(videoId, VideoCompressionStatus.error,
            errorMessage: e.toString());
      }
    }
  }

  /// 调度压缩任务
  Future<void> _scheduleCompression() async {
    _logger.info('开始执行压缩任务');
    while (_isRunning) {
      final videoId = await _videoIdsToCompress.take();
      try {
        final videoInfo = state.getVideoCompressionInfoByVideoId(videoId);
        if (videoInfo.status == VideoCompressionStatus.waiting) {
          // 更新视频状态为正在压缩
          _updateVideoStatus(videoId, VideoCompressionStatus.compressing);
          // 开始压缩视频
          final outputPath = await _runFfmpegForVideo(videoInfo);
          // 获取压缩后文件大小
          final compressedSize = await _readFileSize(outputPath);
          _logger.debug('压缩后文件大小', {
            'videoId': videoId,
            'outputPath': outputPath,
            'compressedSize': compressedSize
          });

          // 更新视频状态为已完成
          _updateVideoStatus(videoId, VideoCompressionStatus.completed,
              progress: 1.0,
              outputPath: outputPath,
              compressedSize: compressedSize);
        }
      } catch (e) {
        _logger.error('处理视频压缩失败', error: e, data: {'videoId': videoId});
        if (e is Exception && e.toString() == 'canceled') {
          // 如果处理被取消，则更新视频状态为已取消
          // 这里不更新状态，取消时直接更新状态，避免重复更新
          // _updateVideoStatus(videoId, VideoCompressionStatus.cancelled);
        } else {
          // 如果处理失败，则更新视频状态为错误
          _updateVideoStatus(videoId, VideoCompressionStatus.error,
              errorMessage: e.toString());
        }
      }
    }
  }

  /// 辅助方法：更新视频状态
  void _updateVideoStatus(
    String videoId,
    VideoCompressionStatus status, {
    double? progress,
    String? errorMessage,
    String? outputPath,
    int? compressedSize,
  }) {
    _logger.debug('更新视频状态', {
      'videoId': videoId,
      'status': status.toString(),
      'outputPath': outputPath,
      'compressedSize': compressedSize,
    });

    final updatedVideos = state.videos.map((v) {
      if (v.video.id == videoId) {
        final updated = v.copyWith(
          status: status,
          progress: progress ?? v.progress,
          errorMessage: errorMessage ?? v.errorMessage,
          outputPath: outputPath ?? v.outputPath,
          compressedSize: compressedSize ?? v.compressedSize,
        );

        return updated;
      }
      return v;
    }).toList();

    emit(state.copyWith(videos: updatedVideos));
  }

  /// 调用原生方法获取视频文件路径
  ///
  /// 此方法封装了与 iOS 原生代码的通信逻辑
  ///
  /// 参数：
  /// - videoId: PHAsset 的 localIdentifier
  ///
  /// 返回：
  /// - 视频文件的绝对路径
  ///
  /// 异常：
  /// - PlatformException: 原生方法调用失败
  /// - Exception: 其他错误
  Future<String> _getVideoFilePath(String videoId) async {
    try {
      final filePath = await _platform.invokeMethod<String>(
        'getVideoFilePath',
        {'assetId': videoId},
      );

      if (filePath == null || filePath.isEmpty) {
        throw Exception('原生方法返回空路径');
      }

      return filePath;
    } on PlatformException catch (e) {
      throw Exception('[${e.code}] ${e.message}');
    }
  }

  /// 获取视频文件路径（统一入口）
  ///
  /// 工作流程：
  /// 1. 从 state.videos 中查找对应视频的 originalFilePath
  /// 2. 如果已缓存，直接返回（避免重复调用）
  /// 3. 如果未缓存，通过原生方法获取文件路径
  /// 4. 验证文件是否存在
  /// 5. 将获取到的路径保存到 state.videos 中，供后续使用
  ///
  /// 原生方法的优势：
  /// - 智能处理本地和 iCloud 视频
  /// - 支持下载进度回调
  /// - 保留完整的视频元数据
  /// - 直接返回文件路径，无需复制
  ///
  /// 注意事项：
  /// - 对于 iCloud 视频，会触发下载（可能耗时较长）
  /// - 如果网络不可用且视频在 iCloud，会抛出错误
  /// - 方法内部会自动更新 state，调用者无需手动更新 originalFilePath
  ///
  /// 参数：
  /// - videoId: 视频的唯一标识符
  ///
  /// 返回：
  /// - 视频文件的绝对路径，如果已缓存则立即返回，否则获取后返回
  Future<String> _ensureVideoFilePath(String videoId) async {
    // 从 state.videos 中查找缓存的路径
    final videoInfo = state.getVideoCompressionInfoByVideoId(videoId);

    // 如果已有缓存路径，直接返回
    if (videoInfo.originalFilePath != null) {
      return videoInfo.originalFilePath!;
    }

    _logger.debug('获取视频文件路径', {'videoId': videoId});
    // 调用原生方法获取视频文件路径
    final filePath = await _getVideoFilePath(videoId);
    _logger.info('成功获取文件路径', {'videoId': videoId, 'filePath': filePath});

    // 验证文件是否存在
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }

    // 更新 state.videos 中的原始文件路径
    final updatedVideos = state.videos.map((v) {
      if (v.video.id == videoId) {
        return v.copyWith(originalFilePath: filePath);
      }
      return v;
    }).toList();
    emit(state.copyWith(videos: updatedVideos));

    return filePath;
  }

  /// 使用 FFmpegKit 压缩单个视频
  Future<String> _runFfmpegForVideo(VideoCompressionInfo videoInfo) async {
    // 创建Completer，用于等待压缩完成
    final Completer<String> completer = Completer<String>();

    try {
      if (_compressionConfig == null) throw Exception('无有效的压缩配置');

      // 从 videoId 获取文件路径
      final inputPath = await _ensureVideoFilePath(videoInfo.video.id);

      // 构建输出文件路径
      final String outputPath = await _buildOutputPath(inputPath);
      _logger.info('开始压缩视频', {
        'videoId': videoInfo.video.id,
        'inputPath': inputPath,
        'outputPath': outputPath,
      });

      final String command = await _buildFfmpegCommand(
        inputPath: inputPath,
        outputPath: outputPath,
        config: _compressionConfig!,
      );

      _logger.debug('FFmpeg命令', {'command': command});

      // 运行FFmpeg，并追踪进度
      final session = await FFmpegKit.executeAsync(
        command,
        (session) async {
          try {
            final ReturnCode? returnCode = await session.getReturnCode();
            if (ReturnCode.isSuccess(returnCode)) {
              _logger.info('压缩成功', {
                'videoId': videoInfo.video.id,
                'originalSize': videoInfo.video.fileSize,
                'outputPath': outputPath,
              });

              if (!completer.isCompleted) {
                completer.complete(outputPath);
              }
            } else if (ReturnCode.isCancel(returnCode)) {
              _logger.warning('压缩被取消', {'videoId': videoInfo.video.id});
              if (!completer.isCompleted) {
                completer.completeError(Exception('canceled'));
              }
            } else {
              final String logs =
                  (await session.getAllLogsAsString()) ?? '未知错误';
              _logger.error('压缩失败', data: {
                'videoId': videoInfo.video.id,
                'returnCode': returnCode?.getValue(),
                'logs': logs,
              });

              if (!completer.isCompleted) {
                completer.completeError(
                    Exception('压缩失败: ${returnCode?.getValue()}'));
              }
            }
          } catch (e) {
            _logger.error('FFmpeg回调异常',
                error: e, data: {'videoId': videoInfo.video.id});
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          }
        },
        (log) {
          // FFmpeg 日志输出
          final String logMessage = log.getMessage();
          final int logLevel = log.getLevel();
          final String levelStr = _getLogLevelString(logLevel);
          _logger.debug('FFmpeg日志', {'level': levelStr, 'message': logMessage});
        },
        (Statistics statistics) {
          // ========== FFmpeg 统计信息回调 ==========
          // 已处理的视频时长（单位：毫秒）
          // 注意：这是视频内容的时长，不是实际消耗的时钟时间
          final int timeMs = statistics.getTime();

          // 视频总时长（单位：毫秒）
          final double totalMs = max(videoInfo.video.duration * 1000.0, 1.0);

          // 压缩进度（0.0 - 1.0）
          // 计算公式：已处理时长 / 总时长
          final double progress = (timeMs / totalMs).clamp(0.0, 1.0);

          // FFmpeg 处理速度倍率（例如：1.5x 表示处理速度是实时播放速度的 1.5 倍）
          // 用于计算预估剩余时间
          final double speed = statistics.getSpeed();

          // 预估剩余时间
          // 计算公式：剩余视频时长 / 处理速度
          // 例如：还剩 30 秒视频，处理速度 1.5x，则需要 30/1.5 = 20 秒实际时间
          final Duration remaining = speed > 0
              ? Duration(milliseconds: ((totalMs - timeMs) / speed).round())
              : Duration.zero;

          _logger.debug('FFmpeg统计', {
            'progress': '${(progress * 100).toStringAsFixed(1)}%',
            'time':
                '${(timeMs / 1000).toStringAsFixed(1)}s/${(totalMs / 1000).toStringAsFixed(1)}s',
            'speed': '${speed.toStringAsFixed(1)}x',
            'remaining': '${remaining.inMinutes}分${remaining.inSeconds % 60}秒',
          });

          _updateVideoProgress(
              videoInfo.video.id, progress, remaining.inSeconds);
        },
      );

      _logger.info('创建压缩会话', {
        'sessionId': session.getSessionId(),
        'videoId': videoInfo.video.id,
      });
      _updateVideoSessionId(videoInfo.video.id, session.getSessionId() ?? 0);
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }
    return completer.future;
  }

  /// 构建输出文件路径
  ///
  /// 使用 UUID 生成唯一文件名，保留原视频的文件扩展名。
  /// 例如：
  /// - 原视频：'/path/to/IMG_1234.MOV' → '/tmp/xxx/a3f2b1c4-5d6e-7f8a-9b0c-1d2e3f4a5b6c.MOV'
  /// - 原视频：'/path/to/video.mp4' → '/tmp/xxx/b4c3d2e1-6f7a-8b9c-0d1e-2f3a4b5c6d7e.mp4'
  Future<String> _buildOutputPath(String inputPath) async {
    final Directory dir =
        await Directory.systemTemp.createTemp('video_compression_');

    // 使用 path 包提取扩展名（包含点号，如 '.mov'）
    String ext = path.extension(inputPath);
    // 使用 UUID 生成唯一文件名，保留原扩展名
    const uuid = Uuid();
    final String fileName = '${uuid.v4()}${ext.isNotEmpty ? ext : '.mp4'}';

    return '${dir.path}/$fileName';
  }

  /// 检查是否应该使用硬件加速
  ///
  /// 对于 iOS 14+，VideoToolbox 硬件加速是系统级支持，无需复杂检测
  ///
  /// 返回值：
  /// - iOS/macOS: 始终返回 true（iOS 14+ 所有设备都支持）
  /// - 其他平台: 返回 false
  bool _shouldUseHardwareAcceleration() {
    return Platform.isIOS || Platform.isMacOS;
  }

  /// 检测原视频的编码格式
  ///
  /// 返回视频编码器名称，如 'hevc', 'h264', 'vp9' 等
  Future<String?> _detectVideoCodec(String videoPath) async {
    try {
      final MediaInformationSession session =
          await FFprobeKit.getMediaInformation(videoPath);
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
      _logger.warning('检测视频编码失败', {'error': e.toString()});
      return null;
    }
  }

  /// 获取视频元数据
  ///
  /// 使用 FFprobe 提取视频的完整元数据信息，返回结构化的 [VideoMetadata] 对象。
  ///
  /// 包含信息：
  /// - 文件基本信息（大小、格式、时长、码率）
  /// - 视频流信息（编码、分辨率、帧率、色彩空间）
  /// - 音频流信息（编码、采样率、声道数）
  /// - 元数据标签（GPS、拍摄时间、设备信息）
  ///
  /// 参数：
  /// - [videoPath]: 视频文件的绝对路径
  ///
  /// 返回值：
  /// - 成功：返回 [VideoMetadata] 对象
  /// - 失败：返回 null
  Future<VideoMetadata?> _getVideoMetadata(String videoPath) async {
    try {
      // 使用 FFprobe 获取媒体信息
      final MediaInformationSession session =
          await FFprobeKit.getMediaInformation(videoPath);
      final mediaInformation = session.getMediaInformation();

      if (mediaInformation == null) {
        return null;
      }

      // 文件基本信息
      final fileSize = await File(videoPath).length();
      final format = mediaInformation.getFormat();
      final durationStr = mediaInformation.getDuration();
      final bitrateStr = mediaInformation.getBitrate();

      final double? duration =
          durationStr != null ? double.tryParse(durationStr) : null;
      final int? bitrate = bitrateStr != null ? int.tryParse(bitrateStr) : null;

      // 解析流信息
      VideoStreamInfo? videoStream;
      AudioStreamInfo? audioStream;
      final streams = mediaInformation.getStreams();

      for (final stream in streams) {
        final props = stream.getAllProperties();
        final codecType = props?['codec_type'];

        if (codecType == 'video' && videoStream == null) {
          // 解析视频流
          videoStream = VideoStreamInfo(
            codecName: props?['codec_name'],
            width: props?['width'],
            height: props?['height'],
            frameRate: props?['r_frame_rate'],
            bitrate: props?['bit_rate'] != null
                ? int.tryParse(props!['bit_rate'].toString())
                : null,
            pixelFormat: props?['pix_fmt'],
            colorSpace: props?['color_space'],
            colorPrimaries: props?['color_primaries'],
            colorTransfer: props?['color_transfer'],
          );
        } else if (codecType == 'audio' && audioStream == null) {
          // 解析音频流
          audioStream = AudioStreamInfo(
            codecName: props?['codec_name'],
            sampleRate: props?['sample_rate'] != null
                ? int.tryParse(props!['sample_rate'].toString())
                : null,
            channels: props?['channels'],
            bitrate: props?['bit_rate'] != null
                ? int.tryParse(props!['bit_rate'].toString())
                : null,
          );
        }
      }

      // 解析元数据标签
      MetadataTags? tags;
      final rawTags = mediaInformation.getTags();
      if (rawTags != null && rawTags.isNotEmpty) {
        tags = MetadataTags(
          creationTime: rawTags['creation_time'] ??
              rawTags['com.apple.quicktime.creationdate'],
          location: rawTags['location'] ??
              rawTags['com.apple.quicktime.location.ISO6709'],
          make: rawTags['make'] ?? rawTags['com.apple.quicktime.make'],
          model: rawTags['model'] ?? rawTags['com.apple.quicktime.model'],
          software:
              rawTags['software'] ?? rawTags['com.apple.quicktime.software'],
          encoder: rawTags['encoder'],
          comment: rawTags['comment'],
        );
      }

      return VideoMetadata(
        filePath: videoPath,
        fileSize: fileSize,
        format: format,
        duration: duration,
        bitrate: bitrate,
        videoStream: videoStream,
        audioStream: audioStream,
        tags: tags,
      );
    } catch (e) {
      _logger.warning('获取视频元数据失败', {'error': e.toString()});
      return null;
    }
  }

  /// 构建优化后的 FFmpeg 压缩命令（iOS 专用）
  ///
  /// 改进点：
  /// - 修复原始编码检测逻辑错误
  /// - 精确保留元数据（GPS 位置、QuickTime keys）
  /// - 优化 VideoToolbox 参数（去掉不必要的 hwaccel_output_format）
  /// - 自动选择 .mov 输出容器（iOS 最兼容）
  /// - 保留 data streams（Dolby Vision 等 HDR 元数据）
  /// - 保留色彩空间信息（HDR 视频）
  Future<String> _buildFfmpegCommand({
    required String inputPath,
    required String outputPath,
    required CompressionConfig config,
  }) async {
    final int crf = config.customCRF ?? 23;
    final int videoBitrate = config.customBitrate ?? 0;
    final bool keepFps = config.keepOriginalFrameRate;
    final double? customFps = config.customFrameRate;
    final int audioKbps = config.audioQuality;

    // 检测原始编码格式
    final String? originalCodec = await _detectVideoCodec(inputPath);
    _logger.debug('视频编码信息', {'originalCodec': originalCodec});

    // 检测色彩空间信息（用于 HDR 视频）
    final VideoMetadata? metadata = await _getVideoMetadata(inputPath);
    final String? colorSpace = metadata?.videoStream?.colorSpace;
    final String? colorPrimaries = metadata?.videoStream?.colorPrimaries;
    final String? colorTransfer = metadata?.videoStream?.colorTransfer;
    final bool isHdrVideo = colorSpace == 'bt2020nc' ||
        colorTransfer == 'arib-std-b67' ||
        colorTransfer == 'smpte2084';

    if (isHdrVideo) {
      _logger.info('检测到HDR视频', {
        'colorSpace': colorSpace,
        'colorPrimaries': colorPrimaries,
        'colorTransfer': colorTransfer,
      });
    }

    final bool isHevc = originalCodec?.contains('hevc') == true ||
        originalCodec?.contains('h265') == true;
    final bool useHardwareAcceleration = _shouldUseHardwareAcceleration();

    // 根据编码格式选择编码器与标签
    final String videoCodec;
    final String videoTag;

    if (isHevc) {
      if (useHardwareAcceleration) {
        videoCodec = 'hevc_videotoolbox';
        _logger.debug('使用HEVC硬件编码', {'codec': 'hevc_videotoolbox'});
      } else {
        videoCodec = 'libx265';
        _logger.debug('使用HEVC软件编码', {'codec': 'libx265'});
      }
      videoTag = 'hvc1';
    } else {
      if (useHardwareAcceleration) {
        videoCodec = 'h264_videotoolbox';
        _logger.debug('使用H.264硬件编码', {'codec': 'h264_videotoolbox'});
      } else {
        videoCodec = 'libx264';
        _logger.debug('使用H.264软件编码', {'codec': 'libx264'});
      }
      videoTag = 'avc1';
    }

    final List<String> args = [];

    // === 全局参数 ===
    args.addAll(['-y', '-hide_banner']);

    // === 硬件加速 ===
    if (useHardwareAcceleration) {
      args.addAll(['-hwaccel', 'videotoolbox']);
      _logger.debug('硬件加速已启用', {'type': 'VideoToolbox'});
    }

    // === 容错设置 ===
    args.addAll(['-err_detect', 'ignore_err', '-strict', 'experimental']);

    // === 输入 ===
    args.addAll(['-i', _q(inputPath)]);

    // === 流映射 ===
    // 映射视频流、音频流，并尝试保留 data streams（包含 Dolby Vision 等 HDR 元数据）
    args.addAll([
      '-map', '0:v:0',
      '-map', '0:a:0?',
      '-map', '0:d?', // 可选：复制 data streams（Dolby Vision 元数据）
    ]);

    // === 元数据保留 ===
    // 精确保留元数据，包括 GPS 位置信息（QuickTime location keys）
    args.addAll([
      '-map_metadata', '0', // 全局元数据（包含 QuickTime keys）
      '-map_metadata:s:v', '0:s:v', // 视频流元数据
      '-map_metadata:s:a', '0:s:a', // 音频流元数据
      '-map_chapters', '0', // 章节信息
    ]);

    // 显式保留 QuickTime 位置元数据
    if (metadata?.tags?.location != null) {
      final location = metadata!.tags!.location!;
      args.addAll([
        '-metadata',
        _q('location=$location'),
        '-metadata',
        _q('com.apple.quicktime.location.ISO6709=$location'),
      ]);
    }

    // 显式保留其他 QuickTime 元数据
    if (metadata?.tags?.creationTime != null) {
      args.addAll([
        '-metadata',
        _q('creation_time=${metadata!.tags!.creationTime}'),
      ]);
    }
    if (metadata?.tags?.make != null) {
      args.addAll([
        '-metadata',
        _q('make=${metadata!.tags!.make}'),
      ]);
    }
    if (metadata?.tags?.model != null) {
      args.addAll([
        '-metadata',
        _q('model=${metadata!.tags!.model}'),
      ]);
    }

    // 添加应用压缩标识元数据
    args.addAll([
      '-metadata',
      _q('encoder=VideoSlimmer'),
    ]);

    args.addAll([
      '-movflags', 'faststart', // 移除 use_metadata_tags，避免丢失 QuickTime 特定标签
    ]);

    // === 旋转元数据处理 ===
    // FFmpeg 已在解码时应用旋转矩阵，输出帧已是正确方向，清除旋转元数据避免重复旋转
    args.addAll([
      '-metadata:s:v:0',
      'rotate=0',
    ]);

    // === 视频编码 ===
    if (useHardwareAcceleration) {
      args.addAll([
        '-c:v', videoCodec,
        '-b:v', videoBitrate > 0 ? '${videoBitrate}k' : '0',
        '-quality', 'high', // 提高质量（realtime/medium/high）
      ]);

      // 对于 HDR 视频，尝试保留色彩空间信息
      // 注意：VideoToolbox 对 Dolby Vision 的支持有限，这里主要保留基础色彩参数
      if (isHdrVideo) {
        if (colorSpace != null) {
          args.addAll(['-colorspace', colorSpace]);
        }
        if (colorPrimaries != null) {
          args.addAll(['-color_primaries', colorPrimaries]);
        }
        if (colorTransfer != null) {
          args.addAll(['-color_trc', colorTransfer]);
        }
        // 保留 TV range（limited range）
        args.addAll(['-color_range', 'tv']);
        _logger.debug('已添加HDR色彩空间参数');
      }
    } else {
      args.addAll([
        '-c:v',
        videoCodec,
        '-preset',
        'medium',
        '-crf',
        crf.toString(),
      ]);
      if (videoBitrate > 0) {
        args.addAll([
          '-maxrate',
          '${videoBitrate}k',
          '-bufsize',
          '${videoBitrate * 2}k',
        ]);
      }
    }

    // === 色彩空间处理 ===
    if (isHevc && !useHardwareAcceleration) {
      args.addAll([
        '-x265-params', 'hdr-opt=1:repeat-headers=1', // 自动保留 HDR
      ]);
    } else if (!isHevc && !useHardwareAcceleration) {
      args.addAll([
        '-colorspace',
        'bt709',
        '-color_primaries',
        'bt709',
        '-color_trc',
        'bt709',
        '-pix_fmt',
        'yuv420p',
      ]);
    }

    // === 帧率控制 ===
    if (!keepFps && customFps != null && customFps > 0) {
      args.addAll(['-r', customFps.toStringAsFixed(0)]);
    }

    // === 音频编码 ===
    args.addAll([
      '-c:a',
      'aac',
      '-b:a',
      '${audioKbps}k',
      '-ac',
      '2',
    ]);

    // === 标签与封装 ===
    args.addAll([
      '-tag:v', videoTag,
      '-f', 'mov', // 强制使用 mov 容器，iOS 相册最兼容
    ]);

    // === 输出 ===
    args.add(_q(outputPath));

    final command = args.join(' ');
    _logger.debug('构建FFmpeg命令完成', {'command': command});
    return command;
  }

  String _q(String path) => '"$path"';

  /// 读取文件大小
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

  /// 更新视频压缩进度
  void _updateVideoProgress(
      String videoId, double progress, int remainingSeconds) {
    final updatedVideos = state.videos.map((video) {
      if (video.video.id == videoId) {
        return video.copyWith(
          progress: progress,
          estimatedTimeRemaining:
              remainingSeconds > 0 ? remainingSeconds : null,
        );
      }
      return video;
    }).toList();

    emit(state.copyWith(videos: updatedVideos));
  }

  /// 更新视频会话 ID
  void _updateVideoSessionId(String videoId, int sessionId) {
    final updatedVideos = state.videos.map((video) {
      if (video.video.id == videoId) {
        return video.copyWith(sessionId: sessionId);
      }
      return video;
    }).toList();
    emit(state.copyWith(videos: updatedVideos));
  }

  /// 取消视频（包括下载和压缩）
  void cancelVideo(String videoId) {
    final video = state.getVideoCompressionInfoByVideoId(videoId);

    if (video.status == VideoCompressionStatus.waitingDownload) {
      _logger.info('取消排队下载', {'videoId': video.video.id});
      // 从下载队列中移除视频ID
      _videoIdsToDownload.remove(videoId);
    } else if (video.status == VideoCompressionStatus.downloading) {
      _logger.info('取消正在下载', {'videoId': video.video.id});
    } else if (video.status == VideoCompressionStatus.compressing) {
      FFmpegKit.cancel(video.sessionId);
      _logger.info('取消正在压缩', {'videoId': video.video.id});
    } else if (video.status == VideoCompressionStatus.waiting) {
      _logger.info('取消排队压缩', {'videoId': video.video.id});
      // 从压缩队列中移除视频ID
      _videoIdsToCompress.remove(videoId);
    }

    // 更新视频状态为已取消
    _updateVideoStatus(
      videoId,
      VideoCompressionStatus.cancelled,
      progress: 0.0,
    );
  }

  /// 重新压缩视频
  Future<void> retryVideo(String videoId) async {
    final isLocallyAvailable = await isVideoLocallyAvailable(videoId);

    final updatedVideos = state.videos.map((video) {
      if (video.video.id == videoId) {
        // 根据视频是否已下载，决定重置为等待下载还是等待压缩状态
        final VideoCompressionStatus newStatus = isLocallyAvailable
            ? VideoCompressionStatus.waiting
            : VideoCompressionStatus.waitingDownload;

        return video.copyWith(
          status: newStatus,
          progress: 0.0,
          sessionId: null,
          errorMessage: null,
          estimatedTimeRemaining: null,
          compressedSize: null,
          outputPath: null,
        );
      }
      return video;
    }).toList();

    emit(state.copyWith(videos: updatedVideos));

    // 根据视频是否已下载，添加到相应的队列
    if (isLocallyAvailable) {
      // 已下载，添加到压缩队列
      _videoIdsToCompress.add(videoId);
    } else {
      // 未下载，添加到下载队列
      _videoIdsToDownload.add(videoId);
    }
  }

  /// 取消所有压缩
  void cancelAllCompression() {
    // 取消所有 FFmpeg 会话
    FFmpegKit.cancel();

    // 清空队列
    _videoIdsToCompress.clear();
    _videoIdsToDownload.clear();

    final updatedVideos = state.videos.map((video) {
      if (video.status == VideoCompressionStatus.waiting ||
          video.status == VideoCompressionStatus.downloading ||
          video.status == VideoCompressionStatus.compressing) {
        return video.copyWith(
          status: VideoCompressionStatus.cancelled,
          progress: 0.0,
          estimatedTimeRemaining: null,
          sessionId: null,
          errorMessage: null,
          outputPath: null,
          compressedSize: null,
        );
      }
      return video;
    }).toList();

    emit(state.copyWith(videos: updatedVideos));
  }

  /// 保存视频到相册
  Future<void> saveVideoToPhotos(VideoCompressionInfo videoInfo) async {
    if (videoInfo.outputPath == null) {
      _logger.warning('无法保存视频：输出路径为空', {'videoId': videoInfo.video.id});
      throw Exception('无法保存视频：输出路径为空');
    }

    try {
      // 1. 请求相册权限
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) {
        _logger.warning('用户拒绝相册权限', {'videoId': videoInfo.video.id});
        throw Exception('需要相册权限才能保存视频');
      }

      // 2. 构建新文件名：原始文件名 + _compressed 后缀
      String newTitle;
      if (videoInfo.video.title.isNotEmpty &&
          videoInfo.video.title != 'unknown') {
        // 移除扩展名（如 .MOV、.mp4）
        final originalFilename = videoInfo.video.title;
        final nameWithoutExt = originalFilename.split('.').first;
        // 添加 _compressed 后缀，如 IMG_0001_compressed
        newTitle = '${nameWithoutExt}_compressed';
      } else {
        // 如果无法获取原始文件名，使用时间戳
        newTitle = 'compressed_${DateTime.now().millisecondsSinceEpoch}';
      }

      // 3. 检查文件是否存在
      final file = File(videoInfo.outputPath!);
      if (!await file.exists()) {
        throw Exception('视频文件不存在: ${videoInfo.outputPath}');
      }

      // 4. 使用 PhotoManager 保存视频到相册
      final assetEntity = await PhotoManager.editor.saveVideo(
        file,
        title: newTitle,
      );

      _logger.info('视频已保存到相册', {
        'videoId': videoInfo.video.id,
        'assetId': assetEntity.id,
        'title': newTitle,
      });
    } catch (e, stackTrace) {
      _logger.error(
        '保存视频到相册失败',
        error: e,
        stackTrace: stackTrace,
        data: {'videoId': videoInfo.video.id},
      );
      rethrow;
    }
  }

  /// 删除原始视频（系统会将其移动到相册的“最近删除”中）
  Future<void> deleteOriginalVideo(VideoCompressionInfo videoInfo) async {
    try {
      final PermissionState permissionState =
          await PhotoManager.requestPermissionExtend();
      if (!permissionState.hasAccess) {
        _logger.warning('删除原视频失败：无相册权限', {
          'videoId': videoInfo.video.id,
        });
        throw Exception('需要相册权限才能删除原视频');
      }

      _logger.info('开始删除原视频（移动到最近删除）', {
        'videoId': videoInfo.video.id,
      });

      final List<String> deletedIds =
          await PhotoManager.editor.deleteWithIds(<String>[videoInfo.video.id]);
      if (deletedIds.isEmpty) {
        throw Exception('系统未能删除原视频');
      }
    } catch (e, stackTrace) {
      _logger.error(
        '删除原视频时发生错误',
        error: e,
        stackTrace: stackTrace,
        data: {'videoId': videoInfo.video.id},
      );
      rethrow;
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
}
