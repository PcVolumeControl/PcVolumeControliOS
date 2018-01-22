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
    
    let protocolVersion = 7
    var SController: StreamController?
    var alreadySwitched: Bool?
    var selectedDefaultDevice: (String, String)?
    var allSessions = [Session]() // Array used to build slider table
    var IPaddr: String!
    var PortNum: UInt32?
    var disconnectRequested: Bool = false
    var initialDraw: Bool = false
    var defaults = UserDefaults.standard
    
    @IBOutlet weak var defaultDeviceView: UIView!
    @IBOutlet weak var pickerTextField: UITextField!
    @IBOutlet weak var masterVolumeSlider: DesignableSlider!
    @IBOutlet weak var masterMuteButton: UISwitch!
    
    @IBAction func masterMuteSwitch(_ sender: UISwitch) {
        
        let id = SController?.fullState?.defaultDevice.deviceId
        var defaultDevId: AMasterChannelUpdate.adflDevice?
        // Volume is not changing.
        guard let masterVolume = SController?.fullState?.defaultDevice.masterVolume else { return }
        if sender.isOn {
            // Unmute the master.
            defaultDevId = AMasterChannelUpdate.adflDevice(deviceId: id!, masterMuted: false, masterVolume: Float(masterVolume))
        }
        else
        {
            // Mute the master.
            defaultDevId = AMasterChannelUpdate.adflDevice(deviceId: id!, masterMuted: true, masterVolume: Float(masterVolume))
        }
        let data = AMasterChannelUpdate(protocolVersion: protocolVersion, defaultDevice: (defaultDevId!))
        
        let encoder = JSONEncoder()
        let dataAsBytes = try! encoder.encode(data)
        dump(dataAsBytes)
        // The data is supposed to be an array of Uint8.
        guard let dataAsString = String(bytes: dataAsBytes, encoding: .utf8) else { return }
        let dataWithNewline = dataAsString + "\n"
        SController?.sendString(input: dataWithNewline)
    }

    @IBAction func masterVolumeChanged(_ sender: UISlider) {

        guard let id = SController?.fullState?.defaultDevice.deviceId else { reloadTheWorld(); return }
        var defaultDevId: AMasterChannelUpdate.adflDevice?
        // mute value is not changing.
        guard let masterMuted = SController?.fullState?.defaultDevice.masterMuted else { return }
        let volumeValue = sender.value
        defaultDevId = AMasterChannelUpdate.adflDevice(deviceId: id, masterMuted: masterMuted, masterVolume: volumeValue)

        let data = AMasterChannelUpdate(protocolVersion: protocolVersion, defaultDevice: (defaultDevId)!)
        let encoder = JSONEncoder()
        
        let dataAsBytes = try! encoder.encode(data)
        dump(dataAsBytes)
        // The data is supposed to be an array of Uint8.
        guard let dataAsString = String(bytes: dataAsBytes, encoding: .utf8) else { return }
        let dataWithNewline = dataAsString + "\n"
        SController?.sendString(input: dataWithNewline)
    }
    
    // bottom sliders for sessions
    @IBOutlet weak var sliderTableView: UITableView!
    
    // bottom toolbar buttons
    @IBOutlet weak var bottomToolbar: UIToolbar!
    
    // Very bottom toolbar with disconnect button
    @IBOutlet weak var disconnectButton: UIBarButtonItem!
    @IBOutlet weak var editCellsButton: UIBarButtonItem!
    @IBAction func disconnectButtonClicked(_ sender: UIBarButtonItem) {
        print("Disconnect requested by user...")
        disconnectRequested = true
        SController?.disconnect()
        bailToConnectScreen()
    }
    
    @IBAction func editCellButtonClicked(_ sender: UIBarButtonItem) {
        // Toggle editing of the cells - reordering or deleting.
        self.sliderTableView.isEditing = !self.sliderTableView.isEditing
        if self.sliderTableView.isEditing {
            sender.title = "Done"
            sender.tintColor = .white
        } else {
            sender.title = "Reorder Sliders"
            sender.tintColor = .none
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if initialDraw == true {
            reloadTheWorld()
            initialDraw = false
        }
        
        setNeedsStatusBarAppearanceUpdate() // white top status bar
        disconnectRequested = false
        
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
        
        // Make this a delegate for the TCP Stream Controller class.
        SController?.delegate = self
        
        if SController?.fullState?.defaultDevice == nil {
            view.setNeedsDisplay()
        }
    }
    
    // white top carrier/battery bar
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    struct ADefaultDeviceUpdate : Codable {
        struct adflDevice : Codable {
            let deviceId: String
        }
        let protocolVersion: Int
        let defaultDevice: adflDevice
    }
    
    struct AMasterChannelUpdate : Codable {
        struct adflDevice : Codable {
            let deviceId: String
            let masterMuted: Bool
            let masterVolume: Float
        }
        let protocolVersion: Int
        let defaultDevice: adflDevice
    }
    
    struct ASessionUpdate : Codable {
        struct adflDevice : Codable {
            let sessions: [OneSession]
            let deviceId: String
            
        }
        let protocolVersion: Int
        let defaultDevice: adflDevice
        
    }
    struct OneSession : Codable {
        let name: String
        let id: String
        let volume: Float
        let muted: Bool
    }
    
    func appMovedToBackground() {
        // Tear down the TCP connection any time they minimize or exit the app.
        print("App moved to background. TCP Connection should be torn down now...")
        if SController?.clientSocket?.isConnected == true {
            disconnectRequested = true
            SController?.disconnect()
        }
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
        if alreadySwitched == false {
            bailToConnectScreen()
        }
    }
    
    func createDisconnectAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Quit", style: UIAlertActionStyle.default, handler: { (action) in alert.dismiss(animated:true, completion: nil); self.bailToConnectScreen()}))
        self.present(alert, animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func initSessions() {
        // This finds all sessions and overwrites the global session state.
        print("Sessions are being re-intialized...")
        allSessions.removeAll()
        guard let sessions = SController?.fullState?.defaultDevice.sessions else {
            createDisconnectAlert(title: "Whoops", message: "Full state sent from the server was not loaded for some reason.")
            return
        }
        for x : FullState.Session in sessions {
            allSessions.append(Session(id: x.id, muted: x.muted, name: x.name, volume: Double(x.volume)))
        }
        // always sort alphabetically for a consistent view
        allSessions.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == ComparisonResult.orderedAscending
        }
        // While we are reloading here, initialize the title showing in the initial picker view.
        guard let state = SController?.fullState?.defaultDevice.name else { return }
        
        DispatchQueue.main.async {
            self.pickerTextField.text = state
            self.pickerTextField.tintColor = .clear
        }
        /*
        of all the sessions here, if we have already reordered the stack, move our cells around
        so the prioritized ones are up top and everything else appears below.
        */
        
        if let dfl = defaults.object(forKey: "customOrderedCells") as? [String] {
            // We found a customized ordering.
            if dfl.count > allSessions.count {
                // TODO: This is kinda hacky. There has to be a better way.
                defaults.set([], forKey: "customOrderedCells")
                defaults.synchronize()
                return
            }
            for item in allSessions {
                if dfl.contains(item.id) {
                    // The ID we are looking at has a custom ordering.
                    if let cIdx = dfl.index(of: item.id) {
                        // allSessions is mutated in this loop. Get the new index.
                        if let aIdx = allSessions.index(where: {$0.id == item.id}) {
                            allSessions.remove(at: aIdx)
                            allSessions.insert(item, at: cIdx)
                        }
                    }
                }
            }
        }
    }
    
    func findDeviceId(longName: String) -> String {
        // Look through the device IDs to get the short-form device ID.
        // This takes in the long-form session ID as input.
        
        var deviceName = "Unknown"
        if let ids = SController?.fullState?.deviceIds {
            for (shortId, _) in ids {
                if longName.contains(shortId) {
                    deviceName = shortId
                }
            }
        }
        return deviceName
    }
    
    func reloadTheWorld() {
        // Reload everything! All the things!
        // bail if the client and server protocols mismatch.
        
        if SController?.fullState?.protocolVersion != protocolVersion {
            createDisconnectAlert(title: "Error", message: "Client and server protocols mismatch.")
        }

        guard let masterMuteState = SController?.fullState?.defaultDevice.masterMuted else {
            print("Master mute state could not be set!")
            return
        }
        masterMuteButton.isOn = !masterMuteState
        let masterVolume = SController?.fullState?.defaultDevice.masterVolume ?? 50.0
        masterVolumeSlider?.value = masterVolume

        // Bottom slider table stack with all sessions
        // re-populate the array of current sessions and reload the sliders.
        initSessions()

        sliderTableView.reloadData()
    }
}

