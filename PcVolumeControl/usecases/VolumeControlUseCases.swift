struct SendDefaultDeviceUpdateUseCase {
    let repo: VolumeControlRepository
    func execute(_ id: String) async throws { try await repo.pushDefaultDevice(id: id) }
}

struct SendMasterChannelUpdateUseCase {
    let repo: VolumeControlRepository
    func execute(id: String, muted: Bool, volume: Double) async throws {
        try await repo.pushMasterValues(id: id, muted: muted, volume: volume)
    }
}

struct SendSessionUpdateUseCase {
    let repo: VolumeControlRepository
    func execute(name: String, id: String, vol: Double, muted: Bool) async throws {
        try await repo.pushSessionValues(name: name, id: id, volume: vol, muted: muted)
    }
}
