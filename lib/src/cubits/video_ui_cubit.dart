import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

/// 视频列表UI交互状态
class VideoUIState extends Equatable {
  /// 是否显示搜索栏
  final bool isSearchVisible;

  /// 列表显示模式：'list', 'grid'
  final String viewMode;

  /// 是否显示详细信息
  final bool showDetailInfo;

  /// 当前展开的视频ID（用于显示详细信息）
  final String? expandedVideoId;

  /// 是否启用多选模式
  final bool isMultiSelectMode;

  /// 刷新状态
  final bool isRefreshing;

  /// 是否显示筛选面板
  final bool isFilterPanelVisible;

  const VideoUIState({
    this.isSearchVisible = false,
    this.viewMode = 'list',
    this.showDetailInfo = false,
    this.expandedVideoId,
    this.isMultiSelectMode = false,
    this.isRefreshing = false,
    this.isFilterPanelVisible = false,
  });

  VideoUIState copyWith({
    bool? isSearchVisible,
    String? viewMode,
    bool? showDetailInfo,
    String? expandedVideoId,
    bool? isMultiSelectMode,
    bool? isRefreshing,
    bool? isFilterPanelVisible,
  }) {
    return VideoUIState(
      isSearchVisible: isSearchVisible ?? this.isSearchVisible,
      viewMode: viewMode ?? this.viewMode,
      showDetailInfo: showDetailInfo ?? this.showDetailInfo,
      expandedVideoId: expandedVideoId != null ? (expandedVideoId == 'null' ? null : expandedVideoId) : this.expandedVideoId,
      isMultiSelectMode: isMultiSelectMode ?? this.isMultiSelectMode,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isFilterPanelVisible: isFilterPanelVisible ?? this.isFilterPanelVisible,
    );
  }

  @override
  List<Object?> get props => [
        isSearchVisible,
        viewMode,
        showDetailInfo,
        expandedVideoId,
        isMultiSelectMode,
        isRefreshing,
        isFilterPanelVisible,
      ];
}

/// 视频UI交互状态管理
class VideoUICubit extends Cubit<VideoUIState> {
  VideoUICubit() : super(const VideoUIState());

  /// 切换搜索栏显示状态
  void toggleSearchVisibility() {
    emit(state.copyWith(isSearchVisible: !state.isSearchVisible));
  }

  /// 显示搜索栏
  void showSearch() {
    emit(state.copyWith(isSearchVisible: true));
  }

  /// 隐藏搜索栏
  void hideSearch() {
    emit(state.copyWith(isSearchVisible: false));
  }

  /// 切换视图模式（列表/网格）
  void toggleViewMode() {
    final newMode = state.viewMode == 'list' ? 'grid' : 'list';
    emit(state.copyWith(viewMode: newMode));
  }

  /// 设置视图模式
  void setViewMode(String mode) {
    emit(state.copyWith(viewMode: mode));
  }

  /// 切换详细信息显示
  void toggleDetailInfo() {
    emit(state.copyWith(showDetailInfo: !state.showDetailInfo));
  }

  /// 展开/收起指定视频的详细信息
  void toggleVideoExpansion(String videoId) {
    final newExpandedId = state.expandedVideoId == videoId ? null : videoId;
    emit(state.copyWith(expandedVideoId: newExpandedId ?? 'null'));
  }

  /// 收起所有展开的视频
  void collapseAll() {
    emit(state.copyWith(expandedVideoId: 'null'));
  }

  /// 进入多选模式
  void enterMultiSelectMode() {
    emit(state.copyWith(isMultiSelectMode: true));
  }

  /// 退出多选模式
  void exitMultiSelectMode() {
    emit(state.copyWith(isMultiSelectMode: false));
  }

  /// 切换多选模式
  void toggleMultiSelectMode() {
    emit(state.copyWith(isMultiSelectMode: !state.isMultiSelectMode));
  }

  /// 设置刷新状态
  void setRefreshing(bool isRefreshing) {
    emit(state.copyWith(isRefreshing: isRefreshing));
  }

  /// 切换筛选面板显示
  void toggleFilterPanel() {
    emit(state.copyWith(isFilterPanelVisible: !state.isFilterPanelVisible));
  }

  /// 显示筛选面板
  void showFilterPanel() {
    emit(state.copyWith(isFilterPanelVisible: true));
  }

  /// 隐藏筛选面板
  void hideFilterPanel() {
    emit(state.copyWith(isFilterPanelVisible: false));
  }

  /// 重置UI状态
  void reset() {
    emit(const VideoUIState());
  }
}
