//
//  ViewControllerStart.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 12/21/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import UIKit
import Foundation
import Socket

class ViewControllerStart: UIViewController, UITextFieldDelegate {
    // This is controlling the initial connection screen.
    
    let asyncQueue = DispatchQueue(label: "asyncQueue", attributes: .concurrent)
    var spinnerView: UIView? = nil
    var SController: StreamController? = nil
    var defaults = UserDefaults.standard // to persist the IP/port entered previously
    var serverIP: String!
    var serverPort: Int32!

    @IBOutlet weak var Cbutton: UIButton!
    @IBOutlet weak var ServerIPField: UITextField!
    @IBOutlet weak var ServerPortField: UITextField!
    
    @IBOutlet weak var frontAboutButton: UIBarButtonItem!
    @IBAction func frontAboutButtonClicked(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "showAbout", sender: "nothing")
    }
    
    @IBAction func ConnectButtonClicked(_ sender: UIButton) {
        

        // handoff to the main viewcontroller
//        guard let PortNum = Int32(self.ServerPortField.text!) else {
//            let _ = Alert.showBasic(title: "Error", message: "Bad port number specified.\nThe default is 3000. The port number needs to be between 1-65535.", vc: self)
//            return
//        }
//        guard let IPaddr = self.ServerIPField.text else {
//            return
//        }
//
//        // Check if the IP field is blank.
//        if IPaddr.isEmpty {
//            let _ = Alert.showBasic(title: "Error", message: "A host name or IPv4 address is required in order to connect to your PCVolumeControl server.", vc: self)
//            return
//        } else {
//            // They entered *something*
//            if IPaddr.matches("^[0-9]") && IPaddr.matches("[0-9]$") {
//                // pretty sure it's an IP address, but is it valid?
//                if !isValidIP(s: IPaddr) {
//                    let _ = Alert.showBasic(title: "Error", message: "The entry '\(IPaddr)' was not a valid IPv4 address.", vc: self)
//                    return
//                }
//            }
//        }
        
        
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        ServerIPField.delegate = self
        ServerPortField.delegate = self
        ServerIPField.returnKeyType = UIReturnKeyType.next
        ServerIPField.tag = 1
        ServerPortField.tag = 2
        ServerIPField.autocorrectionType = .no
        ServerPortField.autocorrectionType = .no
        ServerIPField.keyboardType = .numbersAndPunctuation
        ServerPortField.keyboardType = .numberPad
        
        setNeedsStatusBarAppearanceUpdate() // light upper bar
        
        // connect button styling
        Cbutton.styleButton(cornerRadius: 8, borderWidth: 2, borderColor: UIColor.gray.cgColor)
//        addDoneButtonOnKeyboard()
        
        if let ipaddr = defaults.string(forKey: "IPaddr") {
            ServerIPField.text = "remove me"
        }
        if let port = defaults.string(forKey: "PortNum") {
            ServerPortField.text = "remove me"
        }
    }
    
    // used to move between IP and Port fields
//    func textFieldShouldReturn(_ textField: UITextField) -> Bool
//    {
//        if let nextField = textField.superview?.viewWithTag(textField.tag + 1) as? UITextField {
//            nextField.becomeFirstResponder()
//        } else {
//            textField.resignFirstResponder()
//        }
//        return false
//    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        if segue.identifier == "ConnectSegue" {
//            let destVC = segue.destination as! ViewController
//            destVC.SController = self.SController // give them our stream controller
//            destVC.initialDraw = true // signal to viewDidLoad() to reload everything.
//        }
//    }
//    func addDoneButtonOnKeyboard()
//    {
//        let doneToolbar: UIToolbar = UIToolbar()
//        doneToolbar.barStyle = UIBarStyle.default
//
//        let flexSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
//        let done: UIBarButtonItem = UIBarButtonItem(title: "Done", style: UIBarButtonItemStyle.done, target: self, action: #selector(ViewControllerStart.doneButtonAction(_:)))
//        var items = [UIBarButtonItem]()
//        items.append(flexSpace)
//        items.append(done)
//        items.append(flexSpace)
//
//        doneToolbar.items = items
//        doneToolbar.sizeToFit()
//
//        ServerPortField.inputAccessoryView = doneToolbar
//
//    }
//
//    @objc func doneButtonAction(_ sender: UIBarButtonItem!)
//    {
//        view.endEditing(true)
//    }
//    func isValidIP(s: String) -> Bool {
//        let parts = s.components(separatedBy: ".")
//        let nums = parts.flatMap { Int($0) }
//        return parts.count == 4 && nums.count == 4 && nums.filter { $0 >= 0 && $0 < 256}.count == 4
//    }
}

