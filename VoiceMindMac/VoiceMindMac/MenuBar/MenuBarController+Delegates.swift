import Cocoa
import Foundation
import SharedCore

enum VoiceInboundLogPolicy {
    static func shouldAppendInboundRecord(for messageType: MessageType) -> Bool {
        switch messageType {
        case .result:
            return false
        case .textMessage:
            return true
        default:
            return false
        }
    }
}

// MARK: - ConnectionManagerDelegate
extension MenuBarController: ConnectionManagerDelegate {
    func connectionManager(_ manager: ConnectionManager, didChangePairingState state: PairingState) {
        DispatchQueue.main.async {
            self.refreshPublishedState()
            self.updateStatusIcon()
            self.updateMenu()

            if case .paired = state {
                self.pairingWindow?.close()
            }
        }
    }

    func connectionManager(_ manager: ConnectionManager, didChangeConnectionState state: ConnectionState) {
        DispatchQueue.main.async {
            self.refreshPublishedState()
            self.updateStatusIcon()
            self.updateMenu()
            self.recordConnectionStateChange(state)
        }
    }

    func connectionManager(_ manager: ConnectionManager, didUpdatePairingProgress message: String?) {
        DispatchQueue.main.async {
            self.pairingProgressMessage = message
        }
    }

    func connectionManager(
        _ manager: ConnectionManager,
        didRecordInboundEvent title: String,
        detail: String,
        category: InboundDataCategory,
        severity: InboundDataSeverity
    ) {
        DispatchQueue.main.async {
            self.appendInboundDataRecord(title: title, detail: detail, category: category, severity: severity)
        }
    }

    func connectionManager(_ manager: ConnectionManager, didReceiveMessage envelope: MessageEnvelope) {
        switch envelope.type {
        case .result:
            handleResultMessage(envelope)
        case .textMessage:
            handleTextMessage(envelope)
        case .ping:
            handlePingMessage(envelope)
        default:
            break
        }
    }

    private func handleResultMessage(_ envelope: MessageEnvelope) {
        print("🔔 handleResultMessage 被调用")
        guard let payload = try? JSONDecoder().decode(ResultPayload.self, from: envelope.payload) else {
            print("❌ 无法解码 ResultPayload")
            return
        }

        print("📝 解码成功 - 文本: \(payload.text), sessionId: \(payload.sessionId)")

        if VoiceInboundLogPolicy.shouldAppendInboundRecord(for: .result) {
            appendInboundDataRecord(
                title: "收到识别文本",
                detail: "Session: \(payload.sessionId)\n语言: \(payload.language)\n内容: \(payload.text)",
                category: .voice
            )
        }

        if let currentSessionId, payload.sessionId != currentSessionId {
            print("Ignoring result with mismatched session ID")
            appendInboundDataRecord(
                title: "忽略识别结果",
                detail: "收到的 Session 与当前活动会话不一致。\n当前: \(currentSessionId)\n收到: \(payload.sessionId)",
                category: .voice,
                severity: .warning
            )
            return
        }

        currentSessionId = nil
        sessionTimer?.invalidate()
        sessionTimer = nil

        DispatchQueue.main.async {
            self.noteText = payload.text
            self.appendVoiceRecognitionRecord(payload.text, source: .iosSync)
        }
    }

    private func handleTextMessage(_ envelope: MessageEnvelope) {
        print("🔔 handleTextMessage 被调用")
        guard let payload = try? JSONDecoder().decode(TextMessagePayload.self, from: envelope.payload) else {
            print("❌ 无法解码 TextMessagePayload")
            return
        }

        if VoiceInboundLogPolicy.shouldAppendInboundRecord(for: .textMessage) {
            appendInboundDataRecord(
                title: "收到文本消息",
                detail: "Session: \(payload.sessionId)\n语言: \(payload.language)\n内容: \(payload.text)",
                category: .voice
            )
        }

        DispatchQueue.main.async {
            self.noteText = payload.text
            self.appendVoiceRecognitionRecord(payload.text, source: .iosSync)
        }
    }

    private func handlePingMessage(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(PingPayload.self, from: envelope.payload) else {
            return
        }

        // Send pong
        let pongPayload = PongPayload(nonce: payload.nonce)
        guard let payloadData = try? JSONEncoder().encode(pongPayload) else { return }

        let timestamp = Date()
        let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
            type: .pong,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId
        )

        let pongEnvelope = MessageEnvelope(
            type: .pong,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId,
            hmac: hmac
        )

        connectionManager.send(pongEnvelope)
    }

    private func recordConnectionStateChange(_ state: ConnectionState) {
        switch state {
        case .disconnected:
            appendInboundDataRecord(
                title: "连接已断开",
                detail: "当前没有活跃的 iPhone 连接。",
                category: .connection,
                severity: .warning
            )
        case .connecting:
            appendInboundDataRecord(
                title: "正在建立连接",
                detail: "Mac 正在等待与 iPhone 建立连接。",
                category: .connection,
                severity: .info
            )
        case .connected:
            appendInboundDataRecord(
                title: "连接已建立",
                detail: "iPhone 与 Mac 已建立可用连接。",
                category: .connection,
                severity: .info
            )
        case .error(let error):
            appendInboundDataRecord(
                title: "连接错误",
                detail: error.localizedDescription,
                category: .connection,
                severity: .error
            )
        }
    }
}
