//
//  DiscoverViewController.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 1/26/18.
//  Copyright © 2018 PcVolumeControl. All rights reserved.
//

import UIKit

class DiscoverViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, MdnsServerDelegate  {
    
    @IBOutlet weak var scanPercentage: UIProgressView!
    @IBOutlet weak var discoverTableView: UITableView!
    
    var minValue = 0
    var maxValue = 100
    var barTimer = Timer()
    var serverControl: ServerController?
    var serverList: [(ip: String, port: Int32)] = []
    let asyncQueue = DispatchQueue(label: "asyncQueue", attributes: .concurrent)
    var spinnerView: UIView? = nil
    var SController: StreamController? = nil


    override func viewDidLoad() {
        super.viewDidLoad()
        

        scanPercentage.progress = 0
        barTimer = Timer.scheduledTimer(timeInterval: 0.06, target: self, selector: (#selector(DiscoverViewController.progress)), userInfo: nil, repeats: true)
        
        discoverTableView.delegate = self
        discoverTableView.dataSource = self
        
        serverControl = ServerController(delegate: self)
        print("looking around for servers...")
        serverControl?.listen()
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "testSegue" {
            let destVC = segue.destination as! ViewController
            destVC.SController = self.SController // give them our stream controller
            destVC.initialDraw = true // signal to viewDidLoad() to reload everything.
            let backItem = UIBarButtonItem(title: "Servers", style: .plain, target: nil, action: nil)
            self.navigationItem.backBarButtonItem? = backItem
        }
    }
    
    @objc func progress() {
        if minValue != maxValue {
            minValue += 1
            scanPercentage.progress = Float(minValue) / Float(maxValue)
        } else {
            minValue = 0
        }
    }
    

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return serverList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "serverCell") as! ServerCell
        cell.delegate = self
        
        let targetServer = serverList[indexPath.row]
        cell.setCellParameter(ip: targetServer.0, port: targetServer.1)
        return cell
    }
    
    func didFindServer(ip: String, port: Int32) {
        serverList.append((ip: ip, port: port))
        discoverTableView.reloadData()
    }
    
    func serverUnregistered(ip: String, port: Int32) {
        print("server was unregistered!")
        // find the index of this object
        if let idx = serverList.index(where: {$0 == (ip, port)}) {
            serverList.remove(at: idx)
            discoverTableView.reloadData()
        }
    }
}

extension DiscoverViewController: ServerCellDelegate {

    func didClickConnect(ip: String, port: Int32) {
        // load segue here.
        SController = StreamController(address: ip, port: port, delegate: self)
        SController?.delegate = self

        // Start looking for messages in the publish subject.
        SController?.processMessages()

        // Make the initial server connection and get the first message.
        asyncQueue.async {
            self.SController?.connectNoSend()
        }
        
    }
    
}

extension DiscoverViewController: StreamControllerDelegate {
    func isAttemptingConnection() {
        print("Connection is in progress...")
        
        asyncQueue.async {
            DispatchQueue.main.async {
                self.spinnerView = UIViewController.displaySpinner(onView: self.view)
            }
        }
    }
    func didConnectToServer() {
        print("Server connection complete. Moving to main VC.")
        asyncQueue.async {
            DispatchQueue.main.async {
                if let spinner = self.spinnerView {
                    UIViewController.removeSpinner(spinner: spinner)
                }
                // go to the next screen, pushing along the stream controller instance.
                self.performSegue(withIdentifier: "testSegue", sender: self.SController)
            }
        }
    }
    
    func failedToConnect() {
        if let spinner = spinnerView {
            UIViewController.removeSpinner(spinner: spinner)
            DispatchQueue.main.async {
                let _ = Alert.showBasic(title: "Connection Error", message: "Connection to the server failed.\n\nIs the IP or name correct?\nIs the port open?", vc: self)
            }
        }
    }
    func didGetServerUpdate() {}
    func bailToConnectScreen() {}
    func tearDownConnection() {}
}

// This is the spinner shown when the socket is being set up.
extension UIViewController {
    class func displaySpinner(onView : UIView) -> UIView {
        
        let spinnerView = UIView.init(frame: onView.bounds)
        spinnerView.backgroundColor = UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        let ai = UIActivityIndicatorView.init(activityIndicatorStyle: .whiteLarge)
        ai.startAnimating()
        ai.center = spinnerView.center
        
        spinnerView.addSubview(ai)
        onView.addSubview(spinnerView)
        
        return spinnerView
    }
    
    class func removeSpinner(spinner :UIView) {
        DispatchQueue.main.async {
            spinner.removeFromSuperview()
        }
    }
}