/*
This controls the picker view for the master/default device.
*/
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
        
        let doneButton = UIBarButtonItem(title: "Set Output Device", style: .plain, target: self,
                                         action: #selector(ViewController.outputDeviceSelected))
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
        if let deviceIDs = SController?.fullState?.deviceIds {
            for (shortId, prettyName) in deviceIDs {
                y.append((shortId, prettyName))
            }
        }
        
        return y
    }
    
    func outputDeviceSelected() {
        view.endEditing(true)
        
        // When they select the default, we need to update state and send a new master device to the server.
        guard let id = selectedDefaultDevice?.0 else {
            // They didn't change anything. They just hit 'Done'.
            return
        }
        let defaultDevId = ADefaultDeviceUpdate.adflDevice(deviceId: id)
        let data = ADefaultDeviceUpdate(protocolVersion: protocolVersion, defaultDevice: defaultDevId)
        
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
        
        // Customize the reordercontrol/hamburger icon background
        cell.backgroundColor = .gray
        // TODO: We really should disable the sliders/switches in each cell during editing.
     
        return cell
    }
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        // return .delete to get a delete button on the left side of the cell.
        return .none
    }
    
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        // indentation on the left side of the cell
        return false
    }
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let movedObject = self.allSessions[sourceIndexPath.row]
        allSessions.remove(at: sourceIndexPath.row)
        allSessions.insert(movedObject, at: destinationIndexPath.row)
        NSLog("%@", "\(sourceIndexPath.row) => \(destinationIndexPath.row) \(allSessions)")
        // The sessions have been customized. Write the state/order into defaults so initsessions can read them.
        var customOrdering = [String]()
        for (index, session) in allSessions.enumerated() {
            customOrdering.append(session.id)
            print("Session '\(session.name)' custom-ordered to index: \(index)")
        }
        defaults.set(customOrdering, forKey: "customOrderedCells")
        defaults.synchronize()
    }
}

