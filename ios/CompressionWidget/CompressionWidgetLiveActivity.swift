//
//  CompressionWidgetLiveActivity.swift
//  CompressionWidget
//
//  Created by 田永科 on 2025/12/12.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct CompressionWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct CompressionWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CompressionWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension CompressionWidgetAttributes {
    fileprivate static var preview: CompressionWidgetAttributes {
        CompressionWidgetAttributes(name: "World")
    }
}

extension CompressionWidgetAttributes.ContentState {
    fileprivate static var smiley: CompressionWidgetAttributes.ContentState {
        CompressionWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: CompressionWidgetAttributes.ContentState {
         CompressionWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: CompressionWidgetAttributes.preview) {
   CompressionWidgetLiveActivity()
} contentStates: {
    CompressionWidgetAttributes.ContentState.smiley
    CompressionWidgetAttributes.ContentState.starEyes
}
