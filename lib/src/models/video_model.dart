import 'package:equatable/equatable.dart';

import '../utils.dart';

/// 视频元数据模型 - 从 FFprobe 提取的完整视频信息
class VideoMetadata {
  /// 文件路径
  final String filePath;

  /// 文件大小（字节）
  final int fileSize;

  /// 容器格式（mov, mp4, etc.）
  final String? format;

  /// 视频时长（秒）
  final double? duration;

  /// 总码率（bps）
  final int? bitrate;

  /// 视频流信息
  final VideoStreamInfo? videoStream;

  /// 音频流信息
  final AudioStreamInfo? audioStream;

  /// 元数据标签
  final MetadataTags? tags;

  const VideoMetadata({
    required this.filePath,
    required this.fileSize,
    this.format,
    this.duration,
    this.bitrate,
    this.videoStream,
    this.audioStream,
    this.tags,
  });

  /// 格式化文件大小
  String get formattedFileSize => formatFileSize(fileSize);

  /// 格式化时长
  String get formattedDuration {
    if (duration == null) return '未知';
    final minutes = (duration! / 60).floor();
    final seconds = (duration! % 60).floor();
    return '${minutes}分${seconds}秒';
  }

  /// 格式化码率
  String get formattedBitrate {
    if (bitrate == null) return '未知';
    if (bitrate! < 1000) return '$bitrate bps';
    if (bitrate! < 1000000) return '${(bitrate! / 1000).toStringAsFixed(1)} Kbps';
    return '${(bitrate! / 1000000).toStringAsFixed(2)} Mbps';
  }
}

/// 视频流信息
class VideoStreamInfo {
  /// 编码器名称（hevc, h264, etc.）
  final String? codecName;

  /// 视频宽度
  final int? width;

  /// 视频高度
  final int? height;

  /// 帧率（如 "30/1"）
  final String? frameRate;

  /// 码率（bps）
  final int? bitrate;

  /// 像素格式（yuv420p, yuv420p10le, etc.）
  final String? pixelFormat;

  /// 色彩空间（bt709, bt2020nc, etc.）
  final String? colorSpace;

  /// 色域（bt709, bt2020, etc.）
  final String? colorPrimaries;

  /// 传输特性（bt709, arib-std-b67, etc.）
  final String? colorTransfer;

  const VideoStreamInfo({
    this.codecName,
    this.width,
    this.height,
    this.frameRate,
    this.bitrate,
    this.pixelFormat,
    this.colorSpace,
    this.colorPrimaries,
    this.colorTransfer,
  });

  /// 格式化码率
  String get formattedBitrate {
    if (bitrate == null) return '未知';
    if (bitrate! < 1000) return '$bitrate bps';
    if (bitrate! < 1000000) return '${(bitrate! / 1000).toStringAsFixed(1)} Kbps';
    return '${(bitrate! / 1000000).toStringAsFixed(2)} Mbps';
  }
}

/// 音频流信息
class AudioStreamInfo {
  /// 编码器名称（aac, mp3, etc.）
  final String? codecName;

  /// 采样率（Hz）
  final int? sampleRate;

  /// 声道数
  final int? channels;

  /// 码率（bps）
  final int? bitrate;

  const AudioStreamInfo({
    this.codecName,
    this.sampleRate,
    this.channels,
    this.bitrate,
  });

  /// 格式化码率
  String get formattedBitrate {
    if (bitrate == null) return '未知';
    if (bitrate! < 1000) return '$bitrate bps';
    if (bitrate! < 1000000) return '${(bitrate! / 1000).toStringAsFixed(1)} Kbps';
    return '${(bitrate! / 1000000).toStringAsFixed(2)} Mbps';
  }
}

/// 元数据标签
class MetadataTags {
  /// 拍摄时间
  final String? creationTime;

  /// GPS 位置
  final String? location;

  /// 设备制造商
  final String? make;

  /// 设备型号
  final String? model;

  /// 软件版本
  final String? software;

  const MetadataTags({
    this.creationTime,
    this.location,
    this.make,
    this.model,
    this.software,
  });
}

/// 视频数据模型 - 表示可压缩视频的核心信息
class VideoModel extends Equatable {
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

  /// 原始文件名（如 IMG_0001.MOV）
  final String title;

  const VideoModel({
    required this.id,
    required this.duration,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.creationDate,
    required this.title,
  });

  /// 文件大小格式化显示（自动转换为B/KB/MB/GB）
  String get fileSize => formatFileSize(sizeBytes);

  /// 格式化视频时长，根据时长自适应显示格式
  /// 小于1小时: mm:ss；≥1小时: hh:mm:ss
  String get formattedDuration {
    return formatDurationToClock(duration);
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
    String? title,
  }) {
    return VideoModel(
      id: id ?? this.id,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      creationDate: creationDate ?? this.creationDate,
      title: title ?? this.title,
    );
  }

  @override
  List<Object?> get props => [
        id,
        duration,
        width,
        height,
        sizeBytes,
        creationDate,
        title,
      ];
}
