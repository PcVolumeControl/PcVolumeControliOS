import Foundation

/// Shared connection state between app and widget
struct SharedConnectionState: Codable {
    var isConnected: Bool
    var lastSeenAlive: Date
    var serverName: String?
    var serverAddress: String?
    var masterVolume: Double
    var chatVolume: Double?
    var chatSessionName: String?

    init(
        isConnected: Bool = false,
        lastSeenAlive: Date = Date(),
        serverName: String? = nil,
        serverAddress: String? = nil,
        masterVolume: Double = 0,
        chatVolume: Double? = nil,
        chatSessionName: String? = nil
    ) {
        self.isConnected = isConnected
        self.lastSeenAlive = lastSeenAlive
        self.serverName = serverName
        self.serverAddress = serverAddress
        self.masterVolume = masterVolume
        self.chatVolume = chatVolume
        self.chatSessionName = chatSessionName
    }

    /// Returns true if the connection state is older than 45 seconds
    var isStale: Bool {
        Date().timeIntervalSince(lastSeenAlive) > 45
    }

    /// Returns a human-readable string indicating how long ago the state was updated
    var staleDurationString: String {
        let interval = Date().timeIntervalSince(lastSeenAlive)
        if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval/60))m ago"
        } else {
            return "\(Int(interval/3600))h ago"
        }
    }

    var displayServerName: String {
        serverName ?? serverAddress ?? "Unknown"
    }
}

/// Helper for reading/writing shared state to App Group container
struct SharedStateManager {
    static let appGroupIdentifier = "group.cwb.PcVolumeControl"
    private static let stateKey = "connectionState"

    static func readState() -> SharedConnectionState? {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            appLog("Failed to access shared UserDefaults with suite: \(appGroupIdentifier)")
            return nil
        }

        guard let data = sharedDefaults.data(forKey: stateKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(SharedConnectionState.self, from: data)
        } catch {
            appLog("Failed to decode shared state: \(error)")
            return nil
        }
    }

    static func writeState(_ state: SharedConnectionState) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            appLog("Failed to access shared UserDefaults for writing")
            return
        }

        do {
            let data = try JSONEncoder().encode(state)
            sharedDefaults.set(data, forKey: stateKey)
            sharedDefaults.synchronize()
        } catch {
            appLog("Failed to encode shared state: \(error)")
        }
    }

}
