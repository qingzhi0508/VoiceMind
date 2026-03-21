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

    func start(port: UInt16 = 8899) throws {
        do {
            // 配置 TCP 参数以保持长连接
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.enableKeepalive = true
            tcpOptions.keepaliveIdle = 30
            tcpOptions.keepaliveInterval = 10
            tcpOptions.keepaliveCount = 3
            tcpOptions.noDelay = true

            let parameters = NWParameters(tls: nil, tcp: tcpOptions)
            parameters.allowLocalEndpointReuse = true
            parameters.includePeerToPeer = true

            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))

            listener.service = NWListener.Service(
                name: Host.current().localizedName ?? "VoiceMind Mac",
                type: "_voicerelay._tcp"
            )

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
            print("✅ WebSocket server started on port \(port)")
            print("✅ Bonjour service: _voicerelay._tcp")
            print("✅ TCP Keep-Alive 已启用")
        } catch {
            throw NSError(
                domain: "WebSocketServer",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "端口 \(port) 已被占用或不可用，请在设置中更换端口。"]
            )
        }
    }

    func stop() {
        print("🛑 停止 WebSocket 服务器")
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
        print("🔗 收到新连接请求")

        // If already connected, close old connection and accept new one
        if let oldConnection = connection {
            print("⚠️ 已有活动连接，关闭旧连接并接受新连接")
            oldConnection.cancel()
            connection = nil
        }

        connection = newConnection
        // 先设置为 connecting，等连接就绪后再设置为 connected
        state = .connecting
        print("✅ 接受新连接")

        newConnection.stateUpdateHandler = { [weak self] newState in
            guard let self = self else { return }
            print("🔄 连接状态变化: \(newState)")
            switch newState {
            case .ready:
                print("✅ 连接就绪，开始接收消息")
                self.state = .connected
                self.receiveMessage()
            case .failed(let error):
                print("❌ 连接失败: \(error)")
                // 连接失败后，清除连接并设置为 disconnected
                self.connection = nil
                self.state = .disconnected
            case .cancelled:
                print("🔌 连接已取消")
                self.connection = nil
                // 连接取消后，设置为 disconnected（不再等待）
                self.state = .disconnected
            default:
                break
            }
        }

        newConnection.start(queue: .main)
        print("🚀 启动连接")
    }

    private func receiveMessage() {
        guard let connection = connection else {
            print("⚠️ 无法接收消息: 连接不存在")
            return
        }

        // First receive 4 bytes for length
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ 接收长度失败: \(error)")
                self.handleConnectionClosed()
                return
            }

            guard let data = data, data.count == 4 else {
                if isComplete || data?.isEmpty == true {
                    print("ℹ️ 对端已关闭连接")
                    self.handleConnectionClosed()
                } else if let data = data {
                    print("⚠️ 接收到的长度数据不完整: \(data.count) 字节")
                } else {
                    print("⚠️ 接收到空数据，连接可能已关闭")
                    self.handleConnectionClosed()
                }
                return
            }

            let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            print("📦 收到消息长度: \(length) 字节")

            // 验证长度是否合理（防止异常数据）
            guard length > 0 && length < 10_000_000 else {
                print("❌ 消息长度异常: \(length) 字节，停止接收")
                return
            }

            // Then receive the actual message
            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { data, _, isComplete, error in
                if let error = error {
                    print("❌ 接收消息失败: \(error)")
                    self.handleConnectionClosed()
                    return
                }

                guard let data = data else {
                    if isComplete {
                        print("ℹ️ 对端在消息体读取阶段关闭连接")
                        self.handleConnectionClosed()
                    } else {
                        print("⚠️ 接收到的消息数据为空")
                    }
                    return
                }

                print("📥 收到消息数据: \(data.count) 字节")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 消息内容: \(jsonString)")
                }

                self.handleReceivedData(data)
            }
        }
    }

    private func handleReceivedData(_ data: Data) {
        do {
            let envelope = try JSONDecoder().decode(MessageEnvelope.self, from: data)
            print("✅ 消息解码成功: type=\(envelope.type)")
            delegate?.server(self, didReceiveMessage: envelope)
        } catch {
            print("❌ 消息解码失败: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("   原始数据: \(jsonString)")
            } else {
                print("   原始数据 (hex): \(data.map { String(format: "%02x", $0) }.joined())")
            }
        }

        // Continue receiving next message
        receiveMessage()
    }

    private func handleConnectionClosed() {
        connection?.cancel()
        connection = nil
        state = .disconnected
    }
}
