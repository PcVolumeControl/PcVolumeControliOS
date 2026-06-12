import Foundation
import Network

enum TCPConnectionError: LocalizedError {
    case invalidPort(UInt16)
    case cancelledBeforeReady
    case connectionTimeout(String, UInt16)
    
    var errorDescription: String? {
        switch self {
        case .invalidPort(let port):
            return "Invalid port: \(port)"
        case .cancelledBeforeReady:
            return "Connection was cancelled before becoming ready"
        case .connectionTimeout(let address, let port):
            return "Connection timeout to \(address):\(port). The server did not respond within 5 seconds."
        }
    }
}

struct Connection {
    let nw: NWConnection
    
    func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { cont in
            nw.send(content: data, completion: .contentProcessed { err in
                err.map { cont.resume(throwing: $0) } ?? cont.resume()
            })
        }
    }

    func bytes() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            // Tear down the socket when the consumer cancels or the stream finishes.
            continuation.onTermination = { [nw] _ in nw.cancel() }
            func receiveNext() {
                nw.receive(minimumIncompleteLength: 1,
                           maximumLength: 65_536) { data, _, isComplete, error in
                    if let error { continuation.finish(throwing: error); return }
                    if let data { continuation.yield(data) }
                    if isComplete { continuation.finish() }
                    else { receiveNext() }
                }
            }
            receiveNext()
        }
    }

    func close() { nw.cancel() }
}
