//
//  MDNSDiscoveryServiceTests.swift
//  PcVolumeControlTests
//
//  Created by Bill Booth on 6/19/26.
//

import XCTest
@testable import PcVolumeControl

@MainActor
final class MDNSDiscoveryServiceTests: XCTestCase {

    // A server that withdraws from mDNS (Bonjour goodbye / NWBrowser .removed)
    // must be taken off the discovered list. Regression guard for the old bug
    // where removal matched the service name against the IP+port id and so
    // never removed anything, leaving the green "Auto-discovered" indicator up.
    func testWithdrawalRemovesResolvedDiscoveredServer() {
        let service = MDNSDiscoveryService()
        let serviceName = "CHOSS-pcvolumecontrol-3000"
        let server = DiscoveredServer(address: "192.168.0.42", port: 3000, computerName: "CHOSS")

        service.recordResolvedServer(server, forServiceName: serviceName)
        XCTAssertEqual(service.discoveredServers.count, 1)
        XCTAssertEqual(service.discoveredServers.first?.address, "192.168.0.42")

        service.removeServer(forServiceName: serviceName)
        XCTAssertTrue(service.discoveredServers.isEmpty,
                      "A withdrawn service must be removed from the discovered list")
    }

    // A withdrawal for a service we never resolved must not touch the list.
    func testWithdrawalForUnknownServiceIsNoOp() {
        let service = MDNSDiscoveryService()
        let server = DiscoveredServer(address: "192.168.0.42", port: 3000, computerName: "CHOSS")
        service.recordResolvedServer(server, forServiceName: "CHOSS-pcvolumecontrol-3000")

        service.removeServer(forServiceName: "OTHER-pcvolumecontrol-9999")

        XCTAssertEqual(service.discoveredServers.count, 1,
                       "Removing an unknown service must not affect existing discoveries")
    }
}
