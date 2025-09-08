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
    let videoMetadataChannel = FlutterMethodChannel(name: "cc.kevin.videoslimmer", binaryMessenger: controller.binaryMessenger)
    
    // 设置方法调用处理器
    videoMetadataChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      // 根据调用的方法名分发到对应处理函数
      if call.method == "getVideoFrameRate" {
        self.getVideoFrameRate(call: call, result: result)
      } else if call.method == "getVideoMetadata" {
        self.getVideoMetadata(call: call, result: result)
      } else if call.method == "getAssetFileSize" {
        self.getAssetFileSize(call: call, result: result)
      } else if call.method == "getAssetCloudStatus" {
        self.getAssetCloudStatus(call: call, result: result)
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
  
  /// 获取视频文件的完整元数据（包括杜比视界 HDR 检测）
  /// - Parameters:
  ///   - call: Flutter 方法调用对象，包含参数
  ///   - result: 结果回调，返回包含帧率和 HDR 信息的字典
  private func getVideoMetadata(call: FlutterMethodCall, result: @escaping FlutterResult) {
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
    let asset = AVAsset(url: fileURL)
    
    // 获取视频轨道数组
    let videoTracks = asset.tracks(withMediaType: .video)
    
    // 确保至少有一个视频轨道
    guard let videoTrack = videoTracks.first else {
      result(FlutterError(code: "NO_VIDEO_TRACK", message: "No video track found", details: nil))
      return
    }
    
    // 获取基本信息
    let frameRate = videoTrack.nominalFrameRate
    
    // 检测 HDR 和杜比视界
    let hdrInfo = detectHDRAndDolbyVision(videoTrack: videoTrack)
    
    // 构建返回数据
    let metadata: [String: Any] = [
      "frameRate": Double(frameRate),
      "isHDR": hdrInfo.isHDR,
      "isDolbyVision": hdrInfo.isDolbyVision,
      "hdrType": hdrInfo.hdrType,
      "colorSpace": hdrInfo.colorSpace
    ]
    
    result(metadata)
  }
  
  /// 检测视频是否为 HDR 和杜比视界
  /// - Parameter videoTrack: 视频轨道
  /// - Returns: HDR 检测结果
  private func detectHDRAndDolbyVision(videoTrack: AVAssetTrack) -> (isHDR: Bool, isDolbyVision: Bool, hdrType: String, colorSpace: String) {
    // 获取格式描述
    guard let formatDescriptions = videoTrack.formatDescriptions as? [CMVideoFormatDescription],
          let formatDescription = formatDescriptions.first else {
      return (false, false, "SDR", "Unknown")
    }
    
    var isHDR = false
    var isDolbyVision = false
    var hdrType = "SDR"
    var colorSpace = "Unknown"
    
    // 检查转换函数 (Transfer Function)
    if let transferFunction = CMFormatDescriptionGetExtension(formatDescription, extensionKey: kCVImageBufferTransferFunctionKey) as? String {
      
      // 检测 HDR10 (PQ 转换函数)
      if transferFunction == kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String {
        isHDR = true
        hdrType = "HDR10"
      }
      // 检测 HLG HDR
      else if transferFunction == kCVImageBufferTransferFunction_ITU_R_2100_HLG as String {
        isHDR = true
        hdrType = "HLG"
      }
    }
    
    // 检查色彩空间
    if let colorPrimaries = CMFormatDescriptionGetExtension(formatDescription, extensionKey: kCVImageBufferColorPrimariesKey) as? String {
      colorSpace = colorPrimaries
      
      // Rec. 2020 色彩空间通常表示 HDR
      if colorPrimaries == kCVImageBufferColorPrimaries_ITU_R_2020 as String {
        isHDR = true
        if hdrType == "SDR" {
          hdrType = "HDR"
        }
      }
    }
    
    // 检测杜比视界
    // 杜比视界通常使用特定的编解码器配置
    let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
    
    // 检查是否为 HEVC 编码（杜比视界通常基于 HEVC）
    if codecType == kCMVideoCodecType_HEVC {
      // 进一步检查杜比视界特征
      if let colorPrimaries = CMFormatDescriptionGetExtension(formatDescription, extensionKey: kCVImageBufferColorPrimariesKey) as? String,
         let transferFunction = CMFormatDescriptionGetExtension(formatDescription, extensionKey: kCVImageBufferTransferFunctionKey) as? String {
        
        // 杜比视界的典型特征：Rec.2020 色彩空间 + PQ 转换函数
        if colorPrimaries == kCVImageBufferColorPrimaries_ITU_R_2020 as String &&
           transferFunction == kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String {
          
          // 检查是否有杜比视界的特定元数据扩展
          let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [String: Any]
          
          // 杜比视界通常会有特定的配置信息
          if let _ = extensions?["DolbyVisionConfiguration"] {
            isDolbyVision = true
            hdrType = "Dolby Vision"
          } else if let _ = extensions?["DoVi"] {
            isDolbyVision = true
            hdrType = "Dolby Vision"
          }
          // 如果没有明确的杜比视界标识，但具备杜比视界的技术特征，标记为可能的杜比视界
          else if isHDR && hdrType == "HDR10" {
            // 注意：这里只是基于技术特征的推测，不是 100% 准确
            // 真正的杜比视界检测需要解析更深层的元数据
            hdrType = "HDR10/Possible DV"
          }
        }
      }
    }
    
    return (isHDR, isDolbyVision, hdrType, colorSpace)
  }
  
  /// 获取PHAsset的真实文件大小
  /// 使用PHAssetResource API获取原始文件大小，即使文件在iCloud中
  /// - Parameters:
  ///   - call: Flutter 方法调用对象，包含assetId参数
  ///   - result: 结果回调，返回文件大小（字节）或错误信息
  private func getAssetFileSize(call: FlutterMethodCall, result: @escaping FlutterResult) {
    // 解析方法参数，获取资源ID
    guard let args = call.arguments as? [String: Any],
          let assetId = args["assetId"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid asset ID", details: nil))
      return
    }
    
    // 通过localIdentifier获取PHAsset
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = fetchResult.firstObject else {
      result(FlutterError(code: "ASSET_NOT_FOUND", message: "Asset not found", details: nil))
      return
    }
    
    // 获取资源列表
    let resources = PHAssetResource.assetResources(for: asset)
    
    // 查找视频资源
    for resource in resources {
      if resource.type == .video {
        // 尝试获取文件大小
        if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
          let uniformTypeIdentifier = resource.uniformTypeIdentifier
          
          // 构建详细信息
          let sizeInfo: [String: Any] = [
            "fileSize": fileSize,
            "uniformTypeIdentifier": uniformTypeIdentifier,
            "originalFilename": resource.originalFilename ?? "unknown",
            "resourceType": resource.type.rawValue
          ]
          
          result(sizeInfo)
          return
        }
      }
    }
    
    // 如果无法通过资源获取大小，尝试其他方法
    // 对于某些iCloud视频，可能需要使用PHImageManager
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = false // 不自动从iCloud下载
    options.deliveryMode = .fastFormat
    
    PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { (avAsset, audioMix, info) in
      DispatchQueue.main.async {
        if let urlAsset = avAsset as? AVURLAsset {
          do {
            let resourceValues = try urlAsset.url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resourceValues.fileSize {
              let sizeInfo: [String: Any] = [
                "fileSize": Int64(fileSize),
                "uniformTypeIdentifier": "video/unknown",
                "originalFilename": "unknown",
                "resourceType": PHAssetResourceType.video.rawValue,
                "source": "AVURLAsset"
              ]
              result(sizeInfo)
            } else {
              result(FlutterError(code: "SIZE_NOT_AVAILABLE", message: "File size not available", details: nil))
            }
          } catch {
            result(FlutterError(code: "SIZE_ERROR", message: "Error getting file size: \(error.localizedDescription)", details: nil))
          }
        } else {
          result(FlutterError(code: "ASSET_UNAVAILABLE", message: "Video asset unavailable", details: nil))
        }
      }
    }
  }
  
  /// 获取PHAsset的iCloud状态信息
  /// 返回详细的iCloud存储状态和下载信息
  /// - Parameters:
  ///   - call: Flutter 方法调用对象，包含assetId参数
  ///   - result: 结果回调，返回状态信息字典
  private func getAssetCloudStatus(call: FlutterMethodCall, result: @escaping FlutterResult) {
    // 解析方法参数，获取资源ID
    guard let args = call.arguments as? [String: Any],
          let assetId = args["assetId"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid asset ID", details: nil))
      return
    }
    
    // 通过localIdentifier获取PHAsset
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = fetchResult.firstObject else {
      result(FlutterError(code: "ASSET_NOT_FOUND", message: "Asset not found", details: nil))
      return
    }
    
    // 获取资源列表以检查iCloud状态
    let resources = PHAssetResource.assetResources(for: asset)
    var isInCloud = false
    var estimatedSize: Int64 = 0
    
    for resource in resources {
      if resource.type == .video {
        // 检查资源是否在iCloud中
        if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
          estimatedSize = fileSize
        }
        
        // 检查本地可用性
        let manager = PHAssetResourceManager.default()
        let requestOptions = PHAssetResourceRequestOptions()
        requestOptions.isNetworkAccessAllowed = false
        
        // 通过尝试获取数据来判断是否在本地
        var locallyAvailable = true
        let semaphore = DispatchSemaphore(value: 0)
        
        manager.requestData(for: resource, options: requestOptions) { (data) in
          // 如果能获取到数据，说明本地可用
        } completionHandler: { (error) in
          if let error = error as NSError? {
            // 检查是否是网络访问需要的错误（iCloud文件）
            if error.domain == "CloudPhotoLibraryErrorDomain" ||
               error.code == -1 { // 网络访问需要的错误码
              locallyAvailable = false
              isInCloud = true
            }
          }
          semaphore.signal()
        }
        
        // 等待检查完成（最多等待0.5秒）
        _ = semaphore.wait(timeout: .now() + 0.5)
        
        // 构建状态信息
        let cloudStatus: [String: Any] = [
          "assetId": assetId,
          "isInCloud": isInCloud,
          "isLocallyAvailable": locallyAvailable,
          "estimatedFileSize": estimatedSize,
          "pixelWidth": asset.pixelWidth,
          "pixelHeight": asset.pixelHeight,
          "duration": asset.duration,
          "mediaType": asset.mediaType.rawValue,
          "mediaSubtypes": asset.mediaSubtypes.rawValue
        ]
        
        result(cloudStatus)
        return
      }
    }
    
    result(FlutterError(code: "VIDEO_RESOURCE_NOT_FOUND", message: "Video resource not found", details: nil))
  }
}
