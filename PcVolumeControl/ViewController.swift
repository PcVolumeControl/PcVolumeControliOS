//
//  ViewController.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 11/21/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import UIKit
import Foundation


@objcMembers
class ViewController: UIViewController, UITextFieldDelegate {
    
    //MARK: Properties
    @IBOutlet weak var connectionStatus: UILabel!
    @IBOutlet weak var defaultDeviceView: UIView!
    @IBOutlet weak var masterFooterUIView: UIView!
    // picker
    @IBOutlet weak var pickerTextField: UITextField!
    @IBOutlet weak var masterPickerLabel: UITextField!
    // top slider for master channel
    @IBOutlet weak var masterVolumeSlider: UISlider!
    @IBOutlet weak var masterMuteButton: UISwitch!
    
    @IBAction func masterMuteSwitch(_ sender: UISwitch) {
        
        let id = SController?.fullState?.defaultDevice.deviceId
        var defaultDevId: AMasterChannelUpdate.adflDevice?
        // Volume is not changing.
        let masterVolume = SController?.fullState?.defaultDevice.masterVolume
        if sender.isOn {
            // Unmute the master.
            defaultDevId = AMasterChannelUpdate.adflDevice(deviceId: id!, masterMuted: false, masterVolume: masterVolume!)
        }
        else
        {
            // Mute the master.
            defaultDevId = AMasterChannelUpdate.adflDevice(deviceId: id!, masterMuted: true, masterVolume: masterVolume!)
        }
        let data = AMasterChannelUpdate(version: protocolVersion, defaultDevice: (defaultDevId)!)
        let encoder = JSONEncoder()
        
        let dataAsBytes = try! encoder.encode(data)
        dump(dataAsBytes)
        // The data is supposed to be an array of Uint8.
        let dataAsString = String(bytes: dataAsBytes, encoding: .utf8)
        let dataWithNewline = dataAsString! + "\n"
        SController?.sendString(input: dataWithNewline)
    }

    @IBAction func masterVolumeChanged(_ sender: UISlider) {

        guard let id = SController?.fullState?.defaultDevice.deviceId else { reloadTheWorld(); return }
        var defaultDevId: AMasterChannelUpdate.adflDevice?
        // mute value is not changing.
        let masterMuted = SController?.fullState?.defaultDevice.masterMuted
        let volumeValue = sender.value
        defaultDevId = AMasterChannelUpdate.adflDevice(deviceId: id, masterMuted: masterMuted!, masterVolume: Double(volumeValue))

        let data = AMasterChannelUpdate(version: protocolVersion, defaultDevice: (defaultDevId)!)
        let encoder = JSONEncoder()
        
        let dataAsBytes = try! encoder.encode(data)
        dump(dataAsBytes)
        // The data is supposed to be an array of Uint8.
        let dataAsString = String(bytes: dataAsBytes, encoding: .utf8)
        let dataWithNewline = dataAsString! + "\n"
        SController?.sendString(input: dataWithNewline)
    }
    
    // about page popup
    @IBOutlet weak var aboutButton: UIBarButtonItem!
    @IBAction func aboutButtonClicked(_ sender: UIBarButtonItem) {
        let reconnectInfo = [IPaddr, PortNum ?? 3000] as [Any]
        performSegue(withIdentifier: "aboutSegue", sender: reconnectInfo)
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "aboutSegue" {
            let destVC = segue.destination as! AboutViewController
            destVC.configuredIP = IPaddr
            destVC.configuredPort = PortNum
        }
    }
    
    // bottom sliders for sessions
    @IBOutlet weak var sliderTableView: UITableView!
    
    // bottom toolbar buttons
    @IBOutlet weak var bottomToolbar: UIToolbar!
    
