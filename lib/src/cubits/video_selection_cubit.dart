import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

/// 视频选择状态
class VideoSelectionState extends Equatable {
  /// 已选择的视频ID集合
  final Set<String> selectedVideoIds;

  /// 已选择视频的总大小（字节）
  final double totalSelectedSize;

  const VideoSelectionState({
    this.selectedVideoIds = const {},
    this.totalSelectedSize = 0.0,
  });

  VideoSelectionState copyWith({
    Set<String>? selectedVideoIds,
    double? totalSelectedSize,
  }) {
    return VideoSelectionState(
      selectedVideoIds: selectedVideoIds ?? this.selectedVideoIds,
      totalSelectedSize: totalSelectedSize ?? this.totalSelectedSize,
    );
  }

  /// 检查指定视频是否被选中
  bool isSelected(String videoId) => selectedVideoIds.contains(videoId);

  /// 已选择视频数量
  int get selectedCount => selectedVideoIds.length;

  /// 格式化总大小显示
  String get formattedTotalSize {
    if (totalSelectedSize < 1024) return '${totalSelectedSize.toStringAsFixed(0)} B';
    if (totalSelectedSize < 1024 * 1024) return '${(totalSelectedSize / 1024).toStringAsFixed(1)} KB';
    if (totalSelectedSize < 1024 * 1024 * 1024) return '${(totalSelectedSize / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(totalSelectedSize / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  @override
  List<Object> get props => [selectedVideoIds, totalSelectedSize];
}

/// 视频选择状态管理
class VideoSelectionCubit extends Cubit<VideoSelectionState> {
  VideoSelectionCubit() : super(const VideoSelectionState());

  /// 切换视频选择状态
  void toggleSelection(String videoId, double videoSize) {
    final newSelectedIds = Set<String>.from(state.selectedVideoIds);
    double newTotalSize = state.totalSelectedSize;

    if (newSelectedIds.contains(videoId)) {
      // 取消选择
      newSelectedIds.remove(videoId);
      newTotalSize -= videoSize;
    } else {
      // 添加选择
      newSelectedIds.add(videoId);
      newTotalSize += videoSize;
    }

    emit(VideoSelectionState(
      selectedVideoIds: newSelectedIds,
      totalSelectedSize: newTotalSize,
    ));
  }

  /// 清除所有选择
  void clearSelection() {
    emit(const VideoSelectionState());
  }

  /// 全选
  void selectAll(Map<String, double> videoSizeMap) {
    final totalSize = videoSizeMap.values.fold(0.0, (sum, size) => sum + size);

    emit(VideoSelectionState(
      selectedVideoIds: Set<String>.from(videoSizeMap.keys),
      totalSelectedSize: totalSize,
    ));
  }

  /// 反选
  void invertSelection(Map<String, double> allVideoSizeMap) {
    final currentSelected = state.selectedVideoIds;
    final newSelected = allVideoSizeMap.keys.where((id) => !currentSelected.contains(id)).toSet();
    final newTotalSize = newSelected.fold(0.0, (sum, id) => sum + (allVideoSizeMap[id] ?? 0));

    emit(VideoSelectionState(
      selectedVideoIds: newSelected,
      totalSelectedSize: newTotalSize,
    ));
  }
}
