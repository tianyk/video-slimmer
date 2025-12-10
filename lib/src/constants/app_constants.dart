class AppConstants {
  static const String appName = '视频压缩';
  static const String i18nAssetsDirectory = 'assets/i18n';
  static const String fallbackLocaleCode = 'en-US';

  // File name related
  static const String compressedSuffix = '_compressed';

  // 权限相关
  static const String permissionTitle = '访问相册权限';
  static const String permissionDescription =
      '为了帮您压缩视频，我们需要访问您的相册。请在设置中授权后重新打开应用。';

  // IAP 相关常量
  /// 免费版最大可选视频数量
  static const int maxFreeVideoSelection = 5;

  /// IAP 产品ID（与 App Store Connect 配置一致）
  static const String proProductId = 'cc.kekek.videoslimmer.pro';

  /// 本地存储 Key
  static const String purchaseStatusKey = 'is_pro_purchased';
}
