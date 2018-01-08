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
import Socket

protocol StreamControllerDelegate {
    func didGetServerUpdate()
    func bailToConnectScreen()
    func tearDownConnection()
    func didConnectToServer()
    func isAttemptingConnection()
    func failedToConnect()
}

class StreamController: NSObject {
    // This class uses RxSwift to communicate over a TCP socket.
    // Note that HTTP is not used. It is a raw TCP socket.
    var clientSocket: Socket?
    
    var address: String
    var port: Int32
    var lastState: String
    var fullState: FullState?
    var serverConnected: Bool?
    var delegate: StreamControllerDelegate?
    let TCPTimeout: UInt = 2
    
    // Rx stuff
    let bag = DisposeBag()
    var lastMessageSubject = PublishSubject<String>()
    
    enum CodingError: Error {
        case JSONDecodeProblem // garbage data, bad decode
    }
    enum ConnectionError: Error {
        case ServerConnectionError // IP:port or FQDN:port wrong or not reachable.
    }
    
    init(address: String, port: Int32, delegate: StreamControllerDelegate) {
        // This is run on initial tap of the 'connect' button or on any spontaneous reconnect.
        self.address = address
        self.port = port
        self.serverConnected = false
        self.delegate = delegate
        self.lastState = ""
        self.clientSocket = try! Socket.create()
    }
    
    private func serverUpdated() {
        self.delegate?.didGetServerUpdate()
        
    }
    private func connectionIssue() {
        self.delegate?.bailToConnectScreen()
        serverConnected = false
        disconnect()
    }
    func tearDownServerConnection() {
        self.delegate?.tearDownConnection()
        serverConnected = false
        disconnect()
    }
    func didConnectToServer() {
        // Signal to delegates that the socket is open.
        self.delegate?.didConnectToServer()
    }
    
    func disconnect() {
        if let cs = clientSocket {
            cs.close()
            print("Socket disconnected by user.")
        }
    }
    
    func connectNoSend() {
        self.delegate?.isAttemptingConnection()
        do {
            let mySocket = try Socket.create()
            clientSocket = mySocket
            try clientSocket?.connect(to: address, port: port, timeout: 2000)
            print("socket connected!")
            self.delegate?.didConnectToServer() // signal we connected.
            while true {
                if clientSocket?.isConnected == false {
                    break
                }
                let result = pollSocket(socket: mySocket)
                if result != nil {
                    print("result: \(String(describing: result))\n")
                    lastMessageSubject.onNext(result!)
                } else {
                    break
                }
            }
        }
        catch let error {
            guard let _ = error as? Socket.Error else {
                print("Unexpected socket error!")
                return
            }
        }
        self.delegate?.failedToConnect()
    }
    
    func sendString(input: String) {
        print("Client has data to send to the server...\n\(input)")
        if let cs = clientSocket {
            try! cs.write(from: input)
        }
    }
    
    func pollSocket(socket: Socket) -> String? {
            var shouldKeepRunning = true
            
            var readData = Data(capacity: 1024)
            var responseString = ""
            
            do {
                repeat {
                    let bytesRead = try socket.read(into: &readData)
                    
                    if bytesRead > 0 {
                        guard let response = String(data: readData, encoding: .utf8) else {
                            print("Error string decoding response...")
                            readData.count = 0
                            break
                        }
                        responseString += response
                        if response.hasSuffix("\n") {
                            print("newline detected! That's the end of a message from the server.")
                            return responseString
                        }
                        print("This iOS client received made connection to \(socket.remoteHostname):\(socket.remotePort): \(response) ")
                    }
                    
                    if bytesRead == 0 {
                        
                        shouldKeepRunning = false
                        break
                    }
                    
                    readData.count = 0
                    
                } while shouldKeepRunning
                
                print("Socket: \(socket.remoteHostname):\(socket.remotePort) closed...")
                socket.close()
                serverConnected = false
                
            }
            catch let error {
                guard let socketError = error as? Socket.Error else {
                    print("Unexpected error by connection at \(socket.remoteHostname):\(socket.remotePort)...")
                    return "Error!"
                }
            }
        // If we got to this point, the server closed the connection.
        socket.close()
        connectionIssue()
        return "Socket has been closed!"
        }
    
    func processMessages() {
        let distinct = lastMessageSubject.distinctUntilChanged()
        let jsonSubscription = distinct.subscribe {
            guard let message = $0.element else { return }
            
            do {
                try self.JSONDecode(input: message)
            } catch CodingError.JSONDecodeProblem {
                print("JSONSubscription: JSON decode failed!!!!")
                print("Here is what we attempted to decode:\n\n\(message)")
            } catch {
                print("JSONSubscription: fell off the end...")
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
        let masterVolume: Float
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
    let protocolVersion: Int
    
    init(protocolVersion: Int, deviceIds: [String:String], defaultDevice: theDefaultDevice) {
        self.protocolVersion = protocolVersion
        self.deviceIds = deviceIds
        self.defaultDevice = defaultDevice
    }
}
