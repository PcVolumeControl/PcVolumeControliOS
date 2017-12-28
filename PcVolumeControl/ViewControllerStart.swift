//
//  ViewControllerStart.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 12/21/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import UIKit
import Foundation

class ViewControllerStart: UIViewController, UITextFieldDelegate {
    // This is controlling the initial connection screen.
    @IBOutlet weak var Cbutton: UIButton!
    @IBOutlet weak var ServerIPField: UITextField!
    @IBOutlet weak var ServerPortField: UITextField!
    
    
    @IBAction func ConnectButtonClicked(_ sender: UIButton) {
        // handoff to the main viewcontroller
        var connectionParams = [String?]()
        connectionParams.append(ServerIPField.text)
        connectionParams.append(ServerPortField.text)
        performSegue(withIdentifier: "ConnectSegue", sender: connectionParams)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        ServerIPField.delegate = self
        ServerPortField.delegate = self
        ServerIPField.keyboardType = .numbersAndPunctuation
        ServerPortField.keyboardType = .numberPad
        
        setNeedsStatusBarAppearanceUpdate() // light upper bar
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ConnectSegue" {
            let destVC = segue.destination as! ViewController
            destVC.IPaddr = ServerIPField.text
            destVC.PortNum = UInt32(ServerPortField.text!)
            destVC.connectButtonAction(ip: ServerIPField.text!, port: UInt32(ServerPortField.text!)!)
        }
    }
}
