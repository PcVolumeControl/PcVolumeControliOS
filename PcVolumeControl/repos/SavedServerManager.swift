class SavedServerManager: ObservableObject {
    func loadSavedServers() {
        let decoder = JSONDecoder()

        if let lastConnectedData = defaults.object(forKey: "lastConnectedServer") as? Data,
           let lastConnectedServer = try? decoder.decode(DiscoveredServer.self, from: lastConnectedData) {
            selectedServer = lastConnectedServer
        }

        if let savedServers = defaults.object(forKey: "recentServers") as? Data,
           let loadedServers = try? decoder.decode([DiscoveredServer].self, from: savedServers) {
            usedServers = loadedServers

            // Fall back to the most recent history entry if no last-connected server was set.
            if selectedServer.address.isEmpty && !usedServers.isEmpty {
                selectedServer = usedServers[0]
            }
        }
    }

    func saveRecentServers() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(usedServers) {
            defaults.set(encoded, forKey: "recentServers")
        }
    }
    
    func saveLastConnectedServer(server: DiscoveredServer) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(server) {
            defaults.set(encoded, forKey: "lastConnectedServer")
        }
    }
}
