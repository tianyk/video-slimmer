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
  /// 当前页码
  final int page;

  /// 所有视频数据
  final List<VideoModel> videos;

  /// 加载时间戳
  final DateTime loadedAt;

  /// 总文件大小
  final double totalSize;

  const VideoDataLoaded({
    required this.page,
    required this.videos,
    required this.loadedAt,
    this.totalSize = 0.0,
  });

  VideoDataLoaded copyWith({
    int? page,
    List<VideoModel>? videos,
    DateTime? loadedAt,
    double? totalSize,
  }) {
    return VideoDataLoaded(
      page: page ?? this.page,
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
  List<Object> get props => [page, videos, loadedAt, totalSize];
}

/// 加载失败状态
class VideoDataError extends VideoDataState {
  // 页码
  final int page;
  // 错误信息
  final String message;
  // 错误对象
  final Object? error;

  const VideoDataError(this.message, {this.error, required this.page});

  @override
  List<Object> get props => [message];
}

/// 视频数据管理 - 只负责数据加载和缓存
class VideoDataCubit extends Cubit<VideoDataState> {
  VideoDataCubit() : super(const VideoDataInitial());

  // MethodChannel for iOS native API
  static const _platform = MethodChannel('cc.kekek.videoslimmer');

  /// 加载视频
  Future<void> loadVideos({int page = 0}) async {
    try {
      if (state is VideoDataLoading) {
        return;
      }
      emit(VideoDataLoading());

      // 请求权限
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        emit(VideoDataError('需要相册权限才能查看视频', page: page));
        return;
      }

      // 加载视频数据
      final result = await _loadVideoData(page: page);
      final videos = result['videos'] as List<VideoModel>;
      final totalSize = result['totalSize'] as double;

      // 按创建时间倒序排列（最新的在前面）
      videos.sort((a, b) => b.creationDate.compareTo(a.creationDate));

      emit(VideoDataLoaded(
        page: page,
        videos: videos,
        loadedAt: DateTime.now(),
        totalSize: totalSize,
      ));
    } catch (e) {
      emit(VideoDataError('加载视频失败: ${e.toString()}', error: e, page: page));
      // 可以在这里添加日志记录
      // debugPrint('视频加载错误: $e');
      // debugPrint('堆栈跟踪: $stackTrace');
    }
  }

  /// 刷新视频列表
  Future<void> refreshVideos() async {
    await loadVideos(page: 0);
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
  Future<Map<String, dynamic>> _loadVideoData({required int page}) async {
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
        page: page,
        size: 200, // 可以根据需要调整批次大小
      );

      for (final videoEntity in videoAssets) {
        final isLocallyAvailable = await videoEntity.isLocallyAvailable();
        final basicInfo = await getAssetBasicInfo(videoEntity.id);

        totalSize += basicInfo?['fileSize'] ?? 0;

        final metadata = await _getVideoMetadata(videoEntity.id);
        if (metadata.isNotEmpty) {
          print('帧率: ${metadata['frameRate']}');
          print('HDR: ${metadata['isHDR']}');
          print('色彩空间: ${metadata['colorSpace']}');
        }
        print('========================');

        videos.add(VideoModel(
          id: videoEntity.id,
          title: videoEntity.title ?? '未知视频',
          // path: file.path,
          duration: videoEntity.duration.toDouble(),
          width: videoEntity.width,
          height: videoEntity.height,
          sizeBytes: basicInfo?['fileSize'] ?? 0,
          frameRate: metadata['frameRate'] ?? 30.0,
          creationDate: videoEntity.createDateTime,
          isHDR: metadata['isHDR'] ?? false,
          isDolbyVision: metadata['isDolbyVision'] ?? false,
          hdrType: metadata['hdrType'] ?? 'SDR',
          colorSpace: metadata['colorSpace'] ?? 'Unknown',
          isLocallyAvailable: isLocallyAvailable,
        ));
        // } else {
        //   print('===== 视频文件获取失败 =====');
        //   print('视频: ${videoEntity.title}');
        //   print('获取文件对象耗时: ${fileElapsed}ms');
        //   print('========================');
        // }
      }
    }

    return {
      'videos': videos,
      'totalSize': totalSize,
    };
  }

  /// 通过 iOS 原生 API 获取视频完整元数据
  ///
  /// 使用 PHAsset 的 localIdentifier 获取视频元数据，无需文件路径
  ///
  /// 参数:
  /// - [assetId]: PHAsset 的 localIdentifier（即 AssetEntity.id）
  ///
  /// 返回包含以下字段的 Map:
  /// - frameRate: 视频帧率（fps）
  /// - isHDR: 是否为 HDR 视频
  /// - isDolbyVision: 是否为杜比视界视频
  /// - hdrType: HDR 类型（SDR/HDR10/HLG/Dolby Vision 等）
  /// - colorSpace: 色彩空间（ITU_R_709/ITU_R_2020/Display_P3 等）
  ///
  /// 如果获取失败，返回默认值（30fps SDR）
  Future<Map<String, dynamic>> _getVideoMetadata(String assetId) async {
    try {
      final result = await _platform.invokeMethod('getVideoMetadata', {
        'assetId': assetId,
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

  /// 通过 iOS 原生 API 获取资源的真实文件大小
  ///
  /// 使用 PHAssetResource API 获取视频的原始文件大小
  /// 即使文件存储在 iCloud 中未下载，也能获取真实文件大小
  ///
  /// 参数:
  /// - [assetId]: PHAsset 的 localIdentifier（即 AssetEntity.id）
  ///
  /// 返回:
  /// - 成功时返回文件大小（int，单位：字节）
  /// - 失败时返回 null
  ///
  /// 注意:
  /// - 原生方法直接返回 Int64 类型的文件大小
  /// - 不会触发 iCloud 下载
  /// - 比通过 file.length() 获取本地文件大小更准确
  Future<int?> _getRealFileSize(String assetId) async {
    try {
      final result = await _platform.invokeMethod('getAssetFileSize', {
        'assetId': assetId,
      });

      if (result != null) {
        if (result is int) {
          return result;
        } else if (result is double) {
          return result.toInt();
        }
      }
    } catch (e) {
      print('获取真实文件大小失败: $e');
    }

    return null;
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
  /// - 比 getAssetCloudStatus 更轻量，只返回核心信息
  Future<Map<String, dynamic>?> getAssetBasicInfo(String assetId) async {
    try {
      final result = await _platform.invokeMethod('getAssetBasicInfo', {
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

  /// 通过 iOS 原生 API 获取资源的详细 iCloud 状态
  ///
  /// 使用 PHAsset 和 PHAssetResource API 检查视频的云存储状态
  ///
  /// 参数:
  /// - [assetId]: PHAsset 的 localIdentifier（即 AssetEntity.id）
  ///
  /// 返回包含以下字段的 Map（如果获取失败则返回 null）:
  /// - assetId: 资源的唯一标识符
  /// - isInCloud: 资源是否存储在 iCloud 中（bool）
  /// - isLocallyAvailable: 资源是否在本地可用/已下载到设备（bool）
  /// - estimatedFileSize: 预估的文件大小，单位：字节（int）
  /// - pixelWidth: 视频像素宽度（int）
  /// - pixelHeight: 视频像素高度（int）
  /// - duration: 视频时长，单位：秒（double）
  /// - mediaType: 媒体类型的原始值，2 表示视频（int）
  /// - mediaSubtypes: 媒体子类型的原始值（int）
  ///
  /// 使用场景:
  /// - 检查视频是否在 iCloud 中
  /// - 判断视频是否需要从 iCloud 下载
  /// - 获取视频的基本信息（尺寸、时长等）
  /// - 调试时输出详细的云状态信息
  Future<Map<String, dynamic>?> _getCloudStatus(String assetId) async {
    try {
      final result = await _platform.invokeMethod('getAssetCloudStatus', {
        'assetId': assetId,
      });

      if (result != null && result is Map) {
        return Map<String, dynamic>.from(result);
      }
    } catch (e) {
      print('获取iCloud状态失败: $e');
    }

    return null;
  }
}
