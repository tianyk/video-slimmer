import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// 检测并请求相册权限
  static Future<bool> requestStoragePermission() async {
    const permission = Permission.photos;

    final status = await permission.status;

    // 如果已经有权限，直接返回
    if (status == PermissionStatus.granted) {
      return true;
    }

    // 对于其他所有状态（包括首次安装），都请求权限
    final result = await permission.request();
    return result == PermissionStatus.granted;
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
