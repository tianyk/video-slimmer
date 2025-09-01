class AppConstants {
  static const String appName = '视频压缩';

  // 权限相关
  static const String permissionTitle = '访问相册权限';
  static const String permissionDescription = '为了帮您压缩视频，我们需要访问您的相册。请在设置中授权后重新打开应用。';

  // 压缩相关
  static const int maxWidth1080p = 1920;
  static const int maxWidth720p = 1280;
  static const int maxWidth480p = 854;

  // 文件扩展名
  static const List<String> supportedExtensions = [
    'mp4',
    'mov',
    'm4v',
    'avi',
    'mkv',
    '3gp',
    'flv',
  ];

  // 默认排序
  static const String defaultSortBy = 'size';
  static const bool defaultSortDescending = true;

  // 过滤阈值
  static const int minVideoSizeMB = 10; // 最小视频大小 (MB)

  // 压缩后文件前缀
  static const String compressedPrefix = 'VSLIM_';
}
