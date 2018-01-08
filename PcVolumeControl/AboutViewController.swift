//
//  AboutViewController.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 12/26/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import UIKit

class AboutViewController: UITableViewController {
    
    @IBOutlet var aboutTableView: UITableView!
    
    @IBAction func aboutBackButtonClicked(_ sender: UIBarButtonItem) {
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "closeAbout", sender: "aboutvc")
        }
    }
    @IBAction func downloadServerClicked(_ sender: UIButton) {
        // When they want to download the server code
        openLink(url: "https://github.com/PcVolumeControl/PcVolumeControlWindows/releases/latest")
    }
    @IBAction func gitButtonClicked(_ sender: UIButton) {
        openLink(url: "https://github.com/PcVolumeControl")
    }
    
    // white top carrier/battery bar
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setNeedsStatusBarAppearanceUpdate() // white top status bar
        let color = UIColor(hex: "303030")
        aboutTableView.backgroundColor = color
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
    
    func openLink(url: String) {
        if let url = URL(string: url) {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:])
            } else {
                // Fallback on earlier versions not supported. 10.0 is lowest.
            }
        }
    }
}

extension UIColor {
    convenience init(hex: String) {
        let scanner = Scanner(string: hex)
        scanner.scanLocation = 0
        
        var rgbValue: UInt64 = 0
        
        scanner.scanHexInt64(&rgbValue)
        
        let r = (rgbValue & 0xff0000) >> 16
        let g = (rgbValue & 0xff00) >> 8
        let b = rgbValue & 0xff
        
        self.init(
            red: CGFloat(r) / 0xff,
            green: CGFloat(g) / 0xff,
            blue: CGFloat(b) / 0xff, alpha: 1
        )
    }
}
