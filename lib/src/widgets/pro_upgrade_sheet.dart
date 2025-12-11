import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:remixicon/remixicon.dart';
import '../constants/app_constants.dart';
import '../constants/app_theme.dart';
import '../cubits/purchase_cubit.dart';
import '../libs/localization.dart';
import '../models/purchase_state.dart';
import 'app_bottom_sheet.dart';
import 'primary_action_button.dart';

/// Pro 版升级介绍弹窗内容
/// 使用 [showProUpgradeSheet] 函数来显示
class ProUpgradeSheet extends StatelessWidget {
  final int selectedCount;
  final VoidCallback? onPurchaseSuccess;

  const ProUpgradeSheet({
    super.key,
    required this.selectedCount,
    this.onPurchaseSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PurchaseCubit, PurchaseState>(
      listener: (context, state) {
        if (state.isPro) {
          onPurchaseSuccess?.call();
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.prosperityDarkGold,
            ),
          );
          context.read<PurchaseCubit>().clearError();
        }
      },
      builder: (context, state) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            _buildTitle(),
            const SizedBox(height: 20),
            _buildFeatureCard(),
            const SizedBox(height: 28),
            _buildBenefitsList(),
            const SizedBox(height: 20),
            _buildSelectionHint(),
            const SizedBox(height: 24),
            _buildPurchaseButton(context, state),
            const SizedBox(height: 12),
            _buildRestoreButton(context, state),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  /// 构建标题栏：皇冠图标 + "Video Slimmer Pro"
  Widget _buildTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Remix.vip_crown_2_fill,
            color: AppTheme.prosperityGold, size: 28),
        const SizedBox(width: 8),
        Text(
          'Video Slimmer Pro',
          style: AppTheme.titleLarge,
        ),
      ],
    );
  }

  /// 构建功能展示卡片：无限符号 + 视频图标 + 核心卖点文案
  Widget _buildFeatureCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.prosperityBlack,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Remix.video_fill,
                color: AppTheme.prosperityGold.withValues(alpha: 0.6),
                size: 28,
              ),
              const SizedBox(width: 8),
              const Icon(
                Remix.infinity_fill,
                color: AppTheme.prosperityGold,
                size: 40,
              ),
              const SizedBox(width: 8),
              Icon(
                Remix.video_fill,
                color: AppTheme.prosperityGold.withValues(alpha: 0.6),
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            tr('批量压缩，无限视频'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.prosperityLightGold,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建权益列表：展示 Pro 版的核心权益
  Widget _buildBenefitsList() {
    final benefits = [
      tr('一次购买，永久使用'),
      tr('无限批量压缩视频'),
      tr('支持未来所有更新'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: benefits.map((benefit) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Remix.checkbox_circle_fill,
                  color: AppTheme.prosperityGold,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  benefit,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.prosperityLightGold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 构建当前选择提示：显示已选视频数量与免费版限制
  Widget _buildSelectionHint() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.prosperityDarkGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Remix.information_line,
            color: AppTheme.prosperityGold.withValues(alpha: 0.7),
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              tr('当前已选择 {count} 个视频，免费版最多支持 {max} 个')
                  .replaceAll('{count}', '$selectedCount')
                  .replaceAll('{max}', '${AppConstants.maxFreeVideoSelection}'),
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.prosperityLightGold.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建购买按钮：显示动态价格，点击发起购买
  Widget _buildPurchaseButton(BuildContext context, PurchaseState state) {
    final buttonText = state.priceString != null
        ? '${tr('立即解锁')} - ${state.priceString}'
        : tr('立即解锁');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: PrimaryActionButton(
        text: buttonText,
        onPressed: state.isLoading
            ? null
            : () => context.read<PurchaseCubit>().purchasePro(),
        isLoading: state.isLoading,
      ),
    );
  }

  /// 构建恢复购买按钮：用于已购用户恢复购买记录
  Widget _buildRestoreButton(BuildContext context, PurchaseState state) {
    return TextButton(
      onPressed: state.isLoading
          ? null
          : () => context.read<PurchaseCubit>().restorePurchases(),
      child: Text(
        tr('恢复购买'),
        style: TextStyle(
          fontSize: 14,
          color: state.isLoading
              ? AppTheme.prosperityLightGray
              : AppTheme.prosperityGold,
        ),
      ),
    );
  }
}

/// 显示 Pro 升级弹窗的便捷函数
///
/// [onPurchaseSuccess] 回调会传入 modalContext，方便关闭弹窗
Future<void> showProUpgradeSheet({
  required BuildContext context,
  required int selectedCount,
  void Function(BuildContext modalContext)? onPurchaseSuccess,
}) {
  return showAppBottomSheet(
    context: context,
    builder: (modalContext) => BlocProvider.value(
      value: context.read<PurchaseCubit>(),
      child: ProUpgradeSheet(
        selectedCount: selectedCount,
        onPurchaseSuccess: onPurchaseSuccess != null
            ? () => onPurchaseSuccess(modalContext)
            : null,
      ),
    ),
  );
}