//extension ViewControllerStart: StreamControllerDelegate {
//    func isAttemptingConnection() {
//        print("Connection is in progress...")
//
//        asyncQueue.async {
//            DispatchQueue.main.async {
//                self.spinnerView = UIViewController.displaySpinner(onView: self.view)
//            }
//        }
//    }
//    func didConnectToServer() {
//        print("Server connection complete. Moving to main VC.")
//        asyncQueue.async {
//            DispatchQueue.main.async {
//                if let spinner = self.spinnerView {
//                    UIViewController.removeSpinner(spinner: spinner)
//                }
//                // go to the next screen, pushing along the stream controller instance.
//                self.performSegue(withIdentifier: "ConnectSegue", sender: self.SController)
//            }
//        }
//    }
//
//    func failedToConnect() {
//        if let spinner = spinnerView {
//            UIViewController.removeSpinner(spinner: spinner)
//            DispatchQueue.main.async {
//                let _ = Alert.showBasic(title: "Connection Error", message: "Connection to the server failed.\n\nIs the IP or name correct?\nIs the port open?", vc: self)
//            }
//        }
//    }
//    func didGetServerUpdate() {}
//    func bailToConnectScreen() {}
//    func tearDownConnection() {}
//}

// This is the spinner shown when the socket is being set up.
//extension UIViewController {
//    class func displaySpinner(onView : UIView) -> UIView {
//
//        let spinnerView = UIView.init(frame: onView.bounds)
//        spinnerView.backgroundColor = UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
//        let ai = UIActivityIndicatorView.init(activityIndicatorStyle: .whiteLarge)
//        ai.startAnimating()
//        ai.center = spinnerView.center
//
//        spinnerView.addSubview(ai)
//        onView.addSubview(spinnerView)
//
//        return spinnerView
//    }
//
//    class func removeSpinner(spinner :UIView) {
//        DispatchQueue.main.async {
//            spinner.removeFromSuperview()
//        }
//    }
//}

//extension ViewControllerStart: NetServiceBrowserDelegate, NetServiceDelegate {
//    // This is the mDNS extension on the start screen: auto-discovery of the server.
//
//    func updateInterface () {
//        for service in services {
//            if service.port == -1 {
//                print("service \(service.name) of type \(service.type)" +
//                    " not yet resolved")
//                service.delegate = self
//                service.resolve(withTimeout:10)
//            } else {
//                print("service \(service.name) of type \(service.type)," +
//                    "port \(service.port), addresses \(String(describing: service.addresses))")
//                if service.name == "pcvolumecontrol" {
//                    print("Our service '\(service.name)' was located!")
//                    // now we know the IP and port of the server.
//                    if let addresses = service.addresses {
//                        guard let ip = getIPV4StringfromAddress(address: addresses) else { return }
//                        serverIP = ip
//                        serverPort = Int32(service.port)
//                        print("Connecting to server \(serverIP):\(serverPort)")
////                        defaults.set(serverIP, forKey: "IPaddr")
////                        defaults.set(serverPort, forKey: "PortNum")
////                        defaults.synchronize()
//
//                        SController = StreamController(address: serverIP, port: serverPort, delegate: self)
//                        SController?.delegate = self
//
//                        // Start looking for messages in the publish subject.
//                        SController?.processMessages()
//
//                        // Make the initial server connection and get the first message.
//                        asyncQueue.async {
//                            self.SController?.connectNoSend()
//                        }
//                    }
//                }
//            }
//        }
//    }
//
//}

// Customizing the Connect button a bit
//extension UIButton {
//    func styleButton(cornerRadius: CGFloat, borderWidth: CGFloat, borderColor: CGColor) {
//        self.layer.cornerRadius = cornerRadius
//        self.layer.borderWidth = borderWidth
//        self.layer.borderColor = borderColor
//    }
//}

//// Extend String so we can allow regex matching on the domain name/IP entered.
//extension String {
//    func matches(_ regex: String) -> Bool {
//        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
//    }
//}

