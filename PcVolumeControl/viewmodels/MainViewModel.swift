import Foundation
import Network
import UIKit
import WidgetKit

@MainActor
final class MainViewModel: ObservableObject {
    /// Default server port used when the user leaves the port field blank.
    static let defaultPort: UInt16 = 3000

    // UI-bound state
    @Published var address = ""
    @Published var port: UInt16 = 0
    @Published var isLoading = false
    @Published var error: String?
    @Published var fullState: FullState?

    // Server management state
    @Published var recentServers: [DiscoveredServer] = []
    @Published var discoveredServers: [DiscoveredServer] = []
    @Published var isAutoDiscovered = false
    @Published var currentDiscoveredServer: DiscoveredServer? = nil

    // Reconnection state
    enum ConnectionStatus: Equatable { case connected, reconnecting, lost }
    @Published var connectionStatus: ConnectionStatus = .connected

    /// True only when the connection is live; controls are interactive only then.
    var isConnectionLive: Bool { connectionStatus == .connected }

    private let connect: ConnectToServerUseCase
    private var defUpdate: SendDefaultDeviceUpdateUseCase
    private var masterUpdate: SendMasterChannelUpdateUseCase
    private var sessionUpdate: SendSessionUpdateUseCase

    private let serversRepo: ServersRepository
    private var streamTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var currentRepo: VolumeControlRepository?
    private var isInBackground = false
    private var userInitiatedDisconnect = false
    private var lastConnectedServer: DiscoveredServer?
    // Reconnect backoff/window. Settable so tests don't have to wait in realtime.
    var reconnectInitialDelaySeconds: Double = 5
    var reconnectMaxDelaySeconds: Double = 30
    var reconnectWindowSeconds: Double = 120   // ~2 minutes total before giving up

    // Network path monitoring: detects WiFi/cellular interface changes a stalled socket won't report.
    private var pathMonitor: NWPathMonitor?
    private let pathMonitorQueue = DispatchQueue(label: "cwb.PcVolumeControl.path-monitor")
    private var lastPathSignature: String?
    private var connectedOverWiFi = false
    private var connectedOverCellular = false

    init(connect: ConnectToServerUseCase,
         defUpdate: SendDefaultDeviceUpdateUseCase,
         masterUpdate: SendMasterChannelUpdateUseCase,
         sessionUpdate: SendSessionUpdateUseCase,
         serversRepo: ServersRepository)
    {
        self.connect = connect
        self.defUpdate = defUpdate
        self.masterUpdate = masterUpdate
        self.sessionUpdate = sessionUpdate
        self.serversRepo = serversRepo
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.appDidEnterBackground()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.appWillEnterForeground()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        streamTask?.cancel()
        heartbeatTask?.cancel()
        reconnectTask?.cancel()
        pathMonitor?.cancel()
        if let repo = currentRepo {
            repo.transport.close()
        }
    }

    func connectToServer(address: String, port: UInt16) {
        // Resolve a blank port (0) to the default so UI state and saved recents reflect the real port.
        let resolvedPort = port == 0 ? Self.defaultPort : port
        self.port = resolvedPort

        disconnect()

        Task {
            isLoading = true
            do {
                let repo = try await connect.execute(address: address, port: resolvedPort)
                currentRepo = repo

                defUpdate = SendDefaultDeviceUpdateUseCase(repo: repo)
                masterUpdate = SendMasterChannelUpdateUseCase(repo: repo)
                sessionUpdate = SendSessionUpdateUseCase(repo: repo)

                lastConnectedServer = DiscoveredServer(address: address, port: resolvedPort, computerName: nil)
                userInitiatedDisconnect = false

                subscribe(to: repo)
                isLoading = false
                connectionStatus = .connected

                if UserDefaults(suiteName: "group.cwb.PcVolumeControl") == nil {
                    appLog("App Group access FAILED - check Developer Portal configuration")
                }
            } catch {
                isLoading = false
                connectionStatus = .connected
                self.error = error.localizedDescription
                currentRepo = nil
                fullState = nil
            }
        }
    }

    func disconnect() {
        // Mark as user-initiated so we don't auto-reconnect
        userInitiatedDisconnect = true
        forceDisconnect()
        updateSharedStateDisconnected()
        // Reset to the idle/connected default for the next session.
        connectionStatus = .connected
    }

    private func forceDisconnect() {
        streamTask?.cancel()
        streamTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        stopPathMonitor()

        if let repo = currentRepo {
            closeConnection(repo)
            currentRepo = nil
        }

        // Clear the full state to trigger UI reset
        fullState = nil
    }
    
    private func closeConnection(_ repo: VolumeControlRepository) {
        repo.transport.close()
    }
    
    // MARK: - App Lifecycle Handlers

