import Flutter
import UIKit
import AVFoundation

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
    let videoMetadataChannel = FlutterMethodChannel(name: "video_metadata", binaryMessenger: controller.binaryMessenger)
    
    // 设置方法调用处理器
    videoMetadataChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      // 根据调用的方法名分发到对应处理函数
      if call.method == "getVideoFrameRate" {
        self.getVideoFrameRate(call: call, result: result)
      } else {
        // 未实现的方法返回错误
        result(FlutterMethodNotImplemented)
      }
    }
    
    // 注册 Flutter 插件
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  /// 获取视频文件的帧率
  /// 使用 iOS AVFoundation 框架读取视频元数据
  /// - Parameters:
  ///   - call: Flutter 方法调用对象，包含参数
  ///   - result: 结果回调，用于返回帧率值或错误信息
  private func getVideoFrameRate(call: FlutterMethodCall, result: @escaping FlutterResult) {
    // 解析方法参数，获取视频文件路径
    guard let args = call.arguments as? [String: Any],
          let filePath = args["filePath"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid file path", details: nil))
      return
    }
    
    // 构建文件 URL
    let fileURL = URL(fileURLWithPath: filePath)
    
    // 验证文件是否存在于文件系统中
    guard FileManager.default.fileExists(atPath: filePath) else {
      result(FlutterError(code: "FILE_NOT_FOUND", message: "Video file not found", details: nil))
      return
    }
    
    // 创建 AVAsset 实例来访问视频文件
    // AVAsset 提供对媒体资源的抽象访问，无需加载整个文件到内存
    let asset = AVAsset(url: fileURL)
    
    // 获取视频轨道数组（一个视频文件可能包含多个视频轨道）
    let videoTracks = asset.tracks(withMediaType: .video)
    
    // 确保至少有一个视频轨道
    guard let videoTrack = videoTracks.first else {
      result(FlutterError(code: "NO_VIDEO_TRACK", message: "No video track found", details: nil))
      return
    }
    
    // 获取视频轨道的标称帧率
    // nominalFrameRate 表示视频的目标播放帧率（单位：fps）
    let frameRate = videoTrack.nominalFrameRate
    
    // 验证帧率值的有效性并返回结果
    if frameRate > 0 {
      // 成功获取帧率，转换为 Double 类型返回给 Flutter
      result(Double(frameRate))
    } else {
      // 帧率无效（可能是损坏的视频文件或不支持的格式）
      result(FlutterError(code: "INVALID_FRAME_RATE", message: "Invalid frame rate", details: nil))
    }
  }
}
