import AppKit
import ApplicationServices
import Foundation
import Network

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

    /// Check if macOS firewall is enabled
    static var isFirewallEnabled: Bool {
        // Try to read firewall status from socket filter
        let task = Process()
        task.launchPath = "/usr/libexec/ApplicationFirewall/socketfilterfw"
        task.arguments = ["--getglobalstate"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.contains("enabled")
        } catch {
            return false
        }
    }

    /// Test if the local port accepts TCP connections (self-test)
    static func testLocalPort(port: UInt16) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var success = false

        let endpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: NWEndpoint.Port(integerLiteral: port))
        let connection = NWConnection(to: endpoint, using: .tcp)

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                success = true
                connection.cancel()
                semaphore.signal()
            case .failed, .cancelled:
                success = false
                connection.cancel()
                semaphore.signal()
            default:
                break
            }
        }

        connection.start(queue: .global())
        _ = semaphore.wait(timeout: .now() + 3)
        return success
    }
}
