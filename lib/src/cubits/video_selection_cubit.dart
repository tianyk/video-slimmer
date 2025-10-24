import 'package:flutter_bloc/flutter_bloc.dart';

/// 视频选择状态管理
class VideoSelectionCubit extends Cubit<Set<String>> {
  VideoSelectionCubit() : super(const {});

  /// 切换视频选择状态
  void toggleSelection(String videoId, double videoSize) {
    if (state.contains(videoId)) {
      // 取消选择
      state.remove(videoId);
    } else {
      // 添加选择
      state.add(videoId);
    }

    emit(state);
  }

  /// 清除所有选择
  void clearSelection() {
    emit(const {});
  }

  /// 全选
  void selectAll(Map<String, double> videoSizeMap) {
    emit(Set<String>.from(videoSizeMap.keys));
  }

  /// 反选
  void invertSelection(Map<String, double> allVideoSizeMap) {
    final newSelected = Set<String>.from(allVideoSizeMap.keys.where((id) => !state.contains(id)));

    emit(newSelected);
  }
}
