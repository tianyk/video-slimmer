import 'package:photo_manager/photo_manager.dart';

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

  /// 相册系统实体引用 - 用于获取缩略图等原生功能
  final AssetEntity? assetEntity;

  /// 选择状态（在列表中是否被选中）
  bool isSelected;

  VideoModel({
    required this.id,
    required this.title,
    required this.path,
    required this.duration,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.frameRate,
    required this.creationDate,
    this.assetEntity,
    this.isSelected = false,
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
    final totalSeconds = duration.round();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// 获取分辨率级别（4K/1080p/720p等）+帧率描述
  String get resolutionAndFrameRate {
    String resolutionText;
    if (width >= 3840) {
      resolutionText = '4K';
    } else if (width >= 1920) {
      resolutionText = '1080p';
    } else if (width >= 1280) {
      resolutionText = '720p';
    } else {
      resolutionText = '${width}p';
    }

    return '$resolutionText/${frameRate.round()}fps';
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
    String? thumbnailPath,
    AssetEntity? assetEntity,
    bool? isSelected,
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
      assetEntity: assetEntity ?? this.assetEntity,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
