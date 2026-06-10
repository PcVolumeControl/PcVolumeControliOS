import Network

struct ServersRepository {
    let local: ServersLocalDataSourceProtocol
    let remote: TCPConnectionDataSourceProtocol
    
    func connect(to server: DiscoveredServer) async throws -> VolumeControlRepository {
        let connection = try await remote.openConnection(to: server)
        let transport = VolumeTransportDataSource(connection: connection)
        return VolumeControlRepository(transport: transport)
    }
    
    func recent() -> [DiscoveredServer] { local.loadRecent() }
    func saveRecent(_ list: [DiscoveredServer]) { local.saveRecent(list) }
}
