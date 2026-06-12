//
//  PcVolumeControlWidgetLiveActivity.swift
//  PcVolumeControlWidget
//
//  Created by Bill Booth on 10/19/25.
//  Copyright © 2025 PcVolumeControl. All rights reserved.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PcVolumeControlWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct PcVolumeControlWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PcVolumeControlWidgetAttributes.self) { context in
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

extension PcVolumeControlWidgetAttributes {
    fileprivate static var preview: PcVolumeControlWidgetAttributes {
        PcVolumeControlWidgetAttributes(name: "World")
    }
}

extension PcVolumeControlWidgetAttributes.ContentState {
    fileprivate static var smiley: PcVolumeControlWidgetAttributes.ContentState {
        PcVolumeControlWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: PcVolumeControlWidgetAttributes.ContentState {
         PcVolumeControlWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: PcVolumeControlWidgetAttributes.preview) {
   PcVolumeControlWidgetLiveActivity()
} contentStates: {
    PcVolumeControlWidgetAttributes.ContentState.smiley
    PcVolumeControlWidgetAttributes.ContentState.starEyes
}
