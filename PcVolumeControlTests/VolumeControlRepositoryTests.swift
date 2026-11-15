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

    func testSessionUpdateDoesNotSendDetail() async throws {
        let transport = MockVolumeTransport()
        let repo = VolumeControlRepository(transport: transport)
        let session = FullState.Session(
            id: "dev-a|961", muted: false, name: "Firefox", volume: 40,
            iconId: "4b13f0d55a3779a6ff892414f951be3f", detail: "Big Buck Bunny - YouTube"
        )
        try await repo.pushSessionValues(name: session.name, id: session.id, volume: session.volume, muted: session.muted)

        let sent = try XCTUnwrap(transport.sentData.first)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: sent) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["protocolVersion", "defaultDevice"])
        let device = try XCTUnwrap(json["defaultDevice"] as? [String: Any])
        XCTAssertEqual(Set(device.keys), ["sessions", "deviceId"])
        let sessions = try XCTUnwrap(device["sessions"] as? [[String: Any]])
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(Set(sessions[0].keys), ["name", "id", "volume", "muted"])
    }

    func testIconRequestEncoding() async throws {
        let transport = MockVolumeTransport()
        let repo = VolumeControlRepository(transport: transport)
        try await repo.requestIcons(ids: ["abc", "def"], size: 66)

        let sent = try XCTUnwrap(transport.sentData.first)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: sent) as? [String: Any])
        XCTAssertEqual(json["protocolVersion"] as? Int, 7)
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
