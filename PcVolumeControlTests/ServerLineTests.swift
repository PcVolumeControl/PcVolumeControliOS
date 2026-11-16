//
//  ServerLineTests.swift
//  PcVolumeControlTests
//
//  Decoding and classification of protocol version 8 server lines, including icon
//  replies captured from a server, and the version check.
//

import XCTest
import UIKit
@testable import PcVolumeControl

final class ServerLineTests: XCTestCase {

    // A server that serves no icons or details: no `iconId`, no `detail`.
    static let plainState = #"""
    {"protocolVersion":8,"applicationVersion":"v10","deviceIds":{"dev-a":"Speakers"},"defaultDevice":{"deviceId":"dev-a","name":"Speakers","masterVolume":80.0,"masterMuted":false,"sessions":[{"name":"Chrome","id":"{0.0.0.00000000}.{dev-a}|chrome.exe","volume":35.0,"muted":false}]}}
    """#

    // The original C# Windows server: the same shape, but protocol version 7.
    static let olderServerState = #"""
    {"protocolVersion":7,"applicationVersion":"v10","deviceIds":{"dev-a":"Speakers"},"defaultDevice":{"deviceId":"dev-a","name":"Speakers","masterVolume":80.0,"masterMuted":false,"sessions":[{"name":"Chrome","id":"{0.0.0.00000000}.{dev-a}|chrome.exe","volume":35.0,"muted":false}]}}
    """#

    // examples/full-state.json from the protocol repo (the reference mock server), on one line.
    static let referenceState = #"""
    {"protocolVersion":8,"applicationVersion":"v10","deviceIds":{"0f4090a9-dee2-4563-ba29-0ad6b93d9e22":"Speakers (Mock Audio)","c5a32106-264d-40b2-a2e0-74eda397454c":"Headphones (Mock Audio)","c98e4030-926b-4e62-8c83-1c529574cc51":"Headset (Mock USB Audio)"},"defaultDevice":{"deviceId":"0f4090a9-dee2-4563-ba29-0ad6b93d9e22","name":"Speakers (Mock Audio)","masterVolume":80.0,"masterMuted":false,"sessions":[{"name":"Firefox","id":"mock-9ff8bf89-firefox","volume":100.0,"muted":false,"iconId":"demo1d94c5a"},{"name":"Spotify","id":"mock-9ff8bf89-spotify","volume":65.0,"muted":false,"iconId":"demo1b64cd9"},{"name":"Discord","id":"mock-9ff8bf89-discord","volume":40.0,"muted":false,"iconId":"demo174d94c"},{"name":"Musique été","id":"mock-9ff8bf89-musique","volume":55.0,"muted":false,"iconId":"demo14cd968"},{"name":"Firefox","id":"mock-9ff8bf89-firefox-radio","volume":70.0,"muted":false,"iconId":"demo1d94c5a","detail":"Radio Paradise - Main Mix"},{"name":"Firefox","id":"mock-9ff8bf89-firefox-video","volume":90.0,"muted":false,"iconId":"demo1d94c5a","detail":"Tears of Steel - YouTube"}]}}
    """#

    // Shape captured from a v8 server (device names shortened): one session without an
    // icon id yet, and two sessions sharing an id.
    static let v8State = #"""
    {"protocolVersion":8,"applicationVersion":"v10","deviceIds":{"dev-a":"Headset","dev-b":"Speakers"},"defaultDevice":{"deviceId":"dev-a","name":"Headset","masterVolume":100.0,"masterMuted":false,"sessions":[{"name":"speech-dispatcher-dummy","id":"dev-a|413","volume":100.0,"muted":false},{"name":"Firefox","id":"dev-a|961","volume":100.0,"muted":false,"iconId":"4b13f0d55a3779a6ff892414f951be3f"},{"name":"Firefox","id":"dev-a|6492","volume":100.0,"muted":false,"iconId":"4b13f0d55a3779a6ff892414f951be3f"},{"name":"Spotify","id":"dev-a|6565","volume":100.0,"muted":false,"iconId":"6b58026ae167f8f2e802f2531657443c"}]}}
    """#

    // Captured from a v8 server on Linux with Firefox playing in three tabs. Device names
    // are shortened and the tab titles replaced; field order and shape are as sent.
    static let v8StateWithDetails = #"""
    {"protocolVersion":8,"applicationVersion":"v10","deviceIds":{"dev-a":"Speakers","dev-b":"Headset"},"defaultDevice":{"deviceId":"dev-a","name":"Speakers","masterVolume":36.439514,"masterMuted":false,"sessions":[{"name":"speech-dispatcher-dummy","id":"dev-a|413","volume":100.0,"muted":false},{"name":"Firefox","id":"dev-a|961","volume":100.0,"muted":false,"iconId":"4b13f0d55a3779a6ff892414f951be3f","detail":"Big Buck Bunny - YouTube"},{"name":"Firefox","id":"dev-a|6622","volume":100.0,"muted":false,"iconId":"4b13f0d55a3779a6ff892414f951be3f","detail":"Radio Paradise - Main Mix"},{"name":"Firefox","id":"dev-a|6974","volume":100.0,"muted":false,"iconId":"4b13f0d55a3779a6ff892414f951be3f","detail":"Café Concert: You've Got a Friend…"}]}}
    """#

    // Captured verbatim from a v8 server: a 16 px PNG reply and a notFound reply.
    static let iconImageReply = #"""
    {"protocolVersion":8,"icon":{"id":"6b58026ae167f8f2e802f2531657443c","size":16,"mime":"image/png","data":"iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACWUlEQVR4Ae3AA6AkWZbG8f937o3IzKdyS2Oubdu2bdu2bdu2bWmMnpZKr54yMyLu+Xa3anqmhztr1U/8+yCej1se/14vZ8Vby34UgKQn5qifuf0lvvPPeU6IB7j2b97jmllfvh14C56/n1sP7f3vfanvu48rEM/0sKe8xzXjWH4feAQvjP2Urs9Xe+rDv+8+APFMtzz+fX4O/Oa8KMwv3vbY734zAAE8+G/e45WyL388/fodDN/3FPLeJawb9EGcWRCP2KG8whnqa16PtjoAYuBVbn2p7/5jAdzy9+/9xRQ+qf31efJvzqMbNtGi4FXD9yxpj9+l/fl9eDLdWz2I2Ue+OJgvue2x3/3JAnjQP7zXTzn01qwaw088nbz9AI4mWFTihg3iJU5SH3Oc6bfvpv35OWaf/jIY//Ttj/2etxHALf/wnj9NxFv50sDwXU8ibthAmxUvG3n7Ae0vz5O7a/p3eCj9ez6Cy1r+zG0v/r1vLYCb/+Y9v0x9fDzA9Mf30f7mPD4Y0aISD9mmvuIZfG7F9Ot30X/IYyAEw/Rlt73U93+iAG75/Xd5dU7Nfg9g+p270ayg7Q4fTuRT95h+/250cs78014a5pXLdo9e/bZX+dE/EFfolr95j1+lL6/PC5BP2nU8dEfUwKv2a7e/zPe9EWDxTDf+xJvcVB5++vfpy4N4YaZ8RnvS2Ve/8+1+6Q4A8QAnv/MNb954iTPfFVvd6/F85MH4G/l3Z9/nrvf91du5AvG84rqfeuvXrNcs3pqiRxLA6CdN9y1/+p63+enfBZJnQ/z78I+X+d0RjTFkMwAAAABJRU5ErkJggg=="}}
    """#
    static let iconNotFoundReply = #"""
    {"protocolVersion":8,"icon":{"id":"0000notarealid","error":"notFound"}}
    """#

    private func classify(_ text: String) throws -> ServerLine? {
        try ServerLine.classify(Data(text.utf8))
    }

    // MARK: - Full state decoding

    func testStateWithoutIconsOrDetailsDecodes() throws {
        guard case .state(let state) = try classify(Self.plainState) else {
            return XCTFail("Expected a full state")
        }
        XCTAssertEqual(state.protocolVersion, 8)
        XCTAssertEqual(state.defaultDevice.sessions.count, 1)
        XCTAssertNil(state.defaultDevice.sessions[0].iconId)
        XCTAssertEqual(state.defaultDevice.sessions[0].volume, 35.0)
    }

    func testReferenceExampleDecodes() throws {
        guard case .state(let state) = try classify(Self.referenceState) else {
            return XCTFail("Expected a full state")
        }
        let sessions = state.defaultDevice.sessions
        XCTAssertEqual(sessions.count, 6)
        // Session ids are opaque: none contains the device id.
        XCTAssertFalse(sessions.contains { $0.id.contains(state.defaultDevice.deviceId) })
        XCTAssertEqual(state.iconIds, ["demo1d94c5a", "demo1b64cd9", "demo174d94c", "demo14cd968"])
        XCTAssertEqual(sessions.compactMap(\.detail), ["Radio Paradise - Main Mix", "Tears of Steel - YouTube"])
        XCTAssertEqual(sessions[3].name, "Musique \u{E9}t\u{E9}")
    }

    func testStateDecodesIconIds() throws {
        guard case .state(let state) = try classify(Self.v8State) else {
            return XCTFail("Expected a full state")
        }
        XCTAssertEqual(state.defaultDevice.sessions.map(\.iconId), [
            nil,
            "4b13f0d55a3779a6ff892414f951be3f",
            "4b13f0d55a3779a6ff892414f951be3f",
            "6b58026ae167f8f2e802f2531657443c",
        ])
    }

    func testIconIdsAreDistinctAndInSessionOrder() throws {
        guard case .state(let withIcons) = try classify(Self.v8State),
              case .state(let plain) = try classify(Self.plainState) else {
            return XCTFail("Expected full states")
        }
        XCTAssertEqual(withIcons.iconIds, ["4b13f0d55a3779a6ff892414f951be3f", "6b58026ae167f8f2e802f2531657443c"])
        XCTAssertEqual(plain.iconIds, [])
    }

    func testSessionDetailsDecode() throws {
        guard case .state(let state) = try classify(Self.v8StateWithDetails) else {
            return XCTFail("Expected a full state")
        }
        XCTAssertEqual(state.defaultDevice.sessions.map(\.detail), [
            nil,
            "Big Buck Bunny - YouTube",
            "Radio Paradise - Main Mix",
            "Caf\u{E9} Concert: You've Got a Friend\u{2026}",
        ])
        // Same application, told apart only by the detail.
        XCTAssertEqual(Set(state.defaultDevice.sessions.dropFirst().map(\.name)), ["Firefox"])
    }

    func testStatesWithoutDetailsDecodeWithNone() throws {
        for text in [Self.plainState, Self.v8State] {
            guard case .state(let state) = try classify(text) else {
                return XCTFail("Expected a full state")
            }
            XCTAssertTrue(state.defaultDevice.sessions.allSatisfy { $0.detail == nil })
        }
    }

    func testUnknownFieldsAreIgnored() throws {
        let text = Self.plainState.replacingOccurrences(
            of: #""applicationVersion":"v10","#,
            with: #""applicationVersion":"v10","features":["icons"],"somethingNew":{"a":1},"#
        )
        guard case .state(let state) = try classify(text) else {
            return XCTFail("Expected a full state")
        }
        XCTAssertEqual(state.defaultDevice.sessions.count, 1)
    }

    // MARK: - Protocol version

    func testOlderServerIsRejected() {
        XCTAssertThrowsError(try classify(Self.olderServerState)) { error in
            guard let mismatch = error as? ProtocolVersionMismatch else {
                return XCTFail("Expected a version mismatch, got \(error)")
            }
            XCTAssertEqual(mismatch.serverVersion, 7)
            XCTAssertTrue(mismatch.serverIsOlder)
        }
    }

    func testNewerServerIsRejectedEvenIfItsStateCannotBeDecoded() {
        XCTAssertThrowsError(try classify(#"{"protocolVersion":9,"defaultDevice":{"somethingElse":true}}"#)) { error in
            guard let mismatch = error as? ProtocolVersionMismatch else {
                return XCTFail("Expected a version mismatch, got \(error)")
            }
            XCTAssertEqual(mismatch.serverVersion, 9)
            XCTAssertFalse(mismatch.serverIsOlder)
        }
    }

    func testMismatchMessagesSayWhichSideToUpdate() {
        let older = ProtocolVersionMismatch(serverVersion: 7).localizedDescription
        let newer = ProtocolVersionMismatch(serverVersion: 9).localizedDescription
        XCTAssertTrue(older.contains("PcVolumeControlServer"), older)
        XCTAssertTrue(older.contains("7"), older)
        XCTAssertTrue(newer.contains("Update PcVolumeControl on this device"), newer)
        XCTAssertTrue(newer.contains("9"), newer)
    }

    func testStateWithoutVersionIsMalformed() {
        XCTAssertThrowsError(try classify(#"{"defaultDevice":{"deviceId":"x"}}"#)) { error in
            XCTAssertTrue(error is MalformedStateError)
        }
    }

    // MARK: - Icon replies

    func testIconImageReplyDecodesToPNG() throws {
        guard case .icon(let reply) = try classify(Self.iconImageReply) else {
            return XCTFail("Expected an icon reply")
        }
        XCTAssertEqual(reply.id, "6b58026ae167f8f2e802f2531657443c")
        let png = try XCTUnwrap(reply.png)
        XCTAssertEqual(Array(png.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
        let image = try XCTUnwrap(UIImage(data: png))
        XCTAssertEqual(image.size.width * image.scale, 16)
        XCTAssertEqual(image.size.height * image.scale, 16)
    }

    func testIconNotFoundReplyHasNoImage() throws {
        guard case .icon(let reply) = try classify(Self.iconNotFoundReply) else {
            return XCTFail("Expected an icon reply")
        }
        XCTAssertEqual(reply.id, "0000notarealid")
        XCTAssertNil(reply.png)
    }

    func testIconReplyWithUnknownErrorHasNoImage() throws {
        let text = #"{"protocolVersion":8,"icon":{"id":"abc","error":"somethingElse","data":"iVBORw0KGgo="}}"#
        guard case .icon(let reply) = try classify(text) else {
            return XCTFail("Expected an icon reply")
        }
        XCTAssertNil(reply.png)
    }

    func testIconReplyWithInvalidBase64StillAnswersTheId() throws {
        let text = #"{"protocolVersion":8,"icon":{"id":"abc","size":16,"mime":"image/png","data":"not base64!"}}"#
        guard case .icon(let reply) = try classify(text) else {
            return XCTFail("Expected an icon reply")
        }
        XCTAssertEqual(reply.id, "abc")
        XCTAssertNil(reply.png)
    }

    func testIconReplyWithNonStringErrorHasNoImage() throws {
        let text = #"{"protocolVersion":8,"icon":{"id":"abc","error":{"code":3},"data":"iVBORw0KGgo="}}"#
        guard case .icon(let reply) = try classify(text) else {
            return XCTFail("Expected an icon reply")
        }
        XCTAssertNil(reply.png)
    }

    func testIconReplyWithEmptyDataHasNoImage() throws {
        let text = #"{"protocolVersion":8,"icon":{"id":"abc","size":16,"mime":"image/png","data":""}}"#
        guard case .icon(let reply) = try classify(text) else {
            return XCTFail("Expected an icon reply")
        }
        XCTAssertNil(reply.png)
    }

    // MARK: - Classification

    func testUnknownLineIsIgnored() throws {
        XCTAssertNil(try classify(#"{"protocolVersion":8,"somethingNew":{"a":1}}"#))
    }

    func testMalformedLinesAreIgnored() throws {
        for text in [
            #"{"protocolVersion":8,"defaultDevice":{"deviceId":"#,
            #"{"protocolVersion":8,"icon":{"error":"notFound"}}"#,
            "[1,2,3]",
            "not json",
        ] {
            XCTAssertNil(try classify(text), text)
        }
    }

    func testLineWithBothStateAndIconIsIgnored() throws {
        let text = Self.plainState.replacingOccurrences(
            of: #""protocolVersion":8,"#,
            with: #""protocolVersion":8,"icon":{"id":"abc","error":"notFound"},"#
        )
        XCTAssertNil(try classify(text))
    }

    func testUndecodableFullStateThrows() {
        XCTAssertThrowsError(try classify(#"{"protocolVersion":8,"defaultDevice":{"deviceId":"x"}}"#)) { error in
            XCTAssertTrue(error is MalformedStateError)
        }
    }
}
