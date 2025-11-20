/// 压缩预设方案枚举
enum CompressionPreset {
  /// 高画质 - 保留尽可能高的质量
  highQuality(title: '高画质', description: '推荐'),

  /// 平衡模式 - 平衡文件大小和质量
  balance(title: '平衡模式', description: '文件大小与质量平衡'),

  /// 极限压缩 - 最小文件大小，可能损失一些质量
  extreme(title: '极限压缩', description: '适合分享');

  const CompressionPreset({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

/// 压缩配置模型
class CompressionConfig {
  final CompressionPreset preset;
  final int? targetWidth;
  final int? targetHeight;
  final int? crfValue; // Constant Rate Factor (0-51, 越低质量越好)
  final int? bitrate; // 比特率 (bps)

  const CompressionConfig({
    this.preset = CompressionPreset.balance,
    this.targetWidth,
    this.targetHeight,
    this.crfValue,
    this.bitrate,
  });

  /// 根据预设获取默认配置
  static CompressionConfig fromPreset(CompressionPreset preset) {
    switch (preset) {
      case CompressionPreset.highQuality:
        return const CompressionConfig(
          preset: CompressionPreset.highQuality,
          crfValue: 20,
        );
      case CompressionPreset.balance:
        return const CompressionConfig(
          preset: CompressionPreset.balance,
          crfValue: 23,
        );
      case CompressionPreset.extreme:
        return const CompressionConfig(
          preset: CompressionPreset.extreme,
          crfValue: 28,
        );
    }
  }

  CompressionConfig copyWith({
    CompressionPreset? preset,
    int? targetWidth,
    int? targetHeight,
    int? crfValue,
    int? bitrate,
  }) {
    return CompressionConfig(
      preset: preset ?? this.preset,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
      crfValue: crfValue ?? this.crfValue,
      bitrate: bitrate ?? this.bitrate,
    );
  }
}
