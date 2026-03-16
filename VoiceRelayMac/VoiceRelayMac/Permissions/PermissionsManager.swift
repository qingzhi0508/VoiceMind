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
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func requestInputMonitoring() {
        let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        if granted == false {
            openSystemPreferences(for: .inputMonitoring)
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