    private func appDidEnterBackground() {
        isInBackground = true
        // Pause the stream and reconnect tasks but keep the connection alive
        streamTask?.cancel()
        streamTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        stopPathMonitor()
    }

    private func appWillEnterForeground() {
        isInBackground = false

        guard !userInitiatedDisconnect, let server = lastConnectedServer else {
            return
        }

        // If the socket survived the background, just resume streaming.
        if let repo = currentRepo, isConnectionHealthy(repo) {
            connectionStatus = .connected
            subscribe(to: repo)
            return
        }

        // Connection died while backgrounded: keep stale sliders on screen and reconnect behind the banner.
        if let repo = currentRepo {
            repo.transport.close()
            currentRepo = nil
        }
        startReconnectLoop(to: server)
    }

    private func isConnectionHealthy(_ repo: VolumeControlRepository) -> Bool {
        if let transport = repo.transport as? VolumeTransportDataSource {
            return transport.connection.nw.state == .ready
        }
        return false
    }

    /// Called when the live stream ends unexpectedly; keeps `fullState` and drives auto-reconnect.
    private func handleConnectionLost() {
        // Ignore losses we caused ourselves or while paused in the background.
        guard !userInitiatedDisconnect, !isInBackground else { return }
        // React only once; the byte stream and NWConnection state can both report the same drop.
        guard connectionStatus == .connected else { return }

        // Tear down the dead socket but deliberately keep `fullState`.
        streamTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        if let repo = currentRepo {
            repo.transport.close()
            currentRepo = nil
        }
        updateSharedStateDisconnected()

        guard let server = lastConnectedServer else {
            connectionStatus = .lost
            return
        }
        startReconnectLoop(to: server)
    }

    /// Watch the connection state; a local network drop parks the socket in `.waiting` with no error.
    private func monitorConnectionState(_ repo: VolumeControlRepository) {
        guard let transport = repo.transport as? VolumeTransportDataSource else { return }
        transport.connection.nw.stateUpdateHandler = { [weak self] state in
            let lost: Bool
            switch state {
            case .failed, .waiting: lost = true
            default: lost = false
            }
            guard lost else { return }
            Task { @MainActor in
                self?.handleConnectionLost()
            }
        }
    }

