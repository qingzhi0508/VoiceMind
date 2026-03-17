import SwiftUI
import SharedCore
import Network

struct StatusWindow: View {
    @ObservedObject var controller: MenuBarController
    @State private var localIPAddress: String = "获取中..."

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with App Status
                HeaderSection(
                    pairingState: controller.pairingState,
                    connectionState: controller.connectionState
                )

                // System Information
                SystemInfoSection(
                    localIP: localIPAddress,
                    accessibilityStatus: controller.accessibilityStatus,
                    inputMonitoringStatus: controller.inputMonitoringStatus
                )

                // Device Connection Status
                DeviceConnectionSection(
                    pairingState: controller.pairingState,
                    connectionState: controller.connectionState
                )

                // Permissions Section
                PermissionsSection(
                    accessibilityStatus: controller.accessibilityStatus,
                    onRequestAccessibility: {
                        controller.requestAccessibilityPermissionFromUI()
                    }
                )

                // Quick Start Guide (only show when unpaired)
                if case .unpaired = controller.pairingState {
                    QuickStartSection(
                        onStartPairing: {
                            controller.showPairingWindowFromUI()
                        }
                    )
                }

                // Action Buttons
                ActionButtonsSection(
                    pairingState: controller.pairingState,
                    onStartPairing: {
                        controller.showPairingWindowFromUI()
                    },
                    onOpenPermissions: {
                        controller.openPermissionsFromUI()
                    },
                    onUnpair: {
                        controller.unpairDeviceFromUI()
                    }
                )
            }
            .padding()
        }
        .frame(width: 480, height: 560)
        .onAppear {
            fetchLocalIPAddress()
            // Refresh every 5 seconds
            Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                fetchLocalIPAddress()
                controller.refreshPublishedState()
            }
        }
    }

    private func fetchLocalIPAddress() {
        localIPAddress = getLocalIPAddress() ?? "未获取到"
    }

    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" { // WiFi or Ethernet
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        return address
    }
}

// MARK: - Header Section

struct HeaderSection: View {
    let pairingState: PairingState
    let connectionState: ConnectionState

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: statusIcon)
                .font(.system(size: 48))
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("VoiceMind")
                    .font(.title)
                    .fontWeight(.bold)

                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }

    private var statusIcon: String {
        switch (pairingState, connectionState) {
        case (.paired, .connected):
            return "checkmark.circle.fill"
        case (.paired, .connecting):
            return "arrow.triangle.2.circlepath"
        case (.paired, .disconnected):
            return "exclamationmark.triangle.fill"
        case (.pairing, _):
            return "arrow.triangle.2.circlepath"
        case (.unpaired, _):
            return "link.circle"
        default:
            return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch (pairingState, connectionState) {
        case (.paired, .connected):
            return .green
        case (.paired, .connecting):
            return .orange
        case (.paired, .disconnected):
            return .red
        case (.pairing, _):
            return .blue
        case (.unpaired, _):
            return .gray
        default:
            return .gray
        }
    }

    private var statusText: String {
        switch (pairingState, connectionState) {
        case (.paired, .connected):
            return "已连接 - 可以使用语音输入"
        case (.paired, .connecting):
            return "正在连接到 iPhone..."
        case (.paired, .disconnected):
            return "已配对但未连接"
        case (.pairing, _):
            return "正在配对..."
        case (.unpaired, _):
            return "未配对 - 请先与 iPhone 配对"
        default:
            return "未知状态"
        }
    }
}

// MARK: - System Info Section

struct SystemInfoSection: View {
    let localIP: String
    let accessibilityStatus: PermissionStatus
    let inputMonitoringStatus: PermissionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("系统信息")
                .font(.headline)

            VStack(spacing: 8) {
                InfoRow(
                    icon: "network",
                    title: "本机 IP 地址",
                    value: localIP,
                    color: .blue
                )

                InfoRow(
                    icon: "lock.shield",
                    title: "辅助功能权限",
                    value: accessibilityStatus.displayText,
                    color: accessibilityStatus.color
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Device Connection Section

struct DeviceConnectionSection: View {
    let pairingState: PairingState
    let connectionState: ConnectionState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设备连接")
                .font(.headline)

            VStack(spacing: 8) {
                InfoRow(
                    icon: "iphone",
                    title: "配对状态",
                    value: pairingStatusText,
                    color: pairingStatusColor
                )

                if case .paired(_, let deviceName) = pairingState {
                    InfoRow(
                        icon: "person.circle",
                        title: "设备名称",
                        value: deviceName,
                        color: .blue
                    )
                }

                InfoRow(
                    icon: "wifi",
                    title: "连接状态",
                    value: connectionStatusText,
                    color: connectionStatusColor
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var pairingStatusText: String {
        switch pairingState {
        case .unpaired:
            return "未配对"
        case .pairing:
            return "配对中..."
        case .paired:
            return "已配对"
        }
    }

    private var pairingStatusColor: Color {
        switch pairingState {
        case .unpaired:
            return .gray
        case .pairing:
            return .blue
        case .paired:
            return .green
        }
    }

    private var connectionStatusText: String {
        switch connectionState {
        case .disconnected:
            return "未连接"
        case .connecting:
            return "连接中..."
        case .connected:
            return "已连接"
        case .error(let error):
            return "错误: \(error.localizedDescription)"
        }
    }

    private var connectionStatusColor: Color {
        switch connectionState {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
}

// MARK: - Permissions Section

struct PermissionsSection: View {
    let accessibilityStatus: PermissionStatus
    let onRequestAccessibility: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("权限管理")
                .font(.headline)

            if accessibilityStatus != .granted {
                VStack(spacing: 8) {
                    PermissionRequestRow(
                        icon: "lock.shield",
                        title: "辅助功能权限",
                        description: "用于识别当前光标位置并将转写文字输入到目标应用",
                        status: accessibilityStatus,
                        onRequest: onRequestAccessibility
                    )
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("所有权限已授予")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.orange.opacity(accessibilityStatus != .granted ? 0.1 : 0.05))
        .cornerRadius(12)
    }
}

struct PermissionRequestRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let onRequest: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.orange)
                    Text(title)
                        .fontWeight(.medium)
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("授权") {
                onRequest()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Quick Start Section

struct QuickStartSection: View {
    let onStartPairing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速开始")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                GuideStep(number: 1, text: "在 iPhone 上打开 VoiceMind 应用")
                GuideStep(number: 2, text: "点击下方\"开始配对\"按钮")
                GuideStep(number: 3, text: "在 iPhone 上输入配对码")
                GuideStep(number: 4, text: "配对成功后，在 iPhone 上按住麦克风说话，Mac 会自动转写并尝试输入")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct GuideStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

// MARK: - Action Buttons Section

struct ActionButtonsSection: View {
    let pairingState: PairingState
    let onStartPairing: () -> Void
    let onOpenPermissions: () -> Void
    let onUnpair: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if case .unpaired = pairingState {
                Button(action: onStartPairing) {
                    HStack {
                        Image(systemName: "link")
                        Text("开始配对")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            HStack(spacing: 12) {
                Button(action: onOpenPermissions) {
                    HStack {
                        Image(systemName: "lock.shield")
                        Text("权限")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if case .paired = pairingState {
                    Button(action: onUnpair) {
                        HStack {
                            Image(systemName: "link.badge.minus")
                            Text("解除配对")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    StatusWindow(controller: MenuBarController())
}
