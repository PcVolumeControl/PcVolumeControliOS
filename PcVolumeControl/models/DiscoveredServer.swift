class DiscoveredServer: Hashable, Codable {
    var id: String
    var address: String
    var port: UInt16
    var computerName: String?
    
    init(address: String, port: UInt16, computerName: String? = nil) {
        self.address = address
        self.port = port
        self.computerName = computerName
        self.id = address + String(port)
    }
    
    func toString() -> String {
        return "\(self.address):\(self.port)"
    }

    static func == (lhs: DiscoveredServer, rhs: DiscoveredServer) -> Bool {
        return lhs.toString() == rhs.toString()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.toString())
    }

    enum CodingKeys: String, CodingKey {
        case id, address, port, computerName
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        address = try container.decode(String.self, forKey: .address)
        port = try container.decode(UInt16.self, forKey: .port)
        computerName = try container.decodeIfPresent(String.self, forKey: .computerName)
        id = try container.decode(String.self, forKey: .id)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(address, forKey: .address)
        try container.encode(port, forKey: .port)
        try container.encodeIfPresent(computerName, forKey: .computerName)
        try container.encode(id, forKey: .id)
    }
}
