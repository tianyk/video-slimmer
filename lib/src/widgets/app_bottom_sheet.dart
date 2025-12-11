import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

/// 显示应用统一风格的底部弹窗
///
/// 自带 DragHandle 和统一的样式（圆角、背景色）
/// [builder] 接收弹窗的 BuildContext，可用于 Navigator.pop(context) 关闭弹窗
/// [title] 可选的标题文字，传入后会显示统一样式的标题栏
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (modalContext) => AppBottomSheetContainer(
      title: title,
      child: builder(modalContext),
    ),
  );
}

/// 底部弹窗容器
/// 提供统一的外观：圆角、背景色、DragHandle、可选标题栏
class AppBottomSheetContainer extends StatelessWidget {
  final Widget child;
  final String? title;

  const AppBottomSheetContainer({
    super.key,
    required this.child,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.prosperityGray,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const _DragHandle(),
            if (title != null)
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// 底部弹窗顶部拖动指示条
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppTheme.prosperityLightGray,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
