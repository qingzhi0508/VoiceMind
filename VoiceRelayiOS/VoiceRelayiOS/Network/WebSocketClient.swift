import Foundation
import Network
import SharedCore

protocol WebSocketClientDelegate: AnyObject {
    func client(_ client: WebSocketClient, didReceiveMessage message: MessageEnvelope)
    func client(_ client: WebSocketClient, didChangeState state: WebSocketConnectionState)
}

enum WebSocketConnectionState {
    case disconnected
    case connecting
    case connected
    case error(Error)
}

class WebSocketClient {
    weak var delegate: WebSocketClientDelegate?

    private var connection: NWConnection?
    private let reconnectionManager = ReconnectionManager()

    private(set) var state: WebSocketConnectionState = .disconnected {
        didSet {
            delegate?.client(self, didChangeState: state)
        }
    }

    private var host: String?
    private var port: UInt16?

    func connect(to host: String, port: UInt16) {
        self.host = host
        self.port = port

        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
        let connection = NWConnection(to: endpoint, using: .tcp)

        connection.stateUpdateHandler = { [weak self] newState in
            self?.handleConnectionState(newState)
        }

        connection.start(queue: .main)
        self.connection = connection
        state = .connecting
    }

    func disconnect() {
        reconnectionManager.reset()
        connection?.cancel()
        connection = nil
        state = .disconnected
    }

    func send(_ envelope: MessageEnvelope) {
        guard let connection = connection, connection.state == .ready else {
            print("Cannot send message: not connected")
            return
        }

        do {
            let data = try JSONEncoder().encode(envelope)
            let lengthData = withUnsafeBytes(of: UInt32(data.count).bigEndian) { Data($0) }

            connection.send(content: lengthData + data, completion: .contentProcessed { error in
                if let error = error {
                    print("Failed to send message: \(error)")
                }
            })
        } catch {
            print("Failed to encode message: \(error)")
        }
    }

    private func handleConnectionState(_ newState: NWConnection.State) {
        switch newState {
        case .ready:
            state = .connected
            reconnectionManager.reset()
            print("WebSocket connected")
            receiveMessage()

        case .waiting(let error):
            print("WebSocket waiting: \(error)")
            state = .connecting

        case .failed(let error):
            state = .error(error)
            print("WebSocket failed: \(error)")
            connection = nil
            attemptReconnect()

        case .cancelled:
            state = .disconnected
            print("WebSocket cancelled")

        default:
            break
        }
    }

    private func receiveMessage() {
        guard let connection = connection else { return }

        // First receive 4 bytes for length
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, data.count == 4 else {
                if let error = error {
                    print("Failed to receive length: \(error)")
                }
                return
            }

            let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            // Then receive the actual message
            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { data, _, isComplete, error in
                guard let data = data else {
                    if let error = error {
                        print("Failed to receive message: \(error)")
                    }
                    return
                }

                self.handleReceivedData(data)

                // Continue receiving
                if !isComplete {
                    self.receiveMessage()
                }
            }
        }
    }

    private func handleReceivedData(_ data: Data) {
        do {
            let envelope = try JSONDecoder().decode(MessageEnvelope.self, from: data)
            delegate?.client(self, didReceiveMessage: envelope)
        } catch {
            print("Failed to decode message: \(error)")
        }

        // Continue receiving next message
        receiveMessage()
    }

    private func attemptReconnect() {
        guard let host = host, let port = port else { return }

        reconnectionManager.scheduleReconnect { [weak self] in
            self?.connect(to: host, port: port)
        }
    }
}
