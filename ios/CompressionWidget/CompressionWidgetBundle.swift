//
//  CompressionWidgetBundle.swift
//  CompressionWidget
//
//  Created by 田永科 on 2025/12/12.
//

import WidgetKit
import SwiftUI

@main
struct CompressionWidgetBundle: WidgetBundle {
    var body: some Widget {
        // 压缩进度 Live Activity
        CompressionLiveActivity()
    }
}
