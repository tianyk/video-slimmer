import Flutter
import UIKit
import AVFoundation
import Photos

/// VideoSlimmer iOS 应用入口类
/// 负责 Flutter 应用的初始化和原生功能桥接
@main
@objc class AppDelegate: FlutterAppDelegate {
  
  /// 应用启动完成回调
  /// 在此处设置 MethodChannel 和注册插件
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 获取 Flutter 主控制器
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    
    // 创建视频元数据通道，用于 Flutter 与 iOS 原生代码通信
    let videoMetadataChannel = FlutterMethodChannel(name: "cc.kekek.videoslimmer", binaryMessenger: controller.binaryMessenger)
    
    // 设置方法调用处理器
    videoMetadataChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      // 根据调用的方法名分发到对应处理函数
      if call.method == "getVideoMetadata" {
        self.getVideoMetadata(call: call, result: result)
      } else {
        // 未实现的方法返回错误
        result(FlutterMethodNotImplemented)
      }
    }
    
    // 注册 Flutter 插件
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  /// 获取 PHAsset 的基本信息
  /// 
  /// 快速获取视频的核心属性：文件大小、分辨率、时长
  /// 
  /// - Parameters:
  ///   - call: Flutter 方法调用对象，包含 assetId 参数
  ///   - result: 结果回调，返回基本信息字典或错误信息
  /// 
  /// - Returns: 包含以下字段的字典：
  ///   - fileSize: 文件大小（Int64，单位：字节）
  ///   - pixelWidth: 视频像素宽度（Int）
  ///   - pixelHeight: 视频像素高度（Int）
  ///   - duration: 视频时长（Double，单位：秒）
  /// 
  /// - Note:
  ///   - 使用 PHAssetResource 获取精确的文件大小
  ///   - 使用 PHAsset 属性获取分辨率和时长
  ///   - 不会触发 iCloud 下载，只获取元数据
  ///   - 即使视频在 iCloud 中未下载，也能获取所有信息
  private func getVideoMetadata(call: FlutterMethodCall, result: @escaping FlutterResult) {
    // 解析方法参数，获取资源 ID（PHAsset 的 localIdentifier）
    guard let args = call.arguments as? [String: Any],
          let assetId = args["assetId"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid asset ID", details: nil))
      return
    }
    
    // 通过 localIdentifier 从相册中获取 PHAsset 对象
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = fetchResult.firstObject else {
      result(FlutterError(code: "ASSET_NOT_FOUND", message: "Asset not found", details: nil))
      return
    }
    
    // 获取 PHAsset 关联的资源列表并查找文件大小
    let resources = PHAssetResource.assetResources(for: asset)
    var fileSize: Int64 = 0
    for resource in resources where resource.type == .video {
      if let size = resource.value(forKey: "fileSize") as? Int64 {
        fileSize = size
        break
      }
    }
    
    // 构建基本信息字典
    let basicInfo: [String: Any] = [
      "fileSize": fileSize,
      "pixelWidth": asset.pixelWidth,
      "pixelHeight": asset.pixelHeight,
      "duration": asset.duration
    ]
    
    result(basicInfo)
  }
}
