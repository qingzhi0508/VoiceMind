import Cocoa
import Combine
import SwiftUI
import SharedCore

private enum AutoSpeechRecognitionLanguagePolicy {
    static let fallbackLanguage = "zh-CN"

    static func resolvedLanguage(
        for engine: SpeechRecognitionEngine?,
        selectedSherpaModelId: String?
    ) -> String {
        if engine?.identifier == "sherpa-onnx",
           let selectedSherpaModelId,
           let model = SherpaOnnxModelDefinition.catalog.first(where: { $0.id == selectedSherpaModelId }),
           let modelLanguage = model.languages.first {
            return modelLanguage
        }

        if let preferred = Locale.preferredLanguages.first, !preferred.isEmpty {
            return preferred
        }

        return fallbackLanguage
    }
}

class MenuBarController: NSObject, ObservableObject {
    private enum MainWindowSizingPolicy {
        static let defaultWidth: CGFloat = 850
        static let defaultHeight: CGFloat = 720
    }

    var statusItem: NSStatusItem!
    let connectionManager = ConnectionManager()
    let settings = AppSettings.shared
    private let textInjectionCoordinator: TextInjectionCoordinator

    private let speechRecognitionManager: SpeechRecognitionManager
    private let localAudioRecorder = LocalAudioStreamingRecorder()

    @Published var pairingState: PairingState
    @Published var connectionState: ConnectionState
    @Published var pairingProgressMessage: String?
    @Published var inboundDataRecords: [InboundDataRecord]
    @Published var voiceRecognitionRecords: [VoiceRecognitionRecord]
    @Published var isServiceRunning = false

    // 笔记相关状态
    @Published var noteText: String = ""
    @Published var isLocalRecording: Bool = false

    var currentSessionId: String?
    var sessionTimer: Timer?
    var pendingInjectionTargetAppPID: pid_t?

    var pairingWindow: NSWindow?
    var statusWindow: NSWindow?
    var onboardingWindow: NSWindow?
    var usageGuideWindow: NSWindow?

    private var cancellables = Set<AnyCancellable>()
    private let voiceRecognitionHistoryStore: VoiceRecognitionHistoryStore

    init(
        voiceRecognitionHistoryStore: VoiceRecognitionHistoryStore = VoiceRecognitionHistoryStore(),
        textInjector: TextInjecting = AccessibilityTextInjector(),
        speechRecognitionManager: SpeechRecognitionManager = .shared
    ) {
        self.pairingState = connectionManager.pairingState
        self.connectionState = connectionManager.connectionState
        self.pairingProgressMessage = connectionManager.pairingProgressMessage
        self.inboundDataRecords = []
        self.voiceRecognitionRecords = []
        self.voiceRecognitionHistoryStore = voiceRecognitionHistoryStore
        self.textInjectionCoordinator = TextInjectionCoordinator(injector: textInjector)
        self.speechRecognitionManager = speechRecognitionManager
        super.init()

        settings.$serverPort
            .dropFirst()
            .sink { [weak self] newPort in
                self?.handleServerPortChange(newPort)
            }
            .store(in: &cancellables)

        setupStatusItem()
        setupConnectionManager()
        reloadVoiceRecognitionHistory()
        // Don't start services automatically
        // User will start them manually from the UI
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            updateStatusIcon()
        }

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        let statusItem = NSMenuItem(title: AppLocalization.localizedString("menu_status_unpaired"), action: nil, keyEquivalent: "")
        statusItem.tag = 100 // For updating later
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        let returnItem = NSMenuItem(title: AppLocalization.localizedString("menu_return_main"), action: #selector(showStatus), keyEquivalent: "s")
        returnItem.target = self
        menu.addItem(returnItem)

        let quitItem = NSMenuItem(title: AppLocalization.localizedString("menu_quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
        updateMenu()
    }

    func setupConnectionManager() {
        connectionManager.delegate = self
    }

    func captureInjectionTargetApplication() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            pendingInjectionTargetAppPID = nil
            return
        }

        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            pendingInjectionTargetAppPID = nil
            return
        }

