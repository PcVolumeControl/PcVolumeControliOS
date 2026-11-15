//
//  LineFramerTests.swift
//  PcVolumeControlTests
//
//  Newline framing of the server byte stream, independent of socket read sizes.
//

import XCTest
@testable import PcVolumeControl

final class LineFramerTests: XCTestCase {

    private func strings(_ lines: [Data]) -> [String] {
        lines.map { String(decoding: $0, as: UTF8.self) }
    }

    func testCompleteLinesInOneRead() {
        var framer = LineFramer()
        XCTAssertEqual(strings(framer.append(Data("a\nbb\nccc\n".utf8))), ["a", "bb", "ccc"])
    }

    func testLineSplitAcrossReads() {
        var framer = LineFramer()
        XCTAssertEqual(framer.append(Data(#"{"protocol"#.utf8)), [])
        XCTAssertEqual(framer.append(Data(#"Version":8,"#.utf8)), [])
        XCTAssertEqual(strings(framer.append(Data((#""x":1}"# + "\n{").utf8))), [#"{"protocolVersion":8,"x":1}"#])
        XCTAssertEqual(strings(framer.append(Data("}\n".utf8))), ["{}"])
    }

    func testTerminatorSplitFromCarriageReturn() {
        var framer = LineFramer()
        XCTAssertEqual(framer.append(Data("abc\r".utf8)), [])
        XCTAssertEqual(strings(framer.append(Data("\n".utf8))), ["abc"])
    }

    func testBlankLinesAreSkipped() {
        var framer = LineFramer()
        XCTAssertEqual(strings(framer.append(Data("\n\r\na\n\n".utf8))), ["a"])
    }

    func testVeryLongLineInSocketSizedReads() {
        // Larger than any icon reply the protocol allows, delivered in 64 KiB reads.
        let longLine = Data(repeating: UInt8(ascii: "A"), count: 1_500_000)
        let stream = longLine + Data("\nnext\n".utf8)
        var framer = LineFramer()
        var lines: [Data] = []
        var offset = 0
        while offset < stream.count {
            let end = min(offset + 65_536, stream.count)
            lines += framer.append(stream.subdata(in: offset..<end))
            offset = end
        }
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines.first, longLine)
        XCTAssertEqual(lines.last, Data("next".utf8))
    }

    func testOneByteReads() {
        var framer = LineFramer()
        var lines: [Data] = []
        for byte in Data("ab\ncd\n".utf8) {
            lines += framer.append(Data([byte]))
        }
        XCTAssertEqual(strings(lines), ["ab", "cd"])
    }

    func testOverlongLineIsDiscardedAndFramingRecovers() {
        var framer = LineFramer(maxLineLength: 8)
        XCTAssertEqual(framer.append(Data("0123456789".utf8)), [])
        XCTAssertEqual(framer.append(Data("0123456789".utf8)), [])
        XCTAssertEqual(strings(framer.append(Data("tail\nok\n".utf8))), ["ok"])
        XCTAssertEqual(strings(framer.append(Data("fine\n".utf8))), ["fine"])
    }

    func testOverlongLineCompletedInOneReadIsDiscarded() {
        var framer = LineFramer(maxLineLength: 8)
        XCTAssertEqual(strings(framer.append(Data("0123456789\n12345678\n".utf8))), ["12345678"])
    }
}
