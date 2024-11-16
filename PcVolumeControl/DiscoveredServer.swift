//
//  DiscoveredServer.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 11/16/24.
//  Copyright © 2024 PcVolumeControl. All rights reserved.
//



class DiscoveredServer: Hashable {
    var id: String
    var address: String
    var port: UInt16
    
    init(address: String, port: UInt16) {
        self.address = address
        self.port = port
        self.id = address + String(port)
    }
    // for printing in the console and UI only
    func toString() -> String {
        return "\(self.address):\(self.port)"
    }
    // equality
    static func == (lhs: DiscoveredServer, rhs: DiscoveredServer) -> Bool {
        return lhs.toString() == rhs.toString()
    }
    // hashing
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.toString())
    }
}

func addUniqueElement(_ element: DiscoveredServer, to array: inout [DiscoveredServer]) {
    let isDuplicate = array.contains { existingElement in
        existingElement.id == element.id //concatenation of name/IP and port
    }
    
    if !isDuplicate {
//        array.append(element)
        array.insert(element, at: 0)
    }
}
