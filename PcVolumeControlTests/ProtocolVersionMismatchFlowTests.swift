//
//  ProtocolVersionMismatchFlowTests.swift
//  PcVolumeControlTests
//
//  Connecting to a server of another protocol version: the view model leaves it,
//  shows a message and does not try to reconnect.
//

import Combine
import Network
import XCTest
@testable import PcVolumeControl

@MainActor
final class ProtocolVersionMismatchFlowTests: XCTestCase {

    private func makeViewModel(serverLines: [String]) -> MainViewModel {
        let serversRepo = ServersRepository(
            local: MockLocalDataSource(),
            remote: UnstartedConnectionDataSource(),
            makeTransport: { _ in ScriptedTransport(lines: serverLines) }
        )
        let placeholder = VolumeControlRepository(transport: MockVolumeTransport())
        let viewModel = MainViewModel(
            connect: ConnectToServerUseCase(repo: serversRepo),
            defUpdate: SendDefaultDeviceUpdateUseCase(repo: placeholder),
            masterUpdate: SendMasterChannelUpdateUseCase(repo: placeholder),
            sessionUpdate: SendSessionUpdateUseCase(repo: placeholder),
            serversRepo: serversRepo
        )
        // Short enough that a reconnect, if one were started, would show within the test.
        viewModel.reconnectInitialDelaySeconds = 0.01
        viewModel.reconnectMaxDelaySeconds = 0.01
        viewModel.reconnectWindowSeconds = 0.2
        return viewModel
    }

    private func connectAndWaitForError(_ sut: MainViewModel) async throws -> [MainViewModel.ConnectionStatus] {
        var statuses: [MainViewModel.ConnectionStatus] = []
        let statusSubscription = sut.$connectionStatus.sink { statuses.append($0) }
        let errorShown = expectation(description: "Error shown")
        errorShown.assertForOverFulfill = false
        let errorSubscription = sut.$error.sink { if $0 != nil { errorShown.fulfill() } }

        sut.connectToServer(address: "192.0.2.1", port: 3000)
        await fulfillment(of: [errorShown], timeout: 5)
        // Leave time for a reconnect attempt to begin if the view model started one.
        try await Task.sleep(nanoseconds: 300_000_000)

        statusSubscription.cancel()
        errorSubscription.cancel()
        return statuses
    }

    func testOlderServerIsLeftWithAMessageAndNoReconnect() async throws {
        let sut = makeViewModel(serverLines: [ServerLineTests.olderServerState])

        let statuses = try await connectAndWaitForError(sut)

        XCTAssertEqual(sut.error, ProtocolVersionMismatch(serverVersion: 7).localizedDescription)
        XCTAssertTrue(sut.error?.contains("PcVolumeControlServer") ?? false)
        XCTAssertNil(sut.fullState)
        XCTAssertFalse(sut.hasActiveConnection)
        XCTAssertFalse(statuses.contains(.reconnecting))
        XCTAssertEqual(sut.connectionStatus, .connected)
    }

    func testNewerServerAsksToUpdateTheApp() async throws {
        let newer = ServerLineTests.plainState.replacingOccurrences(
            of: #""protocolVersion":8"#, with: #""protocolVersion":9"#
        )
        let sut = makeViewModel(serverLines: [newer])

        let statuses = try await connectAndWaitForError(sut)

        XCTAssertEqual(sut.error, ProtocolVersionMismatch(serverVersion: 9).localizedDescription)
        XCTAssertNil(sut.fullState)
        XCTAssertFalse(statuses.contains(.reconnecting))
    }
}

/// Hands out a connection that is never started; the scripted transport replaces it.
final class UnstartedConnectionDataSource: TCPConnectionDataSourceProtocol {
    func openConnection(to server: DiscoveredServer) async throws -> Connection {
        Connection(nw: NWConnection(host: "192.0.2.1", port: 3000, using: .tcp))
    }
}
