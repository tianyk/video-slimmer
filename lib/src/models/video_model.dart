import '../utils/duration_utils.dart';

/// 视频数据模型 - 表示可压缩视频的核心信息
class VideoModel {
  /// 视频唯一标识符（来自相册系统的ID）
  final String id;

  /// 视频时长（单位：秒）
  final double duration;

  /// 视频宽度（像素）
  final int width;

  /// 视频高度（像素）
  final int height;

  /// 文件大小（单位：字节）
  final int sizeBytes;

  /// 创建时间
  final DateTime creationDate;

  /// 是否本地可用（已下载到设备）
  final bool isLocallyAvailable;

  const VideoModel({
    required this.id,
    required this.duration,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.creationDate,
    this.isLocallyAvailable = true,
  });

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

  /// 获取视频规格描述
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

    return resolutionText;
  }

  /// 创建更新后的VideoModel副本
  VideoModel copyWith({
    String? id,
    double? duration,
    int? width,
    int? height,
    int? sizeBytes,
    DateTime? creationDate,
    bool? isLocallyAvailable,
  }) {
    return VideoModel(
      id: id ?? this.id,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      creationDate: creationDate ?? this.creationDate,
      isLocallyAvailable: isLocallyAvailable ?? this.isLocallyAvailable,
    );
  }
}
