import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:remixicon/remixicon.dart';

import '../constants/app_constants.dart';
import '../constants/app_theme.dart';
import '../cubits/video_data_cubit.dart';
import '../cubits/video_filter_cubit.dart';
import '../cubits/video_selection_cubit.dart';
import '../models/video_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final VideoDataCubit _videoDataCubit;
  late final VideoSelectionCubit _videoSelectionCubit;
  late final VideoFilterCubit _videoFilterCubit;

  @override
  void initState() {
    super.initState();
    _videoDataCubit = VideoDataCubit();
    _videoSelectionCubit = VideoSelectionCubit();
    _videoFilterCubit = VideoFilterCubit();
    _videoDataCubit.loadVideos();
  }

  @override
  void dispose() {
    _videoDataCubit.close();
    _videoSelectionCubit.close();
    _videoFilterCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _videoDataCubit),
        BlocProvider.value(value: _videoSelectionCubit),
        BlocProvider.value(value: _videoFilterCubit),
      ],
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text(AppConstants.appName),
            actions: [
              // 排序按钮
              IconButton(
                icon: const Icon(Icons.sort),
                onPressed: () => _showSortDialog(context),
              ),
              // 筛选按钮
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () => _showFilterDialog(context),
              ),
            ],
          ),
          body: BlocBuilder<VideoDataCubit, VideoDataState>(
            builder: (context, dataState) {
              if (dataState is VideoDataInitial) {
                return const SizedBox.shrink();
              } else if (dataState is VideoDataLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (dataState is VideoDataLoaded) {
                return BlocBuilder<VideoFilterCubit, VideoFilterState>(
                  builder: (context, filterState) {
                    final filteredVideos = filterState.applyFilterAndSort(dataState.videos);
                    return _buildVideoList(filteredVideos);
                  },
                );
              } else if (dataState is VideoDataError) {
                return _buildErrorState(dataState.message);
              } else {
                return const Center(child: Text('未知状态'));
              }
            },
          ),
          // 浮动按钮只监听选择状态
          floatingActionButton: BlocBuilder<VideoSelectionCubit, VideoSelectionState>(
            builder: (context, selectionState) {
              if (selectionState.selectedCount > 0) {
                return SizedBox(
                  width: double.infinity,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: FloatingActionButton.extended(
                      onPressed: _onNextPressed,
                      label: Text(
                        '下一步 (${selectionState.selectedCount})',
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
      ),
    );
  }

  Widget _buildVideoList(List<VideoModel> videos) {
    if (videos.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _videoDataCubit.refreshVideos(),
      child: ListView.builder(
        itemCount: videos.length,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemBuilder: (context, index) {
          final video = videos[index];
          return _VideoItem(
            key: ValueKey(video.id),
            video: video,
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
          ElevatedButton(
            onPressed: () => _videoDataCubit.refreshVideos(),
            child: const Text('刷新'),
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
          ElevatedButton(
            onPressed: () => _videoDataCubit.refreshVideos(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  void _showSortDialog(BuildContext context) {
    final filterCubit = context.read<VideoFilterCubit>();
    final currentState = filterCubit.state;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext modalContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text(
                '排序方式',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            // 排序选项
            _SortOption(
              title: '文件大小',
              sortKey: 'size',
              currentSort: currentState.sortBy,
              isDescending: currentState.sortDescending,
              onTap: (sortKey) => _handleSortSelection(filterCubit, sortKey, currentState),
            ),
            _SortOption(
              title: '拍摄时间',
              sortKey: 'date',
              currentSort: currentState.sortBy,
              isDescending: currentState.sortDescending,
              onTap: (sortKey) => _handleSortSelection(filterCubit, sortKey, currentState),
            ),
            _SortOption(
              title: '视频时长',
              sortKey: 'duration',
              currentSort: currentState.sortBy,
              isDescending: currentState.sortDescending,
              onTap: (sortKey) => _handleSortSelection(filterCubit, sortKey, currentState),
            ),
            _SortOption(
              title: '文件名称',
              sortKey: 'title',
              currentSort: currentState.sortBy,
              isDescending: currentState.sortDescending,
              onTap: (sortKey) => _handleSortSelection(filterCubit, sortKey, currentState),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _showFilterDialog(BuildContext context) {
    final filterCubit = context.read<VideoFilterCubit>();
    final currentState = filterCubit.state;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('按分辨率和类型筛选', style: TextStyle(fontSize: 18)),
            ),
            ListTile(
              title: const Text('全部视频'),
              trailing: currentState.selectedFilter == null ? const Icon(Icons.check) : null,
              onTap: () {
                filterCubit.clearFilter();
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('4K/60fps'),
              trailing: currentState.selectedFilter == '4K60' ? const Icon(Icons.check) : null,
              onTap: () {
                filterCubit.setFilter('4K60');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('4K/30fps'),
              trailing: currentState.selectedFilter == '4K30' ? const Icon(Icons.check) : null,
              onTap: () {
                filterCubit.setFilter('4K30');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('1080p/30fps'),
              trailing: currentState.selectedFilter == '1080p30' ? const Icon(Icons.check) : null,
              onTap: () {
                filterCubit.setFilter('1080p30');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('大文件 (>100MB)'),
              trailing: currentState.selectedFilter == 'large_files' ? const Icon(Icons.check) : null,
              onTap: () {
                filterCubit.setFilter('large_files');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('长视频 (>5分钟)'),
              trailing: currentState.selectedFilter == 'long_videos' ? const Icon(Icons.check) : null,
              onTap: () {
                filterCubit.setFilter('long_videos');
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  /// 处理排序选择逻辑
  void _handleSortSelection(VideoFilterCubit filterCubit, String sortKey, VideoFilterState currentState) {
    if (currentState.sortBy == sortKey) {
      // 🔄 如果已经是当前排序字段，切换升序/降序
      filterCubit.toggleSortDirection();
    } else {
      // 🆕 如果是新的排序字段，设置为该字段并默认降序
      filterCubit.setSortBy(sortKey, descending: true);
    }
    Navigator.pop(context);
  }

  void _onNextPressed() {
    final selectionState = _videoSelectionCubit.state;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已选择 ${selectionState.selectedCount} 个视频 (${selectionState.formattedTotalSize})',
        ),
      ),
    );

    // 这里可以导航到下一个页面
    // Navigator.of(context).push(...);
  }
}

class _VideoItem extends StatelessWidget {
  final VideoModel video;

  const _VideoItem({
    required Key key,
    required this.video,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoSelectionCubit, VideoSelectionState>(
      // 只有这个视频的选择状态变化时才重建
      buildWhen: (previous, current) => previous.isSelected(video.id) != current.isSelected(video.id),
      builder: (context, selectionState) {
        final isSelected = selectionState.isSelected(video.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isSelected ? 8 : 2,
          color: isSelected ? AppTheme.prosperityDarkGold.withValues(alpha: 0.2) : AppTheme.prosperityGray,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => context.read<VideoSelectionCubit>().toggleSelection(video.id, video.sizeBytes.toDouble()),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 缩略图
                  _buildThumbnail(),
                  const SizedBox(width: 12),
                  // 视频信息
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
                  // 选择框
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) => context.read<VideoSelectionCubit>().toggleSelection(video.id, video.sizeBytes.toDouble()),
                    activeColor: AppTheme.prosperityGold,
                    checkColor: Colors.black,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail() {
    return SizedBox(
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
    );
  }
}

/// 🎯 自定义排序选项组件
class _SortOption extends StatelessWidget {
  final String title;
  final String sortKey;
  final String currentSort;
  final bool isDescending;
  final ValueChanged<String> onTap;

  const _SortOption({
    required this.title,
    required this.sortKey,
    required this.currentSort,
    required this.isDescending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentSort == sortKey;

    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppTheme.prosperityGold : null,
        ),
      ),
      trailing: isSelected
          ? Icon(
              isDescending ? Icons.arrow_downward : Icons.arrow_upward,
              color: AppTheme.prosperityGold,
              size: 20,
            )
          : null,
      onTap: () => onTap(sortKey),
    );
  }
}
