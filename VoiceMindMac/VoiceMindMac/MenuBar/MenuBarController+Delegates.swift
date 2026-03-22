import Cocoa
import Foundation
import SharedCore

// MARK: - ConnectionManagerDelegate
extension MenuBarController: ConnectionManagerDelegate {
    private static let executeCommandKeyword = "执行"

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

        appendInboundDataRecord(
            title: "收到识别文本",
            detail: "Session: \(payload.sessionId)\n语言: \(payload.language)\n内容: \(payload.text)",
            category: .voice
        )

        // Validate session ID
        print("🔍 验证 session ID - 当前: \(currentSessionId?.description ?? "nil"), 收到: \(payload.sessionId)")
        if let currentSessionId {
            guard payload.sessionId == currentSessionId else {
                print("Ignoring result with mismatched session ID")
                appendInboundDataRecord(
                    title: "忽略识别结果",
                    detail: "收到的 Session 与当前热键会话不一致。\n当前: \(currentSessionId)\n收到: \(payload.sessionId)",
                    category: .voice,
                    severity: .warning
                )
                return
            }
            print("✅ Session ID 匹配")
        } else {
            print("Accepting proactive speech result without active hotkey session")
            appendInboundDataRecord(
                title: "收到同步文本",
                detail: "当前没有热键会话，按同步文本消息处理，可直接粘贴到当前光标位置。\nSession: \(payload.sessionId)",
                category: .voice
            )
        }

        // Clear session
        currentSessionId = nil
        sessionTimer?.invalidate()
        sessionTimer = nil

        restoreInjectionTargetApplicationIfNeeded { [weak self] in
            guard let self else { return }

            print("🔍 检查是否需要执行回车命令")
            if self.shouldTriggerEnterCommand(for: payload.text) {
                print("✅ 检测到执行命令，触发回车")
                do {
                    try self.triggerReturnKey()
                    self.appendInboundDataRecord(
                        title: "执行回车命令",
                        detail: "识别到命令词\"\(Self.executeCommandKeyword)\"，已触发一次 Enter。",
                        category: .voice
                    )
                } catch TextInjectionError.accessibilityPermissionDenied {
                    self.appendInboundDataRecord(
                        title: "执行回车失败",
                        detail: "缺少辅助功能权限，无法发送 Enter 键事件。",
                        category: .connection,
                        severity: .warning
                    )
                    self.showTextInjectionPermissionError(with: payload.text)
                } catch {
                    self.appendInboundDataRecord(
                        title: "执行回车失败",
                        detail: "发送 Enter 键事件失败：\(error.localizedDescription)",
                        category: .connection,
                        severity: .warning
                    )
                }
                return
            }

            print("💉 开始注入文本: \(payload.text)")
            do {
                try self.textInjector.inject(payload.text)
                print("✅ 文本注入成功")
            } catch TextInjectionError.noFocusedInputTarget {
                let focusedElementSummary = FocusedInputDetector.currentFocusedElementSummary()
                self.appendInboundDataRecord(
                    title: "未找到可输入控件",
                    detail: "当前没有检测到可写输入框，本次识别结果未自动输入。\n内容: \(payload.text)\n\n\(focusedElementSummary)",
                    category: .connection,
                    severity: .warning
                )
            } catch TextInjectionError.accessibilityPermissionDenied {
                self.appendInboundDataRecord(
                    title: "文本注入权限不足",
                    detail: "缺少辅助功能权限，无法直接注入文本。\n已提示用户授权或复制文本。\n内容: \(payload.text)",
                    category: .connection,
                    severity: .warning
                )
                self.showTextInjectionPermissionError(with: payload.text)
            } catch {
                let focusedElementSummary = FocusedInputDetector.currentFocusedElementSummary()
                self.appendInboundDataRecord(
                    title: "文本注入失败，已降级为复制",
                    detail: "注入错误: \(error.localizedDescription)\n内容: \(payload.text)\n\n\(focusedElementSummary)",
                    category: .connection,
                    severity: .warning
                )
                self.showTextCopyAlert(payload.text, error: error.localizedDescription)
            }

            // 更新笔记显示最新识别结果
            self.noteText = payload.text
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

    private func shouldTriggerEnterCommand(for text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return normalized == Self.executeCommandKeyword
    }

    private func triggerReturnKey() throws {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        guard AXIsProcessTrustedWithOptions(options) else {
            throw TextInjectionError.accessibilityPermissionDenied
        }

        let keyCode = CGKeyCode(36)

        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw TextInjectionError.injectionFailed("Failed to create Return key event")
        }

        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
    }
}

// MARK: - HotkeyMonitorDelegate
extension MenuBarController: HotkeyMonitorDelegate {
    func hotkeyMonitor(_ monitor: HotkeyMonitor, didPressHotkey sessionId: String) {
        guard case .paired = connectionManager.pairingState else {
            return
        }

        captureInjectionTargetApplication()
        currentSessionId = sessionId

        // Start 30-second timeout
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            self?.handleSessionTimeout()
        }

        // Send startListen message
        let payload = StartListenPayload(sessionId: sessionId)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let timestamp = Date()
        let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
            type: .startListen,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId
        )

        let envelope = MessageEnvelope(
            type: .startListen,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId,
            hmac: hmac
        )

        connectionManager.send(envelope)
    }

    func hotkeyMonitor(_ monitor: HotkeyMonitor, didReleaseHotkey sessionId: String) {
        guard sessionId == currentSessionId else { return }

        // Send stopListen message
        let payload = StopListenPayload(sessionId: sessionId)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let timestamp = Date()
        let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
            type: .stopListen,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId
        )

        let envelope = MessageEnvelope(
            type: .stopListen,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId,
            hmac: hmac
        )

        connectionManager.send(envelope)
    }

    private func handleSessionTimeout() {
        appendInboundDataRecord(
            title: "语音会话超时",
            detail: "30 秒内未收到 iPhone 返回结果，已结束当前会话。",
            category: .voice,
            severity: .warning
        )
        currentSessionId = nil
        showError("30秒内未收到 iPhone 响应")
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
