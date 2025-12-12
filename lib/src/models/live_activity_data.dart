/// Live Activity 数据模型
///
/// 用于在 Flutter 与 iOS Widget Extension 之间传递压缩进度数据。
class LiveActivityData {
  /// 当前压缩进度 (0.0 - 1.0)
  final double progress;

  /// 当前处理的视频索引 (1-based)
  final int currentIndex;

  /// 总视频数量
  final int totalCount;

  /// 预估剩余时间（秒）
  final int? remainingSeconds;

  /// 当前视频文件名
  final String? currentVideoName;

  /// 状态：downloading / compressing / completed / cancelled
  final String status;

  const LiveActivityData({
    required this.progress,
    required this.currentIndex,
    required this.totalCount,
    this.remainingSeconds,
    this.currentVideoName,
    required this.status,
  });

  /// 转换为 Map，用于传递给原生端
  Map<String, dynamic> toMap() => {
        'progress': progress,
        'currentIndex': currentIndex,
        'totalCount': totalCount,
        'remainingSeconds': remainingSeconds,
        'currentVideoName': currentVideoName,
        'status': status,
      };
}
