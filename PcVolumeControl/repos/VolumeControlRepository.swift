import Foundation

struct VolumeControlRepository {
    static let protocolVersion = 7

    let transport: VolumeTransportDataSourceProtocol
    let deviceIdLookup = DeviceIdLookup()

    func fullStateStream() -> AsyncThrowingStream<FullState, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await msgBytes in transport.incoming() {
                        let state = try JSONDecoder().decode(FullState.self, from: msgBytes)
                        deviceIdLookup.ingest(state.deviceIds)
                        continuation.yield(state)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // Propagate consumer cancellation down the stream chain.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func pushDefaultDevice(id: String) async throws {
        let dto = ADefaultDeviceUpdate(
            protocolVersion: VolumeControlRepository.protocolVersion,
            defaultDevice: ADefaultDeviceUpdate.adflDevice(deviceId: id)
        )
        try await send(dto)
    }

    func pushMasterValues(id: String, muted: Bool, volume: Double) async throws {
        let dto = AMasterChannelUpdate(
            protocolVersion: VolumeControlRepository.protocolVersion,
            defaultDevice: AMasterChannelUpdate.adflDevice(
                deviceId: id,
                masterMuted: muted,
                masterVolume: volume
            )
        )
        try await send(dto)
    }

    func pushSessionValues(name: String, id: String, volume: Double, muted: Bool) async throws {
        let shortId = deviceIdLookup.shortId(for: id) ?? id
        let dto = ASessionUpdate(
            protocolVersion: VolumeControlRepository.protocolVersion,
            defaultDevice: ASessionUpdate.adflDevice(
                sessions: [OneSession(name: name, id: id, volume: volume, muted: muted)],
                deviceId: shortId
            )
        )
        try await send(dto)
    }

    private func send<T: Encodable>(_ dto: T) async throws {
        try await transport.outgoing(JSONEncoder().encode(dto))
    }
}

final class DeviceIdLookup {
    private var table = [String: String]()
    func ingest(_ mapping: [String: String]) {
        table.merge(mapping) { _, new in new }
    }
    func shortId(for longName: String) -> String? {
        table.first { longName.contains($0.key) }?.key
    }
}
