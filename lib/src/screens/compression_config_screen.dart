import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../constants/app_theme.dart';
import '../cubits/compression_cubit.dart';
import '../models/compression_model.dart';
import '../models/video_model.dart';

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

                      // 自定义设置 (V1.5功能，暂时隐藏)
                      if (state.config.preset == CompressionPreset.custom)
                        _buildCustomSettingsSection(state),

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

  /// 构建自定义设置区域 (V1.5功能)
  Widget _buildCustomSettingsSection(CompressionState state) {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: const Text('自定义设置', style: AppTheme.titleMedium),
          initiallyExpanded: state.isCustomSettingsExpanded,
          onExpansionChanged: (expanded) {
            if (!expanded) _compressionCubit.toggleCustomSettings();
          },
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 分辨率设置
                  _buildResolutionSetting(state),
                  const SizedBox(height: 16),

                  // 质量设置
                  _buildQualitySetting(state),
                  const SizedBox(height: 16),

                  // 帧率设置
                  _buildFrameRateSetting(state),
                  const SizedBox(height: 16),

                  // 音频设置
                  _buildAudioSetting(state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建分辨率设置
  Widget _buildResolutionSetting(CompressionState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('分辨率', style: AppTheme.bodyLarge),
        const SizedBox(height: 8),
        DropdownButtonFormField<VideoResolution>(
          value: state.config.customResolution ?? VideoResolution.original,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: VideoResolution.values.map((resolution) {
            return DropdownMenuItem(
              value: resolution,
              child: Text(resolution.displayName),
            );
          }).toList(),
          onChanged: (resolution) {
            if (resolution != null) {
              _compressionCubit.updateCustomResolution(resolution);
            }
          },
        ),
      ],
    );
  }

  /// 构建质量设置
  Widget _buildQualitySetting(CompressionState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '画质设置 (CRF: ${state.config.customCRF ?? 23})',
          style: AppTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Slider(
          value: (state.config.customCRF ?? 23).toDouble(),
          min: 18,
          max: 28,
          divisions: 10,
          activeColor: AppTheme.prosperityGold,
          label: '${state.config.customCRF ?? 23}',
          onChanged: (value) {
            _compressionCubit.updateCustomCRF(value.round());
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '高画质',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.prosperityLightGold
                    .withValues(alpha: 0.7), // 金色主题的较暗版本
              ),
            ),
            Text(
              '小文件',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.prosperityLightGold
                    .withValues(alpha: 0.7), // 金色主题的较暗版本
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建帧率设置
  Widget _buildFrameRateSetting(CompressionState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('帧率设置', style: AppTheme.bodyLarge),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('保持原始帧率'),
          value: state.config.keepOriginalFrameRate,
          activeColor: AppTheme.prosperityGold,
          onChanged: (value) {
            _compressionCubit.toggleKeepOriginalFrameRate();
          },
          contentPadding: EdgeInsets.zero,
        ),
        if (!state.config.keepOriginalFrameRate) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<double>(
            value: state.config.customFrameRate ?? 30.0,
            decoration: const InputDecoration(
              labelText: '自定义帧率',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 24.0, child: Text('24 fps')),
              DropdownMenuItem(value: 30.0, child: Text('30 fps')),
              DropdownMenuItem(value: 60.0, child: Text('60 fps')),
            ],
            onChanged: (frameRate) {
              if (frameRate != null) {
                _compressionCubit.updateCustomFrameRate(frameRate);
              }
            },
          ),
        ],
      ],
    );
  }

  /// 构建音频设置
  Widget _buildAudioSetting(CompressionState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('音频设置', style: AppTheme.bodyLarge),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('保持原始音频'),
          value: state.config.keepOriginalAudio,
          activeColor: AppTheme.prosperityGold,
          onChanged: (value) {
            _compressionCubit.toggleKeepOriginalAudio();
          },
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: state.config.audioQuality,
          decoration: const InputDecoration(
            labelText: '音频质量',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: const [
            DropdownMenuItem(value: 96, child: Text('96 kbps (低)')),
            DropdownMenuItem(value: 128, child: Text('128 kbps (标准)')),
            DropdownMenuItem(value: 192, child: Text('192 kbps (高)')),
            DropdownMenuItem(value: 256, child: Text('256 kbps (极高)')),
          ],
          onChanged: (quality) {
            if (quality != null) {
              _compressionCubit.updateAudioQuality(quality);
            }
          },
        ),
      ],
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
              valueColor: Colors.green,
            ),

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
    // 显示压缩任务信息
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '准备压缩 ${widget.selectedVideos.length} 个视频\n'
          '预计节省 ${_compressionCubit.state.formattedSavings}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    // TODO: 导航到压缩进度页面
    // final taskInfo = _compressionCubit.getCompressionTaskInfo();
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (context) => CompressionProgressScreen(taskInfo: taskInfo),
    //   ),
    // );
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
