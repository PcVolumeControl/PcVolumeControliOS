//
//  AboutViewController.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 12/26/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import UIKit

class AboutViewController: UITableViewController {
    
    @IBOutlet weak var buildNumberLabel: UILabel!
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
        let version = Bundle.main.releaseVersionNumber
        let build = Bundle.main.buildVersionNumber
        buildNumberLabel.text = "App: v\(version ?? "1").\(build ?? "0")"
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "closeAbout" {
            let destVC = segue.destination as UIViewController
            destVC.modalPresentationStyle = .fullScreen
            destVC.modalTransitionStyle = .flipHorizontal
        }
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
extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}
