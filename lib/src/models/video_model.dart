import 'package:photo_manager/photo_manager.dart';

import '../utils/duration_utils.dart';

/// 视频数据模型 - 表示可压缩视频的核心信息
class VideoModel {
  /// 视频唯一标识符（来自相册系统的ID）
  final String id;

  /// 视频标题（文件名或用户设置的标题）
  final String title;

  /// 本地文件路径
  final String path;

  /// 视频时长（单位：秒）
  final double duration;

  /// 视频宽度（像素）
  final int width;

  /// 视频高度（像素）
  final int height;

  /// 文件大小（单位：字节）
  final int sizeBytes;

  /// 帧率（默认值30fps）
  final double frameRate;

  /// 创建时间
  final DateTime creationDate;

  /// 是否为 HDR 视频
  final bool isHDR;

  /// 是否为杜比视界视频
  final bool isDolbyVision;

  /// HDR 类型标识
  ///
  /// 可能的枚举值：
  /// - 'SDR': 标准动态范围视频 (Standard Dynamic Range)
  /// - 'HDR': 通用高动态范围视频标识
  /// - 'HDR10': HDR10 标准 (使用 ST.2084 PQ 传输函数)
  /// - 'HDR10+': HDR10+ 动态元数据标准
  /// - 'HLG': 混合对数伽马 HDR (Hybrid Log-Gamma)
  /// - 'Dolby Vision': 杜比视界 HDR 标准
  /// - 'HDR10/Possible DV': HDR10 但可能是杜比视界 (需进一步验证)
  ///
  /// 检测基于视频的传输函数和色彩空间元数据
  final String hdrType;

  /// 色彩空间信息
  ///
  /// 常见的色彩空间枚举值：
  /// - 'ITU_R_709': 标准高清电视色彩空间 (sRGB 相似)
  /// - 'ITU_R_2020': 超高清广色域色彩空间 (用于 4K/8K HDR)
  /// - 'SMPTE_C': SMPTE-C 色彩空间
  /// - 'EBU_3213': EBU 色彩空间标准
  /// - 'DCI_P3': 数字电影放映色彩空间
  /// - 'Display_P3': Apple 显示器 P3 广色域
  /// - 'P22': P22 磷光体
  /// - 'Generic_Film': 通用胶片色彩空间
  /// - 'Unknown': 未知或无法识别的色彩空间
  ///
  /// HDR 视频通常使用 ITU_R_2020，而普通视频使用 ITU_R_709
  final String colorSpace;

  /// 相册系统实体引用 - 用于获取缩略图等原生功能
  final AssetEntity? assetEntity;

  /// 是否在iCloud中（需要下载）
  final bool isInCloud;

  /// 是否本地可用（已下载到设备）
  final bool isLocallyAvailable;

  const VideoModel({
    required this.id,
    required this.title,
    required this.path,
    required this.duration,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.frameRate,
    required this.creationDate,
    this.isHDR = false,
    this.isDolbyVision = false,
    this.hdrType = 'SDR',
    this.colorSpace = 'Unknown',
    this.assetEntity,
    this.isInCloud = false,
    this.isLocallyAvailable = true,
  });

  /// 分辨率字符串，格式：宽度×高度（如1920×1080）
  String get resolution => '${width}x$height';

  /// 文件大小格式化显示（自动转换为B/KB/MB/GB）
  String get fileSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(sizeBytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  /// 格式化视频时长，根据时长自适应显示格式
  /// 小于1小时: mm:ss；≥1小时: hh:mm:ss
  String get formattedDuration {
    return DurationUtils.formatToClock(duration);
  }

  /// 获取分辨率级别（4K/1080p/720p等）+帧率描述
  String get resolutionAndFrameRate {
    String resolutionText;
    if (width >= 2160) {
      resolutionText = '4K'; // iPhone 4K (2160×3840)
    } else if (width >= 1920) {
      resolutionText = '1080p'; // iPhone 1080p (1920×1080)
    } else if (width >= 1280) {
      resolutionText = '720p'; // iPhone 720p (1280×720)
    } else {
      resolutionText = '${width}p';
    }

    return '$resolutionText/${frameRate.round()}fps';
  }

  /// 获取完整的视频规格描述（包含 HDR 信息）
  String get videoSpecification {
    String resolutionText;
    if (width >= 2160) {
      resolutionText = '4K';
    } else if (width >= 1920) {
      resolutionText = '1080p';
    } else if (width >= 1280) {
      resolutionText = '720p';
    } else {
      resolutionText = '${width}p';
    }

    final frameRateText = '${frameRate.round()}fps';

    // 如果是杜比视界视频，添加杜比视界标识
    if (isDolbyVision) {
      return '$resolutionText/$frameRateText 杜比视界';
    } else if (isHDR) {
      return '$resolutionText/$frameRateText HDR';
    } else {
      return '$resolutionText/$frameRateText';
    }
  }

  /// 获取 HDR 状态描述
  String get hdrDescription {
    if (isDolbyVision) {
      return 'Dolby Vision';
    } else if (isHDR) {
      return hdrType;
    } else {
      return 'SDR';
    }
  }

  /// 是否为高质量视频（HDR 或高帧率）
  bool get isHighQuality {
    return isHDR || frameRate >= 60;
  }

  /// 获取储存状态描述
  String get storageStatus {
    if (isInCloud && !isLocallyAvailable) {
      return '☁️ iCloud中';
    } else if (isInCloud && isLocallyAvailable) {
      return '📱 已下载';
    } else {
      return '📱 本地';
    }
  }

  /// 是否需要从iCloud下载
  bool get needsDownload {
    return isInCloud && !isLocallyAvailable;
  }

  /// 创建更新后的VideoModel副本
  VideoModel copyWith({
    String? id,
    String? title,
    String? path,
    double? duration,
    int? width,
    int? height,
    int? sizeBytes,
    double? frameRate,
    DateTime? creationDate,
    bool? isHDR,
    bool? isDolbyVision,
    String? hdrType,
    String? colorSpace,
    AssetEntity? assetEntity,
    bool? isInCloud,
    bool? isLocallyAvailable,
  }) {
    return VideoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      frameRate: frameRate ?? this.frameRate,
      creationDate: creationDate ?? this.creationDate,
      isHDR: isHDR ?? this.isHDR,
      isDolbyVision: isDolbyVision ?? this.isDolbyVision,
      hdrType: hdrType ?? this.hdrType,
      colorSpace: colorSpace ?? this.colorSpace,
      assetEntity: assetEntity ?? this.assetEntity,
      isInCloud: isInCloud ?? this.isInCloud,
      isLocallyAvailable: isLocallyAvailable ?? this.isLocallyAvailable,
    );
  }
}
