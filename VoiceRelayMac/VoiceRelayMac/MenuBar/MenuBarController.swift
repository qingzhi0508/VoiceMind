import Cocoa
import Combine
import SwiftUI
import SharedCore

class MenuBarController: NSObject, ObservableObject {
    var statusItem: NSStatusItem!
    let connectionManager = ConnectionManager()
    let hotkeyMonitor: HotkeyMonitor
    var textInjector: TextInjectionProtocol!
    let settings = AppSettings.shared

    @Published var pairingState: PairingState
    @Published var connectionState: ConnectionState
    @Published var accessibilityStatus: PermissionStatus
    @Published var inputMonitoringStatus: PermissionStatus
    @Published var isServiceRunning = false

    var currentSessionId: String?
    var sessionTimer: Timer?

    var pairingWindow: NSWindow?
    var permissionsWindow: NSWindow?
    var hotkeySettingsWindow: NSWindow?
    var statusWindow: NSWindow?
    var onboardingWindow: NSWindow?

    private var cancellables = Set<AnyCancellable>()

    override init() {
        self.hotkeyMonitor = HotkeyMonitor()
        self.pairingState = connectionManager.pairingState
        self.connectionState = connectionManager.connectionState
        self.accessibilityStatus = PermissionsManager.checkAccessibility()
        self.inputMonitoringStatus = PermissionsManager.checkInputMonitoring()
        super.init()

        // Initialize text injector based on settings
        updateTextInjector()

        // Observe settings changes
        settings.$textInjectionMethod.sink { [weak self] _ in
            self?.updateTextInjector()
        }.store(in: &cancellables)

        setupStatusItem()
        setupConnectionManager()
        // Don't start services automatically
        // User will start them manually from the UI
    }

