import Foundation

/// Splits a byte stream into newline-terminated lines, independent of how the bytes
/// were chunked by the socket. A trailing `\r` is dropped and blank lines are skipped.
/// A line longer than `maxLineLength` is discarded up to its terminator so one bad
/// line cannot grow the buffer without bound or end the stream.
struct LineFramer {
    /// Icon replies can be several hundred KiB; the protocol requires accepting at least 1 MiB.
    static let defaultMaxLineLength = 4 * 1024 * 1024

    private let maxLineLength: Int
    private var buffer: [UInt8] = []
    // Bytes at the front of `buffer` already searched for a newline.
    private var searchedCount = 0
    private var discardingOverlongLine = false

    init(maxLineLength: Int = LineFramer.defaultMaxLineLength) {
        self.maxLineLength = maxLineLength
    }

    /// Appends `chunk` and returns every line it completes, in order.
    mutating func append(_ chunk: Data) -> [Data] {
        buffer.append(contentsOf: chunk)

        var lines: [Data] = []
        var lineStart = 0
        var searchFrom = searchedCount
        while let newline = buffer[searchFrom...].firstIndex(of: 0x0A) {
            if discardingOverlongLine {
                discardingOverlongLine = false
            } else {
                var lineEnd = newline
                if lineEnd > lineStart, buffer[lineEnd - 1] == 0x0D {
                    lineEnd -= 1
                }
                if lineEnd > lineStart, lineEnd - lineStart <= maxLineLength {
                    lines.append(Data(buffer[lineStart..<lineEnd]))
                }
            }
            lineStart = newline + 1
            searchFrom = lineStart
        }

        buffer.removeFirst(lineStart)
        searchedCount = buffer.count
        if buffer.count > maxLineLength {
            buffer.removeAll()
            searchedCount = 0
            discardingOverlongLine = true
        }
        return lines
    }
}
