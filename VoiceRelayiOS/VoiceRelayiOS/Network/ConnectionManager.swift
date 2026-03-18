import Foundation
import SharedCore
import CryptoKit
import UIKit

protocol ConnectionManagerDelegate: AnyObject {
    func connectionManager(_ manager: ConnectionManager, didChangePairingState state: PairingState)
    func connectionManager(_ manager: ConnectionManager, didChangeConnectionState state: ConnectionState)
    func connectionManager(_ manager: ConnectionManager, didReceiveMessage envelope: MessageEnvelope)
}

class ConnectionManager: NSObject {
    weak var delegate: ConnectionManagerDelegate?

    private let client = WebSocketClient()
    var hmacValidator: HMACValidator?
    private var pendingPairConfirmEnvelope: MessageEnvelope?

    private let keychainService = "com.voicerelay.ios"
    private let keychainAccount = "pairing"
    let deviceId = UUID().uuidString
    private var pendingPairingDeviceName: String?

    private(set) var pairingState: PairingState = .unpaired {
        didSet {
            delegate?.connectionManager(self, didChangePairingState: pairingState)
        }
    }

    private var heartbeatTimer: Timer?
    private var pongTimer: Timer?
    private var currentPingNonce: String?
    private var connectionValidationTimer: Timer?
    private var isConnectionValidated = false

    override init() {
        super.init()
        client.delegate = self
        loadPairing()
    }

    func connect(to service: DiscoveredService) {
        print("🔗 连接到服务: \(service.name) (\(service.host):\(service.port))")
        client.connect(to: service.host, port: service.port)
    }

    func disconnect() {
        stopHeartbeat()
        client.disconnect()
    }

    func pair(with service: DiscoveredService, code: String) {
        print("🔗 开始配对流程: \(service.name) (\(service.host):\(service.port))")
        print("🔐 配对码: \(code)")
        pendingPairingDeviceName = service.name
        connect(to: service)
        queueOrSendPairConfirm(code: code)
    }

    func unpair() {
        try? KeychainManager.delete(service: keychainService, account: keychainAccount)
        hmacValidator = nil
        pairingState = .unpaired
        disconnect()
    }

    func connectDirectly(ip: String, port: UInt16) {
        print("📡 直接连接到: \(ip):\(port)")
        client.connect(to: ip, port: port)
    }

    func pairWithCode(_ code: String) {
        print("🔐 使用配对码配对: \(code)")
        queueOrSendPairConfirm(code: code)
    }

    func setPendingPairingDeviceName(_ deviceName: String?) {
        pendingPairingDeviceName = deviceName
    }

    func send(_ envelope: MessageEnvelope) {
        client.send(envelope)
    }

    private func loadPairing() {
        do {
            let pairing = try KeychainManager.retrievePairing(service: keychainService, account: keychainAccount)
            hmacValidator = HMACValidator(sharedSecret: pairing.sharedSecret)
            pairingState = .paired(deviceId: pairing.deviceId, deviceName: pairing.deviceName)
        } catch {
            pairingState = .unpaired
        }
    }

    private func queueOrSendPairConfirm(code: String) {
        guard let envelope = makePairConfirmEnvelope(code: code) else {
            print("❌ 无法创建配对确认消息")
            return
        }

        if case .connected = client.state {
            print("✅ 连接已建立，立即发送配对确认")
            pendingPairConfirmEnvelope = nil
            client.send(envelope)
        } else {
            print("⏳ 连接未建立，将配对确认消息加入队列")
            pendingPairConfirmEnvelope = envelope
        }
    }

    private func makePairConfirmEnvelope(code: String) -> MessageEnvelope? {
        let payload = PairConfirmPayload(
            shortCode: code,
            iosName: UIDevice.current.name,
            iosId: deviceId
        )

        guard let payloadData = try? JSONEncoder().encode(payload) else { return nil }

        return MessageEnvelope(
            type: .pairConfirm,
            payload: payloadData,
            timestamp: Date(),
            deviceId: deviceId,
            hmac: nil
        )
    }

    private func handlePairSuccess(_ payload: PairSuccessPayload, macId: String, macName: String) {
        let resolvedMacName = pendingPairingDeviceName ?? macName

        print("🎉 收到配对成功消息")
        print("   Mac ID: \(macId)")
        print("   Mac Name: \(resolvedMacName)")
        print("   共享密钥长度: \(payload.sharedSecret.count)")

        // Save pairing
        let pairing = PairingData(
            deviceId: macId,
            deviceName: resolvedMacName,
            sharedSecret: payload.sharedSecret
        )

        do {
            try KeychainManager.savePairing(pairing, service: keychainService, account: keychainAccount)
            hmacValidator = HMACValidator(sharedSecret: payload.sharedSecret)
            pairingState = .paired(deviceId: macId, deviceName: resolvedMacName)
            pendingPairingDeviceName = nil

            print("💾 配对信息已保存到 Keychain")
            print("❤️ 启动心跳")
            startHeartbeat()
        } catch {
            print("❌ 保存配对信息失败: \(error)")
        }
    }

