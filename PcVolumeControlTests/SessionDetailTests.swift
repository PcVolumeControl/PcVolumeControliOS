//
//  SessionDetailTests.swift
//  PcVolumeControlTests
//
//  Session details are display text: a state that only changes details must not
//  disturb what the user is editing, the row order or row identity.
//

import XCTest
@testable import PcVolumeControl

@MainActor
final class SessionDetailTests: XCTestCase {

    private func state(details: [String?], volumes: [Double] = [50, 50, 50]) -> FullState {
        let sessions = zip(details, volumes).enumerated().map { index, pair in
            FullState.Session(
                id: "dev-a|\(index)", muted: false, name: "Firefox", volume: pair.1,
                iconId: "4b13f0d55a3779a6ff892414f951be3f", detail: pair.0
            )
        }
        return FullState(
            protocolVersion: 8,
            deviceIds: ["dev-a": "Speakers"],
            defaultDevice: FullState.theDefaultDevice(
                deviceId: "dev-a", masterMuted: false, masterVolume: 80, name: "Speakers", sessions: sessions
            )
        )
    }

    func testDetailOnlyUpdateKeepsOrderAndIdentity() {
        let vm = SliderViewModel()
        vm.fullState = state(details: ["Tab A", "Tab B", nil])
        let ids = vm.sessions.map(\.id)
        // Same-named sessions are ordered by id, never by detail.
        XCTAssertEqual(ids, ["dev-a|0", "dev-a|1", "dev-a|2"])

        vm.fullState = state(details: ["Tab A2", nil, "Tab C"])

        XCTAssertEqual(vm.sessions.map(\.id), ids)
        let details = Dictionary(uniqueKeysWithValues: vm.sessions.map { ($0.id, $0.detail) })
        XCTAssertEqual(details["dev-a|0"], "Tab A2")
        XCTAssertEqual(details["dev-a|1"], .some(nil))
        XCTAssertEqual(details["dev-a|2"], "Tab C")
    }

    func testDetailOnlyUpdateKeepsValuesOfASessionBeingEdited() throws {
        let vm = SliderViewModel()
        vm.fullState = state(details: ["Tab A", "Tab B", nil])
        let index = try XCTUnwrap(vm.sessions.firstIndex { $0.id == "dev-a|1" })

        // The user is dragging this session's slider.
        vm.beginEditing("dev-a|1")
        vm.sessions[index].volume = 85
        vm.sessions[index].muted = true

        vm.fullState = state(details: ["Tab A", "Tab B changed", nil])

        let edited = try XCTUnwrap(vm.sessions.first { $0.id == "dev-a|1" })
        XCTAssertEqual(edited.volume, 85)
        XCTAssertTrue(edited.muted)
        XCTAssertEqual(edited.detail, "Tab B changed")
        XCTAssertEqual(edited.iconId, "4b13f0d55a3779a6ff892414f951be3f")
        vm.endEditing("dev-a|1")
    }

    func testSpokenNameAddsTheDetailOnlyWhenPresent() {
        XCTAssertEqual(SessionCell.spokenName("Firefox", detail: nil), "Firefox")
        XCTAssertEqual(SessionCell.spokenName("Firefox", detail: "Big Buck Bunny - YouTube"), "Firefox, Big Buck Bunny - YouTube")
    }
}
