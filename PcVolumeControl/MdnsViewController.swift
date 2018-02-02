//
//  MDNS.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 1/24/18.
//  Copyright © 2018 PcVolumeControl. All rights reserved.
//

import UIKit

class MdnsViewController: UIViewController, NetServiceBrowserDelegate, NetServiceDelegate, MdnsServerDelegate {

    @IBOutlet weak var discoverView: UIView!
    @IBOutlet weak var manualView: UIView!
    @IBOutlet weak var addressSegmentControl: UISegmentedControl!
    @IBAction func segmentedControlClicked(_ sender: UISegmentedControl) {
        switch addressSegmentControl.selectedSegmentIndex
        {
        case 0:
            discoverView.isHidden = false
            manualView.isHidden = true
        case 1:
            discoverView.isHidden = true
            manualView.isHidden = false
        default:
            break;
        }
    }
    
//    var nsb : NetServiceBrowser!
//    var services = [NetService]()
    var serverDelegate: MdnsServerDelegate?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.sendSubview(toBack:manualView)
        self.view.bringSubview(toFront: discoverView)

//        listen()
    }
    
        
//    func listen() {
//        print("listening for services...")
//        self.services.removeAll()
//        self.nsb = NetServiceBrowser()
//        self.nsb.delegate = self
//        DispatchQueue.global(qos: .userInitiated).async {
//            self.nsb.searchForServices(ofType: "_http._tcp.", inDomain: "local.")
//        }
//    }
    
//    func updateInterface () {
//        for service in services {
//
//            if service.port == -1 {
//                print("service \(service.name) of type \(service.type)" +
//                    " not yet resolved")
//                service.delegate = self
//                service.resolve(withTimeout:10)
//            } else {
//                print("service \(service.name) of type \(service.type)," +
//                    "port \(service.port), addresses \(String(describing: service.addresses))")
//                if service.name == "pcvolumecontrol" {
//                    let serverIP: String!
//                    let serverPort: Int32!
//                    print("Our service '\(service.name)' was located!")
//                    // now we know the IP and port of the server.
//                    if let addresses = service.addresses {
//                        guard let ip = getIPV4StringfromAddress(address: addresses) else { return }
//                        serverIP = ip
//                        serverPort = Int32(service.port)
//                        // segue to the main VC with the server and port now.
//                        didFindServer(ip: serverIP, port: serverPort)
//
//
//
////                        print("Connecting to server \(serverIP):\(serverPort)")
////                        //                        defaults.set(serverIP, forKey: "IPaddr")
////                        //                        defaults.set(serverPort, forKey: "PortNum")
////                        //                        defaults.synchronize()
////
////                        SController = StreamController(address: serverIP, port: serverPort, delegate: self)
////                        SController?.delegate = self
////
////                        // Start looking for messages in the publish subject.
////                        SController?.processMessages()
////
////                        // Make the initial server connection and get the first message.
////                        asyncQueue.async {
////                            self.SController?.connectNoSend()
////                        }
//                    }
//                }
//            }
//        }
//    }
//
//    // Used to get an IP address out of the array of data within service.addresses
//    func getIPV4StringfromAddress(address: [Data]) -> String? {
//
//        let data = address.first! as NSData;
//
//        var ip1 = UInt8(0)
//        data.getBytes(&ip1, range: NSMakeRange(4, 1))
//
//        var ip2 = UInt8(0)
//        data.getBytes(&ip2, range: NSMakeRange(5, 1))
//
//        var ip3 = UInt8(0)
//        data.getBytes(&ip3, range: NSMakeRange(6, 1))
//
//        var ip4 = UInt8(0)
//        data.getBytes(&ip4, range: NSMakeRange(7, 1))
//
//        let ipStr = String(format: "%d.%d.%d.%d",ip1,ip2,ip3,ip4);
//
//        return ipStr
//    }
//
//    func netServiceDidResolveAddress(_ sender: NetService) {
//        self.updateInterface()
//    }
//
//    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
//        print("search starting.")
//    }
//    private func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch error: Error) {
//        print("error!")
//    }
//
//    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
//        print("search was stopped")
//    }
//
//    func netServiceBrowser(_ aNetServiceBrowser: NetServiceBrowser, didFind aNetService: NetService, moreComing: Bool) {
//        print("adding a service")
//        self.services.append(aNetService)
//        if !moreComing {
//            self.updateInterface()
//        }
//    }
//
//    func netServiceBrowser(_ aNetServiceBrowser: NetServiceBrowser, didRemove aNetService: NetService, moreComing: Bool) {
//        if let ix = self.services.index(of:aNetService) {
//            self.services.remove(at:ix)
//            print("removing a service")
//            if !moreComing {
//                self.updateInterface()
//            }
//        }
//    }
//
    func didFindServer(ip: String, port: Int32) {
    }
    func serverUnregistered(ip: String, port: Int32) {
        
    }
}
