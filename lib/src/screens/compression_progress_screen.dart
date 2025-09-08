import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../constants/app_theme.dart';
import '../cubits/compression_progress_cubit.dart';
import '../models/compression_progress_model.dart';
import '../models/video_model.dart';
import '../models/compression_model.dart';

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

    // 自动开始压缩
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      child: Scaffold(
        appBar: AppBar(
          title: const Text('压缩进度'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _showExitConfirmation(context),
          ),
          actions: [
            BlocBuilder<CompressionProgressCubit, CompressionProgressState>(
              builder: (context, state) {
                if (state.taskInfo.status == CompressionTaskStatus.inProgress) {
                  return IconButton(
                    icon: const Icon(Icons.stop),
                    onPressed: () => _showCancelAllConfirmation(context),
                    tooltip: '停止所有压缩',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            // 主要内容区域
            BlocBuilder<CompressionProgressCubit, CompressionProgressState>(
              builder: (context, state) {
                return Column(
                  children: [
                    // 整体进度区域
                    _buildOverallProgressSection(state.taskInfo),

                    // 视频列表
                    Expanded(
                      child: _buildVideoList(state.taskInfo),
                    ),
                  ],
                );
              },
            ),

            // 底部浮动按钮
            _buildFloatingButton(),
          ],
        ),
      ),
    );
  }

  /// 构建整体进度区域
  Widget _buildOverallProgressSection(CompressionTaskInfo taskInfo) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.prosperityGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.prosperityGold.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态标题
          Row(
            children: [
              Icon(
                _getStatusIcon(taskInfo.status),
                color: AppTheme.prosperityGold,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                taskInfo.statusText,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.prosperityGold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 整体进度条
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '整体进度: ${taskInfo.progressText}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.prosperityLightGold,
                    ),
                  ),
                  Text(
                    '${(taskInfo.overallProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.prosperityGold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: taskInfo.overallProgress,
                backgroundColor:
                    AppTheme.prosperityLightGray.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.prosperityGold),
                minHeight: 8,
              ),
            ],
          ),

          // 统计信息
          if (taskInfo.status != CompressionTaskStatus.preparing) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatChip(
                    '已完成', taskInfo.completedCount, AppTheme.prosperityGold),
                const SizedBox(width: 8),
                _buildStatChip(
                    '等待中', taskInfo.waitingCount, AppTheme.prosperityLightGold),
                const SizedBox(width: 8),
                if (taskInfo.cancelledCount > 0)
                  _buildStatChip('已取消', taskInfo.cancelledCount,
                      AppTheme.prosperityLightGray),
                const SizedBox(width: 8),
                if (taskInfo.errorCount > 0)
                  _buildStatChip('失败', taskInfo.errorCount, Colors.red),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 构建统计芯片
  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  /// 构建视频列表
  Widget _buildVideoList(CompressionTaskInfo taskInfo) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: taskInfo.videos.length,
      itemBuilder: (context, index) {
        final videoInfo = taskInfo.videos[index];
        return _VideoProgressItem(
          key: ValueKey(videoInfo.video.id),
          videoInfo: videoInfo,
          onAction: (action) => _handleVideoAction(videoInfo, action),
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
          if (state.taskInfo.status == CompressionTaskStatus.completed) {
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
                      '完成 (已节省 ${state.taskInfo.formattedTotalSavings})',
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

  /// 获取状态图标
  IconData _getStatusIcon(CompressionTaskStatus status) {
    switch (status) {
      case CompressionTaskStatus.preparing:
        return Icons.hourglass_empty;
      case CompressionTaskStatus.inProgress:
        return Icons.play_circle;
      case CompressionTaskStatus.paused:
        return Icons.pause_circle;
      case CompressionTaskStatus.completed:
        return Icons.check_circle;
      case CompressionTaskStatus.cancelled:
        return Icons.cancel;
    }
  }

  /// 处理视频操作
  void _handleVideoAction(VideoCompressionInfo videoInfo, VideoAction action) {
    switch (action) {
      case VideoAction.cancel:
        _showCancelVideoConfirmation(context, videoInfo);
        break;
      case VideoAction.retry:
        _progressCubit.retryVideo(videoInfo.video.id);
        break;
      case VideoAction.preview:
        _showVideoPreview(context, videoInfo);
        break;
    }
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('停止所有'),
          ),
        ],
      ),
    );
  }

  /// 显示退出确认对话框
  void _showExitConfirmation(BuildContext context) {
    final state = _progressCubit.state;

    if (state.taskInfo.status == CompressionTaskStatus.inProgress) {
      showDialog(
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '继续压缩',
                style: TextStyle(color: AppTheme.prosperityLightGold),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _progressCubit.cancelAllCompression();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('退出'),
            ),
          ],
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  /// 显示视频预览
  void _showVideoPreview(BuildContext context, VideoCompressionInfo videoInfo) {
    // TODO: 实现视频预览功能
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('预览 ${videoInfo.video.title}'),
        backgroundColor: AppTheme.prosperityGold,
      ),
    );
  }
}

