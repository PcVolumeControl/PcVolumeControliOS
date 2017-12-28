//
//  Session.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 12/16/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import Foundation
import UIKit

class Session {
    // This is a single session.
    var id: String
    var muted: Bool
    var name: String
    var volume: Double
    
    init(id: String, muted: Bool, name: String, volume: Double) {
        self.id = id
        self.muted = muted
        self.name = name
        self.volume = volume
    }
}