    /// Watch the system network path; an interface change won't fault a stalled socket, so probe by reconnecting.
    private func startPathMonitor() {
        pathMonitor?.cancel()
        lastPathSignature = nil
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let usesWiFi = path.usesInterfaceType(.wifi)
            let usesCellular = path.usesInterfaceType(.cellular)
            let satisfied = path.status == .satisfied
            Task { @MainActor in
                self?.handlePathUpdate(usesWiFi: usesWiFi, usesCellular: usesCellular, satisfied: satisfied)
            }
        }
        monitor.start(queue: pathMonitorQueue)
    }

    private func stopPathMonitor() {
        pathMonitor?.cancel()
        pathMonitor = nil
        lastPathSignature = nil
    }

    private func handlePathUpdate(usesWiFi: Bool, usesCellular: Bool, satisfied: Bool) {
        let signature = "\(satisfied)-\(usesWiFi)-\(usesCellular)"
        let isFirst = lastPathSignature == nil
        let changed = signature != lastPathSignature
        lastPathSignature = signature

        // First callback is the baseline: record which interface we connected over.
        if isFirst {
            connectedOverWiFi = usesWiFi
            connectedOverCellular = usesCellular
            return
        }
        guard changed else { return }

        if connectionStatus == .connected {
            // Our interface vanished (or all connectivity lost): probe via reconnect.
            let ourInterfaceGone = (connectedOverWiFi && !usesWiFi) || (connectedOverCellular && !usesCellular)
            if !satisfied || ourInterfaceGone {
                handleConnectionLost()
            }
        } else {
            // Reconnecting/lost: a usable path change is a good moment to probe rather than waiting for backoff.
            if satisfied, !userInitiatedDisconnect, !isInBackground, let server = lastConnectedServer {
                startReconnectLoop(to: server)
            }
        }
    }

    /// Reconnects with backoff; lands on `.connected` or `.lost` without clearing `fullState` or bouncing to the connect screen.
    func startReconnectLoop(to server: DiscoveredServer) {
        reconnectTask?.cancel()
        reconnectTask = Task {
            connectionStatus = .reconnecting
            let deadline = Date().addingTimeInterval(reconnectWindowSeconds)
            var delay = reconnectInitialDelaySeconds
            var attempt = 0
            while !Task.isCancelled && Date() < deadline {
                attempt += 1
                do {
                    let repo = try await connect.execute(address: server.address, port: server.port)
                    if Task.isCancelled { repo.transport.close(); return }
                    currentRepo = repo
                    defUpdate = SendDefaultDeviceUpdateUseCase(repo: repo)
                    masterUpdate = SendMasterChannelUpdateUseCase(repo: repo)
                    sessionUpdate = SendSessionUpdateUseCase(repo: repo)
                    subscribe(to: repo)
                    // Mark live immediately so a fresh drop is detected again.
                    connectionStatus = .connected
                    return
                } catch {
                    appLog("Reconnection attempt \(attempt) failed: \(error.localizedDescription)")
                }
                if Task.isCancelled || Date() >= deadline { break }
                try? await Task.sleep(for: .seconds(delay))
                delay = min(delay * 2, reconnectMaxDelaySeconds) // 5 -> 10 -> 20 -> 30 (capped)
            }
            if !Task.isCancelled { connectionStatus = .lost }
        }
    }

    /// User-triggered retry from the "Server disconnected" banner.
    func reconnect() {
        guard let server = lastConnectedServer else { return }
        userInitiatedDisconnect = false
        startReconnectLoop(to: server)
    }

    private func subscribe(to repo: VolumeControlRepository) {
        streamTask = Task {
            do {
                for try await state in repo.fullStateStream() {
                    // Stop applying updates after cancellation so an in-flight value can't resurrect state.
                    if Task.isCancelled { break }
                    fullState = state // view state only here
                    connectionStatus = .connected
                    updateSharedState(with: state) // Update widget state
                }
                // Stream ended without throwing (server closed the connection).
                if !Task.isCancelled { handleConnectionLost() }
            } catch {
                // RST / keepalive timeout / read error.
                if !Task.isCancelled { handleConnectionLost() }
            }
        }

        // Watch the connection state (catches local network loss where the byte stream stalls without error).
        monitorConnectionState(repo)

        // Watch the network path (catches WiFi <-> cellular interface changes).
        startPathMonitor()

        // Start heartbeat to keep widget fresh
        startHeartbeat()
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if !Task.isCancelled, let state = fullState {
                    updateSharedState(with: state)
                }
            }
        }
    }

    // MARK: - Shared State Management (for Widget)

    private func updateSharedState(with state: FullState) {
        // TODO: track chat session info (chatVolume/chatSessionName left nil for now).
        let sharedState = SharedConnectionState(
            isConnected: true,
            lastSeenAlive: Date(),
            serverName: lastConnectedServer?.computerName,
            serverAddress: lastConnectedServer?.address,
            masterVolume: state.defaultDevice.masterVolume,
            chatVolume: nil,
            chatSessionName: nil
        )

        SharedStateManager.writeState(sharedState)

        WidgetCenter.shared.reloadTimelines(ofKind: "PcVolumeControlWidget")
    }

    private func updateSharedStateDisconnected() {
        if var existingState = SharedStateManager.readState() {
            existingState.isConnected = false
            SharedStateManager.writeState(existingState)
        } else {
            let disconnectedState = SharedConnectionState(
                isConnected: false,
                lastSeenAlive: Date(),
                serverName: lastConnectedServer?.computerName,
                serverAddress: lastConnectedServer?.address
            )
            SharedStateManager.writeState(disconnectedState)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "PcVolumeControlWidget")
    }

    var hasActiveConnection: Bool {
        return currentRepo != nil
    }
    
    // UI intents
    func updateDefaultDevice(id: String)  { Task { try? await defUpdate.execute(id) } }
    func updateMaster(id: String, muted: Bool, vol: Double) {
        Task { try? await masterUpdate.execute(id: id, muted: muted, volume: vol) }
    }
    func updateSession(name: String, id: String, vol: Double, muted: Bool) {
        Task { try? await sessionUpdate.execute(name: name, id: id, vol: vol, muted: muted) }
    }
    
    func updateSession(_ session: FullState.Session) async throws {
        try await sessionUpdate.execute(name: session.name, id: session.id, vol: session.volume, muted: session.muted)
    }
    
    // MARK: - Server Management
    
    func loadRecentServers() {
        recentServers = serversRepo.recent()
        
        // Auto-fill the most recent server if fields are empty
        if address.isEmpty && !recentServers.isEmpty {
            let mostRecent = recentServers.first!
            address = mostRecent.address
            port = mostRecent.port
        }
    }
    
    func selectServer(_ server: DiscoveredServer) {
        address = server.address
        port = server.port
        connectToServer(address: address, port: port)
    }
    
    func saveSuccessfulConnection() {
        let newServer = DiscoveredServer(address: address, port: port, computerName: nil)
        
        // Add to the beginning and remove any duplicates
        var updatedServers = [newServer]
        for server in recentServers {
            if server.address != newServer.address || server.port != newServer.port {
                updatedServers.append(server)
            }
        }
        
        // Limit to 5 most recent servers
        recentServers = Array(updatedServers.prefix(5))
        serversRepo.saveRecent(recentServers)
    }
    
    func handleDiscoveredServers(_ servers: [DiscoveredServer]) {
        discoveredServers = servers
        
        guard let firstServer = servers.first else {
            isAutoDiscovered = false
            currentDiscoveredServer = nil
            return
        }

        // Only auto-fill if fields are empty or currently showing auto-discovered content
        let shouldAutoFill = address.isEmpty || isAutoDiscovered

        if shouldAutoFill {
            address = firstServer.address
            port = firstServer.port
            currentDiscoveredServer = firstServer
            isAutoDiscovered = true
        }
    }
    
    func handleManualAddressChange(_ newValue: String) {
        // If user manually changes address and it doesn't match discovered server, clear auto-discovery flag
        if isAutoDiscovered, let discoveredServer = currentDiscoveredServer {
            if newValue != discoveredServer.address {
                isAutoDiscovered = false
                currentDiscoveredServer = nil
            }
        }
    }
    
    func handleManualPortChange(_ newValue: UInt16) {
        // If user manually changes port and it doesn't match discovered server, clear auto-discovery flag
        if isAutoDiscovered, let discoveredServer = currentDiscoveredServer {
            if newValue != discoveredServer.port {
                isAutoDiscovered = false
                currentDiscoveredServer = nil
            }
        }
    }
    
    // MARK: - Unified Server List
    
    enum ServerListItem: Identifiable {
        case discovered(DiscoveredServer)
        case recent(DiscoveredServer)
        case manual
        
        var id: String {
            switch self {
            case .discovered(let server):
                return "discovered_\(server.id)"
            case .recent(let server):
                return "recent_\(server.id)"
            case .manual:
                return "manual_entry"
            }
        }
        
        var server: DiscoveredServer? {
            switch self {
            case .discovered(let server), .recent(let server):
                return server
            case .manual:
                return nil
            }
        }
        
        var isDiscovered: Bool {
            if case .discovered = self { return true }
            return false
        }
        
        var isRecent: Bool {
            if case .recent = self { return true }
            return false
        }
        
        var isManual: Bool {
            if case .manual = self { return true }
            return false
        }
    }
    
    var unifiedServerList: [ServerListItem] {
        var items: [ServerListItem] = []
        var seenAddresses: Set<String> = []
        
        // Add discovered servers first (most recent at top)
        for server in discoveredServers {
            let key = "\(server.address):\(server.port)"
            if !seenAddresses.contains(key) {
                items.append(.discovered(server))
                seenAddresses.insert(key)
            }
        }
        
        // Add recent servers that haven't been seen yet
        for server in recentServers {
            let key = "\(server.address):\(server.port)"
            if !seenAddresses.contains(key) {
                items.append(.recent(server))
                seenAddresses.insert(key)
            }
        }
        
        items.append(.manual)
        
        return items
    }
    
    func deleteServerFromList(_ item: ServerListItem) {
        switch item {
        case .discovered(let server):
            // Remove discovered server from the list (it may reappear if still broadcasting)
            if let index = discoveredServers.firstIndex(where: { $0.id == server.id }) {
                discoveredServers.remove(at: index)
            }
        case .recent(let server):
            if let index = recentServers.firstIndex(where: { $0.id == server.id }) {
                recentServers.remove(at: index)
                serversRepo.saveRecent(recentServers)
            }
        case .manual:
            // The manual-entry row is not deletable.
            break
        }
    }
}


