import AppKit
import SharedCore
import SwiftUI
import UniformTypeIdentifiers

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

            DataRecordsTab(controller: controller)
                .tabItem {
                    Label("数据", systemImage: "tray.full")
                }
                .tag(2)

            PermissionsTab()
                .tabItem {
                    Label("权限", systemImage: "lock.shield")
                }
                .tag(3)

            AboutTab()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
                .tag(4)

            PermissionsDebugView()
                .tabItem {
                    Label("调试", systemImage: "ladybug")
                }
                .tag(5)
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

                    if case .paired(_, let deviceName) = controller.pairingState {
                        Divider()
                        HStack {
                            Text("配对设备:")
                            Spacer()
                            Text(deviceName)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let progressMessage = controller.pairingProgressMessage {
                        Divider()
                        HStack(alignment: .top) {
                            Text("配对进度:")
                            Spacer()
                            Label {
                                Text(progressMessage)
                                    .multilineTextAlignment(.trailing)
                            } icon: {
                                Image(systemName: pairingProgressIconName)
                            }
                            .foregroundColor(pairingProgressColor)
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
        case .error:
            Label("错误", systemImage: "exclamationmark.triangle")
                .foregroundColor(.red)
        }
    }

    private var pairingProgressIconName: String {
        if case .paired = controller.pairingState {
            return "checkmark.circle.fill"
        }

        return "hourglass.circle.fill"
    }

    private var pairingProgressColor: Color {
        if case .paired = controller.pairingState {
            return .green
        }

        return .orange
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
    @State private var serverPortText = ""

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

            Section(header: Text("语言")) {
                Picker("识别语言", selection: $settings.language) {
                    Text("中文").tag("zh-CN")
                    Text("English").tag("en-US")
                }
            }

            Section(header: Text("网络服务")) {
                HStack {
                    Text("监听端口")
                    Spacer()
                    TextField("8899", text: $serverPortText)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            serverPortText = String(settings.serverPort)
                        }
                        .onChange(of: serverPortText) { _, newValue in
                            let digitsOnly = newValue.filter(\.isNumber)
                            if digitsOnly != serverPortText {
                                serverPortText = digitsOnly
                                return
                            }

                            guard let port = UInt16(digitsOnly), port >= 1024 else { return }
                            if settings.serverPort != port {
                                settings.serverPort = port
                            }
                        }
                }

                Text("默认端口已改为 8899。修改后如果服务正在运行，会自动重启到新端口。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Data Records Tab

struct DataRecordsTab: View {
    @ObservedObject var controller: MenuBarController
    @State private var selectedFilter: DataRecordFilter = .all
    @State private var searchText = ""
    @State private var groupBySession = true

    private enum DataRecordFilter: String, CaseIterable, Identifiable {
        case all = "全部"
        case voice = "语音"
        case pairing = "配对/连接"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iOS 数据记录")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("展示 iPhone 发来的数据，以及语音在 Mac 端转写后的最终文字。")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Picker("筛选", selection: $selectedFilter) {
                    ForEach(DataRecordFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Button("复制日志") {
                    copyFilteredRecords()
                }
                .buttonStyle(.bordered)
                .disabled(filteredRecords.isEmpty)

                Button("导出日志") {
                    exportFilteredRecords()
                }
                .buttonStyle(.bordered)
                .disabled(filteredRecords.isEmpty)

                Button("清空记录") {
                    controller.clearInboundDataRecords()
                }
                .buttonStyle(.bordered)
                .disabled(controller.inboundDataRecords.isEmpty)
            }

            HStack(spacing: 12) {
                TextField("搜索标题、内容、Session ID", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Toggle("按会话分组", isOn: $groupBySession)
                    .toggleStyle(.checkbox)
            }

            HStack(spacing: 12) {
                summaryBadge(title: "总数", value: "\(filteredRecords.count)", color: .secondary)
                summaryBadge(title: "语音", value: "\(filteredVoiceCount)", color: .accentColor)
                summaryBadge(title: "配对/连接", value: "\(filteredPairingCount)", color: .blue)
                summaryBadge(title: "失败", value: "\(filteredFailureCount)", color: .red)
            }

            if filteredRecords.isEmpty {
                ContentUnavailableView(
                    "暂无数据",
                    systemImage: "tray",
                    description: Text(emptyStateDescription)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                            if groupBySession {
                                ForEach(groupedRecords, id: \.title) { section in
                                    Section {
                                        ForEach(section.records) { record in
                                            recordCard(record)
                                                .id(record.id)
                                        }
                                    } header: {
                                        sectionHeader(section.title, count: section.records.count)
                                    }
                                }
                            } else {
                                ForEach(filteredRecords) { record in
                                    recordCard(record)
                                        .id(record.id)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: controller.inboundDataRecords.count) { _, _ in
                        guard let latestRecord = filteredRecords.first else { return }
                        proxy.scrollTo(latestRecord.id, anchor: .top)
                    }
                }
            }
        }
        .padding()
    }

    private var filteredRecords: [InboundDataRecord] {
        switch selectedFilter {
        case .all:
            return searchedRecords(controller.inboundDataRecords)
        case .voice:
            return searchedRecords(controller.inboundDataRecords.filter(\.isVoice))
        case .pairing:
            return searchedRecords(controller.inboundDataRecords.filter { !$0.isVoice })
        }
    }

    private var groupedRecords: [GroupedDataRecords] {
        var groups: [GroupedDataRecords] = []

        for record in filteredRecords {
            let sessionKey = extractSessionKey(from: record.detail) ?? "未归档会话"
            if let index = groups.firstIndex(where: { $0.title == sessionKey }) {
                groups[index].records.append(record)
            } else {
                groups.append(GroupedDataRecords(title: sessionKey, records: [record]))
            }
        }

        return groups
    }

    private var filteredVoiceCount: Int {
        filteredRecords.filter { $0.category == .voice }.count
    }

    private var filteredPairingCount: Int {
        filteredRecords.filter { $0.category != .voice }.count
    }

    private var filteredFailureCount: Int {
        filteredRecords.filter { $0.severity == .error }.count
    }

    private var emptyStateDescription: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "没有匹配当前关键词的数据记录。"
        }

        switch selectedFilter {
        case .all:
            return "当 iPhone 发来配对请求、语音流或识别文本后，这里会按时间顺序记录。"
        case .voice:
            return "当前还没有语音流或语音转写结果。"
        case .pairing:
            return "当前还没有配对或连接相关记录。"
        }
    }

    private func copyFilteredRecords() {
        let logText = buildLogText()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logText, forType: .string)
    }

    private func exportFilteredRecords() {
        let panel = NSSavePanel()
        panel.title = "导出数据日志"
        panel.nameFieldStringValue = suggestedFileName
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try buildLogText().write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSSound.beep()
        }
    }

    private var suggestedFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "VoiceMind-\(selectedFilter.rawValue)-\(formatter.string(from: Date())).txt"
    }

    private func buildLogText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return filteredRecords.map { record in
            let category = categoryTitle(for: record.category)
            let severity = severityTitle(for: record.severity)
            return """
            [\(formatter.string(from: record.timestamp))] \(category) | \(severity) | \(record.title)
            \(record.detail)
            """
        }
        .joined(separator: "\n\n")
    }

    private func searchedRecords(_ records: [InboundDataRecord]) -> [InboundDataRecord] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return records }

        return records.filter {
            $0.title.localizedCaseInsensitiveContains(keyword)
            || $0.detail.localizedCaseInsensitiveContains(keyword)
        }
    }

    private func extractSessionKey(from detail: String) -> String? {
        detail
            .split(separator: "\n")
            .first(where: { $0.hasPrefix("Session: ") })
            .map { String($0.dropFirst("Session: ".count)) }
    }

    @ViewBuilder
    private func recordCard(_ record: InboundDataRecord) -> some View {
        let failure = record.severity == .error

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(record.title, systemImage: iconName(for: record, isFailure: failure))
                    .font(.headline)
                    .foregroundColor(recordColor(for: record, isFailure: failure))

                Spacer()

                Text(severityTitle(for: record.severity))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(severityBadgeColor(for: record.severity).opacity(0.15))
                    .foregroundColor(severityBadgeColor(for: record.severity))
                    .clipShape(Capsule())

                Text(record.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(record.detail)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .foregroundColor(failure ? .primary : .secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(recordBackgroundColor(isFailure: failure))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(failure ? Color.red.opacity(0.45) : Color.clear, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(count) 条")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func summaryBadge(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func isFailureRecord(_ record: InboundDataRecord) -> Bool {
        record.severity == .error
    }

    private func recordColor(for record: InboundDataRecord, isFailure: Bool) -> Color {
        if isFailure {
            return .red
        }

        switch record.category {
        case .voice:
            return .accentColor
        case .pairing:
            return .blue
        case .connection:
            return .primary
        }
    }

    private func recordBackgroundColor(isFailure: Bool) -> Color {
        if isFailure {
            return Color.red.opacity(0.08)
        }

        return Color(NSColor.controlBackgroundColor)
    }

    private func iconName(for record: InboundDataRecord, isFailure: Bool) -> String {
        if isFailure {
            return "exclamationmark.triangle.fill"
        }

        switch record.category {
        case .voice:
            return "waveform.circle.fill"
        case .pairing:
            return "iphone.and.arrow.forward"
        case .connection:
            return "tray.and.arrow.down.fill"
        }
    }

    private func severityBadgeColor(for severity: InboundDataSeverity) -> Color {
        switch severity {
        case .info:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private func severityTitle(for severity: InboundDataSeverity) -> String {
        switch severity {
        case .info:
            return "信息"
        case .warning:
            return "警告"
        case .error:
            return "错误"
        }
    }

    private func categoryTitle(for category: InboundDataCategory) -> String {
        switch category {
        case .voice:
            return "语音"
        case .pairing:
            return "配对"
        case .connection:
            return "连接"
        }
    }
}

private struct GroupedDataRecords {
    let title: String
    var records: [InboundDataRecord]
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
