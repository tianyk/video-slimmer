import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../constants/app_theme.dart';
import '../cubits/compression_progress_cubit.dart';
import '../libs/logger.dart';
import '../models/compression_model.dart';
import '../models/compression_progress_model.dart';
import '../models/video_model.dart';
import '../utils.dart';
import '../widgets/video_thumbnail.dart';

final _logger = Logger.getLogger();

class CompressionProgressScreen extends StatefulWidget {
  final List<VideoModel> selectedVideos;
  final CompressionConfig compressionConfig;

  const CompressionProgressScreen({
    super.key,
    required this.selectedVideos,
    required this.compressionConfig,
  });

  @override
  State<CompressionProgressScreen> createState() =>
      _CompressionProgressScreenState();
}

class _CompressionProgressScreenState extends State<CompressionProgressScreen> {
  late final CompressionProgressCubit _progressCubit;

  @override
  void initState() {
    super.initState();
    _progressCubit = CompressionProgressCubit();
    _progressCubit.initializeTask(
      videos: widget.selectedVideos,
      config: widget.compressionConfig,
    );

    // 自动开始压缩（在当前帧绘制完成后回调，确保界面已建立再触发业务逻辑）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logger.info('开始压缩任务');
      _progressCubit.startCompression();
    });
  }

  @override
  void dispose() {
    _progressCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _progressCubit,
      child: BlocBuilder<CompressionProgressCubit, CompressionProgressState>(
        builder: (context, state) {
          return PopScope(
            // 没有活跃任务时允许直接返回，有活跃任务时阻止返回
            canPop: !state.hasActiveCompression,
            onPopInvokedWithResult: (bool didPop, Object? result) async {
              // 如果返回被阻止（didPop = false），检查是否有活跃任务
              if (!didPop) {
                // 重新获取最新状态
                final currentState = _progressCubit.state;
                if (currentState.hasActiveCompression) {
                  await _showExitConfirmation(context);
                }
              }
            },
            child: Scaffold(
              appBar: AppBar(
                title: const Text('压缩进度'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _handleBackNavigation(context),
                ),
                actions: [
                  if (state.hasActiveCompression)
                    IconButton(
                      icon: const Icon(Icons.stop),
                      onPressed: () => _showCancelAllConfirmation(context),
                      tooltip: '停止所有压缩',
                    ),
                ],
              ),
              body: Stack(
                children: [
                  // 主要内容区域
                  _buildVideoList(state.videos),

                  // 底部浮动按钮
                  _buildFloatingButton(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 处理返回导航（统一处理AppBar返回按钮、手势返回、系统返回按钮）
  void _handleBackNavigation(BuildContext context) {
    final state = _progressCubit.state;

    if (state.hasActiveCompression) {
      _showExitConfirmation(context);
    } else {
      Navigator.of(context).pop();
    }
  }

  /// 构建视频列表
  Widget _buildVideoList(List<VideoCompressionInfo> videos) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final videoId = videos[index].video.id;
        return _VideoProgressItem(
          key: ValueKey(videoId),
          videoId: videoId,
          onAction: (action) => _handleVideoAction(videos[index], action),
        );
      },
    );
  }

  /// 构建底部浮动按钮
  Widget _buildFloatingButton() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 32,
      child: BlocBuilder<CompressionProgressCubit, CompressionProgressState>(
        builder: (context, state) {
          if (state.isAllProcessed && state.completedCount > 0) {
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
                onPressed: () => Navigator.of(context).pop(),
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
                    const Icon(Icons.check_circle),
                    const SizedBox(width: 8),
                    Text(
                      '完成 (已节省 ${state.formattedTotalSavings})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// 处理视频操作
  Future<void> _handleVideoAction(
      VideoCompressionInfo videoInfo, VideoAction action) async {
    switch (action) {
      case VideoAction.cancel:
        _showCancelVideoConfirmation(context, videoInfo);
        break;
      case VideoAction.retry:
        try {
          await _progressCubit.retryVideo(videoInfo.video.id);
        } catch (error) {
          if (!mounted) return;
          _showErrorDialog(
            title: '重新压缩失败',
            message: '无法重新压缩视频，请稍后重试',
            error: error.toString(),
          );
        }
        break;
      case VideoAction.saveToPhotos:
        _executeSaveToPhotos(videoInfo);
        break;
    }
  }

  /// 保存压缩视频到相册
  Future<void> _executeSaveToPhotos(VideoCompressionInfo videoInfo) async {
    try {
      await _progressCubit.saveVideoToPhotos(videoInfo);
    } catch (error) {
      if (!mounted) return;
      _showErrorDialog(
        title: '保存失败',
        message: '无法保存压缩视频到相册，请检查相册权限和存储空间',
        error: error.toString(),
      );
      return;
    }

    try {
      await _progressCubit.deleteOriginalVideo(videoInfo);
      if (!mounted) return;
      _showSnackBar('已保存压缩视频并删除原视频');
    } catch (_) {
      // ignore: empty_catches
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.prosperityGold,
      ),
    );
  }

  /// 显示错误对话框
  void _showErrorDialog({
    required String title,
    required String message,
    required String error,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.prosperityGray,
        title: Row(
          children: [
            const Icon(Icons.error_outline,
                color: AppTheme.prosperityDarkGold, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: AppTheme.prosperityGold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                color: AppTheme.prosperityLightGold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  '查看详细错误',
                  style: TextStyle(
                    color: AppTheme.prosperityLightGold,
                    fontSize: 14,
                  ),
                ),
                iconColor: AppTheme.prosperityLightGold,
                collapsedIconColor: AppTheme.prosperityLightGold,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      error,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '关闭',
              style: TextStyle(color: AppTheme.prosperityLightGold),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示取消视频确认对话框
  void _showCancelVideoConfirmation(
      BuildContext context, VideoCompressionInfo videoInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.prosperityGray,
        title: const Text(
          '确认取消',
          style: TextStyle(color: AppTheme.prosperityGold),
        ),
        content: Text(
          videoInfo.status == VideoCompressionStatus.compressing
              ? '确定要取消正在压缩的视频吗？\n当前进度将丢失。'
              : '确定要从队列中移除这个视频吗？',
          style: const TextStyle(color: AppTheme.prosperityLightGold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '取消',
              style: TextStyle(color: AppTheme.prosperityLightGold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _progressCubit.cancelVideo(videoInfo.video.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.prosperityDarkGold,
              foregroundColor: AppTheme.prosperityBlack,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示取消所有压缩确认对话框
  void _showCancelAllConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.prosperityGray,
        title: const Text(
          '停止所有压缩',
          style: TextStyle(color: AppTheme.prosperityGold),
        ),
        content: const Text(
          '确定要停止所有压缩任务吗？\n正在进行的压缩将被取消，进度将丢失。',
          style: TextStyle(color: AppTheme.prosperityLightGold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '取消',
              style: TextStyle(color: AppTheme.prosperityLightGold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _progressCubit.cancelAllCompression();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.prosperityDarkGold,
              foregroundColor: AppTheme.prosperityBlack,
            ),
            child: const Text('停止所有'),
          ),
        ],
      ),
    );
  }

  /// 显示退出确认对话框并处理退出逻辑
  Future<void> _showExitConfirmation(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.prosperityGray,
        title: const Text(
          '确认退出',
          style: TextStyle(color: AppTheme.prosperityGold),
        ),
        content: const Text(
          '压缩任务正在进行中。\n退出将取消所有未完成的压缩。',
          style: TextStyle(color: AppTheme.prosperityLightGold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              '继续压缩',
              style: TextStyle(color: AppTheme.prosperityLightGold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.prosperityDarkGold,
              foregroundColor: AppTheme.prosperityBlack,
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (shouldExit == true && context.mounted) {
      _progressCubit.cancelAllCompression();
      Navigator.of(context).pop();
    }
  }
}

/// 视频操作枚举
enum VideoAction {
  cancel,
  retry,
  saveToPhotos,
}

/// 视频进度项组件
class _VideoProgressItem extends StatelessWidget {
  final String videoId;
  final Function(VideoAction) onAction;

  const _VideoProgressItem({
    super.key,
    required this.videoId,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CompressionProgressCubit, CompressionProgressState,
        VideoCompressionInfo?>(
      selector: (state) {
        try {
          return state.videos.firstWhere((v) => v.video.id == videoId);
        } catch (e) {
          return null;
        }
      },
      builder: (context, videoInfo) {
        if (videoInfo == null) {
          return const SizedBox.shrink();
        }

        return _buildContent(videoInfo);
      },
    );
  }

  /// 构建内容
  Widget _buildContent(VideoCompressionInfo videoInfo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: AppTheme.prosperityGray,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 视频信息行
            Row(
              children: [
                // 缩略图（VideoThumbnail 内部已缓存 Future）
                VideoThumbnail(id: videoInfo.video.id),

                const SizedBox(width: 12),

                // 视频基本信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 状态信息
                      Text(
                        videoInfo.video.fileSize,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.prosperityLightGold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // 视频时长，格式化显示
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            videoInfo.video.formattedDuration,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 视频创建时间，格式化显示
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            // 视频创建时间，格式化显示
                            formatDateToFriendlyString(
                                videoInfo.video.creationDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 操作按钮
                _buildActionButton(videoInfo),
              ],
            ),

            // 进度信息
            if (videoInfo.status == VideoCompressionStatus.compressing ||
                (videoInfo.status == VideoCompressionStatus.completed &&
                    videoInfo.progress > 0)) ...[
              const SizedBox(height: 12),
              _buildProgressSection(videoInfo),
            ],

            // 错误信息
            if (videoInfo.status == VideoCompressionStatus.error &&
                videoInfo.errorMessage != null) ...[
              const SizedBox(height: 12),
              _buildErrorSection(videoInfo),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建进度区域
  Widget _buildProgressSection(VideoCompressionInfo videoInfo) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              videoInfo.status == VideoCompressionStatus.compressing
                  ? '压缩进度'
                  : '已完成',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.prosperityLightGold,
              ),
            ),
            Row(
              children: [
                Text(
                  '${(videoInfo.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.prosperityGold,
                  ),
                ),
                if (videoInfo.estimatedTimeRemaining != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '剩余 ${videoInfo.formattedTimeRemaining}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.prosperityLightGray,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: videoInfo.progress,
          backgroundColor: AppTheme.prosperityLightGray.withValues(alpha: 0.3),
          valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(videoInfo)),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  /// 构建错误信息区域
  Widget _buildErrorSection(VideoCompressionInfo videoInfo) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.error_outline,
          color: AppTheme.prosperityLightGold,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            videoInfo.errorMessage!,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.prosperityLightGold,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton(VideoCompressionInfo videoInfo) {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: _getOnPressed(videoInfo),
        style: ElevatedButton.styleFrom(
          backgroundColor: _getButtonColor(videoInfo),
          foregroundColor: _getButtonTextColor(videoInfo),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          videoInfo.actionButtonText,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// 获取状态颜色
  Color _getStatusColor(VideoCompressionInfo videoInfo) {
    switch (videoInfo.status) {
      case VideoCompressionStatus.waitingDownload:
        return AppTheme.prosperityLightGray;
      case VideoCompressionStatus.waiting:
        return AppTheme.prosperityLightGold;
      case VideoCompressionStatus.downloading:
        return AppTheme.prosperityLightGold;
      case VideoCompressionStatus.compressing:
        return AppTheme.prosperityGold;
      case VideoCompressionStatus.completed:
        return AppTheme.prosperityGold;
      case VideoCompressionStatus.cancelled:
        return AppTheme.prosperityLightGray;
      case VideoCompressionStatus.error:
        return AppTheme.prosperityDarkGold;
    }
  }

  /// 获取按钮颜色
  Color _getButtonColor(VideoCompressionInfo videoInfo) {
    switch (videoInfo.status) {
      case VideoCompressionStatus.waitingDownload:
      case VideoCompressionStatus.waiting:
      case VideoCompressionStatus.downloading:
      case VideoCompressionStatus.compressing:
        return AppTheme.prosperityGold.withValues(alpha: 0.1);
      case VideoCompressionStatus.completed:
        return AppTheme.prosperityGold.withValues(alpha: 0.2);
      case VideoCompressionStatus.cancelled:
      case VideoCompressionStatus.error:
        return AppTheme.prosperityGold.withValues(alpha: 0.2);
    }
  }

  /// 获取按钮文字颜色
  Color _getButtonTextColor(VideoCompressionInfo videoInfo) {
    switch (videoInfo.status) {
      case VideoCompressionStatus.waitingDownload:
      case VideoCompressionStatus.waiting:
      case VideoCompressionStatus.downloading:
      case VideoCompressionStatus.compressing:
        return AppTheme.prosperityGold;
      case VideoCompressionStatus.completed:
      case VideoCompressionStatus.cancelled:
      case VideoCompressionStatus.error:
        return AppTheme.prosperityGold;
    }
  }

  /// 获取按钮点击事件
  VoidCallback? _getOnPressed(VideoCompressionInfo videoInfo) {
    switch (videoInfo.status) {
      case VideoCompressionStatus.waitingDownload:
      case VideoCompressionStatus.waiting:
      case VideoCompressionStatus.downloading:
      case VideoCompressionStatus.compressing:
        return () => onAction(VideoAction.cancel);
      case VideoCompressionStatus.completed:
        return () => onAction(VideoAction.saveToPhotos);
      case VideoCompressionStatus.cancelled:
      case VideoCompressionStatus.error:
        return () => onAction(VideoAction.retry);
    }
  }
}
