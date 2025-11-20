import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../constants/app_constants.dart';
import '../constants/app_theme.dart';
import '../libs/localization.dart';
import '../services/permission_service.dart';

class PermissionDeniedScreen extends StatelessWidget {
  const PermissionDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.prosperityBlack,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.prosperityBlack,
              AppTheme.prosperityGray,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Remix.image_line,
                  size: 80,
                  color: AppTheme.prosperityGold,
                ),
                const SizedBox(height: 24),
                Text(
                  tr(AppConstants.permissionTitle),
                  style: AppTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  tr(AppConstants.permissionDescription),
                  style: AppTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => _requestPermission(context),
                  child: Text(tr('前往设置')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestPermission(BuildContext context) async {
    // 弹出权限请求指引
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr('请前往iOS设置 > 隐私与安全性 > 照片 > 视频瘦身器 > 选择"所有照片"'),
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    // 打开iOS设置
    await PermissionService.openSystemSettings();
  }
}
