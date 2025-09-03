import 'package:equatable/equatable.dart';
import 'package:video_slimmer/src/models/video_model.dart';

sealed class VideoListState extends Equatable {
  const VideoListState();

  @override
  List<Object> get props => [];
}

class VideoListInitial extends VideoListState {
  const VideoListInitial();
}

class VideoListLoading extends VideoListState {
  const VideoListLoading();
}

class VideoListLoaded extends VideoListState {
  final List<VideoModel> videos;
  final String sortBy;
  final bool sortDescending;
  final String? selectedFilter;

  const VideoListLoaded({
    required this.videos,
    this.sortBy = 'date',
    this.sortDescending = true,
    this.selectedFilter,
  });

  VideoListLoaded copyWith({
    List<VideoModel>? videos,
    String? sortBy,
    bool? sortDescending,
    String? selectedFilter,
  }) {
    return VideoListLoaded(
      videos: videos ?? this.videos,
      sortBy: sortBy ?? this.sortBy,
      sortDescending: sortDescending ?? this.sortDescending,
      selectedFilter: selectedFilter != null ? 
        (selectedFilter == 'null' ? null : selectedFilter) : this.selectedFilter,
    );
  }

  List<VideoModel> get filteredVideos {
    List<VideoModel> result = List.from(videos);

    if (selectedFilter != null) {
      switch (selectedFilter) {
        case '4K60':
          result = result.where((video) => 
            video.width >= 3840 && video.frameRate >= 58).toList();
          break;
        case '4K30':
          result = result.where((video) => 
            video.width >= 3840 && video.frameRate < 58).toList();
          break;
        case '1080p30':
          result = result.where((video) => 
            video.width >= 1920 && video.width < 3840 && video.frameRate < 45).toList();
          break;
      }
    }

    result.sort((a, b) {
      int comparison = 0;
      switch (sortBy) {
        case 'size':
          comparison = a.sizeBytes.compareTo(b.sizeBytes);
          break;
        case 'date':
          comparison = a.creationDate.compareTo(b.creationDate);
          break;
        default:
          comparison = b.creationDate.compareTo(a.creationDate);
      }
      return sortDescending ? -comparison : comparison;
    });

    return result;
  }

  int get selectedVideosCount => 
    videos.where((video) => video.isSelected).length;

  double get totalSelectedSize => 
    videos.where((video) => video.isSelected).fold(0, (sum, video) => sum + video.sizeBytes);

  @override
  List<Object> get props => [videos, sortBy, sortDescending, selectedFilter ?? 'null'];
}

class VideoListError extends VideoListState {
  final String message;

  const VideoListError(this.message);

  @override
  List<Object> get props => [message];
}

// 添加类型判断助手方法
extension VideoListStateExtension on VideoListState {
  bool get isInitial => this is VideoListInitial;
  bool get isLoading => this is VideoListLoading;
  bool get isLoaded => this is VideoListLoaded;
  bool get isError => this is VideoListError;
}

