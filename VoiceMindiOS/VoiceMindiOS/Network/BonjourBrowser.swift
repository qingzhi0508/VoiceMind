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
            print("⚠️ 无法解析服务端点")
            return
        }

        print("🔍 开始解析服务: \(name)")

        // Create connection to resolve endpoint
        let connection = NWConnection(to: result.endpoint, using: .tcp)

        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                if let endpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = endpoint {
                    let resolvedHost = "\(host)"
                    let service = DiscoveredService(
                        name: name,
                        host: resolvedHost,
                        port: port.rawValue
                    )
                    print("✅ 服务解析成功: \(name) at \(resolvedHost):\(port.rawValue)")

                    self?.discoveredServices[result.endpoint] = service
                    self?.delegate?.browser(self!, didFindService: service)

                    // If the resolved address is link-local, also try DNS resolution for a better IPv4
                    if Self.isLinkLocalAddress(resolvedHost) {
                        print("🔄 解析到链路本地地址，尝试获取更好的 IPv4 地址")
                        Self.resolveHostname(name: name, port: port.rawValue) { [weak self] ipv4Host in
                            if let ipv4Host {
                                let betterService = DiscoveredService(
                                    name: name,
                                    host: ipv4Host,
                                    port: port.rawValue
                                )
                                print("✅ 找到更好的 IPv4 地址: \(ipv4Host):\(port.rawValue)")
                                self?.discoveredServices[result.endpoint] = betterService
                                self?.delegate?.browser(self!, didFindService: betterService)
                            }
                        }
                    }
                } else {
                    print("❌ 无法获取服务端点信息")
                }
                connection.cancel()
            } else if case .failed(let error) = state {
                print("❌ 服务解析失败: \(error)")
                connection.cancel()
            }
        }

        connection.start(queue: .main)
    }

    // MARK: - Address Helpers

    private static func isLinkLocalAddress(_ address: String) -> Bool {
        // IPv4 link-local: 169.254.x.x
        if address.hasPrefix("169.254.") {
            return true
        }
        // IPv6 link-local: fe80::
        let cleaned = address.split(separator: "%").first.map(String.init) ?? address
        if cleaned.hasPrefix("fe80:") || cleaned.hasPrefix("fe80::") {
            return true
        }
        return false
    }

    /// Try to resolve a Bonjour hostname to an IPv4 address using getaddrinfo
    private static func resolveHostname(name: String, port: UInt16, completion: @escaping (String?) -> Void) {
        let hostname = "\(name).local."
        DispatchQueue.global(qos: .userInitiated).async {
            var hints = addrinfo()
            hints.ai_family = AF_INET  // IPv4 only
            hints.ai_socktype = SOCK_STREAM

            var result: UnsafeMutablePointer<addrinfo>?
            let status = getaddrinfo(hostname, "\(port)", &hints, &result)
            defer { if let result { freeaddrinfo(result) } }

            guard status == 0, let addrInfo = result else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            var ipv4Address: String?
            var ptr: UnsafeMutablePointer<addrinfo>? = addrInfo
            while let current = ptr {
                var addressBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let addr = current.pointee.ai_addr
                guard getnameinfo(addr, current.pointee.ai_addrlen, &addressBuffer, socklen_t(addressBuffer.count), nil, 0, NI_NUMERICHOST) == 0 else {
                    ptr = current.pointee.ai_next
                    continue
                }

                let addressStr = String(cString: addressBuffer)
                // Prefer private LAN IPv4
                if isPrivateLANIPv4(addressStr) {
                    ipv4Address = addressStr
                    break
                }
                // Accept any IPv4 as fallback
                if ipv4Address == nil {
                    ipv4Address = addressStr
                }
                ptr = current.pointee.ai_next
            }

            DispatchQueue.main.async { completion(ipv4Address) }
        }
    }

    private static func isPrivateLANIPv4(_ address: String) -> Bool {
        let octets = address.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else {
            return false
        }
        switch (octets[0], octets[1]) {
        case (10, _): return true
        case (172, 16...31): return true
        case (192, 168): return true
        default: return false
        }
    }
}
