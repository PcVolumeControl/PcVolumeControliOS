//
//  IconRequestPlannerTests.swift
//  PcVolumeControlTests
//
//  Which icon ids are requested, and when, within the protocol's limits.
//

import XCTest
@testable import PcVolumeControl

final class IconRequestPlannerTests: XCTestCase {

    private func ids(_ count: Int, prefix: String = "id") -> [String] {
        (0..<count).map { "\(prefix)\($0)" }
    }

    func testNoRequestsWithoutTheIconsFeature() {
        var planner = IconRequestPlanner()
        XCTAssertEqual(planner.requests(for: ["a", "b"], supportsIcons: false, skipping: []), [])
        XCTAssertTrue(planner.outstanding.isEmpty)
    }

    func testDuplicatesAreRequestedOnce() {
        var planner = IconRequestPlanner()
        XCTAssertEqual(planner.requests(for: ["a", "b", "a", "b", "c"], supportsIcons: true, skipping: []), [["a", "b", "c"]])
    }

    func testSkippedAndInvalidIdsAreNotRequested() {
        var planner = IconRequestPlanner()
        let batches = planner.requests(
            for: ["cached", "UPPER", "", "has-dash", String(repeating: "a", count: 65), "wanted"],
            supportsIcons: true,
            skipping: ["cached"]
        )
        XCTAssertEqual(batches, [["wanted"]])
    }

    func testOutstandingIdsAreNotRequestedAgain() {
        var planner = IconRequestPlanner()
        XCTAssertEqual(planner.requests(for: ["a", "b"], supportsIcons: true, skipping: []), [["a", "b"]])
        XCTAssertEqual(planner.requests(for: ["a", "b", "c"], supportsIcons: true, skipping: []), [["c"]])
        XCTAssertEqual(planner.outstanding, ["a", "b", "c"])
    }

    func testBatchesHoldAtMost32Ids() {
        var planner = IconRequestPlanner()
        let batches = planner.requests(for: ids(40), supportsIcons: true, skipping: [])
        XCTAssertEqual(batches.map(\.count), [32, 8])
        XCTAssertEqual(batches.flatMap { $0 }, ids(40))
    }

    func testAtMost64IdsAreOutstanding() {
        var planner = IconRequestPlanner()
        let all = ids(100)
        let first = planner.requests(for: all, supportsIcons: true, skipping: [])
        XCTAssertEqual(first.map(\.count), [32, 32])
        XCTAssertEqual(planner.outstanding.count, 64)

        // Full: nothing more until replies arrive.
        XCTAssertEqual(planner.requests(for: all, supportsIcons: true, skipping: []), [])

        for id in all.prefix(10) {
            planner.recordReply(for: id, available: true)
        }
        // Answered ids are now cached by the caller and skipped.
        let next = planner.requests(for: all, supportsIcons: true, skipping: Set(all.prefix(10)))
        XCTAssertEqual(next, [Array(all[64..<74])])
        XCTAssertEqual(planner.outstanding.count, 64)
    }

    func testUnavailableIdsAreNotRequestedAgain() {
        var planner = IconRequestPlanner()
        _ = planner.requests(for: ["a", "b"], supportsIcons: true, skipping: [])
        planner.recordReply(for: "a", available: false)
        planner.recordReply(for: "b", available: true)
        XCTAssertTrue(planner.outstanding.isEmpty)
        XCTAssertEqual(planner.requests(for: ["a", "b"], supportsIcons: true, skipping: ["b"]), [])
    }

    func testDroppedConnectionClearsOutstandingButRemembersUnavailable() {
        var planner = IconRequestPlanner()
        _ = planner.requests(for: ["a", "b", "c"], supportsIcons: true, skipping: [])
        planner.recordReply(for: "a", available: false)

        planner.connectionDropped()
        XCTAssertTrue(planner.outstanding.isEmpty)

        // After reconnecting only the still-unknown ids are requested again.
        XCTAssertEqual(planner.requests(for: ["a", "b", "c"], supportsIcons: true, skipping: []), [["b", "c"]])
    }

    func testNewPlannerRetriesUnavailableIds() {
        var planner = IconRequestPlanner()
        _ = planner.requests(for: ["a"], supportsIcons: true, skipping: [])
        planner.recordReply(for: "a", available: false)

        planner = IconRequestPlanner()
        XCTAssertEqual(planner.requests(for: ["a"], supportsIcons: true, skipping: []), [["a"]])
    }

    func testPixelSizeIsRoundedAndClamped() {
        XCTAssertEqual(IconRequestPlanner.pixelSize(points: 22, scale: 3), 66)
        XCTAssertEqual(IconRequestPlanner.pixelSize(points: 22.4, scale: 2), 45)
        XCTAssertEqual(IconRequestPlanner.pixelSize(points: 4, scale: 2), 16)
        XCTAssertEqual(IconRequestPlanner.pixelSize(points: 120, scale: 3), 256)
    }
}