    private func startHeartbeat() {
        print("❤️ 启动心跳定时器（每 30 秒）")
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func stopHeartbeat() {
        print("💔 停止心跳定时器")
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        pongTimer?.invalidate()
        pongTimer = nil
    }

    private func sendPing() {
        print("💓 发送心跳 Ping")
        let nonce = UUID().uuidString
        currentPingNonce = nonce

        let payload = PingPayload(nonce: nonce)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let timestamp = Date()
        let hmac = hmacValidator?.generateHMACForEnvelope(
            type: .ping,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: deviceId
        )

        let envelope = MessageEnvelope(
            type: .ping,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: deviceId,
            hmac: hmac
        )

        client.send(envelope)

        // Start pong timeout
        pongTimer?.invalidate()
        pongTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.handlePongTimeout()
        }
    }

    private func handlePongTimeout() {
        print("Pong timeout, reconnecting...")
        client.disconnect()
    }

    private func startConnectionValidation() {
        print("🔍 开始连接验证")
        isConnectionValidated = false
        stopConnectionValidation()
        
        // 立即发送验证消息
        sendPing()
        
        // 设置验证超时定时器
        connectionValidationTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            self?.handleConnectionValidationTimeout()
        }
    }

    private func stopConnectionValidation() {
        print("🛑 停止连接验证")
        connectionValidationTimer?.invalidate()
        connectionValidationTimer = nil
    }

    private func handleConnectionValidationTimeout() {
        print("❌ 连接验证超时")
        isConnectionValidated = false
        client.disconnect()
    }

    private func validateConnection() {
        print("✅ 连接验证成功")
        isConnectionValidated = true
        stopConnectionValidation()
        
        // 通知代理连接成功
        let validatedState: ConnectionState = .connected
        delegate?.connectionManager(self, didChangeConnectionState: validatedState)
    }

    private func sendError(code: String, message: String) {
        let payload = ErrorPayload(code: code, message: message)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let timestamp = Date()
        let hmac = hmacValidator?.generateHMACForEnvelope(
            type: .error,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: deviceId
        )

        let envelope = MessageEnvelope(
            type: .error,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: deviceId,
            hmac: hmac
        )

        client.send(envelope)
    }
}

extension ConnectionManager: WebSocketClientDelegate {
    func client(_ client: WebSocketClient, didReceiveMessage message: MessageEnvelope) {
        // Handle pairing messages without HMAC
        if message.type == .pairSuccess {
            guard let payload = try? JSONDecoder().decode(PairSuccessPayload.self, from: message.payload) else {
                return
            }
            handlePairSuccess(payload, macId: message.deviceId, macName: "Mac")
            return
        }

        if message.type == .error {
            delegate?.connectionManager(self, didReceiveMessage: message)
            return
        }

        // Validate HMAC for all other messages
        guard let validator = hmacValidator else {
            print("Received message but not paired")
            return
        }

        guard validator.validateEnvelopeHMAC(message) else {
            print("HMAC validation failed")
            return
        }

        // Handle pong
        if message.type == .pong {
            guard let payload = try? JSONDecoder().decode(PongPayload.self, from: message.payload) else {
                print("⚠️ 无法解析 Pong 消息")
                return
            }

            if payload.nonce == currentPingNonce {
                print("💚 收到心跳 Pong 响应")
                pongTimer?.invalidate()
                pongTimer = nil
                
                // 如果连接尚未验证，验证它
                if !isConnectionValidated {
                    validateConnection()
                }
            } else {
                print("⚠️ Pong nonce 不匹配")
            }
            return
        }

        // Forward validated message to delegate
        delegate?.connectionManager(self, didReceiveMessage: message)
    }

    func client(_ client: WebSocketClient, didChangeState state: WebSocketConnectionState) {
        let connectionState: ConnectionState

        switch state {
        case .disconnected:
            print("🔌 连接已断开")
            pendingPairConfirmEnvelope = nil
            isConnectionValidated = false
            stopConnectionValidation()
            connectionState = .disconnected
        case .connecting:
            print("🔄 正在连接...")
            isConnectionValidated = false
            stopConnectionValidation()
            connectionState = .connecting
        case .connected:
            print("✅ 连接已建立")
            connectionState = .connecting // 暂时保持连接中状态，直到验证完成
            if let pendingPairConfirmEnvelope {
                print("📤 发送待发送的配对确认消息")
                client.send(pendingPairConfirmEnvelope)
                self.pendingPairConfirmEnvelope = nil
            }
            
            // 开始连接验证
            if case .paired = pairingState {
                startConnectionValidation()
            } else {
                // 未配对状态，直接认为连接成功
                isConnectionValidated = true
                let validatedState: ConnectionState = .connected
                delegate?.connectionManager(self, didChangeConnectionState: validatedState)
                stopHeartbeat() // 未配对状态不启动心跳
            }
        case .error(let error):
            print("❌ 连接错误: \(error.localizedDescription)")
            pendingPairConfirmEnvelope = nil
            isConnectionValidated = false
            stopConnectionValidation()
            connectionState = .error(error.localizedDescription)
        }

        // 只有在非连接状态下才通知代理
        if case .connected = state {
            if case .paired = pairingState {
                // 已配对状态在验证时避免重复通知
            } else {
                delegate?.connectionManager(self, didChangeConnectionState: connectionState)
            }
        } else {
            delegate?.connectionManager(self, didChangeConnectionState: connectionState)
        }

        if isConnectionValidated, case .paired = pairingState {
            startHeartbeat()
        } else {
            stopHeartbeat()
        }
    }
}
