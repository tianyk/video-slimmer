class VideoModel {
  final String id;
  final String title;
  final String path;
  final double duration;
  final int width;
  final int height;
  final int sizeBytes;
  final double frameRate;
  final DateTime creationDate;
  final String thumbnailPath;
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
    required this.thumbnailPath,
    this.isSelected = false,
  });

  String get resolution => '${width}x$height';
  
  String get fileSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(sizeBytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get resolutionAndFrameRate {
    String resolutionText;
    if (width >= 3840) resolutionText = '4K';
    else if (width >= 1920) resolutionText = '1080p';
    else if (width >= 1280) resolutionText = '720p';
    else resolutionText = '${width}p';
    
    return '$resolutionText/${frameRate.round()}fps';
  }

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
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}