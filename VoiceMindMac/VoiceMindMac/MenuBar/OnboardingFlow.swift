import SwiftUI
import SharedCore

// MARK: - Main Window Coordinator

struct OnboardingFlowView: View {
    @ObservedObject var controller: MenuBarController
    @State private var currentStep: OnboardingStep = .welcome

    enum OnboardingStep {
        case welcome
        case permissions
        case ready
        case running
    }

    var body: some View {
        Group {
            switch currentStep {
            case .welcome:
                WelcomeView(onContinue: {
                    currentStep = .permissions
                })
            case .permissions:
                PermissionsCheckView(
                    controller: controller,
                    onComplete: {
                        currentStep = .ready
                    }
                )
            case .ready:
                ReadyView(
                    controller: controller,
                    onStart: {
                        controller.startNetworkServices()
                        currentStep = .running
                    }
                )
            case .running:
                RunningStatusView(controller: controller)
            }
        }
        .frame(width: 500, height: 600)
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // App Icon
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            // Title
            Text("欢迎使用 语灵")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Subtitle
            Text("通过 iPhone 为 Mac 提供强大的语音输入功能")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            // Features
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "text.cursor",
                    title: "光标自动输入",
                    description: "识别结果会自动尝试输入到当前聚焦的文本框"
                )

                FeatureRow(
                    icon: "iphone.and.arrow.forward",
                    title: "无缝连接",
                    description: "通过本地网络安全连接 iPhone 和 Mac"
                )

