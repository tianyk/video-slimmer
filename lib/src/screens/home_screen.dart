import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:remixicon/remixicon.dart';

import '../constants/app_constants.dart';
import '../constants/app_theme.dart';
import '../cubits/video_list_cubit.dart';
import '../cubits/video_list_state.dart';
import '../models/video_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final VideoListCubit _videoListCubit;

  @override
  void initState() {
    super.initState();
    _videoListCubit = VideoListCubit();
    _videoListCubit.loadVideos();
  }

  @override
  void dispose() {
    _videoListCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _videoListCubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppConstants.appName),
          actions: [
            // 排序
            BlocBuilder<VideoListCubit, VideoListState>(
              builder: (context, state) {
                if (state is VideoListLoaded && state.selectedVideosCount > 0) {
                  return IconButton(
                    onPressed: () {
                      _videoListCubit.clearSelection();
                    },
                    icon: const Icon(Icons.clear_all),
                    tooltip: '取消选择',
                  );
                } else {
                  return IconButton(
                    icon: const Icon(Icons.sort),
                    onPressed: () => _showSortDialog(context),
                  );
                }
              },
            ),
            // 过滤icon
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFilterDialog(context),
            ),
          ],
        ),
        body: BlocBuilder<VideoListCubit, VideoListState>(
          builder: (context, state) {
            if (state is VideoListInitial) {
              return const SizedBox.shrink();
            } else if (state is VideoListLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is VideoListLoaded) {
              return _buildVideoList(state.videos, state.filteredVideos);
            } else if (state is VideoListError) {
              return _buildErrorState(state.message);
            } else {
              return const Center(child: Text('未知状态'));
            }
          },
        ),
        // 按钮
        floatingActionButton: BlocBuilder<VideoListCubit, VideoListState>(
          builder: (context, state) {
            if (state is VideoListLoaded && state.selectedVideosCount > 0) {
              return SizedBox(
                width: double.infinity,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: FloatingActionButton.extended(
                    onPressed: _onNextPressed,
                    label: Text(
                      '下一步 (${state.selectedVideosCount})',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              );
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildVideoList(List<VideoModel> allVideos, List<VideoModel> filteredVideos) {
    if (filteredVideos.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _videoListCubit.loadVideos(),
      child: ListView.builder(
        itemCount: filteredVideos.length,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemBuilder: (context, index) {
          final video = filteredVideos[index];
          return _VideoItem(
            key: ValueKey(video.id),
            video: video,
            onSelectionChanged: (selected) {
              _videoListCubit.toggleVideoSelection(video.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Remix.video_line, size: 64, color: AppTheme.prosperityLightGray),
          const SizedBox(height: 16),
          const Text('暂无视频', style: AppTheme.titleMedium),
          const SizedBox(height: 8),
          BlocBuilder<VideoListCubit, VideoListState>(
            builder: (context, state) {
              return ElevatedButton(
                onPressed: () => _videoListCubit.loadVideos(),
                child: const Text('刷新'),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text('加载失败: $message', style: AppTheme.titleMedium),
          const SizedBox(height: 8),
          BlocBuilder<VideoListCubit, VideoListState>(
            builder: (context, state) {
              return ElevatedButton(
                onPressed: () => _videoListCubit.loadVideos(),
                child: const Text('重试'),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSortDialog(BuildContext context) {
    final currentState = _videoListCubit.state;
    if (currentState is! VideoListLoaded) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SizedBox(
          height: 200,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('排序方式', style: TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: const Text('文件大小'),
                trailing: Icon(
                  currentState.sortBy == 'size' ? (currentState.sortDescending ? Icons.arrow_downward : Icons.arrow_upward) : null,
                ),
                onTap: () {
                  _videoListCubit.sortVideos('size', true);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('拍摄时间'),
                trailing: Icon(
                  currentState.sortBy == 'date' ? (currentState.sortDescending ? Icons.arrow_downward : Icons.arrow_upward) : null,
                ),
                onTap: () {
                  _videoListCubit.sortVideos('date', true);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('文件名称'),
                trailing: Icon(
                  currentState.sortBy == 'title' ? (currentState.sortDescending ? Icons.arrow_downward : Icons.arrow_upward) : null,
                ),
                onTap: () {
                  _videoListCubit.sortVideos('title', true);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterDialog(BuildContext context) {
    final currentState = _videoListCubit.state;
    if (currentState is! VideoListLoaded) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SizedBox(
          height: 250,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('按分辨率和帧率筛选', style: TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: const Text('全部视频'),
                trailing: currentState.selectedFilter == null ? const Icon(Icons.check) : null,
                onTap: () {
                  _videoListCubit.filterVideos(null);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('4K/60fps'),
                trailing: currentState.selectedFilter == '4K60' ? const Icon(Icons.check) : null,
                onTap: () {
                  _videoListCubit.filterVideos('4K60');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('4K/30fps'),
                trailing: currentState.selectedFilter == '4K30' ? const Icon(Icons.check) : null,
                onTap: () {
                  _videoListCubit.filterVideos('4K30');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('1080p/30fps'),
                trailing: currentState.selectedFilter == '1080p30' ? const Icon(Icons.check) : null,
                onTap: () {
                  _videoListCubit.filterVideos('1080p30');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _onNextPressed() {
    final currentState = _videoListCubit.state;
    if (currentState is! VideoListLoaded) return;

    final selectedVideos = currentState.videos.where((video) => video.isSelected).toList();
    final totalSize = selectedVideos.fold(0.0, (sum, video) => sum + video.sizeBytes);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已选择 ${selectedVideos.length} 个视频 (${_formatFileSize(totalSize)})',
        ),
      ),
    );

    // 这里可以导航到下一个页面
    // Navigator.of(context).push(...);
  }

  String _formatFileSize(double bytes) {
    if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}

class _VideoItem extends StatelessWidget {
  final VideoModel video;
  final ValueChanged<bool> onSelectionChanged;

  const _VideoItem({
    required Key key,
    required this.video,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: video.isSelected ? 8 : 2,
      color: video.isSelected ? AppTheme.prosperityDarkGold.withValues(alpha: 0.2) : AppTheme.prosperityGray,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => onSelectionChanged(!video.isSelected),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 缩略图懒加载
              SizedBox(
                width: 80,
                height: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: video.assetEntity != null
                      ? FutureBuilder<Uint8List?>(
                          future: video.assetEntity!.thumbnailDataWithSize(
                            const ThumbnailSize(160, 120),
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                width: 80,
                                height: 60,
                              );
                            }
                            return Container(
                              color: Colors.grey[300],
                              child: Icon(Remix.video_line, color: Colors.grey[600]),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: Icon(Remix.video_line, color: Colors.grey[600]),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${video.resolutionAndFrameRate} | ${video.formattedDuration} | ${video.fileSize}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: video.isSelected,
                onChanged: (value) => onSelectionChanged(value ?? false),
                activeColor: AppTheme.prosperityGold,
                checkColor: Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
