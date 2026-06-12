import Foundation
import Network


protocol TCPConnectionDataSourceProtocol {
    func openConnection(to server: DiscoveredServer) async throws -> Connection
}

struct TCPConnectionDataSource: TCPConnectionDataSourceProtocol {

    func openConnection(to server: DiscoveredServer) async throws -> Connection {

        let host = NWEndpoint.Host(server.address)
        guard let port = NWEndpoint.Port(rawValue: server.port) else {
            throw TCPConnectionError.invalidPort(server.port)
        }

        // TCP keepalive detects a silently dropped peer in ~25s (10s idle + 5s x3 probes) as a read error.
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 10      // seconds idle before first probe
        tcpOptions.keepaliveInterval = 5   // seconds between probes
        tcpOptions.keepaliveCount = 3      // missed probes before declaring dead
        let parameters = NWParameters(tls: nil, tcp: tcpOptions)

        let nwConnection = NWConnection(host: host, port: port, using: parameters)
        let queue = DispatchQueue(label: "TCPConnection-\(UUID().uuidString)")

        return try await withThrowingTaskGroup(of: Connection.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    // Use a class wrapper to make hasResumed thread-safe
                    final class ResumeState: @unchecked Sendable {
                        private let lock = NSLock()
                        private var _hasResumed = false

                        var hasResumed: Bool {
                            lock.lock()
                            defer { lock.unlock() }
                            return _hasResumed
                        }

                        func markResumed() -> Bool {
                            lock.lock()
                            defer { lock.unlock() }
                            if _hasResumed {
                                return false
                            }
                            _hasResumed = true
                            return true
                        }
                    }

                    let resumeState = ResumeState()

                    nwConnection.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            if resumeState.markResumed() {
                                continuation.resume(returning: Connection(nw: nwConnection))
                            }
                        case .failed(let error):
                            if resumeState.markResumed() {
                                continuation.resume(throwing: error)
                            }
                        case .cancelled:
                            if resumeState.markResumed() {
                                continuation.resume(throwing: TCPConnectionError.cancelledBeforeReady)
                            }
                        default:
                            break // .setup / .preparing / .waiting – keep waiting
                        }
                    }

                    nwConnection.start(queue: queue)
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                throw TCPConnectionError.connectionTimeout(server.address, server.port)
            }

            defer {
                group.cancelAll()
                if nwConnection.state != .ready {
                    nwConnection.cancel()
                }
            }

            return try await group.next()!
        }
    }
}
