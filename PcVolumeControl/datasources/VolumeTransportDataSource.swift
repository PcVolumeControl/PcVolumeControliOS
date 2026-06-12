import Foundation

protocol VolumeTransportDataSourceProtocol {
    func outgoing(_ data: Data) async throws
    func incoming() -> AsyncThrowingStream<Data, Error>
    func close()
}

struct VolumeTransportDataSource: VolumeTransportDataSourceProtocol {
    let connection: Connection
    private let newline = Data([0x0A])

    func outgoing(_ data: Data) async throws {
        try await connection.send(data + newline)
    }

    func incoming() -> AsyncThrowingStream<Data, Error> {
        .streamNewlineDelimitedBytes(from: connection.bytes())
    }
    
    func close() {
        connection.close()
    }
}

private extension AsyncThrowingStream where Element == Data, Failure == Error {
    static func streamNewlineDelimitedBytes(from upstream: AsyncThrowingStream<Data, Error>)
        -> AsyncThrowingStream<Data, Error>
    {
        AsyncThrowingStream { continuation in
            var buffer = Data()
            let task = Task {
                do {
                    for try await chunk in upstream {
                        buffer.append(chunk)
                        while let nl = buffer.firstIndex(of: 0x0A) {
                            let frame = buffer.prefix(upTo: nl)
                            buffer.removeSubrange(...nl)
                            continuation.yield(Data(frame))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
