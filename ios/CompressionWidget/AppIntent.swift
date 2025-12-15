//
//  AppIntent.swift
//  CompressionWidget
//
//  Created by 田永科 on 2025/12/12.
//

import ActivityKit
import Foundation

/// 压缩进度 Live Activity 属性
/// 注意：live_activities 插件默认寻找此名称，必须命名为 LiveActivitiesAppAttributes
/// 参考：https://pub.dev/packages/live_activities
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    
    /// 必须添加此 typealias，否则 Live Activity 不会显示
    public typealias LiveDeliveryData = ContentState
    
    /// 动态变化的内容状态（会实时更新）
    public struct ContentState: Codable, Hashable {
        /// 当前压缩进度 (0.0 - 1.0)
        var progress: Double
        /// 当前处理的视频索引 (1-based)
        var currentIndex: Int
        /// 总视频数量
        var totalCount: Int
        /// 预估剩余时间（秒），nil 表示未知
        var remainingSeconds: Int?
        /// 当前视频文件名
        var currentVideoName: String?
        /// 状态：downloading / compressing / completed / cancelled
        var status: String
    }
    
    /// 必须添加 id 属性，用于唯一标识 Activity
    var id = UUID()
}

// MARK: - Extension for prefixed keys
/// 用于处理带前缀的 UserDefaults 键名
/// Flutter 通过 live_activities 插件写入数据时会自动添加 id 前缀
extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}

// 为了代码可读性，保留别名
typealias CompressionActivityAttributes = LiveActivitiesAppAttributes
