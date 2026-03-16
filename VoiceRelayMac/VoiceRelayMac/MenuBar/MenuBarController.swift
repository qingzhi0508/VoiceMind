import Cocoa
import SwiftUI
import SharedCore

class MenuBarController: NSObject {
    var statusItem: NSStatusItem!
    let connectionManager = ConnectionManager()
    let hotkeyMonitor: HotkeyMonitor
    let textInjector = TextInjector()

    var currentSessionId: String?
    var sessionTimer: Timer?

    var pairingWindow: NSWindow?
    var permissionsWindow: NSWindow?
    var hotkeySettingsWindow: NSWindow?

    override init() {
        self.hotkeyMonitor = HotkeyMonitor()
        super.init()

        setupStatusItem()
        setupConnectionManager()
        setupHotkeyMonitor()
        startServices()
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
        do {
            try connectionManager.start()
        } catch {
            print("Failed to start connection manager: \(error)")
            showError("启动服务失败: \(error.localizedDescription)")
        }
    }

    @objc private func startPairing() {
        let code = connectionManager.startPairing()
        showPairingWindow(code: code)
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
        let contentView = PairingWindow(
            code: code,
            onCancel: { [weak self] in
                self?.connectionManager.cancelPairing()
                self?.pairingWindow?.close()
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "与 iPhone 配对"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()

        pairingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
}
