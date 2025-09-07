import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/compression_model.dart';
import '../models/video_model.dart';

/// 压缩配置状态
class CompressionState extends Equatable {
  /// 当前压缩配置
  final CompressionConfig config;

  /// 选中的视频列表
  final List<VideoModel> selectedVideos;

  /// 是否正在计算预估大小
  final bool isCalculatingEstimate;

  /// 总原始大小 (字节)
  final int totalOriginalSize;

  /// 总预估压缩后大小 (字节)
  final int? totalEstimatedSize;

  /// 预估节省空间 (字节)
  final int? estimatedSavings;

  const CompressionState({
    this.config = const CompressionConfig(),
    this.selectedVideos = const [],
    this.isCalculatingEstimate = false,
    this.totalOriginalSize = 0,
    this.totalEstimatedSize,
    this.estimatedSavings,
  });

  CompressionState copyWith({
    CompressionConfig? config,
    List<VideoModel>? selectedVideos,
    bool? isCalculatingEstimate,
    int? totalOriginalSize,
    int? totalEstimatedSize,
    int? estimatedSavings,
  }) {
    return CompressionState(
      config: config ?? this.config,
      selectedVideos: selectedVideos ?? this.selectedVideos,
      isCalculatingEstimate:
          isCalculatingEstimate ?? this.isCalculatingEstimate,
      totalOriginalSize: totalOriginalSize ?? this.totalOriginalSize,
      totalEstimatedSize: totalEstimatedSize ?? this.totalEstimatedSize,
      estimatedSavings: estimatedSavings ?? this.estimatedSavings,
    );
  }

  /// 格式化原始大小显示
  String get formattedOriginalSize {
    if (totalOriginalSize < 1024) return '$totalOriginalSize B';
    if (totalOriginalSize < 1024 * 1024) {
      return '${(totalOriginalSize / 1024).toStringAsFixed(1)} KB';
    }
    if (totalOriginalSize < 1024 * 1024 * 1024) {
      return '${(totalOriginalSize / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(totalOriginalSize / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  /// 格式化预估大小显示
  String get formattedEstimatedSize {
    if (isCalculatingEstimate) return '计算中...';
    if (totalEstimatedSize == null) return '未知';

    final size = totalEstimatedSize!;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  /// 格式化节省空间显示
  String get formattedSavings {
    if (isCalculatingEstimate) return '计算中...';
    if (estimatedSavings == null) return '未知';

    final size = estimatedSavings!;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  /// 压缩比例百分比
  String get compressionPercentage {
    if (isCalculatingEstimate ||
        totalEstimatedSize == null ||
        totalOriginalSize == 0) {
      return '计算中...';
    }

    final ratio = (totalOriginalSize - totalEstimatedSize!) / totalOriginalSize;
    return '${(ratio * 100).toStringAsFixed(0)}%';
  }

  /// 是否可以开始压缩
  bool get canStartCompression {
    return selectedVideos.isNotEmpty && !isCalculatingEstimate;
  }

  @override
  List<Object?> get props => [
        config,
        selectedVideos,
        isCalculatingEstimate,
        totalOriginalSize,
        totalEstimatedSize,
        estimatedSavings,
      ];
}

/// 压缩配置状态管理
class CompressionCubit extends Cubit<CompressionState> {
  CompressionCubit() : super(const CompressionState());

  /// 初始化选中的视频
  void initializeWithVideos(List<VideoModel> videos) {
    final totalSize =
        videos.fold<int>(0, (sum, video) => sum + video.sizeBytes);

    emit(state.copyWith(
      selectedVideos: videos,
      totalOriginalSize: totalSize,
    ));

    // 自动计算预估大小
    _calculateEstimatedSize();
  }

  /// 设置压缩预设
  void setPreset(CompressionPreset preset) {
    final newConfig = CompressionPresetConfig.getPresetConfig(preset);

    emit(state.copyWith(
      config: newConfig,
    ));

    _calculateEstimatedSize();
  }

  /// 重置配置为默认平衡模式
  void resetToDefault() {
    setPreset(CompressionPreset.balanced);
  }

  /// 计算预估压缩大小
  void _calculateEstimatedSize() {
    emit(state.copyWith(isCalculatingEstimate: true));

    // 模拟异步计算过程
    Future.delayed(const Duration(milliseconds: 500), () {
      int totalEstimated = 0;

      for (final video in state.selectedVideos) {
        final estimatedSize = CompressionPresetConfig.estimateCompressedSize(
          originalSize: video.sizeBytes,
          config: state.config,
          videoDuration: video.duration,
          originalBitrate: _estimateOriginalBitrate(video),
        );
        totalEstimated += estimatedSize;
      }

      final savings = state.totalOriginalSize - totalEstimated;

      emit(state.copyWith(
        isCalculatingEstimate: false,
        totalEstimatedSize: totalEstimated,
        estimatedSavings: savings,
      ));
    });
  }

  /// 估算原始视频码率 (简化算法)
  int _estimateOriginalBitrate(VideoModel video) {
    // 基于文件大小和时长估算码率 (kbps)
    if (video.duration <= 0) return 5000; // 默认值

    final fileSizeKB = video.sizeBytes / 1024;
    final durationSeconds = video.duration;
    final estimatedKbps = (fileSizeKB * 8) / durationSeconds;

    return estimatedKbps.round();
  }

  /// 获取压缩任务配置信息
  Map<String, dynamic> getCompressionTaskInfo() {
    return {
      'videos': state.selectedVideos.map((v) => v.id).toList(),
      'config': {
        'preset': state.config.preset.name,
        'crf': state.config.customCRF,
        'bitrate': state.config.customBitrate,
        'resolution': state.config.customResolution?.name,
        'frameRate': state.config.keepOriginalFrameRate
            ? null
            : state.config.customFrameRate,
        'audioQuality': state.config.audioQuality,
        'keepOriginalAudio': state.config.keepOriginalAudio,
      },
      'estimatedOutputSize': state.totalEstimatedSize,
      'estimatedSavings': state.estimatedSavings,
    };
  }
}
