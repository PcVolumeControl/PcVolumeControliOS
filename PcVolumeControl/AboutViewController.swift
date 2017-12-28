//
//  AboutViewController.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 12/26/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import UIKit

class AboutViewController: UITableViewController {
    
    var configuredIP: String!
    var configuredPort: UInt32?
    
    @IBAction func aboutBackButtonClicked(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "closeAboutSegue", sender: "derp")
    }
    @IBAction func downloadServerClicked(_ sender: UIButton) {
        // When they want to download the server code
        openLink(url: "https://github.com/PcVolumeControl/PcVolumeControlWindows/releases/latest")
    }
    @IBAction func gitButtonClicked(_ sender: UIButton) {
        openLink(url: "https://github.com/PcVolumeControl")
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "closeAboutSegue" {
            let destVC = segue.destination as! ViewController
            destVC.connectButtonAction(ip: configuredIP, port: configuredPort!)
        }
    }
    func openLink(url: String) {
        if let url = URL(string: url) {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:])
            } else {
                // Fallback on earlier versions
            }
        }
    }
    
    
}
