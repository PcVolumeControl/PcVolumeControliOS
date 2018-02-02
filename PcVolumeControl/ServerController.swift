//
//  ServerController.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 1/26/18.
//  Copyright © 2018 PcVolumeControl. All rights reserved.
//

import Foundation
import RxSwift


protocol MdnsServerDelegate {
    func didFindServer(ip: String, port: Int32)
    func serverUnregistered(ip: String, port: Int32)
}

class ServerController: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    
    var delegate: MdnsServerDelegate?
    var nsb : NetServiceBrowser!
    var services = [NetService]()
    
    // Rx stuff
    let bag = DisposeBag()
    var lastServerSubject = PublishSubject<(String, Int32)>() // array of ip:port tuples
    
    init(delegate: MdnsServerDelegate) {
        self.delegate = delegate
        
    }
    
    private func foundServer(ip: String, port: Int32) {
        self.delegate?.didFindServer(ip: ip, port: port)
    }
    
    func listen() {
        print("listening for services...")
        self.services.removeAll()
        self.nsb = NetServiceBrowser()
        self.nsb.delegate = self
        DispatchQueue.global(qos: .userInitiated).async {
            self.nsb.searchForServices(ofType: "_http._tcp.", inDomain: "local.")
        }
    }
    func updateInterface () {
        for service in services {
            
            if service.port == -1 {
                print("service \(service.name) of type \(service.type)" +
                    " not yet resolved")
                service.delegate = self
                service.resolve(withTimeout:10)
            } else {
                print("service \(service.name) of type \(service.type)," +
                    "port \(service.port), addresses \(String(describing: service.addresses))")
                if service.name == "pcvolumecontrol" {
                    let serverIP: String!
                    let serverPort: Int32!
                    print("Our service '\(service.name)' was located!")
                    // now we know the IP and port of the server.
                    if let addresses = service.addresses {
                        guard let ip = getIPV4StringfromAddress(address: addresses) else { return }
                        serverIP = ip
                        serverPort = Int32(service.port)
                        // segue to the main VC with the server and port now.
                        lastServerSubject.onNext((serverIP, serverPort))
                        self.delegate?.didFindServer(ip: serverIP, port: serverPort)
                    }
                }
            }
        }
    }
    
    // Used to get an IP address out of the array of data within service.addresses
    func getIPV4StringfromAddress(address: [Data]?) -> String? {
        
        guard let addr = address else { return "" }
        let data = addr.first as! NSData
        
        var ip1 = UInt8(0)
        data.getBytes(&ip1, range: NSMakeRange(4, 1))
        
        var ip2 = UInt8(0)
        data.getBytes(&ip2, range: NSMakeRange(5, 1))
        
        var ip3 = UInt8(0)
        data.getBytes(&ip3, range: NSMakeRange(6, 1))
        
        var ip4 = UInt8(0)
        data.getBytes(&ip4, range: NSMakeRange(7, 1))
        
        let ipStr = String(format: "%d.%d.%d.%d",ip1,ip2,ip3,ip4);
        
        return ipStr
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        self.updateInterface()
    }
    
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        print("search starting.")
    }
    private func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch error: Error) {
        print("error!")
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        print("search was stopped")
    }
    
    func netServiceBrowser(_ aNetServiceBrowser: NetServiceBrowser, didFind aNetService: NetService, moreComing: Bool) {
        print("adding a service")
        self.services.append(aNetService)
        if !moreComing {
            self.updateInterface()
        }
    }
    
    func netServiceBrowser(_ aNetServiceBrowser: NetServiceBrowser, didRemove aNetService: NetService, moreComing: Bool) {
        if let ix = self.services.index(of:aNetService) {
            if let address = self.services[ix].addresses {
                let v4Addr = self.getIPV4StringfromAddress(address: address)
                self.delegate?.serverUnregistered(ip: v4Addr!, port: Int32(self.services[ix].port))
            }
            self.services.remove(at:ix)
           
            print("removing a service")
            if !moreComing {
                self.updateInterface()
            }
        }
    }
    
    func didFindServer(ip: String, port: Int32) {
    }
}