    @IBOutlet weak var disconnectButton: UIBarButtonItem!
    @IBAction func disconnectButtonClicked(_ sender: UIBarButtonItem) {
        print("disconnect requested by user")
        tearDownConnection()
        bailToConnectScreen()
    }
    
    
    let protocolVersion = 6
    var SController: StreamController?
    var clientConnected: Bool? // whether or not the client thinks it is connected
    var alreadySwitched: Bool? //TODO,test
    
    var soundLevel: Float?
    var selectedDefaultDevice: (String, String)?
    
    var allSessions = [Session]() // Array used to build slider table
    var processedSessions = [Session]()
    var IPaddr: String!
    var PortNum: UInt32?
    var connectionParams: [String]?
    
    var deletedSessions = [Session]() // Deleted previously due to a swipe-delete
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setNeedsStatusBarAppearanceUpdate() // white top status bar
        
        // Detection that the app was minimized so we can close TCP connections
        let notificationCenter = NotificationCenter.default
        // If the app is backgrounded with the home button, tear down the TCP connection.
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: Notification.Name.UIApplicationWillResignActive, object: nil)
        // When the app is brough back to foreground, go to the initial connection screen.
        notificationCenter.addObserver(self, selector: #selector(appWillEnterForeground), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
        // table view stuff for the slider screen
        sliderTableView.delegate = self
        sliderTableView.dataSource = self
        sliderTableView.tableFooterView = UIView(frame: CGRect.zero) // remove footer
        sliderTableView.estimatedRowHeight = 140.0
        sliderTableView.rowHeight = UITableViewAutomaticDimension
        
        constructPicker()
        
        alreadySwitched = false
        
    }
    // white top carrier/battery bar
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    struct ADefaultDeviceUpdate : Codable {
        struct adflDevice : Codable {
            let deviceId: String
        }
        let version: Int
        let defaultDevice: adflDevice
    }
    
    struct AMasterChannelUpdate : Codable {
        struct adflDevice : Codable {
            let deviceId: String
            let masterMuted: Bool
            let masterVolume: Double
        }
        let version: Int
        let defaultDevice: adflDevice
    }
    
    struct ASessionUpdate : Codable {
        struct adflDevice : Codable {
            let sessions: [OneSession]
            let deviceId: String
            
        }
        let version: Int
        let defaultDevice: adflDevice
        
    }
    struct OneSession : Codable {
        let name: String
        let id: String
        let volume: Double
        let muted: Bool
    }
    
    func connectButtonAction(ip: String, port: UInt32) {
        // This is the 'connect' button.
        // IP and port have to be tossed back and forth between VCs.
        IPaddr = ip
        PortNum = port
        SController = StreamController(address: ip, port: port, delegate: self)
//        SController?.setupNetworkCommunication()
        SController?.processMessages()
        SController?.delegate = self
        SController?.connectNoSend(ip: ip, port: port)
        
    }
    
    func appMovedToBackground() {
        // Tear down the TCP connection any time they minimize or exit the app.
        print("App moved to background. TCP Connection should be torn down now...")
        clientConnected = false
        if SController?.serverConnected! == false {
            print("Serverside TCP Connection is already dead.")
            return
        }
        tearDownConnection()
    }
    
    func appWillEnterForeground() {
        // If the app is brought out of the background, we _always_ restart.
        print("App moved to foreground. Force reconnection...")
        if alreadySwitched == false {
            bailToConnectScreen()
            alreadySwitched = true
        }
    }
    func appDidBecomeActive() {
        print("App moved from background selection screen to foreground.")
        if alreadySwitched == true {
            return
        }
        bailToConnectScreen()
    }
    
    func createDisconnectAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Quit", style: UIAlertActionStyle.default, handler: { (action) in alert.dismiss(animated:true, completion: nil); self.bailToConnectScreen()}))
        self.present(alert, animated: true, completion: nil)
    }
    
    func pushUpdateToServer(data: ViewController.ADefaultDeviceUpdate?) {
        // Take in the struct for a given update and parse/push to the server.
        // side-effect: server update might come back or disconnection happens
        let encoder = JSONEncoder()
        // TODO: need to understand the input types here...
        
        let dataAsBytes = try! encoder.encode(data)
        dump(dataAsBytes)
        // The data is supposed to be an array of Uint8.
        let dataAsString = String(bytes: dataAsBytes, encoding: .utf8)
        let dataWithNewline = dataAsString! + "\n"
        SController?.sendString(input: dataWithNewline)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func initSessions() {
        // This finds all sessions and overwrites the global session state.
        allSessions.removeAll()
        guard let sessions = SController?.fullState?.defaultDevice.sessions else { return }
        for x : FullState.Session in sessions {
            allSessions.append(Session(id: x.id, muted: x.muted, name: x.name, volume: Double(x.volume)))
        }
        // always sort alphabetically for a consistent view
        allSessions.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == ComparisonResult.orderedAscending
        }
        // While we are reloading here, initialize the title showing in the initial picker view.
        guard let state = SController?.fullState?.defaultDevice.name else { return }
        if pickerTextField == nil {
            self.view.setNeedsLayout()
        }
        pickerTextField.text = state
    }
    
    func findDeviceId(longName: String) -> String {
        // Look through the device IDs to get the short-form device ID.
        // This takes in the long-form session ID as input.
        for (shortId, _) in (SController?.fullState?.deviceIds)! {
            if longName.contains(shortId) {
                return shortId
            }
        }
        return "NOT FOUND"
    }
    
    func reloadTheWorld() {
        // Reload everything! All the things!
        // bail if the client and server protocols mismatch.
        if SController?.fullState?.version != protocolVersion {
            createDisconnectAlert(title: "Error", message: "Client and server protocols mismatch.")
        }
        // re-populate the array of current sessions and reload the sliders.
        initSessions()
        guard let masterMuteState = SController?.fullState?.defaultDevice.masterMuted else {
            print("Master mute state could not be set!")
            return
        }
        masterMuteButton.isOn = !masterMuteState
        // This reloads the sliderTableView completely.
        DispatchQueue.main.async{
            self.sliderTableView.reloadData()
        }
    }
}