        pendingInjectionTargetAppPID = app.processIdentifier
    }

    func restoreInjectionTargetApplicationIfNeeded(completion: @escaping () -> Void) {
        guard let pid = pendingInjectionTargetAppPID,
              let app = NSRunningApplication(processIdentifier: pid) else {
            pendingInjectionTargetAppPID = nil
            completion()
            return
        }

        let isAlreadyFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
        pendingInjectionTargetAppPID = nil

        guard !isAlreadyFrontmost else {
            completion()
            return
        }

        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: [.activateIgnoringOtherApps])
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            completion()
        }
    }

    func startServices() {
        guard !isServiceRunning else { return }

        do {
            try connectionManager.start(port: settings.serverPort)
            isServiceRunning = true
            print("✅ 服务已启动，端口: \(settings.serverPort)")
        } catch {
            print("❌ 启动服务失败: \(error)")
            showError("启动服务失败: \(error.localizedDescription)")
        }
    }

    func startNetworkServices() {
        startServices()
    }

    func stopNetworkServices() {
        guard isServiceRunning else { return }

        connectionManager.stop()
        isServiceRunning = false
        print("🛑 服务已停止")
    }

    @objc private func startPairing() {
        let code = connectionManager.startPairing()
        showPairingWindow(code: code)
    }

    @objc private func showStatus() {
        captureInjectionTargetApplication()

        if let existingWindow = existingMainAppWindow() {
            if existingWindow.isMiniaturized {
                existingWindow.deminiaturize(nil)
            }
            existingWindow.delegate = self
            applyPreferredMainWindowSizeAndPosition(to: existingWindow)
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        if statusWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: MainWindowSizingPolicy.defaultWidth,
                    height: MainWindowSizingPolicy.defaultHeight
                ),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = AppLocalization.localizedString("window_title_main")
            window.setContentSize(
                NSSize(
                    width: MainWindowSizingPolicy.defaultWidth,
                    height: MainWindowSizingPolicy.defaultHeight
                )
            )
            window.contentView = NSHostingView(rootView: MainWindow(controller: self))
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            statusWindow = window
        }

        statusWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func existingMainAppWindow() -> NSWindow? {
        let transientWindows = [pairingWindow, onboardingWindow, usageGuideWindow, statusWindow]
        let excluded = Set(transientWindows.compactMap { window in
            window.map(ObjectIdentifier.init)
        })

        return NSApp.windows.first { window in
            let className = NSStringFromClass(type(of: window))

            return !excluded.contains(ObjectIdentifier(window))
                && window.canBecomeKey
                && window.level == .normal
                && className != "NSStatusBarWindow"
        }
    }

    func normalizeMainWindowFrameIfNeeded() {
        guard let window = existingMainAppWindow() else { return }
        window.delegate = self
        applyPreferredMainWindowSizeAndPosition(to: window)
    }

    private func applyPreferredMainWindowSizeAndPosition(to window: NSWindow) {
        let preferredContentRect = NSRect(
            x: 0,
            y: 0,
            width: MainWindowSizingPolicy.defaultWidth,
            height: MainWindowSizingPolicy.defaultHeight
        )
        var preferredFrame = window.frameRect(forContentRect: preferredContentRect)

        if let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            preferredFrame.origin.x = visibleFrame.midX - (preferredFrame.width / 2)
            preferredFrame.origin.y = visibleFrame.midY - (preferredFrame.height / 2)
        }

        window.setFrame(preferredFrame, display: true)
    }

    func showMainWindow() {
        showStatus()
    }

    func showOnboarding() {
        captureInjectionTargetApplication()

        if onboardingWindow == nil {
            let contentView = OnboardingFlowView(controller: self)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = AppLocalization.localizedString("window_title_onboarding")
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            onboardingWindow = window
        }

        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showUsageGuide() {
        captureInjectionTargetApplication()

        if usageGuideWindow == nil {
            let contentView = UsageGuideView(
                onStartPairing: { [weak self] in
                    self?.showStatus()
                    self?.startPairing()
                },
                onClose: { [weak self] in
                    self?.usageGuideWindow?.close()
                }
            )

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 416, height: 448),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = AppLocalization.localizedString("window_title_usage_guide")
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            usageGuideWindow = window
        }

        usageGuideWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showPairingWindowFromUI() {
        startPairing()
    }

    func unpairDeviceFromUI() {
        unpairDevice()
    }

    @objc private func unpairDevice() {
        let alert = NSAlert()
        alert.messageText = AppLocalization.localizedString("unpair_alert_title")
        alert.informativeText = AppLocalization.localizedString("unpair_alert_message")
        alert.addButton(withTitle: AppLocalization.localizedString("unpair_alert_button"))
        alert.addButton(withTitle: AppLocalization.localizedString("cancel_button"))
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            connectionManager.unpair()
        }
    }

    @objc private func quit() {
        prepareForQuit()
        NSApplication.shared.terminate(nil)
    }

    func prepareForQuit() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        pendingInjectionTargetAppPID = nil

        stopNetworkServices()

        [pairingWindow, statusWindow, onboardingWindow, usageGuideWindow]
            .forEach { $0?.close() }

        pairingWindow = nil
        statusWindow = nil
        onboardingWindow = nil
        usageGuideWindow = nil

        statusItem?.menu = nil
    }

    func showPairingWindow(code: String) {
        captureInjectionTargetApplication()

        // Close existing pairing window if any
        if let existingWindow = pairingWindow {
            existingWindow.close()
            pairingWindow = nil
        }

        // Get local IP address
        guard let ipAddress = getLocalIPAddress() else {
            showError(AppLocalization.localizedString("error_local_ip"))
            return
        }

        // Create connection info with pairing code for QR code
        let connectionInfo = ConnectionInfo(
            ip: ipAddress,
            port: connectionManager.server.port,
            deviceId: connectionManager.deviceId,
            deviceName: Host.current().localizedName ?? "Mac",
            pairingCode: code
        )

        let contentView = QRCodePairingView(
            controller: self,
            connectionInfo: connectionInfo,
            pairingCode: code,
            onCancel: { [weak self] in
                self?.connectionManager.cancelPairing()
                self?.pairingWindow?.close()
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 550),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = AppLocalization.localizedString("window_title_qr_pairing")
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        pairingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func getLocalIPAddress() -> String? {
        LocalNetworkAccessPolicy.preferredLocalIPv4()
    }

    func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        let presentation = MenuBarStatusPresentation(
            pairingState: connectionManager.pairingState,
            connectionState: connectionManager.connectionState
        )
        button.image = NSImage(
            systemSymbolName: presentation.iconName,
            accessibilityDescription: presentation.accessibilityDescription
        )
        button.title = presentation.buttonTitle
    }

    func updateMenu() {
        guard let menu = statusItem.menu else { return }
        let presentation = MenuBarStatusPresentation(
            pairingState: connectionManager.pairingState,
            connectionState: connectionManager.connectionState
        )

        // Update status text
        if let statusItem = menu.item(withTag: 100) {
            statusItem.title = presentation.menuStatusTitle
        }
    }

    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = AppLocalization.localizedString("error_title")
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }

    func handleAutoInjectedText(_ text: String, missingTargetTitle: String) {
        handleAutoInjectedText(text, missingTargetTitle: missingTargetTitle, remainingRetries: 4)
    }

    private func handleAutoInjectedText(
        _ text: String,
        missingTargetTitle: String,
        remainingRetries: Int
    ) {
        switch textInjectionCoordinator.deliver(text: text) {
        case .injected:
            appendInboundDataRecord(
                title: AppLocalization.localizedString("text_injection_success_title"),
                detail: String(
                    format: AppLocalization.localizedString("text_injection_success_message_format"),
                    text
                ),
                category: .voice
            )
        case .permissionRequired:
            appendInboundDataRecord(
                title: AppLocalization.localizedString("text_injection_permission_title"),
                detail: AppLocalization.localizedString("text_injection_permission_message"),
                category: .connection,
                severity: .warning
            )
            showTextInjectionPermissionError(with: text)
        case .fallbackToCopy(let reason):
            if reason == "No focused input target", remainingRetries > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                    self?.handleAutoInjectedText(
                        text,
                        missingTargetTitle: missingTargetTitle,
                        remainingRetries: remainingRetries - 1
                    )
                }
                return
            }

            let titleKey = reason == "No focused input target"
                ? missingTargetTitle
                : AppLocalization.localizedString("text_copy_alert_title")
            let detail = reason == "No focused input target"
                ? textInjectionFailureDetail(for: reason)
                : String(
                    format: AppLocalization.localizedString("text_copy_alert_message_format"),
                    reason
                )
            appendInboundDataRecord(
                title: titleKey,
                detail: detail,
                category: .connection,
                severity: .warning
            )
            showTextCopyAlert(text, error: reason)
        }
    }

    private func textInjectionFailureDetail(for reason: String) -> String {
        let baseDetail = String(
            format: AppLocalization.localizedString("text_copy_alert_message_format"),
            reason
        )
        let focusedElementSummary = FocusedInputDetector.currentFocusedElementSummary()

        return """
        \(baseDetail)

        Debug Context
        \(focusedElementSummary)
        """
    }

    func showTextCopyAlert(_ text: String, error: String) {
        let alert = NSAlert()
        alert.messageText = AppLocalization.localizedString("text_copy_alert_title")
        alert.informativeText = String(
            format: AppLocalization.localizedString("text_copy_alert_message_format"),
            error
        )
        alert.addButton(withTitle: AppLocalization.localizedString("copy_text_button"))
        alert.addButton(withTitle: AppLocalization.localizedString("cancel_button"))
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            copyTextToPasteboard(text)
        }
    }

    func showTextInjectionPermissionError(with text: String) {
        let alert = NSAlert()
        alert.messageText = AppLocalization.localizedString("text_injection_permission_title")
        alert.informativeText = AppLocalization.localizedString("text_injection_permission_message")
        alert.addButton(withTitle: AppLocalization.localizedString("open_system_settings_button"))
        alert.addButton(withTitle: AppLocalization.localizedString("copy_text_button"))
        alert.addButton(withTitle: AppLocalization.localizedString("cancel_button"))
        alert.alertStyle = .warning

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            PermissionsManager.requestAccessibility()
            PermissionsManager.openSystemPreferences(for: .accessibility)
        case .alertSecondButtonReturn:
            copyTextToPasteboard(text)
        default:
            break
        }
    }

    private func copyTextToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func appendInboundDataRecord(
        title: String,
        detail: String,
        category: InboundDataCategory,
        severity: InboundDataSeverity = .info
    ) {
        let record = InboundDataRecord(
            timestamp: Date(),
            title: title,
            detail: detail,
            category: category,
            severity: severity
        )
        inboundDataRecords.insert(record, at: 0)

        if inboundDataRecords.count > 200 {
            inboundDataRecords = Array(inboundDataRecords.prefix(200))
        }
    }

    func clearInboundDataRecords() {
        inboundDataRecords.removeAll()
    }

    func appendVoiceRecognitionRecord(_ text: String, source: VoiceRecognitionRecordSource) {
        do {
            try voiceRecognitionHistoryStore.append(text: text, source: source)
            reloadVoiceRecognitionHistory()
        } catch {
            print("❌ 保存语音记录失败: \(error.localizedDescription)")
        }
    }

    func reloadVoiceRecognitionHistory() {
        do {
            voiceRecognitionRecords = try voiceRecognitionHistoryStore.loadRecentRecords()
        } catch {
            voiceRecognitionRecords = []
            print("❌ 加载语音记录失败: \(error.localizedDescription)")
        }
    }

    func deleteVoiceRecognitionRecords(withIDs ids: Set<UUID>) {
        do {
            try voiceRecognitionHistoryStore.deleteRecords(withIDs: ids)
            reloadVoiceRecognitionHistory()
        } catch {
            print("❌ 删除语音记录失败: \(error.localizedDescription)")
        }
    }

    func clearVoiceRecognitionRecords() {
        do {
            try voiceRecognitionHistoryStore.clearRecentRecords()
            reloadVoiceRecognitionHistory()
        } catch {
            print("❌ 清空语音记录失败: \(error.localizedDescription)")
        }
    }

    private func handleServerPortChange(_ newPort: UInt16) {
        appendInboundDataRecord(
            title: AppLocalization.localizedString("log_server_port_updated_title"),
            detail: String(format: AppLocalization.localizedString("log_server_port_updated_detail_format"), "\(newPort)"),
            category: .connection,
            severity: .warning
        )

        guard isServiceRunning else { return }

        stopNetworkServices()
        startNetworkServices()
    }

    func refreshPublishedState() {
        pairingState = connectionManager.pairingState
        connectionState = connectionManager.connectionState
        pairingProgressMessage = connectionManager.pairingProgressMessage
    }
}

