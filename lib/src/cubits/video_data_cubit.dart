import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
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
}

/// 加载成功状态
class VideoDataLoaded extends VideoDataState {
  /// 所有视频数据
  final List<VideoModel> videos;

  /// 加载时间戳
  final DateTime loadedAt;

  /// 总文件大小
  final double totalSize;

  const VideoDataLoaded({
    required this.videos,
    required this.loadedAt,
    this.totalSize = 0.0,
  });

  VideoDataLoaded copyWith({
    List<VideoModel>? videos,
    DateTime? loadedAt,
    double? totalSize,
  }) {
    return VideoDataLoaded(
      videos: videos ?? this.videos,
      loadedAt: loadedAt ?? this.loadedAt,
      totalSize: totalSize ?? this.totalSize,
    );
  }

  /// 获取所有视频的大小映射表（用于选择状态计算）
  Map<String, double> get videoSizeMap {
    return Map.fromEntries(videos.map((video) => MapEntry(video.id, video.sizeBytes.toDouble())));
  }

  /// 格式化总大小
  String get formattedTotalSize {
    if (totalSize < 1024) return '${totalSize.toStringAsFixed(0)} B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    if (totalSize < 1024 * 1024 * 1024) return '${(totalSize / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(totalSize / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  @override
  List<Object> get props => [videos, loadedAt, totalSize];
}

/// 加载失败状态
class VideoDataError extends VideoDataState {
  final String message;
  final Object? error;

  const VideoDataError(this.message, {this.error});

  @override
  List<Object> get props => [message];
}

/// 视频数据管理 - 只负责数据加载和缓存
class VideoDataCubit extends Cubit<VideoDataState> {
  VideoDataCubit() : super(const VideoDataInitial());

  // MethodChannel for iOS native API
  static const _platform = MethodChannel('video_metadata');

  /// 加载所有视频
  Future<void> loadVideos() async {
    try {
      emit(const VideoDataLoading());

      // 请求权限
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        emit(const VideoDataError('需要相册权限才能查看视频'));
        return;
      }

      // 获取视频路径
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.video,
      );

      final List<VideoModel> videos = [];
      double totalSize = 0.0;

      // 遍历所有路径加载视频
      for (final path in paths) {
        final List<AssetEntity> videoAssets = await path.getAssetListPaged(
          page: 0,
          size: 100, // 可以根据需要调整批次大小
        );

        for (final videoEntity in videoAssets) {
          final file = await videoEntity.file;
          if (file != null) {
            final fileSize = await file.length();
            totalSize += fileSize;

            // 获取视频元数据（包括帧率和 HDR 信息）
            final metadata = await _getVideoMetadata(file.path);

            videos.add(VideoModel(
              id: videoEntity.id,
              title: videoEntity.title ?? '未知视频',
              path: file.path,
              duration: videoEntity.duration.toDouble(),
              width: videoEntity.width,
              height: videoEntity.height,
              sizeBytes: fileSize,
              frameRate: metadata['frameRate'] ?? 30.0,
              creationDate: videoEntity.createDateTime,
              isHDR: metadata['isHDR'] ?? false,
              isDolbyVision: metadata['isDolbyVision'] ?? false,
              hdrType: metadata['hdrType'] ?? 'SDR',
              colorSpace: metadata['colorSpace'] ?? 'Unknown',
              assetEntity: videoEntity,
            ));
          }
        }
      }

      // 按创建时间倒序排列（最新的在前面）
      videos.sort((a, b) => b.creationDate.compareTo(a.creationDate));

      emit(VideoDataLoaded(
        videos: videos,
        loadedAt: DateTime.now(),
        totalSize: totalSize,
      ));
    } catch (e) {
      emit(VideoDataError('加载视频失败: ${e.toString()}', error: e));
      // 可以在这里添加日志记录
      // debugPrint('视频加载错误: $e');
      // debugPrint('堆栈跟踪: $stackTrace');
    }
  }

  /// 刷新视频列表
  Future<void> refreshVideos() async {
    await loadVideos();
  }

  /// 增量加载更多视频（用于分页）
  Future<void> loadMoreVideos({int page = 1, int pageSize = 50}) async {
    final currentState = state;
    if (currentState is! VideoDataLoaded) return;

    try {
      // 这里可以实现增量加载逻辑
      // 暂时保持简单，直接重新加载
      await loadVideos();
    } catch (e) {
      emit(VideoDataError('加载更多视频失败: ${e.toString()}', error: e));
    }
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

  /// 通过 iOS 原生 API 获取视频完整元数据
  Future<Map<String, dynamic>> _getVideoMetadata(String filePath) async {
    try {
      final result = await _platform.invokeMethod('getVideoMetadata', {
        'filePath': filePath,
      });

      if (result != null && result is Map) {
        return Map<String, dynamic>.from(result);
      }
    } catch (e) {
      // print('获取视频元数据失败: $e');
    }

    // 备用方案：返回默认值
    return {
      'frameRate': 30.0,
      'isHDR': false,
      'isDolbyVision': false,
      'hdrType': 'SDR',
      'colorSpace': 'Unknown',
    };
  }
}
