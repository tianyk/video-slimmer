import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/video_model.dart';

/// 视频筛选和排序状态
class VideoFilterState extends Equatable {
  /// 排序方式：'date', 'size', 'title', 'duration'
  final String sortBy;

  /// 是否降序排列
  final bool sortDescending;

  /// 选中的过滤标签：['1080p', '4k', '24fps', '30fps', '60fps', 'hdr', 'dolby_vision']
  final Set<String> selectedTags;

  /// 搜索关键词
  final String? searchKeyword;

  const VideoFilterState({
    this.sortBy = 'date',
    this.sortDescending = true,
    this.selectedTags = const {},
    this.searchKeyword,
  });

  VideoFilterState copyWith({
    String? sortBy,
    bool? sortDescending,
    Set<String>? selectedTags,
    String? searchKeyword,
  }) {
    return VideoFilterState(
      sortBy: sortBy ?? this.sortBy,
      sortDescending: sortDescending ?? this.sortDescending,
      selectedTags: selectedTags ?? this.selectedTags,
      searchKeyword: searchKeyword != null ? (searchKeyword.isEmpty ? null : searchKeyword) : this.searchKeyword,
    );
  }

  /// 应用筛选和排序到视频列表
  List<VideoModel> applyFilterAndSort(List<VideoModel> videos) {
    List<VideoModel> result = List.from(videos);

    // 应用标签筛选
    if (selectedTags.isNotEmpty) {
      result = result.where((video) {
        // 检查是否满足任一选中的标签（OR逻辑）
        for (String tag in selectedTags) {
          switch (tag) {
            case '1080p':
              if ((video.width >= 1920 && video.width < 2160) || (video.height >= 1920 && video.height < 2160)) return true;
              break;
            case '4k':
              if (video.width >= 2160 || video.height >= 2160) return true;
              break;
            case '24fps':
              if (video.frameRate >= 23 && video.frameRate <= 25) return true;
              break;
            case '30fps':
              if (video.frameRate >= 28 && video.frameRate <= 32) return true;
              break;
            case '60fps':
              if (video.frameRate >= 58 && video.frameRate <= 62) return true;
              break;
          }
        }
        return false; // 没有满足任何标签条件
      }).toList();
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
  List<Object?> get props => [sortBy, sortDescending, selectedTags, searchKeyword];
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

  /// 切换标签选择状态
  void toggleTag(String tag) {
    final newTags = Set<String>.from(state.selectedTags);
    if (newTags.contains(tag)) {
      newTags.remove(tag);
    } else {
      newTags.add(tag);
    }
    emit(state.copyWith(selectedTags: newTags));
  }

  /// 清除所有标签筛选
  void clearAllTags() {
    emit(state.copyWith(selectedTags: <String>{}));
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

    // 添加选中的标签
    if (state.selectedTags.isNotEmpty) {
      final tagLabels = state.selectedTags.map((tag) {
        switch (tag) {
          case '1080p':
            return '1080p';
          case '4k':
            return '4K';
          case '24fps':
            return '24帧';
          case '30fps':
            return '30帧';
          case '60fps':
            return '60帧';
          case 'hdr':
            return 'HDR';
          case 'dolby_vision':
            return '杜比视界';
          default:
            return tag;
        }
      }).toList();
      filters.addAll(tagLabels);
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
