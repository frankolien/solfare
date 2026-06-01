//
//  SolfareWidgetLiveActivity.swift
//  SolfareWidget
//
//  Created by Olien on 6/1/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SolfareWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct SolfareWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SolfareWidgetAttributes.self) { context in
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

extension SolfareWidgetAttributes {
    fileprivate static var preview: SolfareWidgetAttributes {
        SolfareWidgetAttributes(name: "World")
    }
}

extension SolfareWidgetAttributes.ContentState {
    fileprivate static var smiley: SolfareWidgetAttributes.ContentState {
        SolfareWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: SolfareWidgetAttributes.ContentState {
         SolfareWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: SolfareWidgetAttributes.preview) {
   SolfareWidgetLiveActivity()
} contentStates: {
    SolfareWidgetAttributes.ContentState.smiley
    SolfareWidgetAttributes.ContentState.starEyes
}
