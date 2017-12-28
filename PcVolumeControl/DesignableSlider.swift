//
//  DesignableSlider.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 12/26/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import UIKit

@IBDesignable
class DesignableSlider: UISlider {

    // This is here for the sole purpose of styling the thumb image on the sliders.
    @IBInspectable var thumbImage: UIImage? {
        didSet {
            setThumbImage(thumbImage, for: .normal)
        }
    }
}
