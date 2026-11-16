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
        .streamLines(from: connection.bytes())
    }
    
    func close() {
        connection.close()
    }
}

private extension AsyncThrowingStream where Element == Data, Failure == Error {
    static func streamLines(from upstream: AsyncThrowingStream<Data, Error>)
        -> AsyncThrowingStream<Data, Error>
    {
        AsyncThrowingStream { continuation in
            let task = Task {
                var framer = LineFramer()
                do {
                    for try await chunk in upstream {
                        for line in framer.append(chunk) {
                            continuation.yield(line)
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
