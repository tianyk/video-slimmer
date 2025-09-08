import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../constants/app_theme.dart';
import '../cubits/compression_cubit.dart';
import '../models/compression_model.dart';
import '../models/video_model.dart';
import 'compression_progress_screen.dart';

class CompressionConfigScreen extends StatefulWidget {
  final List<VideoModel> selectedVideos;

  const CompressionConfigScreen({
    super.key,
    required this.selectedVideos,
  });

  @override
  State<CompressionConfigScreen> createState() =>
      _CompressionConfigScreenState();
}

class _CompressionConfigScreenState extends State<CompressionConfigScreen> {
  late final CompressionCubit _compressionCubit;

  @override
  void initState() {
    super.initState();
    _compressionCubit = CompressionCubit();
    _compressionCubit.initializeWithVideos(widget.selectedVideos);
  }

  @override
  void dispose() {
    _compressionCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _compressionCubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text('压缩设置 (${widget.selectedVideos.length}个视频)'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Stack(
          children: [
            // 主要内容区域
            BlocBuilder<CompressionCubit, CompressionState>(
              builder: (context, state) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 预设方案选择
                      _buildPresetSection(state),
                      const SizedBox(height: 24),

                      // 预计结果
                      _buildEstimateSection(state),

                      // 底部添加额外空间，避免被按钮遮挡
                      const SizedBox(height: 80),
                    ],
                  ),
                );
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
    );
  }

  /// 构建浮动按钮内容
  Widget _buildFloatingButtonContent() {
    return BlocBuilder<CompressionCubit, CompressionState>(
      builder: (context, state) {
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
            onPressed: state.canStartCompression ? _onStartCompression : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: state.canStartCompression
                  ? AppTheme.prosperityGold
                  : AppTheme.prosperityLightGray,
              foregroundColor: state.canStartCompression
                  ? AppTheme.prosperityBlack
                  : AppTheme.prosperityLightGold.withValues(alpha: 0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.isCalculatingEstimate)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.prosperityBlack),
                    ),
                  )
                else
                  const Icon(Icons.compress),
                const SizedBox(width: 8),
                Text(
                  state.isCalculatingEstimate ? '计算中...' : '开始压缩',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建预设方案选择区域
  Widget _buildPresetSection(CompressionState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '预设方案',
              style: AppTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // 高画质选项
            _PresetTile(
              preset: CompressionPreset.highQuality,
              isSelected: state.config.preset == CompressionPreset.highQuality,
              onTap: () =>
                  _compressionCubit.setPreset(CompressionPreset.highQuality),
            ),

            // 平衡模式选项
            _PresetTile(
              preset: CompressionPreset.balanced,
              isSelected: state.config.preset == CompressionPreset.balanced,
              onTap: () =>
                  _compressionCubit.setPreset(CompressionPreset.balanced),
            ),

            // 极限压缩选项
            _PresetTile(
              preset: CompressionPreset.maxCompression,
              isSelected:
                  state.config.preset == CompressionPreset.maxCompression,
              onTap: () =>
                  _compressionCubit.setPreset(CompressionPreset.maxCompression),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建预计结果区域
  Widget _buildEstimateSection(CompressionState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '预计结果',
              style: AppTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // 原始大小
            _EstimateRow(
              label: '原始大小:',
              value: state.formattedOriginalSize,
              icon: Icons.video_library,
            ),

            const SizedBox(height: 8),

            // 压缩后大小
            _EstimateRow(
              label: '压缩后约:',
              value:
                  '${state.formattedEstimatedSize} (${state.compressionPercentage})',
              icon: Icons.compress,
              isHighlighted: true,
            ),

            const SizedBox(height: 8),

            // 节省空间
            _EstimateRow(
              label: '节省空间:',
              value: state.formattedSavings,
              icon: Icons.storage,
              valueColor: AppTheme.prosperityGold,
            ),

            // 计算中时显示loading
            if (state.isCalculatingEstimate) ...[
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.prosperityGold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 开始压缩
  void _onStartCompression() {
    // 导航到压缩进度页面
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CompressionProgressScreen(
          selectedVideos: widget.selectedVideos,
          compressionConfig: _compressionCubit.state.config,
        ),
      ),
    );
  }
}

/// 预设选项瓦片组件
class _PresetTile extends StatelessWidget {
  final CompressionPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetTile({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final config = CompressionPresetConfig.getPresetConfig(preset);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppTheme.prosperityGold
                  : AppTheme.prosperityLightGold.withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
            color: isSelected
                ? AppTheme.prosperityGold.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              // 选择状态指示器
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.prosperityGold
                        : AppTheme.prosperityLightGold.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  color:
                      isSelected ? AppTheme.prosperityGold : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 14,
                        color: AppTheme.prosperityBlack,
                      )
                    : null,
              ),

              const SizedBox(width: 12),

              // 预设信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppTheme.prosperityGold
                            : AppTheme.prosperityLightGold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.prosperityLightGold
                            .withValues(alpha: 0.7), // 金色主题的较暗版本
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 预估结果行组件
class _EstimateRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isHighlighted;
  final Color? valueColor;

  const _EstimateRow({
    required this.label,
    required this.value,
    required this.icon,
    this.isHighlighted = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.prosperityGold,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.prosperityLightGold
                .withValues(alpha: 0.7), // 金色主题的较暗版本
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isHighlighted ? 16 : 14,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
              color: valueColor ??
                  (isHighlighted
                      ? AppTheme.prosperityLightGold
                      : AppTheme.prosperityLightGold.withValues(alpha: 0.7)),
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
