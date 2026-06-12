//
//  AppIntent.swift
//  PcVolumeControlWidget
//
//  Created by Bill Booth on 10/19/25.
//  Copyright © 2025 PcVolumeControl. All rights reserved.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}
