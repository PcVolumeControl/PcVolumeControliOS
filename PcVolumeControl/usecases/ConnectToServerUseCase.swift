import Network

struct ConnectToServerUseCase {
    let repo: ServersRepository

    func execute(address: String, port: UInt16) async throws -> VolumeControlRepository {
        let server = DiscoveredServer(address: address, port: port, computerName: nil)
        return try await repo.connect(to: server)
    }
}
