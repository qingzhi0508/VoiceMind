import Foundation

struct DiscoveredService: Identifiable {
    let id = UUID()
    let name: String
    let host: String
    let port: UInt16
}
