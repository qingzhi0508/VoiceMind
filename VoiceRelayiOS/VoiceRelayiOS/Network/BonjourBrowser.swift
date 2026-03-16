import Foundation
import Network

protocol BonjourBrowserDelegate: AnyObject {
    func browser(_ browser: BonjourBrowser, didFindService service: DiscoveredService)
    func browser(_ browser: BonjourBrowser, didRemoveService service: DiscoveredService)
}

class BonjourBrowser {
    weak var delegate: BonjourBrowserDelegate?

    private var browser: NWBrowser?
    private let serviceType = "_voicerelay._tcp"
    private var discoveredServices: [NWEndpoint: DiscoveredService] = [:]

    func start() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)

        browser.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Bonjour browser ready")
            case .failed(let error):
                print("Bonjour browser failed: \(error)")
            case .cancelled:
                print("Bonjour browser cancelled")
            default:
                break
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleBrowseResults(results, changes: changes)
        }

        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
        discoveredServices.removeAll()
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let result):
                resolveService(result)
            case .removed(let result):
                if let service = discoveredServices.removeValue(forKey: result.endpoint) {
                    delegate?.browser(self, didRemoveService: service)
                }
            default:
                break
            }
        }
    }

    private func resolveService(_ result: NWBrowser.Result) {
        guard case .service(let name, _, _, _) = result.endpoint else {
            return
        }

        // Create connection to resolve endpoint
        let connection = NWConnection(to: result.endpoint, using: .tcp)

        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                if let endpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = endpoint {
                    let service = DiscoveredService(
                        name: name,
                        host: "\(host)",
                        port: port.rawValue
                    )
                    self?.discoveredServices[result.endpoint] = service
                    self?.delegate?.browser(self!, didFindService: service)
                }
                connection.cancel()
            }
        }

        connection.start(queue: .main)
    }
}
