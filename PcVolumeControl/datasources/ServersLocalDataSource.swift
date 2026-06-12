import Foundation

/// Purely synchronous, stateless access to the persisted “recent servers” list.
protocol ServersLocalDataSourceProtocol {
    /// Return the list in most-recent–first order.
    func loadRecent() -> [DiscoveredServer]

    /// Overwrite the stored list (idempotent).
    func saveRecent(_ list: [DiscoveredServer])
}

struct ServersLocalDataSource: ServersLocalDataSourceProtocol {
    private let defaults: UserDefaults
    private static let key = "recentServers"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadRecent() -> [DiscoveredServer] {
        guard
            let data = defaults.data(forKey: Self.key),
            let decoded = try? JSONDecoder().decode([DiscoveredServer].self, from: data)
        else { return [] }
        return decoded
    }

    func saveRecent(_ list: [DiscoveredServer]) {
        guard let encoded = try? JSONEncoder().encode(list) else { return }
        defaults.set(encoded, forKey: Self.key)
    }
}
