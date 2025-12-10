import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

/// 主操作按钮 - 金色胶囊形按钮，用于底部悬浮操作
///
/// 特点：
/// - 高度 56px，圆角 28px（胶囊形）
/// - 金色背景，黑色前景
/// - 带阴影效果
/// - 支持图标、加载态、禁用态
class PrimaryActionButton extends StatelessWidget {
  /// 按钮文字
  final String text;

  /// 点击回调，为 null 时按钮禁用
  final VoidCallback? onPressed;

  /// 前置图标（可选）
  final IconData? icon;

  /// 是否显示加载状态
  final bool isLoading;

  const PrimaryActionButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
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
        onPressed: _isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isEnabled
              ? AppTheme.prosperityGold
              : AppTheme.prosperityLightGray,
          foregroundColor: _isEnabled
              ? AppTheme.prosperityBlack
              : AppTheme.prosperityLightGold.withValues(alpha: 0.5),
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.prosperityBlack),
                ),
              ),
              const SizedBox(width: 8),
            ] else if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: _isEnabled
                    ? AppTheme.prosperityBlack
                    : AppTheme.prosperityLightGold.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              text,
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
}