//
// EXTENSIONS
//


// This controls the picker view for the master/default device.
extension ViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func constructPicker() {
        let devicePicker = UIPickerView()
        devicePicker.delegate = self
        pickerTextField.inputView = devicePicker
        pickerTextField.text = selectedDefaultDevice?.1
        // TODO: change the default selected item to be the current default.
        createToolbar() // done button
    }
    
    func createToolbar() {
        // make a toolbar with a 'done' button for the picker.
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        
        let doneButton = UIBarButtonItem(title: "Set Default Device", style: .plain, target: self,
                                         action: #selector(ViewController.dismissKeyboard))
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil) // shift it right

        toolBar.setItems([spacer, doneButton, spacer], animated: false)
        toolBar.isUserInteractionEnabled = true
        pickerTextField.inputAccessoryView = toolBar
        
        toolBar.barTintColor = .gray
        toolBar.tintColor = .white
    }
    
    func getDeviceIds() -> [(String, String)] {
        // return an array of tuples showing all available device IDs and pretty names
        var y = [(String, String)]()
        if SController == nil {
            print("full state is nil. bailing...")
            bailToConnectScreen()
        }
        for (shortId, prettyName) in (SController?.fullState?.deviceIds)! {
            y.append((shortId, prettyName))
        }
        return y
    }
    
    func dismissKeyboard() {
        view.endEditing(true)
        
        // When they select the default, we need to update state and send a new master device to the server.
        guard let id = selectedDefaultDevice?.0 else {
            // They didn't change anything. They just hit 'Done'.
            return
        }
        let defaultDevId = ADefaultDeviceUpdate.adflDevice(deviceId: id)
        let data = ADefaultDeviceUpdate(version: protocolVersion, defaultDevice: defaultDevId)
        
//        pushUpdateToServer(data: data)
        let encoder = JSONEncoder()
        let dataAsBytes = try! encoder.encode(data)
        dump(dataAsBytes)
        // The data is supposed to be an array of Uint8.
        let dataAsString = String(bytes: dataAsBytes, encoding: .utf8)
        let dataWithNewline = dataAsString! + "\n"
        SController?.sendString(input: dataWithNewline)
    }
    
    //picker view overrides
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        var deviceids = getDeviceIds()
        return deviceids[row].1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        let deviceids = getDeviceIds()
        return deviceids.count
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedDefaultDevice = getDeviceIds()[row]
        pickerTextField.text = getDeviceIds()[row].1
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    // This code controls the tableView rows the sliders live in.
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allSessions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "sliderCell") as! SliderCell
        cell.delegate = self
        
        let targetSession = allSessions[indexPath.row]
        print("Updating cell index path: \(indexPath.row), target: \(targetSession.name)")
        cell.setSessionParameter(session: targetSession)
        
        return cell
    }
    // TODO: v2 allow hiding of sessions
}

