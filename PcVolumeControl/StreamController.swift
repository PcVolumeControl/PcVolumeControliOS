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
    
    var address: String?
    var port: UInt32?
    var lastState: String
    var fullState: FullState?
    var serverConnected: Bool?
    var delegate: StreamControllerDelegate?
    let TCPTimeout = 5
    
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
    
    func processMessages() {
        let messageSubscription = lastMessageContent.subscribe {
            let message = $0.element
            //            guard let first: String = ($0 as AnyObject).element
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
            if $0.element == "NULL" { return }
            print("JSONSubscription: last full message\n\($0.element)")
            do {
                try self.JSONDecode(input: $0.element!)
            } catch CodingError.JSONDecodeProblem {
                print("JSONSubscription: JSON decode failed!!!!")
                //                self.lastMessageSubject.onCompleted()
            } catch {
                print("JSONSubscription: fell off the end...")
            }
        }
        
        
    }
    
    func setupNetworkCommunication() {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        let intport = UInt32(self.port!)
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                           self.address as! CFString,
                                           intport,
                                           &readStream,
                                           &writeStream)
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()
        inputStream.delegate = self
        inputStream.schedule(in: .current, forMode: .commonModes)
        outputStream.schedule(in: .current, forMode: .commonModes)
        inputStream.open()
        outputStream.open()
    }
    
    func sendString(input: String) {
        let data = input.data(using: .utf8)!
        
        _ = data.withUnsafeBytes { outputStream.write($0, maxLength: data.count) }
    }
}

extension StreamController: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            print("TCP: new data chunk seen")
            readAvailableBytes(stream: aStream as! InputStream)
        case Stream.Event.endEncountered:
            print("TCP: message end encountered")
        case Stream.Event.errorOccurred:
            print("TCP: socket error occurred. bailing...")
            connectionIssue()
        case Stream.Event.hasSpaceAvailable:
            print("TCP: has space available")
        default:
            print("TCP: some other event...")
            break
        }
    }
    private func readAvailableBytes(stream: InputStream) {
        
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)
        
        while stream.hasBytesAvailable {
            
            let numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLength)
            
            if numberOfBytesRead < 0 {
                if let _ = stream.streamError {
                    break
                }
            }
            if let message = processedMessageString(buffer: buffer, length: numberOfBytesRead) {
                // add the message into the array
                print("TCP: Message chunk of length: \(message.count) added to messageContent")
                lastMessageContent.onNext(message)
            }
        }
        
    }
    private func processedMessageString(buffer: UnsafeMutablePointer<UInt8>,
                                        length: Int) -> String? {
        
        let stringArray = String(bytesNoCopy: buffer,
                                 length: length,
                                 encoding: .utf8,
                                 freeWhenDone: true)
        return stringArray
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