                FeatureRow(
                    icon: "waveform",
                    title: "高精度识别",
                    description: "使用 Apple 原生语音识别引擎"
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            // Continue Button
            Button(action: onContinue) {
                Text("开始使用")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Permissions Check View

struct PermissionsCheckView: View {
    @ObservedObject var controller: MenuBarController
    let onComplete: () -> Void

    @State private var isCheckingPermissions = false

    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text("权限设置")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("语灵 需要以下权限才能正常工作")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            Spacer()

            // Permission Items
            VStack(spacing: 20) {
                PermissionItem(
                    icon: "lock.shield",
                    title: "辅助功能权限",
                    description: "用于识别当前焦点并将转写结果输入到当前应用",
                    status: controller.accessibilityStatus,
                    onRequest: {
                        controller.requestAccessibilityPermissionFromUI()
                    }
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            // Status Message
            if allPermissionsGranted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("所有权限已授予")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text("请点击上方按钮授予权限")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Continue Button
            Button(action: {
                if allPermissionsGranted {
                    onComplete()
                } else {
                    // Show alert
                }
            }) {
                Text(allPermissionsGranted ? "继续" : "稍后设置")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onAppear {
            // Refresh permissions status
            controller.refreshPermissionState()
        }
    }

    private var allPermissionsGranted: Bool {
        controller.accessibilityStatus == .granted
    }
}

struct PermissionItem: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let onRequest: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(status == .granted ? .green : .orange)
                .frame(width: 40)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.headline)

                    Spacer()

                    // Status Badge
                    StatusBadge(status: status)
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if status != .granted {
                    Button(action: onRequest) {
                        Text("授予权限")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct StatusBadge: View {
    let status: PermissionStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.caption)
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(6)
    }

    private var statusIcon: String {
        switch status {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "exclamationmark.circle.fill"
        }
    }

    private var statusText: String {
        switch status {
        case .granted: return "已授予"
        case .denied: return "已拒绝"
        case .notDetermined: return "未授予"
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        }
    }
}

// MARK: - Ready View

struct ReadyView: View {
    @ObservedObject var controller: MenuBarController
    let onStart: () -> Void

    @State private var localIPAddress: String = "获取中..."

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Ready Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            // Title
            Text("准备就绪")
                .font(.largeTitle)
                .fontWeight(.bold)

                Text("所有设置已完成，可以开始使用了")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            // System Info
            VStack(spacing: 16) {
                InfoCard(
                    icon: "network",
                    title: "本机 IP 地址",
                    value: localIPAddress,
                    color: .blue
                )

                InfoCard(
                    icon: "text.cursor",
                    title: "输入方式",
                    value: "iPhone 按住说话，Mac 自动转写并输入",
                    color: .purple
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("使用说明")
                    .font(.headline)

                InstructionStep(number: 1, text: controller.isServiceRunning ? "网络服务已自动启动" : "点击下方按钮启动网络服务")
                InstructionStep(number: 2, text: "在 iPhone 上打开 语灵 应用")
                InstructionStep(number: 3, text: "完成配对后，在 iPhone 上按住麦克风开始说话")
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal, 40)

            Spacer()

            // Start Button
            Button(action: onStart) {
                HStack {
                    Image(systemName: controller.isServiceRunning ? "arrow.right.circle.fill" : "power")
                    Text(controller.isServiceRunning ? "继续" : "启动服务")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onAppear {
            fetchLocalIPAddress()
            if controller.isServiceRunning {
                onStart()
            }
        }
    }

    private func fetchLocalIPAddress() {
        localIPAddress = getLocalIPAddress() ?? "未获取到"
    }

    private func getLocalIPAddress() -> String? {
        LocalNetworkAccessPolicy.preferredLocalIPv4()
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
                    .foregroundColor(color)
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
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

// MARK: - Running Status View

struct RunningStatusView: View {
    @ObservedObject var controller: MenuBarController
    @State private var localIPAddress: String = "获取中..."
    @State private var refreshTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Header
                StatusHeader(
                    pairingState: controller.pairingState,
                    connectionState: controller.connectionState
                )

                // System Info
                SystemInfoCard(
                    localIP: localIPAddress,
                    accessibilityStatus: controller.accessibilityStatus
                )

                // Device Connection
                DeviceConnectionCard(
                    pairingState: controller.pairingState,
                    connectionState: controller.connectionState
                )

                // Quick Actions
                QuickActionsCard(
                    pairingState: controller.pairingState,
                    onStartPairing: {
                        controller.showPairingWindowFromUI()
                    },
                    onUnpair: {
                        controller.unpairDeviceFromUI()
                    },
                    onStopService: {
                        controller.stopNetworkServices()
                    }
                )
            }
            .padding()
        }
        .onAppear {
            fetchLocalIPAddress()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            fetchLocalIPAddress()
            controller.refreshPublishedState()
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func fetchLocalIPAddress() {
        localIPAddress = getLocalIPAddress() ?? "未获取到"
    }

    private func getLocalIPAddress() -> String? {
        LocalNetworkAccessPolicy.preferredLocalIPv4()
    }
}

struct StatusHeader: View {
    let pairingState: PairingState
    let connectionState: ConnectionState

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: statusIcon)
                .font(.system(size: 48))
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("语灵")
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
        case (.paired, .connected): return "checkmark.circle.fill"
        case (.paired, .connecting): return "arrow.triangle.2.circlepath"
        case (.paired, .disconnected): return "exclamationmark.triangle.fill"
        case (.pairing, _): return "arrow.triangle.2.circlepath"
        case (.unpaired, _): return "link.circle"
        default: return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch (pairingState, connectionState) {
        case (.paired, .connected): return .green
        case (.paired, .connecting): return .orange
        case (.paired, .disconnected): return .red
        case (.pairing, _): return .blue
        case (.unpaired, _): return .gray
        default: return .gray
        }
    }

    private var statusText: String {
        switch (pairingState, connectionState) {
        case (.paired, .connected): return "已连接 - 可以使用语音输入"
        case (.paired, .connecting): return "正在连接到 iPhone..."
        case (.paired, .disconnected): return "已配对但未连接"
        case (.pairing, _): return "正在配对..."
        case (.unpaired, _): return "未配对 - 请先与 iPhone 配对"
        default: return "未知状态"
        }
    }
}

struct SystemInfoCard: View {
    let localIP: String
    let accessibilityStatus: PermissionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("系统信息")
                .font(.headline)

            VStack(spacing: 8) {
                SimpleInfoRow(icon: "network", title: "本机 IP", value: localIP, color: .blue)
                SimpleInfoRow(icon: "text.cursor", title: "输入方式", value: "iPhone 语音直传 Mac 转写", color: .purple)
                SimpleInfoRow(icon: "lock.shield", title: "辅助功能", value: accessibilityStatus.displayText, color: accessibilityStatus.color)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct DeviceConnectionCard: View {
    let pairingState: PairingState
    let connectionState: ConnectionState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设备连接")
                .font(.headline)

            VStack(spacing: 8) {
                SimpleInfoRow(icon: "iphone", title: "配对状态", value: pairingStatusText, color: pairingStatusColor)

                if case .paired(_, let deviceName) = pairingState {
                    SimpleInfoRow(icon: "person.circle", title: "设备名称", value: deviceName, color: .blue)
                }

                SimpleInfoRow(icon: "wifi", title: "连接状态", value: connectionStatusText, color: connectionStatusColor)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var pairingStatusText: String {
        switch pairingState {
        case .unpaired: return "未配对"
        case .pairing: return "配对中..."
        case .paired: return "已配对"
        }
    }

    private var pairingStatusColor: Color {
        switch pairingState {
        case .unpaired: return .gray
        case .pairing: return .blue
        case .paired: return .green
        }
    }

    private var connectionStatusText: String {
        switch connectionState {
        case .disconnected: return "未连接"
        case .connecting: return "连接中..."
        case .connected: return "已连接"
        case .error: return "连接错误"
        }
    }

    private var connectionStatusColor: Color {
        switch connectionState {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
}

struct QuickActionsCard: View {
    let pairingState: PairingState
    let onStartPairing: () -> Void
    let onUnpair: () -> Void
    let onStopService: () -> Void

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
            }

            HStack(spacing: 12) {
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

            Button(action: onStopService) {
                HStack {
                    Image(systemName: "stop.circle")
                    Text("停止服务")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
}

struct SimpleInfoRow: View {
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

// MARK: - PermissionStatus Extension

extension PermissionStatus {
    var displayText: String {
        switch self {
        case .granted: return "已授予"
        case .denied: return "已拒绝"
        case .notDetermined: return "未授予"
        }
    }

    var color: Color {
        switch self {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        }
    }
}