// MARK: - Local Speech Recognition

extension MenuBarController {
    /// 开始本地录音识别
    func startLocalRecording() {
        guard !isLocalRecording else { return }

        if localAudioRecorder.checkMicrophonePermission() {
            beginLocalRecording()
            return
        }

        localAudioRecorder.requestMicrophonePermission { [weak self] micGranted in
            guard let self = self else { return }

            guard micGranted else {
                print("❌ 本地录音需要麦克风权限")
                return
            }

            self.beginLocalRecording()
        }
    }

    /// 停止本地录音识别
    func stopLocalRecording() {
        guard isLocalRecording else { return }

        localAudioRecorder.stopStreaming()
        try? speechRecognitionManager.stopRecognition()
        connectionManager.setupSpeechRecognition()
        currentSessionId = nil
        isLocalRecording = false
        print("✅ 本地录音已停止")
    }

    /// 切换本地录音状态
    func toggleLocalRecording() {
        if isLocalRecording {
            stopLocalRecording()
        } else {
            startLocalRecording()
        }
    }

    /// 清除笔记
    func clearNote() {
        noteText = ""
    }

    private func beginLocalRecording() {
        do {
            let sessionId = UUID().uuidString
            let language = AutoSpeechRecognitionLanguagePolicy.resolvedLanguage(
                for: speechRecognitionManager.currentEngine,
                selectedSherpaModelId: SherpaOnnxModelManager.shared.selectedModelId
            )

            speechRecognitionManager.currentEngine?.delegate = self
            try speechRecognitionManager.startRecognition(sessionId: sessionId, language: language)
            speechRecognitionManager.currentEngine?.delegate = self

            try localAudioRecorder.startStreaming { [weak self] audioData in
                guard let self = self else { return }

                do {
                    try self.speechRecognitionManager.processAudioData(audioData)
                } catch {
                    print("❌ 本地音频投递失败: \(error.localizedDescription)")
                }
            }

            currentSessionId = sessionId
            isLocalRecording = true
            noteText = ""
            print("✅ 本地录音已开始 - 引擎: \(speechRecognitionManager.currentEngine?.displayName ?? "未知")")
        } catch {
            localAudioRecorder.stopStreaming()
            try? speechRecognitionManager.stopRecognition()
            connectionManager.setupSpeechRecognition()
            print("❌ 开始本地录音失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - SpeechRecognitionEngineDelegate

extension MenuBarController: SpeechRecognitionEngineDelegate {
    func engine(
        _ engine: SpeechRecognitionEngine,
        didRecognizeText text: String,
        sessionId: String,
        language: String
    ) {
        DispatchQueue.main.async {
            self.noteText = text
            self.appendVoiceRecognitionRecord(text, source: .localMac)
        }
    }

    func engine(
        _ engine: SpeechRecognitionEngine,
        didFailWithError error: Error,
        sessionId: String
    ) {
        DispatchQueue.main.async {
            self.isLocalRecording = false
            self.currentSessionId = nil
            self.localAudioRecorder.stopStreaming()
            self.connectionManager.setupSpeechRecognition()
            print("❌ 本地语音识别失败: \(error.localizedDescription)")
        }
    }

    func engine(
        _ engine: SpeechRecognitionEngine,
        didReceivePartialResult text: String,
        sessionId: String
    ) {
        DispatchQueue.main.async {
            self.noteText = text
        }
    }
}

// MARK: - NSWindowDelegate
extension MenuBarController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let transientWindows = [pairingWindow, onboardingWindow, usageGuideWindow, statusWindow]
        let isTransientWindow = transientWindows.contains { $0 === window }
        guard isTransientWindow else { return }
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let transientWindows = [pairingWindow, onboardingWindow, usageGuideWindow, statusWindow]
        let isTransientWindow = transientWindows.contains { $0 === window }
        guard !isTransientWindow else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.applyPreferredMainWindowSizeAndPosition(to: window)
        }
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window === pairingWindow {
                connectionManager.cancelPairing()
                pairingWindow = nil
            } else if window === statusWindow {
                statusWindow = nil
            } else if window === onboardingWindow {
                onboardingWindow = nil
            } else if window === usageGuideWindow {
                usageGuideWindow = nil
            }
        }
    }
}
