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
        case .keyword:
            return false
        default:
            return false
        }
    }
}

enum KeywordActionRoutingPolicy {
    static func route(_ action: KeywordAction) -> KeywordActionResult {
        switch action {
        case .confirm:
            return .simulateReturn
        case .undo:
            return .simulateUndo
        }
    }
}

enum KeywordActionResult: Equatable {
    case simulateReturn
    case simulateUndo
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
        case .keyword:
            handleKeywordMessage(envelope)
        case .ping:
            handlePingMessage(envelope)
        default:
            break
        }
    }

    private func handleResultMessage(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(ResultPayload.self, from: envelope.payload) else {
            print("❌ 无法解码 ResultPayload")
            return
        }

        // 话筒模式的结果不注入文字
        if connectionManager.isPlayThroughSession(payload.sessionId) {
            print("🎙️ 话筒模式：跳过文字注入")
            return
        }

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
            self.textInjectionService.injectRecognizedText(payload.text)
        }
    }

    private func handleTextMessage(_ envelope: MessageEnvelope) {
        print("🔔 handleTextMessage 被调用, payload size: \(envelope.payload.count) bytes")
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
            self.textInjectionService.injectRecognizedText(payload.text)
            self.noteText = payload.text
            self.appendVoiceRecognitionRecord(payload.text, source: .iosSync)
        }
    }

    private func handleKeywordMessage(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(KeywordPayload.self, from: envelope.payload) else {
            print("❌ 无法解码 KeywordPayload")
            return
        }

        print("🔑 收到指令: \(payload.action.rawValue)")
        switch KeywordActionRoutingPolicy.route(payload.action) {
        case .simulateReturn:
            simulateReturnKey()
        case .simulateUndo:
            simulateUndoKey()
        }
    }

    private func simulateReturnKey() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        print("✅ 已模拟回车键")
    }

    private func simulateUndoKey() {
        // Cmd+Z: undo the last text injection
        let source = CGEventSource(stateID: .hidSystemState)
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let zDown = CGEvent(keyboardEventSource: source, virtualKey: 0x06, keyDown: true)
        let zUp = CGEvent(keyboardEventSource: source, virtualKey: 0x06, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        zDown?.flags = .maskCommand
        zUp?.flags = .maskCommand

        cmdDown?.post(tap: .cghidEventTap)
        zDown?.post(tap: .cghidEventTap)
        zUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
        print("✅ 已撤销（Cmd+Z）")
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
                detail: "当前没有活跃的手机连接。",
                category: .connection,
                severity: .warning
            )
        case .connecting:
            appendInboundDataRecord(
                title: "正在建立连接",
                detail: "电脑正在等待与手机建立连接。",
                category: .connection,
                severity: .info
            )
        case .connected:
            appendInboundDataRecord(
                title: "连接已建立",
                detail: "手机与电脑已建立可用连接。",
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
