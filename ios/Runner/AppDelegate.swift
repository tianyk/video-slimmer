import Flutter
import UIKit
import AVFoundation
import Photos

/// 进度流处理器
class ProgressStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    print("[ProgressStream] 开始监听进度")
    return nil
  }
  
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    print("[ProgressStream] 停止监听进度")
    return nil
  }
  
  func sendProgress(videoId: String, progress: Double) {
    let data: [String: Any] = [
      "videoId": videoId,
      "progress": progress
    ]
    eventSink?(data)
  }
}

/// VideoSlimmer iOS 应用入口类
/// 负责 Flutter 应用的初始化和原生功能桥接
@main
@objc class AppDelegate: FlutterAppDelegate {
  
  // 进度流处理器
  private let progressHandler = ProgressStreamHandler()
  
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
      } else if call.method == "getVideoFilePath" {
        self.getVideoFilePath(call: call, result: result)
      } else {
        // 未实现的方法返回错误
        result(FlutterMethodNotImplemented)
      }
    }
    
    // 创建进度事件通道
    let progressChannel = FlutterEventChannel(
      name: "cc.kekek.videoslimmer/progress",
      binaryMessenger: controller.binaryMessenger
    )
    progressChannel.setStreamHandler(progressHandler)
    
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
  
  /// 获取视频文件路径
  ///
  /// 此方法会获取 PHAsset 对应的视频文件路径：
  /// - 如果视频在本地，直接返回路径
  /// - 如果视频在 iCloud，会触发下载并返回路径
  /// - 保留完整的视频元数据
  ///
  /// - Parameters:
  ///   - call: Flutter 方法调用对象，包含以下参数：
  ///     - assetId: PHAsset 的 localIdentifier
  ///   - result: 结果回调，返回视频文件路径（String）
  ///
  /// - Note:
  ///   - 返回的路径可能指向系统相册目录或临时缓存目录
  ///   - 如果网络不可用且视频在 iCloud，会返回错误
  private func getVideoFilePath(call: FlutterMethodCall, result: @escaping FlutterResult) {
    // 解析参数
    guard let args = call.arguments as? [String: Any],
          let assetId = args["assetId"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "参数无效", details: nil))
      return
    }
    
    // 获取 PHAsset
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = fetchResult.firstObject else {
      result(FlutterError(code: "ASSET_NOT_FOUND", message: "视频资源不存在", details: nil))
      return
    }
    
    // 检查是否为视频
    guard asset.mediaType == .video else {
      result(FlutterError(code: "INVALID_MEDIA_TYPE", message: "资源不是视频类型", details: nil))
      return
    }
    
    print("[VideoFilePath] 开始获取视频文件路径")
    print("[VideoFilePath] Asset ID: \(assetId)")
    
    // 配置请求选项
    let options = PHVideoRequestOptions()
    options.version = .original  // 获取原始视频
    options.deliveryMode = .highQualityFormat  // 高质量格式
    options.isNetworkAccessAllowed = true  // 允许网络访问（从 iCloud 下载）
    
    // 设置进度回调
    var lastProgress: Double = 0
    options.progressHandler = { progress, error, stop, info in
      DispatchQueue.main.async {
        // 只在进度变化超过 5% 时打印，避免日志过多
        if progress - lastProgress > 0.05 || progress == 1.0 {
          print("[VideoFilePath] 下载进度: \(Int(progress * 100))%")
          lastProgress = progress
          
          // 通过 EventChannel 发送进度到 Flutter
          self.progressHandler.sendProgress(videoId: assetId, progress: progress)
        }
        
        if let error = error {
          print("[VideoFilePath] 下载错误: \(error.localizedDescription)")
        }
      }
    }
    
    // 请求视频文件
    PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
      // 检查是否被取消
      if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
        print("[VideoFilePath] 请求被取消")
        result(FlutterError(code: "CANCELLED", message: "操作被取消", details: nil))
        return
      }
      
      // 检查是否有错误
      if let error = info?[PHImageErrorKey] as? Error {
        print("[VideoFilePath] 请求失败: \(error.localizedDescription)")
        result(FlutterError(
          code: "REQUEST_FAILED",
          message: "获取视频文件失败: \(error.localizedDescription)",
          details: nil
        ))
        return
      }
      
      // 检查是否获取到 AVAsset
      guard let urlAsset = avAsset as? AVURLAsset else {
        print("[VideoFilePath] 无法获取 AVURLAsset")
        result(FlutterError(code: "INVALID_ASSET", message: "无法获取视频资源", details: nil))
        return
      }
      
      let filePath = urlAsset.url.path
      print("[VideoFilePath] 视频文件路径: \(filePath)")
      print("[VideoFilePath] 完成！")
      
      // 直接返回文件路径
      result(filePath)
    }
  }
}
