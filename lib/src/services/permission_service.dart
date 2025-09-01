import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// 检测并请求相册权限
  static Future<bool> requestStoragePermission() async {
    const permission = Permission.photos;
    
    final status = await permission.status;
    
    if (status == PermissionStatus.granted) {
      return true;
    } else if (status == PermissionStatus.denied) {
      final result = await permission.request();
      return result == PermissionStatus.granted;
    } else if (status == PermissionStatus.permanentlyDenied) {
      return false; // 用户已永久拒绝
    }
    
    return false;
  }

  /// 打开应用设置
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// 检查所有必要权限
  static Future<bool> checkAllPermissions() async {
    const permission = Permission.photos;
    final status = await permission.status;
    return status == PermissionStatus.granted;
  }
}