/// 视频操作枚举
enum VideoAction {
  cancel,
  retry,
  preview,
}

/// 视频进度项组件
class _VideoProgressItem extends StatelessWidget {
  final VideoCompressionInfo videoInfo;
  final Function(VideoAction) onAction;

  const _VideoProgressItem({
    required Key key,
    required this.videoInfo,
    required this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.prosperityGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor().withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 视频信息行
          Row(
            children: [
              // 状态图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getStatusColor().withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              // 视频基本信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      videoInfo.video.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.prosperityLightGold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          videoInfo.video.fileSize,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.prosperityLightGray,
                          ),
                        ),
                        if (videoInfo.compressedSize != null) ...[
                          const Text(
                            ' → ',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.prosperityLightGray,
                            ),
                          ),
                          Text(
                            videoInfo.formattedCompressedSize,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.prosperityGold,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (videoInfo.compressionRatio.isNotEmpty) ...[
                            const Text(
                              ' (-',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.prosperityLightGray,
                              ),
                            ),
                            Text(
                              videoInfo.compressionRatio,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.prosperityGold,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Text(
                              ')',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.prosperityLightGray,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // 操作按钮
              _buildActionButton(),
            ],
          ),

          // 进度信息
          if (videoInfo.status == VideoCompressionStatus.compressing ||
              (videoInfo.status == VideoCompressionStatus.completed &&
                  videoInfo.progress > 0)) ...[
            const SizedBox(height: 12),
            _buildProgressSection(),
          ],

          // 状态信息
          if (videoInfo.status != VideoCompressionStatus.waiting) ...[
            const SizedBox(height: 8),
            _buildStatusSection(),
          ],
        ],
      ),
    );
  }

  /// 构建进度区域
  Widget _buildProgressSection() {
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
          valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
          minHeight: 6,
        ),
      ],
    );
  }

  /// 构建状态区域
  Widget _buildStatusSection() {
    return Row(
      children: [
        Icon(
          _getStatusIcon(),
          color: _getStatusColor(),
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          videoInfo.statusText,
          style: TextStyle(
            fontSize: 14,
            color: _getStatusColor(),
            fontWeight: FontWeight.w500,
          ),
        ),
        if (videoInfo.errorMessage != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              videoInfo.errorMessage!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton() {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: _getOnPressed(),
        style: ElevatedButton.styleFrom(
          backgroundColor: _getButtonColor(),
          foregroundColor: _getButtonTextColor(),
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

  /// 获取状态图标
  IconData _getStatusIcon() {
    switch (videoInfo.status) {
      case VideoCompressionStatus.waiting:
        return Icons.access_time;
      case VideoCompressionStatus.compressing:
        return Icons.play_circle;
      case VideoCompressionStatus.completed:
        return Icons.check_circle;
      case VideoCompressionStatus.cancelled:
        return Icons.cancel;
      case VideoCompressionStatus.error:
        return Icons.error;
    }
  }

  /// 获取状态颜色
  Color _getStatusColor() {
    switch (videoInfo.status) {
      case VideoCompressionStatus.waiting:
        return AppTheme.prosperityLightGold;
      case VideoCompressionStatus.compressing:
        return AppTheme.prosperityGold;
      case VideoCompressionStatus.completed:
        return AppTheme.prosperityGold;
      case VideoCompressionStatus.cancelled:
        return AppTheme.prosperityLightGray;
      case VideoCompressionStatus.error:
        return Colors.red;
    }
  }

  /// 获取按钮颜色
  Color _getButtonColor() {
    switch (videoInfo.status) {
      case VideoCompressionStatus.waiting:
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
  Color _getButtonTextColor() {
    switch (videoInfo.status) {
      case VideoCompressionStatus.waiting:
      case VideoCompressionStatus.compressing:
        return AppTheme.prosperityGold;
      case VideoCompressionStatus.completed:
      case VideoCompressionStatus.cancelled:
      case VideoCompressionStatus.error:
        return AppTheme.prosperityGold;
    }
  }

  /// 获取按钮点击事件
  VoidCallback? _getOnPressed() {
    switch (videoInfo.status) {
      case VideoCompressionStatus.waiting:
      case VideoCompressionStatus.compressing:
        return () => onAction(VideoAction.cancel);
      case VideoCompressionStatus.completed:
        return () => onAction(VideoAction.preview);
      case VideoCompressionStatus.cancelled:
      case VideoCompressionStatus.error:
        return () => onAction(VideoAction.retry);
    }
  }
}
