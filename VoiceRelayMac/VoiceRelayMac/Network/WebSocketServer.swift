import Foundation
import Network
import SharedCore

protocol WebSocketServerDelegate: AnyObject {
    func server(_ server: WebSocketServer, didReceiveMessage message: MessageEnvelope)
    func server(_ server: WebSocketServer, didChangeState state: ConnectionState)
}

class WebSocketServer {
    weak var delegate: WebSocketServerDelegate?

    private var listener: NWListener?
    private var connection: NWConnection?
    private(set) var port: UInt16 = 0
    private(set) var state: ConnectionState = .disconnected {
        didSet {
            delegate?.server(self, didChangeState: state)
        }
    }

    func start(portRange: ClosedRange<UInt16> = 8000...9000) throws {
        for port in portRange {
            do {
                let parameters = NWParameters.tcp
                parameters.allowLocalEndpointReuse = true

                let listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))

                listener.stateUpdateHandler = { [weak self] newState in
                    self?.handleListenerState(newState)
                }

                listener.newConnectionHandler = { [weak self] newConnection in
                    self?.handleNewConnection(newConnection)
                }

                listener.start(queue: .main)
                self.listener = listener
                self.port = port
                self.state = .connecting
                print("WebSocket server started on port \(port)")
                return
            } catch {
                continue
            }
        }
        throw NSError(domain: "WebSocketServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No available port in range"])
    }

    func stop() {
        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil
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

    private func handleListenerState(_ newState: NWListener.State) {
        switch newState {
        case .ready:
            state = .connecting
        case .failed(let error):
            state = .error(error)
        case .cancelled:
            state = .disconnected
        default:
            break
        }
    }

    private func handleNewConnection(_ newConnection: NWConnection) {
        // Reject if already connected
        if connection != nil {
            newConnection.cancel()
            return
        }

        connection = newConnection
        state = .connected

        newConnection.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready:
                self?.state = .connected
                self?.receiveMessage()
            case .failed(let error):
                self?.state = .error(error)
                self?.connection = nil
            case .cancelled:
                self?.state = .disconnected
                self?.connection = nil
            default:
                break
            }
        }

        newConnection.start(queue: .main)
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
            delegate?.server(self, didReceiveMessage: envelope)
        } catch {
            print("Failed to decode message: \(error)")
        }

        // Continue receiving next message
        receiveMessage()
    }
}
