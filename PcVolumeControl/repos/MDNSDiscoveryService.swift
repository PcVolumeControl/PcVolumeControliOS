import Foundation
import Network

class MDNSDiscoveryService: ObservableObject {
    @Published var discoveredServers: [DiscoveredServer] = []
    @Published var isDiscovering = false

    private var browser: NWBrowser?
    private let browserQueue = DispatchQueue(label: "mdns.browser.queue")

    // Maps a Bonjour service instance name (e.g. "MYPC-pcvolumecontrol-3000") to the
    // server resolved for it. A withdrawal (.removed) only gives us the service name,
    // while discoveredServers is keyed by resolved IP+port, so this map is the only
    // reliable link from a goodbye packet back to the row that must be removed.
    private var resolvedByServiceName: [String: DiscoveredServer] = [:]

    func startDiscovery() {
        guard browser == nil else { return }

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browserDescriptor = NWBrowser.Descriptor.bonjour(type: "_pcvolumecontrol._tcp", domain: "local.")
        browser = NWBrowser(for: browserDescriptor, using: parameters)

        browser?.stateUpdateHandler = { [weak self] (state: NWBrowser.State) in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isDiscovering = true
                case .failed, .cancelled:
                    self?.isDiscovering = false
                default:
                    break
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] _, changes in
            self?.handleBrowseResults(changes: changes)
        }

        browser?.start(queue: browserQueue)
    }

    func stopDiscovery() {
        guard browser != nil else { return }

        browser?.cancel()
        browser = nil
        DispatchQueue.main.async {
            self.isDiscovering = false
            self.discoveredServers.removeAll()
            self.resolvedByServiceName.removeAll()
        }
    }

    private func handleBrowseResults(changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let result):
                if case .service = result.endpoint {
                    resolveService(result: result)
                }
            case .removed(let result):
                handleRemoval(result: result)
            case .changed(old: _, new: let newResult, flags: _):
                resolveService(result: newResult)
            default:
                break
            }
        }
    }

    private func resolveService(result: NWBrowser.Result) {
        guard case let .service(name: serviceName, type: _, domain: _, interface: _) = result.endpoint else {
            return
        }

        let connection = NWConnection(to: result.endpoint, using: .tcp)

        connection.stateUpdateHandler = { [weak self] (state: NWConnection.State) in
            switch state {
            case .ready:
                if let endpoint = connection.currentPath?.remoteEndpoint,
                   case let .hostPort(host: host, port: port) = endpoint {

                    let rawHostString = "\(host)"
                    let cleanedAddress = self?.cleanIPAddress(rawHostString) ?? rawHostString
                    let computerName = self?.extractComputerName(from: serviceName)
                    let server = DiscoveredServer(address: cleanedAddress, port: port.rawValue, computerName: computerName)

                    DispatchQueue.main.async {
                        self?.recordResolvedServer(server, forServiceName: serviceName)
                    }
                }
                connection.cancel()
            case .failed:
                connection.cancel()
            default:
                break
            }
        }

        connection.start(queue: browserQueue)
    }

    // Records a freshly resolved service and publishes it. Must run on the main queue.
    // Keyed by serviceName so a later withdrawal can find the exact server to remove.
    func recordResolvedServer(_ server: DiscoveredServer, forServiceName serviceName: String) {
        resolvedByServiceName[serviceName] = server
        // Replace any existing entry for the same address, then add the new one.
        discoveredServers.removeAll { $0.address == server.address }
        discoveredServers.append(server)
    }

    private func handleRemoval(result: NWBrowser.Result) {
        guard case let .service(name: serviceName, type: _, domain: _, interface: _) = result.endpoint else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.removeServer(forServiceName: serviceName)
        }
    }

    // Removes a withdrawn service (Bonjour goodbye / NWBrowser .removed). Must run on
    // the main queue. No-op when the service was never resolved into a server.
    func removeServer(forServiceName serviceName: String) {
        guard let server = resolvedByServiceName.removeValue(forKey: serviceName) else { return }
        discoveredServers.removeAll { $0 == server }
    }

    private func cleanIPAddress(_ rawAddress: String) -> String {
        // Remove interface identifier from IP address (e.g., "192.168.1.100%en0" -> "192.168.1.100")
        if let percentIndex = rawAddress.firstIndex(of: "%") {
            return String(rawAddress[..<percentIndex])
        }
        return rawAddress
    }

    private func extractComputerName(from serviceName: String) -> String? {
        // Service name format "COMPUTERNAME-pcvolumecontrol-PORT"; take the part before the first hyphen.
        let components = serviceName.components(separatedBy: "-")
        guard components.count >= 2, !components[0].isEmpty else {
            return nil
        }
        return components[0]
    }

    deinit {
        stopDiscovery()
    }
}
