import Network

struct ServersRepository {
    let local: ServersLocalDataSourceProtocol
    let remote: TCPConnectionDataSourceProtocol
    // Tests substitute a scripted transport to drive the view model without a socket.
    var makeTransport: (Connection) -> VolumeTransportDataSourceProtocol = { VolumeTransportDataSource(connection: $0) }
    
    func connect(to server: DiscoveredServer) async throws -> VolumeControlRepository {
        let connection = try await remote.openConnection(to: server)
        return VolumeControlRepository(transport: makeTransport(connection))
    }
    
    func recent() -> [DiscoveredServer] { local.loadRecent() }
    func saveRecent(_ list: [DiscoveredServer]) { local.saveRecent(list) }
}
