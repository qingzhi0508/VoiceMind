import Foundation
import Cocoa

enum PermissionType: Equatable {
    case accessibility
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
                语灵 需要辅助功能权限来：
                • 识别当前聚焦的输入位置
                • 将语音识别结果输入到当前应用

                请在打开的系统设置中：
                1. 找到"辅助功能"
                2. 找到并勾选"VoiceMind"
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

    static func openSystemPreferences(for permission: PermissionType) {
        switch permission {
        case .accessibility:
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }

    static func showPermissionAlert(for permission: PermissionType) {
        let alert = NSAlert()
        alert.messageText = "Permission Required"

        switch permission {
        case .accessibility:
            alert.informativeText = "VoiceMind needs Accessibility permission to detect the focused input area and insert transcribed text into the current app. Please grant permission in System Settings."
        }

        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            openSystemPreferences(for: permission)
        }
    }
}
