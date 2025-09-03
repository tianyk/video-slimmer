import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_slimmer/src/cubits/video_list_state.dart';
import 'package:video_slimmer/src/models/video_model.dart';

class VideoListCubit extends Cubit<VideoListState> {
  VideoListCubit() : super(const VideoListInitial());

  Future<void> loadVideos() async {
    try {
      emit(const VideoListLoading());

      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        emit(const VideoListError('需要相册权限才能查看视频'));
        return;
      }

      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.video,
      );

      final List<VideoModel> videos = [];

      for (final path in paths) {
        final List<AssetEntity> videoAssets = await path.getAssetListPaged(
          page: 0,
          size: 100,
        );

        for (final videoEntity in videoAssets) {
          final file = await videoEntity.file;
          if (file != null) {
            videos.add(VideoModel(
              id: videoEntity.id,
              title: videoEntity.title ?? '未知视频',
              path: file.path,
              duration: videoEntity.duration.toDouble(),
              width: videoEntity.width,
              height: videoEntity.height,
              sizeBytes: await file.length(),
              frameRate: 30, // 相册API无法直接获取帧率
              creationDate: videoEntity.createDateTime,
              assetEntity: videoEntity,
              isSelected: false,
            ));
          }
        }
      }

      emit(VideoListLoaded(videos: videos));
    } catch (e) {
      emit(VideoListError('加载视频失败: ${e.toString()}'));
    }
  }

  void toggleVideoSelection(String videoId) {
    final currentState = state;
    if (currentState is! VideoListLoaded) return;

    final updatedVideos = currentState.videos.map((video) {
      if (video.id == videoId) {
        return video.copyWith(isSelected: !video.isSelected);
      }
      return video;
    }).toList();

    emit(currentState.copyWith(videos: updatedVideos));
  }

  void sortVideos(String sortBy, bool descending) {
    final currentState = state;
    if (currentState is! VideoListLoaded) return;

    emit(currentState.copyWith(
      sortBy: sortBy,
      sortDescending: descending,
    ));
  }

  void filterVideos(String? filter) {
    final currentState = state;
    if (currentState is! VideoListLoaded) return;

    emit(currentState.copyWith(selectedFilter: filter));
  }

  void clearSelection() {
    final currentState = state;
    if (currentState is! VideoListLoaded) return;

    final updatedVideos = currentState.videos.map((video) {
      return video.copyWith(isSelected: false);
    }).toList();

    emit(currentState.copyWith(videos: updatedVideos));
  }
}