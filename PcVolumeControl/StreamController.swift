//
//  StreamController.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 12/20/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa
import SwiftSocket

protocol StreamControllerDelegate {
    func didGetServerUpdate()
    func bailToConnectScreen()
    func tearDownConnection()
}

class StreamController: NSObject {
    // This class uses RxSwift to communicate over a TCP socket.
    // Note that HTTP is not used. It is a raw TCP socket.
    var inputStream: InputStream!
    var outputStream: OutputStream!
    let maxReadLength = 8192
    
    var address: String
    var port: UInt32
    var lastState: String
    var fullState: FullState?
    var serverConnected: Bool?
    var delegate: StreamControllerDelegate?
    let TCPTimeout = 2
    var ClientConnection: TCPClient?
    
    // Rx stuff
    let bag = DisposeBag()
    var lastMessageSubject = BehaviorSubject<String>(value: "NULL") // holds the last full message
    var lastMessageContent = PublishSubject<String>() // holds the strings of messages to be combined
    
    enum CodingError: Error {
        case JSONDecodeProblem // garbage data, bad decode
    }
    enum ConnectionError: Error {
        case ServerConnectionError // IP:port or FQDN:port wrong or not reachable.
    }
    
    init(address: String, port: UInt32, delegate: StreamControllerDelegate) {
        // This is run on initial tap of the 'connect' button or on any spontaneous reconnect.
        self.address = address
        self.port = port
        self.serverConnected = false
        self.delegate = delegate
        self.lastState = ""
    }
    
    private func serverUpdated() {
        self.delegate?.didGetServerUpdate()
        
    }
    private func connectionIssue() {
        self.delegate?.bailToConnectScreen()
        self.serverConnected = false
    }
    private func tearDownServerConnection() {
        self.delegate?.tearDownConnection()
        self.serverConnected = false
    }
    
    func sendString(input: String){
        guard let client = ClientConnection else { return }
        switch client.send(string: input) {
            case .success:
                var responsestring: String = ""
                var allFullResponses = Set<String>() // for dedup
                while !responsestring.hasSuffix("\n") {
                    // read some more data
                    if let responseChunk = ClientConnection?.read(1024*10, timeout: TCPTimeout) {
                        // convert that data into a string
                        // BUG: At this point, if the server sent us multiple replies, they're all going
                        // to be in this same read(). We have to read more intelligently or just break it
                        // up clientside...I guess?
                        if let stringified = String(bytes: responseChunk, encoding: .utf8) {
                            responsestring += stringified
                            if responsestring.hasSuffix("\n") {
                                // It's a full message. Decode it.
                                // HACK: Check for multiple messages.
                                for resp in responsestring.components(separatedBy: "\n") {
                                    allFullResponses.insert(resp)
                                }
                                allFullResponses.remove("") // get rid of the empty string we initialized with
                                guard let singleUpdate = allFullResponses.popFirst() else { break }
                                print("Response:\n\(singleUpdate)")
                                lastMessageSubject.onNext(singleUpdate)
                                break
                            }
                        }
                    }
                }
            case .failure(let error):
                print(error)
            }
       
    }
    
    func connectNoSend(ip: String, port: UInt32) {
        // Make the initial TCP connection.
        let client = TCPClient(address: address, port: Int32(port))
        ClientConnection = client
        switch client.connect(timeout: TCPTimeout) {
        case .success:
            var responsedata = [UInt8]()
            var responsestring: String = ""
            while true {
                if let responseChunk = client.read(1024*10, timeout: TCPTimeout) {
                    responsedata += responseChunk
                    if let stringified = String(bytes: responseChunk, encoding: .utf8) {
                        responsestring += stringified
//                        print("Response:\n\(responsestring)")
                        
                        if responsestring.hasSuffix("\n") {
                            // It's a full message. Decode it.
                            lastMessageSubject.onNext(responsestring)
                            break
                            
                        }
                    }
                }
            }
        case .failure(let error):
            print(error)
            // socket error
        }
    }
    
    func processMessages() {
        let messageSubscription = lastMessageContent.subscribe {
            let message = $0.element
            if message!.hasSuffix("}\n") {
                // append what we just saw, notify subscribers, reset the last known state string.
                self.lastState += message!
                self.lastMessageSubject.onNext(self.lastState)
                print("PCVC: End of message detected. can be parsed now...")
                self.lastState = "" // reset the last state
                
            } else {
                print("PCVC: Newline not detected. It's a partial update.")
                self.lastState += message!
            }
        }
        let jsonSubscription = lastMessageSubject.subscribe {
            guard let message = $0.element else { return }
            if message == "NULL" { return } // first message ever
            
            // TODO: hack. Only return the first message if the whole update contains multiple messages.
            if message.contains("\n") {
                let wholeUpdate = message.components(separatedBy: "\n")
                guard let firstUpdate = wholeUpdate.first else { print("didn't see the first update"); return }
                do {
                    try self.JSONDecode(input: firstUpdate)
                } catch CodingError.JSONDecodeProblem {
                    print("JSONSubscription: JSON decode failed!!!!")
                } catch {
                    print("JSONSubscription: fell off the end...")
                }
            }
        }
    }
    func JSONDecode(input: String) throws {
        
        // try to decode a JSON string. If it's partial, throw an error.
        let json = input.data(using: .utf8)
        do {
            guard let fs = try JSONDecoder().decode(FullState?.self, from: json!) else {
                return
            }
            print("JSONDecode: Successfully decoded the payload.")
            serverConnected = true
            fullState = fs
            serverUpdated()
            print("JSONDecode: pushing initial server update into fullstate...")
            
        } catch Swift.DecodingError.dataCorrupted {
            // partial message received, probably
            throw CodingError.JSONDecodeProblem
        } catch {
            // should never get here?
            print(error.localizedDescription)
            connectionIssue()
        }
    }
}

class FullState : Codable {
    struct theDefaultDevice : Codable {
        let deviceId: String
        let masterMuted: Bool
        let masterVolume: Double
        let name: String
        let sessions: [Session]
        
    }
    struct Session : Codable {
        let id: String
        let muted: Bool
        let name: String
        let volume: Double
    }
    let defaultDevice: theDefaultDevice
    let deviceIds: [String: String]
    let version: Int
    
    init(version: Int, deviceIds: [String:String], defaultDevice: theDefaultDevice) {
        self.version = version
        self.deviceIds = deviceIds
        self.defaultDevice = defaultDevice
    }
}

