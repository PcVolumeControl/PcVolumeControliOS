import Foundation

struct VolumeControlRepository {
    let transport: VolumeTransportDataSourceProtocol

    /// Full states and icon replies from the server; lines of any other kind are dropped.
    /// Ends with `ProtocolVersionMismatch` for a full state of another protocol version and
    /// with `MalformedStateError` for one that cannot be decoded.
    func serverLines() -> AsyncThrowingStream<ServerLine, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await bytes in transport.incoming() {
                        guard let line = try ServerLine.classify(bytes) else {
                            appLog("Ignoring unrecognized server line (\(bytes.count) bytes)")
                            continue
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
            protocolVersion: WireProtocol.version,
            defaultDevice: ADefaultDeviceUpdate.adflDevice(deviceId: id)
        )
        try await send(dto)
    }

    func pushMasterValues(id: String, muted: Bool, volume: Double) async throws {
        let dto = AMasterChannelUpdate(
            protocolVersion: WireProtocol.version,
            defaultDevice: AMasterChannelUpdate.adflDevice(
                deviceId: id,
                masterMuted: muted,
                masterVolume: volume
            )
        )
        try await send(dto)
    }

    /// `deviceId` is the id of the device the session plays on; session ids are opaque.
    func pushSessionValues(name: String, id: String, volume: Double, muted: Bool, deviceId: String) async throws {
        let dto = ASessionUpdate(
            protocolVersion: WireProtocol.version,
            defaultDevice: ASessionUpdate.adflDevice(
                sessions: [OneSession(name: name, id: id, volume: volume, muted: muted)],
                deviceId: deviceId
            )
        )
        try await send(dto)
    }

    func requestIcons(ids: [String], size: Int) async throws {
        let dto = AIconRequest(
            protocolVersion: WireProtocol.version,
            iconRequest: AIconRequest.Payload(ids: ids, size: size)
        )
        try await send(dto)
    }

    private func send<T: Encodable>(_ dto: T) async throws {
        try await transport.outgoing(JSONEncoder().encode(dto))
    }
}
