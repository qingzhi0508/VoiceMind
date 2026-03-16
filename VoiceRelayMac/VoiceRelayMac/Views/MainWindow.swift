import SwiftUI

struct MainWindow: View {
    @ObservedObject var controller: MenuBarController
    @ObservedObject var settings = AppSettings.shared

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            StatusTab(controller: controller)
                .tabItem {
                    Label("状态", systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(0)

            SettingsTab(settings: settings, controller: controller)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
                .tag(1)

            PermissionsTab()
                .tabItem {
                    Label("权限", systemImage: "lock.shield")
                }
                .tag(2)

            AboutTab()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
                .tag(3)

            PermissionsDebugView()
                .tabItem {
                    Label("调试", systemImage: "ladybug")
                }
                .tag(4)
        }
        .frame(width: 600, height: 600)
    }
}

// MARK: - Status Tab

struct StatusTab: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(spacing: 20) {
            Text("🎤 VoiceMind")
                .font(.system(size: 32, weight: .bold))

            // Connection Status
            GroupBox(label: Label("连接状态", systemImage: "network")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("状态:")
                        Spacer()
                        connectionStatusView
                    }

                    if case .paired(let deviceId, let deviceName) = controller.pairingState {
                        Divider()
                        HStack {
                            Text("配对设备:")
                            Spacer()
                            Text(deviceName)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()
                    HStack {
                        Text("IP 地址:")
                        Spacer()
                        Text(getLocalIPAddress() ?? "未知")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }

            // Service Status
            GroupBox(label: Label("服务状态", systemImage: "server.rack")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("网络服务:")
                        Spacer()
                        Text(controller.isServiceRunning ? "运行中" : "已停止")
                            .foregroundColor(controller.isServiceRunning ? .green : .secondary)
                    }

                    Divider()
                    HStack {
                        Text("快捷键监听:")
                        Spacer()
                        Text(controller.isServiceRunning ? "已启用" : "已禁用")
                            .foregroundColor(controller.isServiceRunning ? .green : .secondary)
                    }
                }
                .padding()
            }

            Spacer()

            // Control Buttons
            HStack(spacing: 15) {
                if !controller.isServiceRunning {
                    Button(action: {
                        controller.startNetworkServices()
                    }) {
                        Label("启动服务", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(action: {
                        controller.stopNetworkServices()
                    }) {
                        Label("停止服务", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)

            // Pairing Button
            if controller.isServiceRunning {
                if case .unpaired = controller.pairingState {
                    Button(action: {
                        controller.showPairingWindowFromUI()
                    }) {
                        Label("开始配对", systemImage: "iphone.and.arrow.forward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                } else if case .paired(_, let deviceName) = controller.pairingState {
                    HStack {
                        Text("已配对设备: \(deviceName)")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("解除配对") {
                            controller.unpairDeviceFromUI()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        switch controller.connectionState {
        case .disconnected:
            Label("未连接", systemImage: "circle")
                .foregroundColor(.secondary)
        case .connecting:
            Label("连接中...", systemImage: "circle.dotted")
                .foregroundColor(.orange)
        case .connected:
            Label("已连接", systemImage: "circle.fill")
                .foregroundColor(.green)
        case .error(let message):
            Label("错误", systemImage: "exclamationmark.triangle")
                .foregroundColor(.red)
        }
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
}

// MARK: - Settings Tab

struct SettingsTab: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var controller: MenuBarController

    var body: some View {
        Form {
            Section(header: Text("文本注入方式")) {
                Picker("注入方式", selection: $settings.textInjectionMethod) {
                    ForEach(TextInjectionMethod.allCases, id: \.self) { method in
                        VStack(alignment: .leading) {
                            Text(method.displayName)
                            Text(method.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(method)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section(header: Text("快捷键配置")) {
                HStack {
                    Text("当前快捷键:")
                    Spacer()
                    Text("Option + Space")
                        .foregroundColor(.secondary)
                }

                Button("自定义快捷键...") {
                    controller.showHotkeySettings()
                }
            }

            Section(header: Text("语言")) {
                Picker("识别语言", selection: $settings.language) {
                    Text("中文").tag("zh-CN")
                    Text("English").tag("en-US")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Permissions Tab

struct PermissionsTab: View {
    @State private var accessibilityGranted = false
    @State private var inputMonitoringGranted = false

    var body: some View {
        VStack(spacing: 20) {
            Text("系统权限")
                .font(.title)
                .padding(.top)

            GroupBox {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(accessibilityGranted ? .green : .red)
                        Text("辅助功能")
                        Spacer()
                        Text(accessibilityGranted ? "已授予" : "未授予")
                            .foregroundColor(.secondary)
                    }

                    Text("VoiceMind 需要辅助功能权限来监听全局快捷键和注入文本")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    HStack {
                        Image(systemName: inputMonitoringGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(inputMonitoringGranted ? .green : .red)
                        Text("输入监控")
                        Spacer()
                        Text(inputMonitoringGranted ? "已授予" : "未授予")
                            .foregroundColor(.secondary)
                    }

                    Text("VoiceMind 需要输入监控权限来检测快捷键按下事件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            HStack(spacing: 15) {
                Button("检查权限") {
                    checkPermissions()
                }
                .buttonStyle(.bordered)

                Button("请求权限") {
                    requestPermissions()
                }
                .buttonStyle(.borderedProminent)

                Button("打开系统设置") {
                    PermissionsManager.openSystemPreferences(for: .accessibility)
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        accessibilityGranted = PermissionsManager.checkAccessibility() == .granted
        inputMonitoringGranted = PermissionsManager.checkInputMonitoring() == .granted
    }

    private func requestPermissions() {
        PermissionsManager.requestAccessibility()
        PermissionsManager.requestInputMonitoring()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            checkPermissions()
        }
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("VoiceMind")
                .font(.title)

            Text("版本 1.0.0")
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 50)

            Text("语音输入助手")
                .font(.headline)

            Text("通过 iOS 设备进行语音识别，将结果实时注入到 Mac 应用中")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Spacer()

            Link("查看帮助文档", destination: URL(string: "https://github.com")!)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}