class FullState: Codable, Equatable {
    static func == (lhs: FullState, rhs: FullState) -> Bool {
        return lhs.protocolVersion == rhs.protocolVersion &&
               lhs.deviceIds == rhs.deviceIds &&
               lhs.defaultDevice.deviceId == rhs.defaultDevice.deviceId &&
               lhs.defaultDevice.masterMuted == rhs.defaultDevice.masterMuted &&
               lhs.defaultDevice.masterVolume == rhs.defaultDevice.masterVolume &&
               lhs.defaultDevice.name == rhs.defaultDevice.name &&
               lhs.defaultDevice.sessions == rhs.defaultDevice.sessions
    }
    struct theDefaultDevice: Codable, Equatable {
        let deviceId: String
        var masterMuted: Bool
        var masterVolume: Double
        let name: String
        var sessions: [Session]
    }
    struct Session: Codable, Identifiable, Equatable {
        let id: String
        var muted: Bool
        var name: String
        var volume: Double
    }
    var defaultDevice: theDefaultDevice
    let deviceIds: [String: String]
    let protocolVersion: Int
    
    init(protocolVersion: Int, deviceIds: [String:String], defaultDevice: theDefaultDevice) {
        self.protocolVersion = protocolVersion
        self.deviceIds = deviceIds
        self.defaultDevice = defaultDevice
    }
}
