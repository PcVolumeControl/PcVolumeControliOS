import Foundation

// Outgoing JSON wire-protocol payloads sent to the server (encode-only).

// to change the default device
struct ADefaultDeviceUpdate : Codable {
    struct adflDevice : Codable {
        let deviceId: String
    }
    let protocolVersion: Int
    let defaultDevice: adflDevice
}

// volume and/or mute for a master device
struct AMasterChannelUpdate : Codable {
    struct adflDevice : Codable {
        let deviceId: String
        let masterMuted: Bool
        let masterVolume: Double
    }
    let protocolVersion: Int
    let defaultDevice: adflDevice
}

// individual session slider/mute updates
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
    let volume: Double
    let muted: Bool
}
