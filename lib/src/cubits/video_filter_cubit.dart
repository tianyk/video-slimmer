import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/video_model.dart';

/// 视频筛选和排序状态
class VideoFilterState extends Equatable {
  /// 排序方式：'date', 'size', 'title', 'duration'
  final String sortBy;

  /// 是否降序排列
  final bool sortDescending;

  /// 当前筛选条件
  final String? selectedFilter;

  /// 搜索关键词
  final String? searchKeyword;

  const VideoFilterState({
    this.sortBy = 'date',
    this.sortDescending = true,
    this.selectedFilter,
    this.searchKeyword,
  });

  VideoFilterState copyWith({
    String? sortBy,
    bool? sortDescending,
    String? selectedFilter,
    String? searchKeyword,
  }) {
    return VideoFilterState(
      sortBy: sortBy ?? this.sortBy,
      sortDescending: sortDescending ?? this.sortDescending,
      selectedFilter: selectedFilter != null ? (selectedFilter == 'null' ? null : selectedFilter) : this.selectedFilter,
      searchKeyword: searchKeyword != null ? (searchKeyword.isEmpty ? null : searchKeyword) : this.searchKeyword,
    );
  }

  /// 应用筛选和排序到视频列表
  List<VideoModel> applyFilterAndSort(List<VideoModel> videos) {
    List<VideoModel> result = List.from(videos);

    // 应用搜索关键词筛选
    if (searchKeyword != null && searchKeyword!.isNotEmpty) {
      result = result.where((video) => video.title.toLowerCase().contains(searchKeyword!.toLowerCase())).toList();
    }

    // 应用分辨率和帧率筛选
    if (selectedFilter != null) {
      switch (selectedFilter) {
        case '4K60':
          result = result.where((video) => video.width >= 3840 && video.frameRate >= 58).toList();
          break;
        case '4K30':
          result = result.where((video) => video.width >= 3840 && video.frameRate < 58).toList();
          break;
        case '1080p60':
          result = result.where((video) => video.width >= 1920 && video.width < 3840 && video.frameRate >= 58).toList();
          break;
        case '1080p30':
          result = result.where((video) => video.width >= 1920 && video.width < 3840 && video.frameRate < 45).toList();
          break;
        case '720p':
          result = result.where((video) => video.width >= 1280 && video.width < 1920).toList();
          break;
        case 'large_files':
          result = result.where((video) => video.sizeBytes > 100 * 1024 * 1024).toList(); // 大于100MB
          break;
        case 'long_videos':
          result = result.where((video) => video.duration > 300).toList(); // 大于5分钟
          break;
      }
    }

    // 应用排序
    result.sort((a, b) {
      int comparison = 0;
      switch (sortBy) {
        case 'size':
          comparison = a.sizeBytes.compareTo(b.sizeBytes);
          break;
        case 'duration':
          comparison = a.duration.compareTo(b.duration);
          break;
        case 'title':
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 'date':
        default:
          comparison = a.creationDate.compareTo(b.creationDate);
          break;
      }
      return sortDescending ? -comparison : comparison;
    });

    return result;
  }

  @override
  List<Object?> get props => [sortBy, sortDescending, selectedFilter, searchKeyword];
}

/// 视频筛选和排序管理
class VideoFilterCubit extends Cubit<VideoFilterState> {
  VideoFilterCubit() : super(const VideoFilterState());

  /// 设置排序方式
  void setSortBy(String sortBy, {bool? descending}) {
    emit(state.copyWith(
      sortBy: sortBy,
      sortDescending: descending ?? state.sortDescending,
    ));
  }

  /// 切换排序方向
  void toggleSortDirection() {
    emit(state.copyWith(sortDescending: !state.sortDescending));
  }

  /// 设置筛选条件
  void setFilter(String? filter) {
    emit(state.copyWith(selectedFilter: filter));
  }

  /// 清除筛选
  void clearFilter() {
    emit(state.copyWith(selectedFilter: 'null'));
  }

  /// 设置搜索关键词
  void setSearchKeyword(String? keyword) {
    emit(state.copyWith(searchKeyword: keyword));
  }

  /// 清除搜索
  void clearSearch() {
    emit(state.copyWith(searchKeyword: ''));
  }

  /// 重置所有筛选和排序
  void reset() {
    emit(const VideoFilterState());
  }

  /// 获取当前筛选条件的描述
  String getFilterDescription() {
    final filters = <String>[];

    if (state.selectedFilter != null) {
      switch (state.selectedFilter) {
        case '4K60':
          filters.add('4K/60fps');
          break;
        case '4K30':
          filters.add('4K/30fps');
          break;
        case '1080p60':
          filters.add('1080p/60fps');
          break;
        case '1080p30':
          filters.add('1080p/30fps');
          break;
        case '720p':
          filters.add('720p');
          break;
        case 'large_files':
          filters.add('大文件');
          break;
        case 'long_videos':
          filters.add('长视频');
          break;
      }
    }

    if (state.searchKeyword != null && state.searchKeyword!.isNotEmpty) {
      filters.add('搜索: ${state.searchKeyword}');
    }

    if (filters.isEmpty) {
      return '全部视频';
    }

    return filters.join(' | ');
  }
}
