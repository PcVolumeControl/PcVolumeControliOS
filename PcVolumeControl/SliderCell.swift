//
//  SliderCell.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 12/11/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import UIKit

protocol SliderCellDelegate {
    func didChangeVolume(id: String, newvalue: Double, name: String)
    func didToggleMute(id: String, muted: Bool, name: String)
}

// This covers individual cells, with one session per cell.
class SliderCell: UITableViewCell {
    
    @IBOutlet weak var actualSlider: UISlider!
    @IBOutlet weak var sliderTextField: UITextField!
    @IBOutlet weak var sliderMuteSwitch: UISwitch!
    
    var sessionItem: Session!
    var delegate: SliderCellDelegate?
    
    func setSessionParameter(session: Session) {
        sessionItem = session
        sliderTextField.text = session.name
        actualSlider.value = Float(session.volume)
        sliderMuteSwitch.isOn = !session.muted
    }
    
    @IBAction func volumeChanged(_ sender: UISlider) {
        delegate?.didChangeVolume(id: sessionItem.id, newvalue: Double(actualSlider.value), name: sessionItem.name)
    }
    @IBAction func muteValueChanged(_ sender: UISwitch) {
        delegate?.didToggleMute(id: sessionItem.id, muted: sender.isOn, name: sessionItem.name)
    }
}
