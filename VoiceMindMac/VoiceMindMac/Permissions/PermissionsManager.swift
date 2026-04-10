import AppKit
import ApplicationServices
import Foundation

enum PermissionType: Equatable {
    case accessibility
}

enum PermissionStatus: Equatable {
    case granted
    case denied
}

enum PermissionsManager {
    static func checkAccessibility() -> PermissionStatus {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options)
        return trusted ? .granted : .denied
    }

    static func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemPreferences(for permission: PermissionType) {
        switch permission {
        case .accessibility:
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
                return
            }
            NSWorkspace.shared.open(url)
        }
    }

    static var appExecutablePath: String {
        Bundle.main.executableURL?.path ?? Bundle.main.bundlePath
    }

    static var appBundlePath: String {
        Bundle.main.bundlePath
    }
}
