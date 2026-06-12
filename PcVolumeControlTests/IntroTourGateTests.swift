//
//  IntroTourGateTests.swift
//  PcVolumeControlTests
//

import XCTest
@testable import PcVolumeControl

final class IntroTourGateTests: XCTestCase {

    func testShowsTourOnFirstLaunch() {
        XCTAssertTrue(IntroTourGate.shouldShowTour(hasSeenTour: false, arguments: []))
    }

    func testDoesNotShowTourWhenAlreadySeen() {
        XCTAssertFalse(IntroTourGate.shouldShowTour(hasSeenTour: true, arguments: []))
    }

    func testScreenshotModeSuppressesTour() {
        XCTAssertFalse(IntroTourGate.shouldShowTour(hasSeenTour: false, arguments: ["--screenshotMode"]))
    }

    func testScreenshotModeWithOtherArgumentsStillSuppresses() {
        XCTAssertFalse(IntroTourGate.shouldShowTour(
            hasSeenTour: false,
            arguments: ["--screenshotMode", "--mockConnected"]
        ))
    }
}
