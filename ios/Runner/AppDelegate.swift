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
      } else if call.method == "getAssetFileSize" {
        self.getAssetFileSize(call: call, result: result)
      } else if call.method == "getAssetCloudStatus" {
        self.getAssetCloudStatus(call: call, result: result)
      } else if call.method == "getAssetBasicInfo" {
        self.getAssetBasicInfo(call: call, result: result)
      } else {
        // 未实现的方法返回错误
        result(FlutterMethodNotImplemented)
      }
    }
    
    // 注册 Flutter 插件
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  /// 获取视频资源的完整元数据（包括杜比视界 HDR 检测）
  /// 通过 PHAsset 的 localIdentifier 获取视频元数据，无需文件路径
  /// - Parameters:
  ///   - call: Flutter 方法调用对象，包含 assetId 参数
  ///   - result: 结果回调，返回包含帧率和 HDR 信息的字典
  /// - Returns: 包含以下字段的字典：
  ///   - frameRate: 视频帧率（fps）
  ///   - isHDR: 是否为 HDR 视频
  ///   - isDolbyVision: 是否为杜比视界视频
  ///   - hdrType: HDR 类型（SDR/HDR10/HLG/Dolby Vision 等）
  ///   - colorSpace: 色彩空间（ITU_R_709/ITU_R_2020/Display_P3 等）
  private func getVideoMetadata(call: FlutterMethodCall, result: @escaping FlutterResult) {
    // 解析方法参数，获取资源 ID（PHAsset 的 localIdentifier）
    guard let args = call.arguments as? [String: Any],
          let assetId = args["assetId"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid asset ID", details: nil))
      return
    }
    
    // 通过 localIdentifier 从相册中获取 PHAsset 对象
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let phAsset = fetchResult.firstObject else {
      result(FlutterError(code: "ASSET_NOT_FOUND", message: "Asset not found", details: nil))
      return
    }
    
    // 配置视频请求选项
    let options = PHVideoRequestOptions()
    options.version = .current // 使用当前版本（编辑后的版本）
    options.deliveryMode = .highQualityFormat // 请求高质量格式
    options.isNetworkAccessAllowed = false // 不从 iCloud 下载，只获取本地可用的信息
    
    // 异步请求 AVAsset 以访问视频轨道信息
    PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { avAsset, _, _ in
      guard let avAsset = avAsset else {
        result(FlutterError(code: "ASSET_LOAD_FAILED", message: "Failed to load AVAsset", details: nil))
        return
      }
      
      // 获取视频轨道数组（一个视频文件可能包含多个视频轨道）
      let videoTracks = avAsset.tracks(withMediaType: .video)
      
      // 确保至少有一个视频轨道
      guard let videoTrack = videoTracks.first else {
        result(FlutterError(code: "NO_VIDEO_TRACK", message: "No video track found", details: nil))
        return
      }
      
      // 获取视频轨道的标称帧率（单位：fps）
      let frameRate = videoTrack.nominalFrameRate
      
      // 检测 HDR 和杜比视界信息
      let hdrInfo = self.detectHDRAndDolbyVision(videoTrack: videoTrack)
      
      // 构建返回数据字典
      let metadata: [String: Any] = [
        "frameRate": Double(frameRate),
        "isHDR": hdrInfo.isHDR,
        "isDolbyVision": hdrInfo.isDolbyVision,
        "hdrType": hdrInfo.hdrType,
        "colorSpace": hdrInfo.colorSpace
      ]
      
      result(metadata)
    }
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
  
  /// 获取 PHAsset 的真实文件大小
  /// 
  /// 使用 PHAssetResource API 获取视频的原始文件大小，即使文件存储在 iCloud 中也能获取
  /// 
  /// - Parameters:
  ///   - call: Flutter 方法调用对象，包含 assetId 参数
  ///   - result: 结果回调，返回文件大小（Int64）或错误信息
  /// 
  /// - Returns: 文件大小（Int64，单位：字节）
  /// 
  /// - Note:
  ///   - 优先使用 PHAssetResource 的 fileSize 属性（最准确）
  ///   - 如果失败，使用 AVURLAsset 作为备用方案
  ///   - 不会触发 iCloud 下载，只获取元数据信息
  ///   - 即使视频在 iCloud 中未下载，也能获取真实文件大小
  private func getAssetFileSize(call: FlutterMethodCall, result: @escaping FlutterResult) {
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
    
    // 获取 PHAsset 关联的资源列表（包含原始文件、编辑版本等）
    let resources = PHAssetResource.assetResources(for: asset)
    
    // 遍历资源列表，查找视频资源
    for resource in resources {
      if resource.type == .video {
        // 尝试通过 KVC 获取文件大小（最准确的方法）
        // 即使文件在 iCloud 中，fileSize 属性也会返回真实大小
        if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
          result(fileSize)
          return
        }
      }
    }
    
    // 备用方案：如果无法通过 PHAssetResource 获取大小，尝试使用 AVURLAsset
    // 这种情况较少见，但对于某些特殊的 iCloud 视频可能需要
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = false // 禁止从 iCloud 自动下载，只获取本地信息
    options.deliveryMode = .fastFormat // 使用快速格式以提高响应速度
    
    // 异步请求 AVAsset
    PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { (avAsset, audioMix, info) in
      // 切换回主线程返回结果
      DispatchQueue.main.async {
        if let urlAsset = avAsset as? AVURLAsset {
          do {
            // 通过 URL 资源值获取文件大小
            let resourceValues = try urlAsset.url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resourceValues.fileSize {
              result(Int64(fileSize))
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
  private func getAssetBasicInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
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
    
    // 获取 PHAsset 关联的资源列表
    let resources = PHAssetResource.assetResources(for: asset)
    
    // 遍历资源列表，查找视频资源并获取文件大小
    for resource in resources {
      if resource.type == .video {
        // 尝试通过 KVC 获取文件大小
        if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
          // 构建基本信息字典
          let basicInfo: [String: Any] = [
            "fileSize": fileSize,
            "pixelWidth": asset.pixelWidth,
            "pixelHeight": asset.pixelHeight,
            "duration": asset.duration
          ]
          
          result(basicInfo)
          return
        }
      }
    }
    
    // 如果无法通过 PHAssetResource 获取文件大小，使用备用方案
    // 仍然返回其他信息，但 fileSize 设为 0
    let basicInfo: [String: Any] = [
      "fileSize": Int64(0),
      "pixelWidth": asset.pixelWidth,
      "pixelHeight": asset.pixelHeight,
      "duration": asset.duration
    ]
    
    result(basicInfo)
  }
  
  /// 获取 PHAsset 的详细 iCloud 状态信息
  /// 
  /// 通过 PHAssetResource API 检查视频资源的云存储状态和本地可用性
  /// 
  /// - Parameters:
  ///   - call: Flutter 方法调用对象，包含 assetId 参数
  ///   - result: 结果回调，返回状态信息字典
  /// 
  /// - Returns: 包含以下字段的字典：
  ///   - assetId: 资源的唯一标识符（String）
  ///   - isInCloud: 资源是否存储在 iCloud 中（Bool）
  ///   - isLocallyAvailable: 资源是否在本地可用/已下载（Bool）
  ///   - estimatedFileSize: 预估的文件大小（Int64，单位：字节）
  ///   - pixelWidth: 视频像素宽度（Int）
  ///   - pixelHeight: 视频像素高度（Int）
  ///   - duration: 视频时长（TimeInterval，单位：秒）
  ///   - mediaType: 媒体类型原始值（Int，2 表示视频）
  ///   - mediaSubtypes: 媒体子类型原始值（Int）
  /// 
  /// - Note: 
  ///   - 通过尝试请求资源数据（不允许网络访问）来判断本地可用性
  ///   - 如果请求失败且错误码为网络访问需要，则判定为 iCloud 资源
  ///   - 最多等待 0.5 秒以避免阻塞主线程
  private func getAssetCloudStatus(call: FlutterMethodCall, result: @escaping FlutterResult) {
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
    
    // 获取 PHAsset 关联的资源列表（包含原始文件、编辑版本等）
    let resources = PHAssetResource.assetResources(for: asset)
    var isInCloud = false
    var estimatedSize: Int64 = 0
    
    // 遍历资源列表，查找视频资源
    for resource in resources {
      if resource.type == .video {
        // 尝试获取文件大小（即使在 iCloud 中也能获取）
        if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
          estimatedSize = fileSize
        }
        
        // 配置资源请求选项以检查本地可用性
        let manager = PHAssetResourceManager.default()
        let requestOptions = PHAssetResourceRequestOptions()
        requestOptions.isNetworkAccessAllowed = false // 禁止网络访问，只检查本地
        
        // 通过尝试请求数据来判断资源是否在本地
        var locallyAvailable = true
        let semaphore = DispatchSemaphore(value: 0)
        
        manager.requestData(for: resource, options: requestOptions) { (data) in
          // 如果能成功接收数据块，说明资源在本地可用
        } completionHandler: { (error) in
          if let error = error as NSError? {
            // 检查错误类型以判断是否为 iCloud 资源
            // CloudPhotoLibraryErrorDomain: iCloud 照片库相关错误
            // 错误码 -1: 需要网络访问（资源在 iCloud 中）
            if error.domain == "CloudPhotoLibraryErrorDomain" ||
               error.code == -1 {
              locallyAvailable = false
              isInCloud = true
            }
          }
          semaphore.signal()
        }
        
        // 等待检查完成（设置超时时间为 0.5 秒，避免长时间阻塞）
        _ = semaphore.wait(timeout: .now() + 0.5)
        
        // 构建详细的云状态信息字典
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
