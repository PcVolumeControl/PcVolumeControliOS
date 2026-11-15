//
//  IconRequestPlannerTests.swift
//  PcVolumeControlTests
//
//  Which icon ids are requested, and when, within the protocol's limits.
//

import XCTest
import SwiftUI
@testable import PcVolumeControl

final class IconRequestPlannerTests: XCTestCase {

    private func ids(_ count: Int) -> [String] {
        (0..<count).map { "id\($0)" }
    }

    private func plan(_ planner: inout IconRequestPlanner, _ ids: [String], skipping: Set<String> = []) -> [[String]] {
        planner.requests(for: ids, size: 66, supportsIcons: true, skipping: skipping)
    }

    func testNoRequestsWithoutTheIconsFeature() {
        var planner = IconRequestPlanner()
        XCTAssertEqual(planner.requests(for: ["a", "b"], size: 66, supportsIcons: false, skipping: []), [])
        XCTAssertTrue(planner.outstanding.isEmpty)
    }

    func testDuplicatesAreRequestedOnce() {
        var planner = IconRequestPlanner()
        XCTAssertEqual(plan(&planner, ["a", "b", "a", "b", "c"]), [["a", "b", "c"]])
    }

    func testSkippedAndInvalidIdsAreNotRequested() {
        var planner = IconRequestPlanner()
        let batches = plan(
            &planner,
            ["cached", "UPPER", "", "has-dash", String(repeating: "a", count: 65), "wanted"],
            skipping: ["cached"]
        )
        XCTAssertEqual(batches, [["wanted"]])
    }

    func testOutstandingIdsAreNotRequestedAgain() {
        var planner = IconRequestPlanner()
        XCTAssertEqual(plan(&planner, ["a", "b"]), [["a", "b"]])
        XCTAssertEqual(plan(&planner, ["a", "b", "c"]), [["c"]])
        XCTAssertEqual(planner.outstanding, ["a": 66, "b": 66, "c": 66])
    }

    func testBatchesHoldAtMost32Ids() {
        var planner = IconRequestPlanner()
        let batches = plan(&planner, ids(40))
        XCTAssertEqual(batches.map(\.count), [32, 8])
        XCTAssertEqual(batches.flatMap { $0 }, ids(40))
    }

    func testAtMost64IdsAreOutstanding() {
        var planner = IconRequestPlanner()
        let all = ids(100)
        XCTAssertEqual(plan(&planner, all).map(\.count), [32, 32])
        XCTAssertEqual(planner.outstanding.count, 64)
        XCTAssertFalse(planner.hasRoomForFullBatch)

        // Full: nothing more until replies arrive.
        XCTAssertEqual(plan(&planner, all), [])

        for id in all.prefix(10) {
            XCTAssertEqual(planner.recordReply(for: id, available: true), 66)
        }
        // Answered ids are now cached by the caller and skipped.
        XCTAssertEqual(plan(&planner, all, skipping: Set(all.prefix(10))), [Array(all[64..<74])])
        XCTAssertEqual(planner.outstanding.count, 64)
    }

    func testRoomForFullBatchOnceEnoughRepliesArrive() {
        var planner = IconRequestPlanner()
        let all = ids(64)
        _ = plan(&planner, all)
        for id in all.prefix(31) {
            _ = planner.recordReply(for: id, available: true)
        }
        XCTAssertFalse(planner.hasRoomForFullBatch)
        _ = planner.recordReply(for: all[31], available: true)
        XCTAssertTrue(planner.hasRoomForFullBatch)
    }

    func testUnavailableIdsAreNotRequestedAgain() {
        var planner = IconRequestPlanner()
        _ = plan(&planner, ["a", "b", "c"])
        _ = planner.recordReply(for: "a", available: false)
        _ = planner.recordReply(for: "b", available: true)
        _ = planner.recordReply(for: "c", available: true)
        planner.markUnavailable("c")
        XCTAssertTrue(planner.outstanding.isEmpty)
        XCTAssertEqual(plan(&planner, ["a", "b", "c"], skipping: ["b"]), [])
    }

    func testReplyThatWasNotRequestedIsReported() {
        var planner = IconRequestPlanner()
        XCTAssertNil(planner.recordReply(for: "a", available: false))
        // ... and does not mark the id unavailable.
        XCTAssertEqual(plan(&planner, ["a"]), [["a"]])
    }

    func testReplyReportsTheRequestedSize() {
        var planner = IconRequestPlanner()
        _ = planner.requests(for: ["a"], size: 48, supportsIcons: true, skipping: [])
        _ = planner.requests(for: ["b"], size: 96, supportsIcons: true, skipping: [])
        XCTAssertEqual(planner.recordReply(for: "a", available: true), 48)
        XCTAssertEqual(planner.recordReply(for: "b", available: true), 96)
    }

    func testDroppedConnectionClearsOutstandingButRemembersUnavailable() {
        var planner = IconRequestPlanner()
        _ = plan(&planner, ["a", "b", "c"])
        _ = planner.recordReply(for: "a", available: false)

        planner.connectionDropped()
        XCTAssertTrue(planner.outstanding.isEmpty)

        // After reconnecting only the still-unknown ids are requested again.
        XCTAssertEqual(plan(&planner, ["a", "b", "c"]), [["b", "c"]])
    }

    func testNewPlannerRetriesUnavailableIds() {
        var planner = IconRequestPlanner()
        _ = plan(&planner, ["a"])
        _ = planner.recordReply(for: "a", available: false)

        planner = IconRequestPlanner()
        XCTAssertEqual(plan(&planner, ["a"]), [["a"]])
    }

    func testPixelSizeIsRoundedAndClamped() {
        XCTAssertEqual(IconRequestPlanner.pixelSize(points: 22, scale: 3), 66)
        XCTAssertEqual(IconRequestPlanner.pixelSize(points: 22.4, scale: 2), 45)
        XCTAssertEqual(IconRequestPlanner.pixelSize(points: 4, scale: 2), 16)
        XCTAssertEqual(IconRequestPlanner.pixelSize(points: 120, scale: 3), 256)
    }

    func testIconPointSizeFollowsDynamicType() {
        XCTAssertEqual(SessionIconView.pointSize(for: .large), 22, accuracy: 0.5)
        XCTAssertGreaterThan(SessionIconView.pointSize(for: .accessibility3), SessionIconView.pointSize(for: .large))
        XCTAssertLessThan(SessionIconView.pointSize(for: .xSmall), SessionIconView.pointSize(for: .large))
    }
}
