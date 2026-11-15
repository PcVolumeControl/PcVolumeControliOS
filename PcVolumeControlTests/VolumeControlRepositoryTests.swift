//
//  VolumeControlRepositoryTests.swift
//  PcVolumeControlTests
//
//  The repository's line stream: states and icon replies are delivered, anything
//  else is dropped without ending the stream.
//

import XCTest
@testable import PcVolumeControl

final class VolumeControlRepositoryTests: XCTestCase {

    func testUnknownAndMalformedLinesDoNotEndTheStream() async throws {
        let transport = ScriptedTransport(lines: [
            ServerLineTests.v7State,
            "not json",
            #"{"protocolVersion":7,"somethingNew":true}"#,
            ServerLineTests.iconNotFoundReply,
            ServerLineTests.v8State,
        ])
        let repo = VolumeControlRepository(transport: transport)

        var kinds: [String] = []
        for try await line in repo.serverLines() {
            switch line {
            case .state: kinds.append("state")
            case .icon: kinds.append("icon")
            }
        }
        XCTAssertEqual(kinds, ["state", "icon", "state"])
    }

    func testUndecodableFullStateEndsTheStream() async {
        let transport = ScriptedTransport(lines: [
            ServerLineTests.v7State,
            #"{"protocolVersion":7,"defaultDevice":{"deviceId":"x"}}"#,
            ServerLineTests.v7State,
        ])
        let repo = VolumeControlRepository(transport: transport)

        var states = 0
        do {
            for try await _ in repo.serverLines() {
                states += 1
            }
            XCTFail("Expected the stream to end with an error")
        } catch {
            XCTAssertTrue(error is MalformedStateError)
        }
        XCTAssertEqual(states, 1)
    }
}

/// A transport that delivers a fixed list of lines, then ends.
final class ScriptedTransport: VolumeTransportDataSourceProtocol {
    private let lines: [String]

    init(lines: [String]) {
        self.lines = lines
    }

    func outgoing(_ data: Data) async throws {}

    func incoming() -> AsyncThrowingStream<Data, Error> {
        let lines = lines
        return AsyncThrowingStream { continuation in
            for line in lines {
                continuation.yield(Data(line.utf8))
            }
            continuation.finish()
        }
    }

    func close() {}
}
