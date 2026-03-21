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
    @Published var pairingProgressMessage: String?
    @Published var inboundDataRecords: [InboundDataRecord]
    @Published var accessibilityStatus: PermissionStatus
    @Published var inputMonitoringStatus: PermissionStatus
    @Published var isServiceRunning = false

    var currentSessionId: String?
    var sessionTimer: Timer?
    var pendingInjectionTargetAppPID: pid_t?

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
        self.pairingProgressMessage = connectionManager.pairingProgressMessage
        self.inboundDataRecords = []
        self.accessibilityStatus = PermissionsManager.checkAccessibility()
        self.inputMonitoringStatus = PermissionsManager.checkInputMonitoring()
        super.init()

        // Initialize text injector based on settings
        updateTextInjector()

        // Observe settings changes
        settings.$textInjectionMethod.sink { [weak self] _ in
            self?.updateTextInjector()
        }.store(in: &cancellables)

        settings.$serverPort
            .dropFirst()
            .sink { [weak self] newPort in
                self?.handleServerPortChange(newPort)
            }
            .store(in: &cancellables)

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
        case .accessibility:
            textInjector = AccessibilityTextInjector()
        }
        print("📝 文本注入方式已切换到: \(settings.textInjectionMethod.displayName)")
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: String(localized: "app_title"))
            updateStatusIcon()
        }

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        let statusItem = NSMenuItem(title: String(localized: "menu_status_unpaired"), action: nil, keyEquivalent: "")
        statusItem.tag = 100 // For updating later
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: String(localized: "menu_show_status"), action: #selector(showStatus), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: String(localized: "menu_start_pairing"), action: #selector(startPairing), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: String(localized: "menu_permissions"), action: #selector(openPermissions), keyEquivalent: ""))

        let unpairItem = NSMenuItem(title: String(localized: "menu_unpair"), action: #selector(unpairDevice), keyEquivalent: "")
        unpairItem.tag = 101 // For showing/hiding
        menu.addItem(unpairItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: String(localized: "menu_quit"), action: #selector(quit), keyEquivalent: "q"))

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

        app.activate(options: [.activateIgnoringOtherApps])
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
        if statusWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = String(localized: "window_title_main")
            window.setContentSize(NSSize(width: 500, height: 600))
            window.contentView = NSHostingView(rootView: MainWindow(controller: self))
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
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
            window.title = String(localized: "window_title_onboarding")
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
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
            window.title = String(localized: "window_title_hotkey")
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            window.delegate = self
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
            window.title = String(localized: "window_title_permissions")
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            window.delegate = self
            permissionsWindow = window
        }

        permissionsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func unpairDevice() {
        let alert = NSAlert()
        alert.messageText = String(localized: "unpair_alert_title")
        alert.informativeText = String(localized: "unpair_alert_message")
        alert.addButton(withTitle: String(localized: "unpair_alert_button"))
        alert.addButton(withTitle: String(localized: "cancel_button"))
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            connectionManager.unpair()
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    func showPairingWindow(code: String) {
        // Close existing pairing window if any
        if let existingWindow = pairingWindow {
            existingWindow.close()
            pairingWindow = nil
        }

        // Get local IP address
        guard let ipAddress = getLocalIPAddress() else {
            showError(String(localized: "error_local_ip"))
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
        window.title = String(localized: "window_title_qr_pairing")
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

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
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: String(localized: "status_access_unpaired"))
        case .pairing:
            button.image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: String(localized: "status_access_pairing"))
        case .paired:
            button.image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: String(localized: "status_access_connected"))
        }
    }

    func updateMenu() {
        guard let menu = statusItem.menu else { return }

        // Update status text
        if let statusItem = menu.item(withTag: 100) {
            switch connectionManager.pairingState {
            case .unpaired:
                statusItem.title = String(localized: "menu_status_unpaired")
            case .pairing:
                statusItem.title = String(localized: "status_menu_pairing")
            case .paired(_, let deviceName):
                statusItem.title = String(format: String(localized: "status_menu_connected_format"), deviceName)
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
        alert.messageText = String(localized: "error_title")
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }

    func showTextCopyAlert(_ text: String, error: String) {
        let alert = NSAlert()
        alert.messageText = String(localized: "text_copy_alert_title")
        alert.informativeText = String(format: String(localized: "text_copy_alert_message_format"), error)
        alert.addButton(withTitle: String(localized: "copy_text_button"))
        alert.addButton(withTitle: String(localized: "cancel_button"))
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

        showError(String(localized: "hotkey_permission_error"))
    }

    func showTextInjectionPermissionError(with text: String) {
        let alert = NSAlert()
        alert.messageText = String(localized: "text_injection_permission_title")
        alert.informativeText = String(localized: "text_injection_permission_message")
        alert.addButton(withTitle: String(localized: "open_system_settings_button"))
        alert.addButton(withTitle: String(localized: "copy_text_button"))
        alert.addButton(withTitle: String(localized: "cancel_button"))
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

    private func handleServerPortChange(_ newPort: UInt16) {
        appendInboundDataRecord(
            title: String(localized: "log_server_port_updated_title"),
            detail: String(format: String(localized: "log_server_port_updated_detail_format"), "\(newPort)"),
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
        refreshPermissionState()
    }
}

// MARK: - NSWindowDelegate
extension MenuBarController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window === pairingWindow {
                pairingWindow = nil
            } else if window === permissionsWindow {
                permissionsWindow = nil
            } else if window === hotkeySettingsWindow {
                hotkeySettingsWindow = nil
            } else if window === statusWindow {
                statusWindow = nil
            } else if window === onboardingWindow {
                onboardingWindow = nil
            }
        }
    }
}
