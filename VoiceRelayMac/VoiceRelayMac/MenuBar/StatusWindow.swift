import SwiftUI

struct StatusWindow: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerCard
            statusSection
            permissionSection
            if case .pairing(let code, let expiresAt) = controller.pairingState {
                pairingCodeCard(code: code, expiresAt: expiresAt)
            } else if case .unpaired = controller.pairingState {
                quickStartCard
            }
            actionSection
            Spacer()
        }
        .padding(24)
        .frame(minWidth: 460, minHeight: 540)
        .background(
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.blue.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.16))
                    .frame(width: 64, height: 64)

                Image(systemName: statusIcon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("VoiceMind 控制台")
                    .font(.system(size: 26, weight: .bold))

                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("当前状态")
                .font(.headline)

            StatusRow(
                icon: "iphone.gen3",
                title: "配对状态",
                value: pairingStatusText,
                color: pairingStatusColor
            )

            StatusRow(
                icon: "wifi",
                title: "连接状态",
                value: connectionStatusText,
                color: connectionStatusColor
            )

            StatusRow(
                icon: "keyboard",
                title: "快捷键",
                value: "Option + Space",
                color: .blue
            )
        }
        .padding(20)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var quickStartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速开始")
                .font(.headline)

            GuideStep(number: 1, text: "打开 iPhone 端 VoiceMind。")
            GuideStep(number: 2, text: "点击下方“开始配对”获取配对码。")
            GuideStep(number: 3, text: "在 iPhone 上输入配对码完成连接。")
            GuideStep(number: 4, text: "配对完成后按住 Option + Space 开始语音输入。")
        }
        .padding(20)
        .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("系统权限")
                .font(.headline)

            PermissionStatusRow(
                title: "辅助功能",
                description: "负责文本注入和部分系统交互。",
                status: controller.accessibilityStatus,
                onRequest: controller.requestAccessibilityPermissionFromUI
            )

            PermissionStatusRow(
                title: "输入监控",
                description: "负责全局监听快捷键。",
                status: controller.inputMonitoringStatus,
                onRequest: controller.requestInputMonitoringPermissionFromUI
            )
        }
        .padding(20)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func pairingCodeCard(code: String, expiresAt: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("正在配对")
                .font(.headline)

            Text(code)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(4)

            Text("请在 iPhone 上输入该配对码，\(expiresText(for: expiresAt))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作")
                .font(.headline)

            HStack(spacing: 12) {
                if case .unpaired = controller.pairingState {
                    actionButton(
                        title: "开始配对",
                        icon: "link.badge.plus",
                        prominence: true,
                        action: controller.showPairingWindowFromUI
                    )
                }

                actionButton(
                    title: "权限设置",
                    icon: "lock.shield",
                    prominence: false,
                    action: controller.openPermissionsFromUI
                )

                actionButton(
                    title: "快捷键设置",
                    icon: "keyboard",
                    prominence: false,
                    action: controller.openHotkeySettingsFromUI
                )
            }

            if case .paired = controller.pairingState {
                Button("解除配对", action: controller.unpairDeviceFromUI)
                    .buttonStyle(.link)
                    .foregroundColor(.red)
            }
        }
    }

    private func actionButton(title: String, icon: String, prominence: Bool, action: @escaping () -> Void) -> some View {
        Group {
            if prominence {
                Button(action: action) {
                    Label(title, systemImage: icon)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: action) {
                    Label(title, systemImage: icon)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.large)
    }

    private func expiresText(for date: Date) -> String {
        let remaining = max(Int(date.timeIntervalSinceNow), 0)
        return remaining > 0 ? "约 \(remaining) 秒后失效" : "已失效"
    }

    private var statusIcon: String {
        switch (controller.pairingState, controller.connectionState) {
        case (.paired, .connected):
            return "checkmark.circle.fill"
        case (.paired, .connecting), (.pairing, _):
            return "arrow.triangle.2.circlepath.circle.fill"
        case (.paired, .disconnected):
            return "wifi.exclamationmark"
        case (.paired, .error):
            return "xmark.octagon.fill"
        case (.unpaired, _):
            return "link.circle"
        }
    }

    private var statusColor: Color {
        switch (controller.pairingState, controller.connectionState) {
        case (.paired, .connected):
            return .green
        case (.paired, .connecting), (.pairing, _):
            return .orange
        case (.paired, .disconnected), (.paired, .error):
            return .red
        case (.unpaired, _):
            return .gray
        }
    }

    private var statusText: String {
        switch (controller.pairingState, controller.connectionState) {
        case (.paired, .connected):
            return "Mac 与 iPhone 已连接，可以开始语音输入。"
        case (.paired, .connecting):
            return "已完成配对，正在尝试建立连接。"
        case (.paired, .disconnected):
            return "已配对，但当前没有可用连接。"
        case (.paired, .error(let error)):
            return "连接异常：\(error.localizedDescription)"
        case (.pairing, _):
            return "等待 iPhone 输入配对码。"
        case (.unpaired, _):
            return "还没有配对，请先连接你的 iPhone。"
        }
    }

    private var pairingStatusText: String {
        switch controller.pairingState {
        case .unpaired:
            return "未配对"
        case .pairing:
            return "等待输入配对码"
        case .paired(_, let deviceName):
            return "已配对：\(deviceName)"
        }
    }

    private var pairingStatusColor: Color {
        switch controller.pairingState {
        case .unpaired:
            return .gray
        case .pairing:
            return .orange
        case .paired:
            return .green
        }
    }

    private var connectionStatusText: String {
        switch controller.connectionState {
        case .disconnected:
            return "未连接"
        case .connecting:
            return "连接中"
        case .connected:
            return "已连接"
        case .error(let error):
            return "错误：\(error.localizedDescription)"
        }
    }

    private var connectionStatusColor: Color {
        switch controller.connectionState {
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

struct StatusRow: View {
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
    }
}

struct GuideStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Color.blue, in: Circle())

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

struct PermissionStatusRow: View {
    let title: String
    let description: String
    let status: PermissionStatus
    let onRequest: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(statusText)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.14), in: Capsule())
                .foregroundColor(statusColor)

            if status != .granted {
                Button("去授权", action: onRequest)
                    .buttonStyle(.bordered)
            }
        }
    }

    private var statusText: String {
        switch status {
        case .granted:
            return "已授权"
        case .denied:
            return "已拒绝"
        case .notDetermined:
            return "未决定"
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        }
    }
}
