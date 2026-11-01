//
//  TorpedouWidgetLiveActivity.swift
//  TorpedouWidget
//
//  Created by Dragos Dima on 01.11.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TorpedouWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TorpedouWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TorpedouWidgetAttributes.self) { context in
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

extension TorpedouWidgetAttributes {
    fileprivate static var preview: TorpedouWidgetAttributes {
        TorpedouWidgetAttributes(name: "World")
    }
}

extension TorpedouWidgetAttributes.ContentState {
    fileprivate static var smiley: TorpedouWidgetAttributes.ContentState {
        TorpedouWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TorpedouWidgetAttributes.ContentState {
         TorpedouWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TorpedouWidgetAttributes.preview) {
   TorpedouWidgetLiveActivity()
} contentStates: {
    TorpedouWidgetAttributes.ContentState.smiley
    TorpedouWidgetAttributes.ContentState.starEyes
}
