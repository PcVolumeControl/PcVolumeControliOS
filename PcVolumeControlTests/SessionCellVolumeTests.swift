//
//  SessionCellVolumeTests.swift
//  PcVolumeControlTests
//
//  Verifies that the slider's displayed volume respects mute state, so a muted
//  session (or a session under a muted master) reads 0 regardless of the cell's
//  view lifecycle (e.g. being recreated after scrolling off-screen).
//

import XCTest
@testable import PcVolumeControl

final class SessionCellVolumeTests: XCTestCase {

    func testUnmutedReturnsSessionVolume() {
        XCTAssertEqual(
            SessionCell.displayVolume(volume: 75, muted: false, masterMuted: false),
            75
        )
    }

    func testMutedSessionReturnsZero() {
        XCTAssertEqual(
            SessionCell.displayVolume(volume: 75, muted: true, masterMuted: false),
            0
        )
    }

    func testMutedMasterReturnsZero() {
        XCTAssertEqual(
            SessionCell.displayVolume(volume: 75, muted: false, masterMuted: true),
            0
        )
    }

    func testMutedSessionAndMasterReturnsZero() {
        XCTAssertEqual(
            SessionCell.displayVolume(volume: 75, muted: true, masterMuted: true),
            0
        )
    }
}
