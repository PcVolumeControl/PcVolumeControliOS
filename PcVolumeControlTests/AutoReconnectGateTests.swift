//
//  AutoReconnectGateTests.swift
//  PcVolumeControlTests
//

import XCTest
@testable import PcVolumeControl

final class AutoReconnectGateTests: XCTestCase {

    func testAutoConnectsWhenEnabledWithRecentServer() {
        XCTAssertTrue(AutoReconnectGate.shouldAutoConnect(
            isEnabled: true, hasRecentServer: true, arguments: []))
    }

    func testDoesNotAutoConnectWhenDisabled() {
        XCTAssertFalse(AutoReconnectGate.shouldAutoConnect(
            isEnabled: false, hasRecentServer: true, arguments: []))
    }

    func testDoesNotAutoConnectWithoutRecentServer() {
        XCTAssertFalse(AutoReconnectGate.shouldAutoConnect(
            isEnabled: true, hasRecentServer: false, arguments: []))
    }

    func testScreenshotModeSuppressesAutoConnect() {
        XCTAssertFalse(AutoReconnectGate.shouldAutoConnect(
            isEnabled: true, hasRecentServer: true, arguments: ["--screenshotMode"]))
    }

    func testScreenshotModeWithOtherArgumentsStillSuppresses() {
        XCTAssertFalse(AutoReconnectGate.shouldAutoConnect(
            isEnabled: true,
            hasRecentServer: true,
            arguments: ["--screenshotMode", "--mockConnected"]))
    }
}