/*
 The cells where the sessions show up are custom UITableViewCells.
 */
extension ViewController: SliderCellDelegate {
    func didChangeVolume(id: String, newvalue: Double, name: String) {
        print("\n\nVolume changed on \(id) to: \(newvalue)")
        
        let defaultDeviceShortId = findDeviceId(longName: id)

        for session in (SController?.fullState?.defaultDevice.sessions)! {
            if session.id == id {
                // Pull the current mute value for this session.
                let currentMuteValue = session.muted
                let encoder = JSONEncoder()
                // TODO: return current muted state and use that to make the onesession instance.
                let onesession = OneSession(name: name, id: id, volume: Float(newvalue), muted: currentMuteValue)
                let adefault = ASessionUpdate.adflDevice(sessions: [onesession], deviceId: defaultDeviceShortId)
                let data = ASessionUpdate(protocolVersion: protocolVersion, defaultDevice: adefault)
                
                let dataAsBytes = try! encoder.encode(data)
                let dataAsString = String(bytes: dataAsBytes, encoding: .utf8)
                let dataWithNewline = dataAsString! + "\n"
                SController?.sendString(input: dataWithNewline)
                break
                
            }
        }
    }
        
    func didToggleMute(id: String, muted: Bool, name: String) {
        print("\n\nMute button hit on session \(id) to value \(muted)")
        let defaultDeviceShortId = findDeviceId(longName: id)
        for session in (SController?.fullState?.defaultDevice.sessions)! {
            if session.id == id {
                
                // Pull the current volume value for this session.
                let currentVolumeValue = session.volume
                let encoder = JSONEncoder()
                // TODO: return current muted state and use that to make the onesession instance.
                let onesession = OneSession(name: name, id: id, volume: Float(currentVolumeValue), muted: !muted)
                let adefault = ASessionUpdate.adflDevice(sessions: [onesession], deviceId: defaultDeviceShortId)
                let data = ASessionUpdate(protocolVersion: protocolVersion, defaultDevice: adefault)
                
                let dataAsBytes = try! encoder.encode(data)
                let dataAsString = String(bytes: dataAsBytes, encoding: .utf8)
                let dataWithNewline = dataAsString! + "\n"
                SController?.sendString(input: dataWithNewline)
                break
                
            }
        }
    }
}

/*
 The streamcontroller is used to keep track of the TCP socket to the server.
 It also handles validation/coding of the JSON strings going to/from the server.
 
 This view controller should not try to look for status on the stream controller
 object here. Instead, delegates from the stream controller should be used to
 signal important events to this view controller.
 */

extension ViewController: StreamControllerDelegate {
    
    func didGetServerUpdate() {
        // This is the top of everything. The entire UI is reloaded if this executes.
        // It's only executed when the streamcontroller parses a valid JSON server message.
        print("Server update detected. Reloading...\n")
        DispatchQueue.main.async {
            self.reloadTheWorld()
        }
    }
    func bailToConnectScreen() {
        // used if the TCP controller detects problems
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "BackToStartSegue", sender: "abort")
        }
    }
    func tearDownConnection() {
        // Check to see if the disconnect button took us here.
        if disconnectRequested == true {
            bailToConnectScreen()
            return
        }
        
        // Something went wrong with the socket open to the server.
        let alert = UIAlertController(title: "Error", message: "The server connection was lost.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Reconnect", style: .default, handler: { action in
            self.bailToConnectScreen()
        }))
        self.present(alert, animated: true)

    }
    func didConnectToServer() {}
    func isAttemptingConnection() {}
    func failedToConnect() {}
    
    func reconnect() {
        // This should tear down what we have, then cause a reload of everything.
        SController?.disconnect()
        SController?.connectNoSend()
    }
}


