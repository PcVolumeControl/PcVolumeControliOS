import Foundation
import Network

class MDNSDiscoveryService: ObservableObject {
    @Published var discoveredServers: [DiscoveredServer] = []
    @Published var isDiscovering = false

    private var browser: NWBrowser?
    private let browserQueue = DispatchQueue(label: "mdns.browser.queue")

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
                removeServer(result: result)
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
                        // Remove any existing server with the same address and add the new one
                        self?.discoveredServers.removeAll { $0.address == cleanedAddress }
                        self?.discoveredServers.append(server)
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

    private func removeServer(result: NWBrowser.Result) {
        guard case let .service(name: serviceName, type: _, domain: _, interface: _) = result.endpoint else {
            return
        }

        DispatchQueue.main.async {
            self.discoveredServers.removeAll { $0.id.contains(serviceName) }
        }
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