extension ViewController: SliderCellDelegate {
    func didChangeVolume(id: String, newvalue: Double, name: String) {
        print("Volume changed on \(id) to: \(newvalue)")
        
        let defaultDeviceShortId = findDeviceId(longName: id)
//        let currentMuteValue: Bool?
        for session in (SController?.fullState?.defaultDevice.sessions)! {
            if session.id == id {
                // Pull the current mute value for this session.
                let currentMuteValue = session.muted
                let encoder = JSONEncoder()
                // TODO: return current muted state and use that to make the onesession instance.
                let onesession = OneSession(name: name, id: id, volume: newvalue, muted: currentMuteValue)
                let adefault = ASessionUpdate.adflDevice(sessions: [onesession], deviceId: defaultDeviceShortId)
                let data = ASessionUpdate(version: protocolVersion, defaultDevice: adefault)
                
                let dataAsBytes = try! encoder.encode(data)
                dump(dataAsBytes)
                // The data is supposed to be an array of Uint8.
                let dataAsString = String(bytes: dataAsBytes, encoding: .utf8)
                let dataWithNewline = dataAsString! + "\n"
                SController?.sendString(input: dataWithNewline)
                
                break
                
            }
        }

    }
        
    func didToggleMute(id: String, muted: Bool, name: String) {
        print("Mute button hit on session \(id) to value \(muted)")
        let defaultDeviceShortId = findDeviceId(longName: id)
        for session in (SController?.fullState?.defaultDevice.sessions)! {
            if session.id == id {
                // Pull the current volume value for this session.
                let currentVolumeValue = session.volume
                let encoder = JSONEncoder()
                // TODO: return current muted state and use that to make the onesession instance.
                let onesession = OneSession(name: name, id: id, volume: currentVolumeValue, muted: !muted)
                let adefault = ASessionUpdate.adflDevice(sessions: [onesession], deviceId: defaultDeviceShortId)
                let data = ASessionUpdate(version: protocolVersion, defaultDevice: adefault)
                
                
                let dataAsBytes = try! encoder.encode(data)
                dump(dataAsBytes)
                // The data is supposed to be an array of Uint8.
                let dataAsString = String(bytes: dataAsBytes, encoding: .utf8)
                let dataWithNewline = dataAsString! + "\n"
                SController?.sendString(input: dataWithNewline)
                
                break
                
            }
        }
    }
}

extension ViewController: StreamControllerDelegate {
    
    func didGetServerUpdate() {
        print("Server update detected. Reloading...")
        clientConnected = true
        reloadTheWorld()
    }
    func bailToConnectScreen() {
        // used if the TCP controller detects problems
        clientConnected = false
        performSegue(withIdentifier: "BackToStartSegue", sender: "abort")
    }
    func tearDownConnection() {
//        SController?.inputStream.close()
//        SController?.outputStream.close()
        SController?.serverConnected = false
        clientConnected = false
    }
    
}