    private func updateTextInjector() {
        switch settings.textInjectionMethod {
        case .clipboard:
            textInjector = ClipboardTextInjector()
        case .cgEvent:
            textInjector = CGEventTextInjector()
        }
        print("📝 文本注入方式已切换到: \(settings.textInjectionMethod.displayName)")
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "VoiceRelay")
            updateStatusIcon()
        }

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        let statusItem = NSMenuItem(title: "未配对", action: nil, keyEquivalent: "")
        statusItem.tag = 100 // For updating later
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "显示状态...", action: #selector(showStatus), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "开始配对...", action: #selector(startPairing), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "热键设置...", action: #selector(openHotkeySettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "权限设置...", action: #selector(openPermissions), keyEquivalent: ""))

        let unpairItem = NSMenuItem(title: "解除配对", action: #selector(unpairDevice), keyEquivalent: "")
        unpairItem.tag = 101 // For showing/hiding
        menu.addItem(unpairItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))

        self.statusItem.menu = menu
        updateMenu()
    }

    func setupConnectionManager() {
        connectionManager.delegate = self
    }

    func setupHotkeyMonitor() {
        hotkeyMonitor.delegate = self

        if hotkeyMonitor.start() == false {
            showHotkeyPermissionError()
        }
    }

    func startServices() {
        guard !isServiceRunning else { return }

        do {
            try connectionManager.start()
            isServiceRunning = true
            print("✅ 服务已启动")
        } catch {
            print("❌ 启动服务失败: \(error)")
            showError("启动服务失败: \(error.localizedDescription)")
        }
    }

    func startNetworkServices() {
        setupHotkeyMonitor()
        startServices()
    }

    func stopNetworkServices() {
        guard isServiceRunning else { return }

        connectionManager.stop()
        hotkeyMonitor.stop()
        isServiceRunning = false
        print("🛑 服务已停止")
    }

    @objc private func startPairing() {
        let code = connectionManager.startPairing()
        showPairingWindow(code: code)
    }

    @objc private func showStatus() {
        if statusWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "VoiceMind"
            window.setContentSize(NSSize(width: 500, height: 600))
            window.contentView = NSHostingView(rootView: MainWindow(controller: self))
            window.center()
            window.isReleasedWhenClosed = false
            statusWindow = window
        }

        statusWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showMainWindow() {
        showStatus()
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            let contentView = OnboardingFlowView(controller: self)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "欢迎使用 VoiceMind"
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            window.isReleasedWhenClosed = false
            onboardingWindow = window
        }

        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showHotkeySettings() {
        openHotkeySettings()
    }

    func requestAccessibilityPermissionFromUI() {
        PermissionsManager.requestAccessibility()
        refreshPermissionState()
    }

    func requestInputMonitoringPermissionFromUI() {
        PermissionsManager.requestInputMonitoring()
        refreshPermissionState()
    }

    func refreshPermissionState() {
        accessibilityStatus = PermissionsManager.checkAccessibility()
        inputMonitoringStatus = PermissionsManager.checkInputMonitoring()

        if accessibilityStatus == .granted, inputMonitoringStatus == .granted {
            _ = hotkeyMonitor.start()
        }
    }

    func showPairingWindowFromUI() {
        startPairing()
    }

    func openHotkeySettingsFromUI() {
        openHotkeySettings()
    }

    func openPermissionsFromUI() {
        openPermissions()
    }

    func unpairDeviceFromUI() {
        unpairDevice()
    }

    @objc private func openHotkeySettings() {
        if hotkeySettingsWindow == nil {
            let contentView = HotkeySettingsWindow(
                onSave: { [weak self] config in
                    self?.hotkeyMonitor.updateConfiguration(config)
                    self?.hotkeySettingsWindow?.close()
                }
            )

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "热键设置"
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            hotkeySettingsWindow = window
        }

        hotkeySettingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openPermissions() {
        if permissionsWindow == nil {
            let contentView = PermissionsWindow()

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "权限设置"
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            permissionsWindow = window
        }

        permissionsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func unpairDevice() {
        let alert = NSAlert()
        alert.messageText = "解除配对？"
        alert.informativeText = "这将移除与 iPhone 的配对。你需要重新配对才能使用 VoiceRelay。"
        alert.addButton(withTitle: "解除配对")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            connectionManager.unpair()
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    func showPairingWindow(code: String) {
        // Get local IP address
        guard let ipAddress = getLocalIPAddress() else {
            showError("无法获取本地 IP 地址")
            return
        }

        // Create connection info
        let connectionInfo = ConnectionInfo(
            ip: ipAddress,
            port: connectionManager.server.port,
            deviceId: connectionManager.deviceId,
            deviceName: Host.current().localizedName ?? "Mac"
        )

        let contentView = QRCodePairingView(
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
        window.title = "扫码配对"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()

        pairingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family

                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        return address
    }

    func updateStatusIcon() {
        guard let button = statusItem.button else { return }

        switch connectionManager.pairingState {
        case .unpaired:
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "未配对")
        case .pairing:
            button.image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "配对中")
        case .paired:
            button.image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "已连接")
        }
    }

    func updateMenu() {
        guard let menu = statusItem.menu else { return }

        // Update status text
        if let statusItem = menu.item(withTag: 100) {
            switch connectionManager.pairingState {
            case .unpaired:
                statusItem.title = "未配对"
            case .pairing:
                statusItem.title = "配对中..."
            case .paired(_, let deviceName):
                statusItem.title = "已连接到 \(deviceName)"
            }
        }

        // Show/hide unpair button
        if let unpairItem = menu.item(withTag: 101) {
            unpairItem.isHidden = {
                if case .paired = connectionManager.pairingState {
                    return false
                }
                return true
            }()
        }
    }

    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "错误"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }

    func showTextCopyAlert(_ text: String, error: String) {
        let alert = NSAlert()
        alert.messageText = "文本注入失败"
        alert.informativeText = "无法注入文本: \(error)\n\n你可以手动复制文本。"
        alert.addButton(withTitle: "复制文本")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    func showHotkeyPermissionError() {
        if PermissionsManager.checkAccessibility() != .granted {
            PermissionsManager.showPermissionAlert(for: .accessibility)
            return
        }

        if PermissionsManager.checkInputMonitoring() != .granted {
            PermissionsManager.showPermissionAlert(for: .inputMonitoring)
            return
        }

        showError("无法启动热键监听。请检查系统权限设置后重试。")
    }

    func showTextInjectionPermissionError(with text: String) {
        let alert = NSAlert()
        alert.messageText = "缺少辅助功能权限"
        alert.informativeText = "VoiceRelay 需要“辅助功能”权限才能把识别结果输入到当前应用。\n\n你也可以先复制文本再手动粘贴。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "复制文本")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            PermissionsManager.openSystemPreferences(for: .accessibility)
        case .alertSecondButtonReturn:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        default:
            break
        }
    }

    func refreshPublishedState() {
        pairingState = connectionManager.pairingState
        connectionState = connectionManager.connectionState
        refreshPermissionState()
    }
}
