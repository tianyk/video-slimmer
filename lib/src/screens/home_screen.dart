import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:remixicon/remixicon.dart';

import '../constants/app_constants.dart';
import '../constants/app_theme.dart';
import '../cubits/video_data_cubit.dart';
import '../cubits/video_filter_cubit.dart';
import '../cubits/video_selection_cubit.dart';
import '../models/video_model.dart';
import '../utils.dart';
import '../widgets/video_thumbnail.dart';
import 'compression_config_screen.dart';

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
    // 加载第一页视频
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
          body: Stack(
            children: [
              // 主要内容区域
              BlocBuilder<VideoDataCubit, VideoDataState>(
                builder: (context, dataState) {
                  if (dataState is VideoDataInitial) {
                    return const SizedBox.shrink();
                  } else if (dataState is VideoDataLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (dataState is VideoDataLoaded) {
                    return BlocBuilder<VideoFilterCubit, VideoFilterState>(
                      builder: (context, filterState) {
                        final filteredVideos =
                            filterState.applyFilterAndSort(dataState.videos);
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

              // 浮动按钮
              Positioned(
                left: 16,
                right: 16,
                bottom: 32,
                child: _buildFloatingButtonContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建浮动按钮内容
  Widget _buildFloatingButtonContent() {
    return BlocBuilder<VideoSelectionCubit, Set<String>>(
      builder: (context, selectionState) {
        if (selectionState.isNotEmpty) {
          return Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _onNextPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.prosperityGold,
                foregroundColor: AppTheme.prosperityBlack,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 8),
                  Text(
                    '下一步 (${selectionState.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
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
        padding: const EdgeInsets.all(16),
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
            // 标题栏
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
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
              onTap: (sortKey) => _handleSortSelection(
                  modalContext, filterCubit, sortKey, currentState),
            ),
            _SortOption(
              title: '拍摄时间',
              sortKey: 'date',
              currentSort: currentState.sortBy,
              isDescending: currentState.sortDescending,
              onTap: (sortKey) => _handleSortSelection(
                  modalContext, filterCubit, sortKey, currentState),
            ),
            _SortOption(
              title: '视频时长',
              sortKey: 'duration',
              currentSort: currentState.sortBy,
              isDescending: currentState.sortDescending,
              onTap: (sortKey) => _handleSortSelection(
                  modalContext, filterCubit, sortKey, currentState),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _showFilterDialog(BuildContext context) {
    final filterCubit = context.read<VideoFilterCubit>();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext modalContext) {
        return BlocProvider.value(
          value: filterCubit,
          child: BlocBuilder<VideoFilterCubit, VideoFilterState>(
            builder: (context, filterState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '筛选标签',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        if (filterState.selectedTags.isNotEmpty)
                          TextButton(
                            onPressed: () => filterCubit.clearAllTags(),
                            child: const Text('清除全部'),
                          ),
                      ],
                    ),
                  ),
                  // 标签列表
                  _FilterListTile(
                    title: '1080p',
                    tag: '1080p',
                    isSelected: filterState.selectedTags.contains('1080p'),
                    onTap: () => filterCubit.toggleTag('1080p'),
                  ),
                  _FilterListTile(
                    title: '4K',
                    tag: '4k',
                    isSelected: filterState.selectedTags.contains('4k'),
                    onTap: () => filterCubit.toggleTag('4k'),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// 处理排序选择逻辑
  void _handleSortSelection(BuildContext context, VideoFilterCubit filterCubit,
      String sortKey, VideoFilterState currentState) {
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
    final dataState = _videoDataCubit.state;

    if (dataState is VideoDataLoaded) {
      // 获取选中的视频
      final selectedVideos = dataState.videos
          .where((video) => selectionState.contains(video.id))
          .toList();

      if (selectedVideos.isNotEmpty) {
        // 导航到压缩配置页面
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CompressionConfigScreen(
              selectedVideos: selectedVideos,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先选择要压缩的视频'),
          ),
        );
      }
    }
  }
}

class _VideoItem extends StatelessWidget {
  final VideoModel video;

  const _VideoItem({
    super.key,
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<VideoSelectionCubit, Set<String>, bool>(
      selector: (selectedVideoIds) => selectedVideoIds.contains(video.id),
      builder: (context, isSelected) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isSelected ? 8 : 2,
          color: isSelected
              ? AppTheme.prosperityDarkGold.withValues(alpha: 0.2)
              : AppTheme.prosperityGray,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => context
                .read<VideoSelectionCubit>()
                .toggleSelection(video.id, video.sizeBytes.toDouble()),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 缩略图
                  VideoThumbnail(id: video.id),
                  const SizedBox(width: 12),
                  // 视频信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 主要信息行：文件大小（突出显示）
                        Row(
                          children: [
                            Text(
                              video.fileSize,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.prosperityLightGold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.prosperityGold
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                video.videoSpecification,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.prosperityGold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 次要信息行：时长和拍摄日期
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            // 视频时长，格式化显示
                            Text(
                              video.formattedDuration,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              // 视频创建时间，格式化显示
                              formatDateToFriendlyString(video.creationDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            // iCloud状态指示器
                            if (video.isLocallyAvailable)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _buildCloudStatusIndicator(video),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 选择框
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) => context
                        .read<VideoSelectionCubit>()
                        .toggleSelection(video.id, video.sizeBytes.toDouble()),
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

  /// 构建符合品牌色系的iCloud状态指示器
  Widget _buildCloudStatusIndicator(VideoModel video) {
    if (!video.isLocallyAvailable) {
      // iCloud中 - 使用主金色表示正常状态
      return Icon(
        Remix.cloud_fill,
        size: 12,
        color: AppTheme.prosperityGold,
      );
    } else {
      // 本地视频，不显示指示器
      return const SizedBox.shrink();
    }
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

/// 🏷️ 过滤列表项组件
class _FilterListTile extends StatelessWidget {
  final String title;
  final String tag;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterListTile({
    required this.title,
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppTheme.prosperityGold : null,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppTheme.prosperityGold)
          : null,
      onTap: onTap,
    );
  }
}
