import '../libs/localization.dart';
import '../utils.dart';

/// 压缩配置模型 - 定义视频压缩的各种参数
class CompressionConfig {
  /// 压缩预设类型
  final CompressionPreset preset;

  /// 自定义分辨率 (当preset为custom时使用)
  final VideoResolution? customResolution;

  /// 自定义质量参数 (当preset为custom时使用)
  /// CRF值: 18-28 (18最高质量，28较低质量但文件更小)
  final int? customCRF;

  /// 自定义码率 (kbps)
  final int? customBitrate;

  /// 是否保持原始帧率
  final bool keepOriginalFrameRate;

  /// 自定义帧率 (当keepOriginalFrameRate为false时使用)
  final double? customFrameRate;

  /// 是否保持原始音频
  final bool keepOriginalAudio;

  /// 音频质量 (kbps)
  final int audioQuality;

  /// 压缩后预估大小 (字节)
  final int? estimatedSize;

  /// 预估压缩比例 (0.0-1.0)
  final double? estimatedCompressionRatio;

  const CompressionConfig({
    this.preset = CompressionPreset.highQuality,
    this.customResolution,
    this.customCRF,
    this.customBitrate,
    this.keepOriginalFrameRate = true,
    this.customFrameRate,
    this.keepOriginalAudio = true,
    this.audioQuality = 128,
    this.estimatedSize,
    this.estimatedCompressionRatio,
  });

  CompressionConfig copyWith({
    CompressionPreset? preset,
    VideoResolution? customResolution,
    int? customCRF,
    int? customBitrate,
    bool? keepOriginalFrameRate,
    double? customFrameRate,
    bool? keepOriginalAudio,
    int? audioQuality,
    int? estimatedSize,
    double? estimatedCompressionRatio,
  }) {
    return CompressionConfig(
      preset: preset ?? this.preset,
      customResolution: customResolution ?? this.customResolution,
      customCRF: customCRF ?? this.customCRF,
      customBitrate: customBitrate ?? this.customBitrate,
      keepOriginalFrameRate:
          keepOriginalFrameRate ?? this.keepOriginalFrameRate,
      customFrameRate: customFrameRate ?? this.customFrameRate,
      keepOriginalAudio: keepOriginalAudio ?? this.keepOriginalAudio,
      audioQuality: audioQuality ?? this.audioQuality,
      estimatedSize: estimatedSize ?? this.estimatedSize,
      estimatedCompressionRatio:
          estimatedCompressionRatio ?? this.estimatedCompressionRatio,
    );
  }

  /// 获取显示名称
  String get displayName {
    switch (preset) {
      case CompressionPreset.highQuality:
        return tr('高画质');
      case CompressionPreset.balanced:
        return tr('平衡模式');
      case CompressionPreset.maxCompression:
        return tr('极限压缩');
    }
  }

  /// 获取描述信息
  String get description {
    switch (preset) {
      case CompressionPreset.highQuality:
        return tr('推荐 • 保持高画质，适度压缩');
      case CompressionPreset.balanced:
        return tr('画质与文件大小平衡');
      case CompressionPreset.maxCompression:
        return tr('适合分享 • 最大化压缩');
    }
  }

  /// 格式化预估大小显示
  String get formattedEstimatedSize {
    if (estimatedSize == null) return tr('计算中...');
    return formatFileSize(estimatedSize!);
  }

  /// 格式化压缩比例显示
  String get formattedCompressionRatio {
    if (estimatedCompressionRatio == null) return tr('计算中...');
    return '${(estimatedCompressionRatio! * 100).toStringAsFixed(0)}%';
  }
}

/// 压缩预设枚举
enum CompressionPreset {
  /// 高画质模式 - 保持较高画质，适度压缩
  highQuality,

  /// 平衡模式 - 画质与文件大小平衡
  balanced,

  /// 极限压缩 - 最大化压缩，适合分享
  maxCompression,
}

/// 视频分辨率枚举
enum VideoResolution {
  /// 保持原始分辨率
  original,

  /// 4K (3840×2160)
  uhd4k,

  /// 1080p (1920×1080)
  fullHd,

  /// 720p (1280×720)
  hd,

  /// 480p (854×480)
  sd;

  /// 获取分辨率显示名称
  String get displayName {
    switch (this) {
      case VideoResolution.original:
        return tr('保持原始');
      case VideoResolution.uhd4k:
        return '4K (3840×2160)';
      case VideoResolution.fullHd:
        return '1080p (1920×1080)';
      case VideoResolution.hd:
        return '720p (1280×720)';
      case VideoResolution.sd:
        return '480p (854×480)';
    }
  }

  /// 获取宽度
  int? get width {
    switch (this) {
      case VideoResolution.original:
        return null;
      case VideoResolution.uhd4k:
        return 3840;
      case VideoResolution.fullHd:
        return 1920;
      case VideoResolution.hd:
        return 1280;
      case VideoResolution.sd:
        return 854;
    }
  }

  /// 获取高度
  int? get height {
    switch (this) {
      case VideoResolution.original:
        return null;
      case VideoResolution.uhd4k:
        return 2160;
      case VideoResolution.fullHd:
        return 1080;
      case VideoResolution.hd:
        return 720;
      case VideoResolution.sd:
        return 480;
    }
  }
}

/// 压缩预设参数配置
class CompressionPresetConfig {
  static CompressionConfig getPresetConfig(CompressionPreset preset) {
    switch (preset) {
      case CompressionPreset.highQuality:
        return const CompressionConfig(
          preset: CompressionPreset.highQuality,
          customCRF: 20,
          customBitrate: 8000,
          keepOriginalFrameRate: true,
          audioQuality: 192,
        );

      case CompressionPreset.balanced:
        return const CompressionConfig(
          preset: CompressionPreset.balanced,
          customCRF: 23,
          customBitrate: 4000,
          keepOriginalFrameRate: true,
          audioQuality: 128,
        );

      case CompressionPreset.maxCompression:
        return const CompressionConfig(
          preset: CompressionPreset.maxCompression,
          customCRF: 28,
          customBitrate: 1500,
          customFrameRate: 30,
          keepOriginalFrameRate: false,
          audioQuality: 96,
        );
    }
  }

  /// 根据原始视频信息估算压缩后大小
  static int estimateCompressedSize({
    required int originalSize,
    required CompressionConfig config,
    required double videoDuration,
    required int originalBitrate,
  }) {
    // 简化的估算算法
    double compressionFactor;

    switch (config.preset) {
      case CompressionPreset.highQuality:
        compressionFactor = 0.7; // 保留70%
        break;
      case CompressionPreset.balanced:
        compressionFactor = 0.4; // 保留40%
        break;
      case CompressionPreset.maxCompression:
        compressionFactor = 0.2; // 保留20%
        break;
    }

    return (originalSize * compressionFactor).round();
  }
}
