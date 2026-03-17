import Foundation
import Network
import SharedCore

protocol WebSocketClientDelegate: AnyObject {
    func client(_ client: WebSocketClient, didReceiveMessage message: MessageEnvelope)
    func client(_ client: WebSocketClient, didChangeState state: WebSocketConnectionState)
}

private struct ReconnectionExhaustedError: LocalizedError {
    let maxAttempts: Int

    var errorDescription: String? {
        "自动重连已停止，连续 \(maxAttempts) 次连接失败，请手动重新连接。"
    }
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
        connect(to: host, port: port, resetReconnectState: true)
    }

    private func connect(to host: String, port: UInt16, resetReconnectState: Bool) {
        print("🔗 开始连接到 \(host):\(port)")
        self.host = host
        self.port = port

        if resetReconnectState {
            reconnectionManager.reset()
        }

        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))

        // 配置 TCP 参数以保持长连接
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 30  // 30 秒后开始发送 keepalive
        tcpOptions.keepaliveInterval = 10  // 每 10 秒发送一次
        tcpOptions.keepaliveCount = 3  // 3 次失败后断开
        tcpOptions.noDelay = true  // 禁用 Nagle 算法，减少延迟

        let parameters = NWParameters(tls: nil, tcp: tcpOptions)
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = true

        let connection = NWConnection(to: endpoint, using: parameters)

        connection.stateUpdateHandler = { [weak self] newState in
            self?.handleConnectionState(newState)
        }

        connection.start(queue: .main)
        self.connection = connection
        state = .connecting
        print("🔄 连接状态: connecting")
        print("✅ TCP Keep-Alive 已启用")
    }

    func disconnect() {
        reconnectionManager.reset()
        connection?.cancel()
        connection = nil
        state = .disconnected
    }

    func send(_ envelope: MessageEnvelope) {
        guard let connection = connection, connection.state == .ready else {
            print("❌ 无法发送消息: 未连接")
            return
        }

        do {
            let data = try JSONEncoder().encode(envelope)
            let lengthData = withUnsafeBytes(of: UInt32(data.count).bigEndian) { Data($0) }

            print("📤 发送消息: type=\(envelope.type), size=\(data.count) 字节")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("   内容: \(jsonString)")
            }

            connection.send(content: lengthData + data, completion: .contentProcessed { error in
                if let error = error {
                    print("❌ 发送消息失败: \(error)")
                } else {
                    print("✅ 消息发送成功")
                }
            })
        } catch {
            print("❌ 消息编码失败: \(error)")
        }
    }

    private func handleConnectionState(_ newState: NWConnection.State) {
        print("📡 连接状态变化: \(newState)")

        switch newState {
        case .ready:
            state = .connected
            reconnectionManager.reset()
            print("✅ WebSocket 已连接")
            receiveMessage()

        case .waiting(let error):
            print("⏳ WebSocket 等待中: \(error)")
            state = .connecting

        case .failed(let error):
            state = .error(error)
            print("❌ WebSocket 连接失败: \(error)")
            connection = nil
            attemptReconnect()

        case .cancelled:
            state = .disconnected
            print("🔌 WebSocket 已取消")

        default:
            break
        }
    }

    private func receiveMessage() {
        guard let connection = connection else { return }

        // First receive 4 bytes for length
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ 接收长度失败: \(error)")
                self.handleReceiveClosure()
                return
            }

            guard let data = data, data.count == 4 else {
                if isComplete || data?.isEmpty == true {
                    print("ℹ️ 服务端已关闭连接")
                    self.handleReceiveClosure()
                } else if let data = data {
                    print("⚠️ 接收到的长度数据不完整: \(data.count) 字节")
                } else {
                    print("⚠️ 接收到空数据，连接可能已关闭")
                    self.handleReceiveClosure()
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
                    self.handleReceiveClosure()
                    return
                }

                guard let data = data else {
                    if isComplete {
                        print("ℹ️ 服务端在消息体读取阶段关闭连接")
                        self.handleReceiveClosure()
                    } else {
                        print("⚠️ 接收到的消息数据为空")
                    }
                    return
                }

                print("📥 收到消息数据: \(data.count) 字节")
                self.handleReceivedData(data)
            }
        }
    }

    private func handleReceivedData(_ data: Data) {
        do {
            let envelope = try JSONDecoder().decode(MessageEnvelope.self, from: data)
            print("✅ 消息解码成功: type=\(envelope.type)")
            delegate?.client(self, didReceiveMessage: envelope)
        } catch {
            print("❌ 消息解码失败: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("   原始数据: \(jsonString)")
            }
        }

        // Continue receiving next message
        receiveMessage()
    }

    private func attemptReconnect() {
        guard let host = host, let port = port else {
            print("⚠️ 无法重连: 缺少主机或端口信息")
            return
        }

        print("🔄 计划重连到 \(host):\(port)")
        reconnectionManager.scheduleReconnect(
            onReconnect: { [weak self] in
                self?.connect(to: host, port: port, resetReconnectState: false)
            },
            onExhausted: { [weak self] in
                print("🛑 自动重连次数已用尽，停止继续重试")
                self?.connection?.cancel()
                self?.connection = nil
                self?.state = .error(ReconnectionExhaustedError(maxAttempts: 3))
            }
        )
    }

    private func handleReceiveClosure() {
        connection?.cancel()
        connection = nil
        state = .disconnected
        attemptReconnect()
    }
}
