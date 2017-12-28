//
//  Alert.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 12/18/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import Foundation
import UIKit

class Alert {
    class func showBasic(title: String, message: String, vc: UIViewController) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        vc.present(alert, animated: true)
    }
   
}
