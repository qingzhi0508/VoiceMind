import Foundation

struct DiscoveredService: Identifiable {
    let name: String
    let host: String
    let port: UInt16

    var id: String {
        "\(name)|\(host)|\(port)"
    }
}
