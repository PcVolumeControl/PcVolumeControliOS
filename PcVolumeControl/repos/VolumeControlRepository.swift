import Foundation

struct VolumeControlRepository {
    static let protocolVersion = 7

    let transport: VolumeTransportDataSourceProtocol
    let deviceIdLookup = DeviceIdLookup()

    /// Full states and icon replies from the server; lines of any other kind are dropped.
    /// Ends with an error for a full state that cannot be decoded.
    func serverLines() -> AsyncThrowingStream<ServerLine, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await bytes in transport.incoming() {
                        guard let line = try ServerLine.classify(bytes) else {
                            appLog("Ignoring unrecognized server line (\(bytes.count) bytes)")
                            continue
                        }
                        if case .state(let state) = line {
                            deviceIdLookup.ingest(state.deviceIds)
                        }
                        continuation.yield(line)
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

    func requestIcons(ids: [String], size: Int) async throws {
        let dto = AIconRequest(
            protocolVersion: VolumeControlRepository.protocolVersion,
            iconRequest: AIconRequest.Payload(ids: ids, size: size)
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
