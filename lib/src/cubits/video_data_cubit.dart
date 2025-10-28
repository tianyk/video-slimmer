import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/video_model.dart';

/// 视频数据状态
sealed class VideoDataState extends Equatable {
  const VideoDataState();

  @override
  List<Object> get props => [];
}

/// 初始状态
class VideoDataInitial extends VideoDataState {
  const VideoDataInitial();
}

/// 加载中状态
class VideoDataLoading extends VideoDataState {
  const VideoDataLoading();

  @override
  List<Object> get props => [];
}

/// 加载成功状态
class VideoDataLoaded extends VideoDataState {
  /// 所有视频数据
  final List<VideoModel> videos;

  /// 加载时间戳
  final DateTime loadedAt;

  const VideoDataLoaded({
    required this.videos,
    required this.loadedAt,
  });

  VideoDataLoaded copyWith({
    List<VideoModel>? videos,
    DateTime? loadedAt,
    double? totalSize,
  }) {
    return VideoDataLoaded(
      videos: videos ?? this.videos,
      loadedAt: loadedAt ?? this.loadedAt,
    );
  }

  /// 获取所有视频的大小映射表（用于选择状态计算）
  Map<String, double> get videoSizeMap {
    return Map.fromEntries(videos.map((video) => MapEntry(video.id, video.sizeBytes.toDouble())));
  }

  @override
  List<Object> get props => [videos, loadedAt];
}

/// 加载失败状态
class VideoDataError extends VideoDataState {
  // 错误信息
  final String message;
  // 错误对象
  final Object? error;

  const VideoDataError(this.message, {this.error});

  @override
  List<Object> get props => [message];
}

/// 视频数据管理 - 只负责数据加载和缓存
class VideoDataCubit extends Cubit<VideoDataState> {
  VideoDataCubit() : super(const VideoDataInitial());

  // MethodChannel for iOS native API
  static const _platform = MethodChannel('cc.kekek.videoslimmer');

  /// 加载视频
  Future<void> loadVideos() async {
    try {
      if (state is VideoDataLoading) {
        return;
      }
      emit(VideoDataLoading());

      // 请求权限
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        emit(VideoDataError('需要相册权限才能查看视频'));
        return;
      }

      int page = 0;
      final int size = 100;
      List<VideoModel> videos = [];
      while (true) {
        final result = await _loadVideoData(page: page, size: size);
        videos.addAll(result);
        if (result.length < size) {
          break;
        }
        page++;
      }
      // 按创建时间倒序排列（最新的在前面）
      videos.sort((a, b) => b.creationDate.compareTo(a.creationDate));

      emit(VideoDataLoaded(
        videos: videos,
        loadedAt: DateTime.now(),
      ));
    } catch (e) {
      emit(VideoDataError(
        '加载视频失败: ${e.toString()}',
        error: e,
      ));
    }
  }

  /// 刷新视频列表
  Future<void> refreshVideos() async {
    await loadVideos();
  }

  /// 获取指定ID的视频
  VideoModel? getVideoById(String id) {
    final currentState = state;
    if (currentState is VideoDataLoaded) {
      try {
        return currentState.videos.firstWhere((video) => video.id == id);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// 清除数据
  void clearData() {
    emit(const VideoDataInitial());
  }

  /// 加载视频数据
  Future<List<VideoModel>> _loadVideoData({required int page, int size = 200}) async {
    // 获取视频路径
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.video,
    );

    // 遍历所有路径加载视频
    List<VideoModel> videos = [];
    for (final path in paths) {
      final List<AssetEntity> videoAssets = await path.getAssetListPaged(
        page: page,
        size: size, // 可以根据需要调整批次大小
      );

      for (final videoEntity in videoAssets) {
        final results = await Future.wait([
          videoEntity.isLocallyAvailable(),
          _getVideoMetadata(videoEntity.id),
        ]);
        final isLocallyAvailable = results[0] as bool;
        final metadata = results[1] as Map<String, dynamic>?;

        videos.add(VideoModel(
          id: videoEntity.id,
          duration: videoEntity.duration.toDouble(),
          width: videoEntity.width,
          height: videoEntity.height,
          sizeBytes: metadata?['fileSize'] ?? 0,
          creationDate: videoEntity.createDateTime,
          isLocallyAvailable: isLocallyAvailable,
        ));
      }
    }

    return videos;
  }

  /// 通过 iOS 原生 API 获取视频的基本信息
  ///
  /// 快速获取视频的核心属性：文件大小、分辨率、时长
  ///
  /// 参数:
  /// - [assetId]: PHAsset 的 localIdentifier（即 AssetEntity.id）
  ///
  /// 返回包含以下字段的 Map（如果获取失败则返回 null）:
  /// - fileSize: 文件大小，单位：字节（int）
  /// - pixelWidth: 视频像素宽度（int）
  /// - pixelHeight: 视频像素高度（int）
  /// - duration: 视频时长，单位：秒（double）
  ///
  /// 注意:
  /// - 使用 PHAssetResource 获取精确的文件大小
  /// - 不会触发 iCloud 下载，只获取元数据
  /// - 即使视频在 iCloud 中未下载，也能获取所有信息
  Future<Map<String, dynamic>?> _getVideoMetadata(String assetId) async {
    try {
      final result = await _platform.invokeMethod('getVideoMetadata', {
        'assetId': assetId,
      });

      if (result != null && result is Map) {
        return Map<String, dynamic>.from(result);
      }
    } catch (e) {
      print('获取视频基本信息失败: $e');
    }

    return null;
  }
}
