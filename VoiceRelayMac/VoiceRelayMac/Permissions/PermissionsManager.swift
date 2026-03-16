import Foundation
import Cocoa
import IOKit.hidsystem

enum PermissionType {
    case accessibility
    case inputMonitoring
}

enum PermissionStatus {
    case granted
    case denied
    case notDetermined
}

class PermissionsManager {
    static func checkAccessibility() -> PermissionStatus {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options)
        return trusted ? .granted : .denied
    }

    static func checkInputMonitoring() -> PermissionStatus {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            return .granted
        case kIOHIDAccessTypeDenied:
            return .denied
        case kIOHIDAccessTypeUnknown:
            return .notDetermined
        default:
            return .notDetermined
        }
    }

    static func requestAccessibility() {
        // First check current status
        let currentStatus = checkAccessibility()

        if currentStatus == .granted {
            print("✅ 辅助功能权限已授予")
            return
        }

        print("🔐 请求辅助功能权限...")

        // Request with prompt
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            // Show alert to guide user
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let alert = NSAlert()
                alert.messageText = "需要辅助功能权限"
                alert.informativeText = """
                VoiceMind 需要辅助功能权限来：
                • 监听全局快捷键（Option+Space）
                • 将语音识别结果注入到当前应用

                请在打开的系统设置中：
                1. 找到"辅助功能"
                2. 找到并勾选"VoiceRelayMac"
                3. 如果看不到应用，请点击"+"手动添加
                """
                alert.addButton(withTitle: "打开系统设置")
                alert.addButton(withTitle: "稍后设置")
                alert.alertStyle = .informational

                if alert.runModal() == .alertFirstButtonReturn {
                    openSystemPreferences(for: .accessibility)
                }
            }
        }
    }

    static func requestInputMonitoring() {
        // First check current status
        let currentStatus = checkInputMonitoring()

        if currentStatus == .granted {
            print("✅ 输入监控权限已授予")
            return
        }

        print("🔐 请求输入监控权限...")

        // Request access
        let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)

        if !granted {
            // Show alert to guide user
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let alert = NSAlert()
                alert.messageText = "需要输入监控权限"
                alert.informativeText = """
                VoiceMind 需要输入监控权限来检测快捷键按下事件。

                请在打开的系统设置中：
                1. 找到"输入监控"
                2. 找到并勾选"VoiceRelayMac"
                3. 如果看不到应用，请点击"+"手动添加

                注意：授予权限后需要重启应用才能生效。
                """
                alert.addButton(withTitle: "打开系统设置")
                alert.addButton(withTitle: "稍后设置")
                alert.alertStyle = .informational

                if alert.runModal() == .alertFirstButtonReturn {
                    openSystemPreferences(for: .inputMonitoring)
                }
            }
        }
    }

    static func openSystemPreferences(for permission: PermissionType) {
        switch permission {
        case .accessibility:
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        case .inputMonitoring:
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
            NSWorkspace.shared.open(url)
        }
    }

    static func showPermissionAlert(for permission: PermissionType) {
        let alert = NSAlert()
        alert.messageText = "Permission Required"

        switch permission {
        case .accessibility:
            alert.informativeText = "VoiceRelay needs Accessibility permission to monitor hotkeys and inject text. Please grant permission in System Settings."
        case .inputMonitoring:
            alert.informativeText = "VoiceRelay needs Input Monitoring permission to detect global keyboard events. macOS requires enabling this manually in System Settings."
        }

        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            openSystemPreferences(for: permission)
        }
    }
}
