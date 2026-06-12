//
//  MainViewModelSimpleTests.swift
//  PcVolumeControlTests
//
//  Created by Bill Booth on 6/4/25.
//  Copyright © 2025 PcVolumeControl. All rights reserved.
//

import XCTest
import UIKit
@testable import PcVolumeControl

@MainActor
final class MainViewModelSimpleTests: XCTestCase {
    
    var sut: MainViewModel!
    var mockRepository: MockVolumeTransport!
    
    override func setUp() {
        super.setUp()
        
        // Create a minimal test setup
        mockRepository = MockVolumeTransport()
        
        // Create use cases with mock repository
        let volumeRepo = VolumeControlRepository(transport: mockRepository)
        let serversRepo = ServersRepository(
            local: MockLocalDataSource(),
            remote: MockTCPDataSource()
        )
        
        let connectUseCase = ConnectToServerUseCase(repo: serversRepo)
        let defUpdateUseCase = SendDefaultDeviceUpdateUseCase(repo: volumeRepo)
        let masterUpdateUseCase = SendMasterChannelUpdateUseCase(repo: volumeRepo)
        let sessionUpdateUseCase = SendSessionUpdateUseCase(repo: volumeRepo)
        
        sut = MainViewModel(
            connect: connectUseCase,
            defUpdate: defUpdateUseCase,
            masterUpdate: masterUpdateUseCase,
            sessionUpdate: sessionUpdateUseCase,
            serversRepo: serversRepo
        )
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - Basic Initialization Tests
    
    func testInitialState() {
        XCTAssertEqual(sut.address, "")
        XCTAssertEqual(sut.port, 0)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
        XCTAssertNil(sut.fullState)
        XCTAssertFalse(sut.hasActiveConnection)
    }
    
    // MARK: - Property Tests
    
    func testHasActiveConnectionProperty() {
        // Initially no connection
        XCTAssertFalse(sut.hasActiveConnection)
        
        // After disconnecting
        sut.disconnect()
        XCTAssertFalse(sut.hasActiveConnection)
    }
    
    func testDisconnectClearsState() {
        // Given - simulate having state
        sut.fullState = createMockFullState()
        
        // When
        sut.disconnect()
        
        // Then
        XCTAssertNil(sut.fullState)
        XCTAssertFalse(sut.hasActiveConnection)
    }
    
    // MARK: - App Lifecycle Tests
    
    func testAppLifecycleNotificationObservers() {
        // Test that notification observers are set up
        // This tests that the init method sets up observers without crashing
        XCTAssertNotNil(sut)
        
        // Post background notification
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        // Post foreground notification
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        
        // Should not crash and should maintain state
        XCTAssertNotNil(sut)
    }
    
    // MARK: - Update Session Tests
    
    func testUpdateSessionWithObject() async throws {
        // Given
        let testSession = FullState.Session(
            id: "test.exe",
            muted: true,
            name: "Test App",
            volume: 80.0
        )
        
        // When - this will call the actual use case but with mock transport
        try await sut.updateSession(testSession)
        
        // Then - verify the mock transport received data
        XCTAssertTrue(mockRepository.outgoingDataCalled)
        XCTAssertFalse(mockRepository.sentData.isEmpty)
    }
    
    // MARK: - Error Handling Tests
    
    func testConnectToServerWithInvalidAddress() async {
        // Given
        let invalidAddress = "invalid.address"
        let port: UInt16 = 8080
        
        // When
        await sut.connectToServer(address: invalidAddress, port: port)
        
        // Then - should handle error gracefully
        XCTAssertFalse(sut.isLoading)
        // Error might be set depending on the mock behavior
        XCTAssertFalse(sut.hasActiveConnection)
    }
    
    // MARK: - State Tests
    
    func testFullStateProperty() {
        // Given
        let mockState = createMockFullState()
        
        // When
        sut.fullState = mockState
        
        // Then
        XCTAssertNotNil(sut.fullState)
        XCTAssertEqual(sut.fullState?.protocolVersion, 7)
        XCTAssertEqual(sut.fullState?.defaultDevice.deviceId, "device1")
    }
    
    // MARK: - Port Resolution Tests

    func testConnectWithZeroPortDefaultsTo3000() {
        // Given a manual connection with an empty port field (port == 0)
        sut.address = "192.168.1.100"

        // When connecting
        sut.connectToServer(address: "192.168.1.100", port: 0)

        // Then the view model reflects the resolved default port
        XCTAssertEqual(sut.port, 3000)
    }

    func testSaveSuccessfulConnectionPersistsResolvedPort() {
        // Given a zero-port connection that resolves to the default
        sut.address = "10.0.0.5"
        sut.connectToServer(address: "10.0.0.5", port: 0)

        // When the successful connection is saved
        sut.saveSuccessfulConnection()

        // Then the persisted recent server has the resolved port, not 0
        XCTAssertEqual(sut.recentServers.first?.port, 3000)
    }

    // MARK: - Connection Loss / Reconnect Tests

    func testReconnectLoopEndsInLostWhenServerUnreachable() async {
        // Given a tiny retry window/delay and an unreachable server (mock TCP throws)
        sut.reconnectInitialDelaySeconds = 0.01
        sut.reconnectMaxDelaySeconds = 0.02
        sut.reconnectWindowSeconds = 0.1

        // When the reconnect loop runs
        sut.startReconnectLoop(to: DiscoveredServer(address: "192.0.2.1", port: 3000))

        // Then it ends in the .lost state after exhausting attempts
        for _ in 0..<300 {
            if sut.connectionStatus == .lost { break }
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        XCTAssertEqual(sut.connectionStatus, .lost)
        XCTAssertFalse(sut.isConnectionLive)
    }

    func testReconnectGoesThroughReconnectingState() async {
        sut.reconnectInitialDelaySeconds = 0.02
        sut.reconnectMaxDelaySeconds = 0.02
        sut.reconnectWindowSeconds = 0.1
        sut.startReconnectLoop(to: DiscoveredServer(address: "192.0.2.1", port: 3000))

        // It should enter .reconnecting before settling on .lost
        var sawReconnecting = false
        for _ in 0..<300 {
            if sut.connectionStatus == .reconnecting { sawReconnecting = true }
            if sut.connectionStatus == .lost { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(sawReconnecting)
        XCTAssertEqual(sut.connectionStatus, .lost)
    }

    // MARK: - Server List Deletion Tests

    func testDeletingServerThatIsBothDiscoveredAndRecentClearsItInOneSwipe() {
        // Given a server that is both live-discovered over mDNS and a saved
        // recent connection (same address:port, different DiscoveredServer
        // instances). The unified list dedupes these into a single row.
        let discovered = DiscoveredServer(address: "192.168.0.42", port: 3000, computerName: "CHOSS")
        let recent = DiscoveredServer(address: "192.168.0.42", port: 3000, computerName: nil)
        sut.discoveredServers = [discovered]
        sut.recentServers = [recent]

        let rowsBefore = sut.unifiedServerList.filter { !$0.isManual }
        XCTAssertEqual(rowsBefore.count, 1, "Discovered and recent duplicates should collapse to one row")
        XCTAssertTrue(rowsBefore.first?.isDiscovered ?? false)

        // When the user swipes to delete that single row once
        sut.deleteServerFromList(rowsBefore[0])

        // Then the row must not resurface as a "recent connection" duplicate
        let rowsAfter = sut.unifiedServerList.filter { !$0.isManual }
        XCTAssertEqual(rowsAfter.count, 0, "One delete should remove both the discovered and recent representations")
        XCTAssertTrue(sut.discoveredServers.isEmpty)
        XCTAssertTrue(sut.recentServers.isEmpty)
    }

    func testDeletingPlainRecentServerStillWorks() {
        // Regression: a recent-only server (no live discovery) still deletes.
        let recent = DiscoveredServer(address: "10.0.0.5", port: 8080, computerName: nil)
        sut.recentServers = [recent]

        let rows = sut.unifiedServerList.filter { !$0.isManual }
        XCTAssertEqual(rows.count, 1)

        sut.deleteServerFromList(rows[0])

        XCTAssertTrue(sut.recentServers.isEmpty)
        XCTAssertEqual(sut.unifiedServerList.filter { !$0.isManual }.count, 0)
    }

    // MARK: - Integration Tests

    func testConnectDisconnectCycle() async {
        // Given
        let address = "192.168.1.100"
        let port: UInt16 = 3000
        
        // When - Connect
        await sut.connectToServer(address: address, port: port)
        
        // Then - Should complete without crashing
        XCTAssertFalse(sut.isLoading)
        
        // When - Disconnect
        sut.disconnect()
        
        // Then
        XCTAssertNil(sut.fullState)
        XCTAssertFalse(sut.hasActiveConnection)
    }
    
    // MARK: - Async Operation Tests
    
    func testUpdateMethodsDoNotCrash() {
        // Test that update methods can be called without crashing
        
        sut.updateDefaultDevice(id: "test-device")
        sut.updateMaster(id: "master-device", muted: true, vol: 50.0)
        sut.updateSession(name: "Test", id: "test.exe", vol: 75.0, muted: false)
        
        // If we get here without crashing, the test passes
        XCTAssertNotNil(sut)
    }
    
    // MARK: - Memory Management Tests
    
    func testDeinitCleansUpObservers() {
        // This test ensures that deinit doesn't crash
        // The actual cleanup is hard to test directly, but we can verify
        // that creating and destroying the view model doesn't leak
        
        weak var weakSUT = sut
        sut = nil
        
        // Give time for cleanup
        let expectation = XCTestExpectation(description: "Cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // The object should be deallocated
        XCTAssertNil(weakSUT)
    }
    
    // MARK: - Helper Methods
    
    private func createMockFullState() -> FullState {
        let session1 = FullState.Session(id: "app1.exe", muted: false, name: "App1", volume: 50.0)
        let session2 = FullState.Session(id: "app2.exe", muted: true, name: "App2", volume: 75.0)
        
        let defaultDevice = FullState.theDefaultDevice(
            deviceId: "device1",
            masterMuted: false,
            masterVolume: 80.0,
            name: "Default Device",
            sessions: [session1, session2]
        )
        
        let deviceIds = ["device1": "Default Device", "device2": "Secondary Device"]
        
        return FullState(
            protocolVersion: 7,
            deviceIds: deviceIds,
            defaultDevice: defaultDevice
        )
    }
}

// MARK: - Simple Mock Objects

class MockVolumeTransport: VolumeTransportDataSourceProtocol {
    var outgoingDataCalled = false
    var sentData: [Data] = []
    var isCloseCalled = false
    
    func outgoing(_ data: Data) async throws {
        outgoingDataCalled = true
        sentData.append(data)
    }
    
    func incoming() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            // Mock stream that just finishes
            continuation.finish()
        }
    }
    
    func close() {
        isCloseCalled = true
    }
}

class MockLocalDataSource: ServersLocalDataSourceProtocol {
    func loadRecent() -> [DiscoveredServer] {
        return []
    }
    
    func saveRecent(_ list: [DiscoveredServer]) {
        // Mock implementation
    }
}

class MockTCPDataSource: TCPConnectionDataSourceProtocol {
    func openConnection(to server: DiscoveredServer) async throws -> Connection {
        // For testing, we'll throw an error to simulate connection failure
        throw NSError(domain: "MockConnectionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock connection failed"])
    }
}
