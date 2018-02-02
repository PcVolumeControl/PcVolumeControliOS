//
//  serverCell.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 1/26/18.
//  Copyright © 2018 PcVolumeControl. All rights reserved.
//

import UIKit

protocol ServerCellDelegate {
    func didClickConnect(ip: String, port: Int32)
}

class ServerCell: UITableViewCell {
    
    @IBOutlet weak var serverNameLabel: UILabel!
    @IBOutlet weak var serverConnectButton: UIButton!
    
    var delegate: ServerCellDelegate?
    var serverIP: String!
    var serverPort: Int32!
    
    func setCellParameter(ip: String, port: Int32) {
        serverNameLabel.text = "\(ip):\(port)"
        serverIP = ip
        serverPort = port
    }
    
    @IBAction func didClickConnect(_ sender: UIButton) {
        print("User requested connection to server...")
        delegate?.didClickConnect(ip: serverIP, port: serverPort)
    }
}

