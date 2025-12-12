//
//  CompressionWidget.swift
//  CompressionWidget
//
//  Created by 田永科 on 2025/12/12.
//

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - 品牌颜色扩展
extension Color {
    static let prosperityGold = Color(red: 184/255, green: 155/255, blue: 110/255)
    static let prosperityDarkGold = Color(red: 143/255, green: 122/255, blue: 80/255)
    static let prosperityGray = Color(red: 58/255, green: 58/255, blue: 58/255)
}

// MARK: - 金色进度条样式
struct GoldProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.prosperityGray)
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.prosperityDarkGold, .prosperityGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geo.size.width * (configuration.fractionCompleted ?? 0),
                        height: 8
                    )
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Live Activity Widget
struct CompressionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CompressionActivityAttributes.self) { context in
            // 锁屏视图
            LockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded - Leading
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: iconName(for: context.state.status))
                        .font(.system(size: 28))
                        .foregroundColor(iconColor(for: context.state.status))
                        .frame(width: 44, height: 44)
                        .background(Color.prosperityGray)
                        .cornerRadius(10)
                }
                
                // Expanded - Center
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Video Slimmer")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.prosperityGold)
                        Text(statusText(for: context.state.status))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                // Expanded - Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.currentIndex)/\(context.state.totalCount)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Expanded - Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        ProgressView(value: context.state.progress)
                            .progressViewStyle(GoldProgressStyle())
                        
                        HStack {
                            Label(
                                context.state.currentVideoName ?? "处理中",
                                systemImage: "film"
                            )
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            
                            Spacer()
                            
                            if let remaining = context.state.remainingSeconds, remaining > 0 {
                                Label(formatTime(remaining), systemImage: "clock")
                                    .font(.system(size: 12))
                                    .foregroundColor(.prosperityDarkGold)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
            } compactLeading: {
                // Compact Leading
                Image(systemName: iconName(for: context.state.status))
                    .foregroundColor(iconColor(for: context.state.status))
                    .font(.system(size: 14, weight: .semibold))
                    
            } compactTrailing: {
                // Compact Trailing
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(context.state.currentIndex)/\(context.state.totalCount)")
                        .font(.system(size: 10))
                        .foregroundColor(.prosperityDarkGold)
                }
                
            } minimal: {
                // Minimal - 环形进度
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(Color.prosperityGold, lineWidth: 2)
                        .frame(width: 22, height: 22)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "video.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.prosperityGold)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func iconName(for status: String) -> String {
        switch status {
        case "downloading": return "icloud.and.arrow.down"
        case "compressing": return "video.fill"
        case "completed": return "checkmark.circle.fill"
        case "cancelled": return "xmark.circle.fill"
        default: return "video.fill"
        }
    }
    
    private func iconColor(for status: String) -> Color {
        switch status {
        case "downloading": return .blue
        case "compressing": return .prosperityGold
        case "completed": return .green
        case "cancelled": return .gray
        default: return .prosperityGold
        }
    }
    
    private func statusText(for status: String) -> String {
        switch status {
        case "downloading": return "正在从 iCloud 下载..."
        case "compressing": return "正在压缩视频..."
        case "completed": return "压缩完成！"
        case "cancelled": return "已取消"
        default: return "处理中..."
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return "剩余 \(mins):\(String(format: "%02d", secs))"
        } else {
            return "剩余 \(secs) 秒"
        }
    }
}

// MARK: - 锁屏视图
struct LockScreenView: View {
    let state: CompressionActivityAttributes.ContentState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部
            HStack(spacing: 12) {
                Image(systemName: iconName(for: state.status))
                    .font(.system(size: 24))
                    .foregroundColor(iconColor(for: state.status))
                    .frame(width: 40, height: 40)
                    .background(Color.prosperityGray)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Video Slimmer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.prosperityGold)
                    Text("正在压缩 \(state.currentIndex)/\(state.totalCount) 个视频")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("\(Int(state.progress * 100))%")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // 进度条
            ProgressView(value: state.progress)
                .progressViewStyle(GoldProgressStyle())
            
            // 底部信息
            HStack {
                Label(
                    state.currentVideoName ?? "处理中",
                    systemImage: "film"
                )
                .font(.system(size: 12))
                .foregroundColor(.white)
                .lineLimit(1)
                
                Spacer()
                
                if let remaining = state.remainingSeconds, remaining > 0 {
                    Label(formatTime(remaining), systemImage: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.prosperityDarkGold)
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Helper Functions
    
    private func iconName(for status: String) -> String {
        switch status {
        case "downloading": return "icloud.and.arrow.down"
        case "compressing": return "video.fill"
        case "completed": return "checkmark.circle.fill"
        case "cancelled": return "xmark.circle.fill"
        default: return "video.fill"
        }
    }
    
    private func iconColor(for status: String) -> Color {
        switch status {
        case "downloading": return .blue
        case "compressing": return .prosperityGold
        case "completed": return .green
        case "cancelled": return .gray
        default: return .prosperityGold
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return "剩余 \(mins):\(String(format: "%02d", secs))"
        } else {
            return "剩余 \(secs) 秒"
        }
    }
}

// MARK: - Widget Bundle
@main
struct CompressionWidgetBundle: WidgetBundle {
    var body: some Widget {
        CompressionLiveActivity()
    }
}
