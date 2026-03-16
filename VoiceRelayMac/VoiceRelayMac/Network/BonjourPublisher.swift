import Foundation
import Network

class BonjourPublisher {
    private var listener: NWListener?
    private let serviceType = "_voicerelay._tcp"
    private var port: UInt16

    init(port: UInt16) {
        self.port = port
    }

    func start() throws {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))

        listener.service = NWListener.Service(
            name: Host.current().localizedName ?? "VoiceRelay Mac",
            type: serviceType
        )

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Bonjour service published on port \(self.port)")
            case .failed(let error):
                print("Bonjour service failed: \(error)")
            case .cancelled:
                print("Bonjour service cancelled")
            default:
                break
            }
        }

        listener.start(queue: .main)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }
}
