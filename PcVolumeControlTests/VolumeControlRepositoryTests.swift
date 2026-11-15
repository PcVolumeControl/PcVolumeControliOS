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
            ServerLineTests.plainState,
            "not json",
            #"{"protocolVersion":8,"somethingNew":true}"#,
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
            ServerLineTests.plainState,
            #"{"protocolVersion":8,"defaultDevice":{"deviceId":"x"}}"#,
            ServerLineTests.plainState,
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

    func testOlderServerEndsTheStreamWithAVersionMismatch() async {
        let transport = ScriptedTransport(lines: [ServerLineTests.olderServerState, ServerLineTests.plainState])
        let repo = VolumeControlRepository(transport: transport)

        var states = 0
        do {
            for try await _ in repo.serverLines() {
                states += 1
            }
            XCTFail("Expected the stream to end with an error")
        } catch {
            XCTAssertEqual((error as? ProtocolVersionMismatch)?.serverVersion, 7)
        }
        XCTAssertEqual(states, 0)
    }

    func testEveryOutgoingMessageSaysVersion8() async throws {
        let transport = MockVolumeTransport()
        let repo = VolumeControlRepository(transport: transport)
        try await repo.pushDefaultDevice(id: "dev-a")
        try await repo.pushMasterValues(id: "dev-a", muted: false, volume: 50)
        try await repo.pushSessionValues(name: "Firefox", id: "s1", volume: 40, muted: false, deviceId: "dev-a")
        try await repo.requestIcons(ids: ["abc"], size: 66)

        XCTAssertEqual(transport.sentData.count, 4)
        for data in transport.sentData {
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(json["protocolVersion"] as? Int, 8)
        }
    }

    func testIconRequestEncoding() async throws {
        let transport = MockVolumeTransport()
        let repo = VolumeControlRepository(transport: transport)
        try await repo.requestIcons(ids: ["abc", "def"], size: 66)

        let sent = try XCTUnwrap(transport.sentData.first)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: sent) as? [String: Any])
        XCTAssertEqual(json["protocolVersion"] as? Int, 8)
        XCTAssertNil(json["defaultDevice"])
        let request = try XCTUnwrap(json["iconRequest"] as? [String: Any])
        XCTAssertEqual(request["ids"] as? [String], ["abc", "def"])
        XCTAssertEqual(request["size"] as? Int, 66)
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
