import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// 检测并请求相册权限
  static Future<bool> requestStoragePermission() async {
    print('📋 尝试请求相册权限...');
    final status = await Permission.photos.request();
    print('📋 相册权限状态: $status');
    return status.isGranted || status.isLimited;
  }

  /// 打开应用设置
  static Future<void> openSystemSettings() async {
    await openAppSettings();
  }

  /// 检查所有必要权限
  static Future<bool> checkAllPermissions() async {
    const permission = Permission.photos;
    final status = await permission.status;
    return status == PermissionStatus.granted;
  }
}
