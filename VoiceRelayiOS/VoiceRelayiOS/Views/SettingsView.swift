import SwiftUI
import SharedCore

struct SettingsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showPermissionAlert = false

    private let languages = [
        ("zh-CN", "中文（普通话）"),
        ("en-US", "English (US)")
    ]

    var body: some View {
        List {
            // Language Section
            Section {
                ForEach(languages, id: \.0) { code, name in
                    Button(action: {
                        viewModel.updateLanguage(code)
                    }) {
                        HStack {
                            Text(name)
                                .foregroundColor(.primary)

                            Spacer()

                            if viewModel.selectedLanguage == code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text("识别语言")
            }

            // Permissions Section
            Section {
                PermissionRow(
                    title: "麦克风",
                    icon: "mic.fill",
                    isGranted: viewModel.checkPermissions()
                )

                PermissionRow(
                    title: "语音识别",
                    icon: "waveform",
                    isGranted: viewModel.checkPermissions()
                )

                if !viewModel.checkPermissions() {
                    Button(action: requestPermissions) {
                        HStack {
                            Spacer()
                            Text("请求权限")
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                }
            } header: {
                Text("权限")
            } footer: {
                Text("VoiceMind 需要麦克风和语音识别权限才能正常工作")
            }

            // Pairing Section
            if case .paired(_, let deviceName) = viewModel.pairingState {
                Section {
                    HStack {
                        Text("已配对设备")
                        Spacer()
                        Text(deviceName)
                            .foregroundColor(.secondary)
                    }

                    // 显示连接状态和重连按钮
                    HStack {
                        Text("连接状态")
                        Spacer()
                        connectionStatusBadge
                    }

                    if case .disconnected = viewModel.connectionState {
                        Button(action: {
                            viewModel.reconnect()
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.clockwise")
                                Text("重新连接")
                                Spacer()
                            }
                        }
                    }

                    if let reconnectStatusMessage = viewModel.reconnectStatusMessage {
                        HStack(alignment: .top) {
                            Image(systemName: reconnectStatusIcon)
                                .foregroundColor(reconnectStatusColor)
                                .font(.caption)
                                .padding(.top, 2)
                            Text(reconnectStatusMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }

                    Button(role: .destructive, action: {
                        viewModel.unpair()
                        dismiss()
                    }) {
                        HStack {
                            Spacer()
                            Text("取消配对")
                            Spacer()
                        }
                    }
                } header: {
                    Text("配对")
                }
            }

            // About Section
            Section {
                NavigationLink {
                    IOSDataLogsView(viewModel: viewModel)
                } label: {
                    HStack {
                        Image(systemName: "tray.full")
                            .foregroundColor(.blue)
                        Text("查看数据日志")
                    }
                }
            } header: {
                Text("调试")
            }

            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("关于")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .alert("权限请求", isPresented: $showPermissionAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("请在系统设置中授予麦克风和语音识别权限")
        }
    }

    private func requestPermissions() {
        viewModel.requestPermissions { granted in
            if !granted {
                showPermissionAlert = true
            }
        }
    }

    private var connectionStatusBadge: some View {
        Group {
            switch viewModel.connectionState {
            case .connected:
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("已连接")
                        .foregroundColor(.secondary)
                }
            case .connecting:
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    Text("连接中...")
                        .foregroundColor(.secondary)
                }
            case .disconnected:
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("已断开")
                        .foregroundColor(.secondary)
                }
            case .error:
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("错误")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var reconnectStatusIcon: String {
        switch viewModel.connectionState {
        case .connected:
            return "checkmark.circle.fill"
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .error:
            return "exclamationmark.triangle.fill"
        case .disconnected:
            return "antenna.radiowaves.left.and.right.slash"
        }
    }

    private var reconnectStatusColor: Color {
        switch viewModel.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .blue
        case .error:
            return .orange
        case .disconnected:
            return .secondary
        }
    }
}

struct IOSDataLogsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var selectedFilter: IOSDataFilter = .all

    private enum IOSDataFilter: String, CaseIterable, Identifiable {
        case all = "全部"
        case voice = "语音"
        case connection = "连接"

        var id: String { rawValue }
    }

    var body: some View {
        List {
            Section {
                Picker("筛选", selection: $selectedFilter) {
                    ForEach(IOSDataFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                Button(role: .destructive) {
                    viewModel.clearInboundDataRecords()
                } label: {
                    Text("清空日志")
                }
                .disabled(viewModel.inboundDataRecords.isEmpty)
            }

            if filteredRecords.isEmpty {
                Section {
                    ContentUnavailableView(
                        "暂无日志",
                        systemImage: "tray",
                        description: Text("这里会展示 iPhone 侧记录的配对、连接和语音流事件。")
                    )
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(filteredRecords) { record in
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(record.title, systemImage: iconName(for: record))
                                    .foregroundColor(color(for: record))
                                Spacer()
                                Text(record.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text(record.detail)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("数据日志")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filteredRecords: [InboundDataRecord] {
        switch selectedFilter {
        case .all:
            return viewModel.inboundDataRecords
        case .voice:
            return viewModel.inboundDataRecords.filter { $0.category == .voice }
        case .connection:
            return viewModel.inboundDataRecords.filter { $0.category != .voice }
        }
    }

    private func iconName(for record: InboundDataRecord) -> String {
        if record.severity == .error {
            return "exclamationmark.triangle.fill"
        }

        switch record.category {
        case .voice:
            return "waveform.circle.fill"
        case .pairing:
            return "iphone.and.arrow.forward"
        case .connection:
            return "antenna.radiowaves.left.and.right"
        }
    }

    private func color(for record: InboundDataRecord) -> Color {
        switch record.severity {
        case .info:
            switch record.category {
            case .voice:
                return .purple
            case .pairing:
                return .blue
            case .connection:
                return .green
            }
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

struct PermissionRow: View {
    let title: String
    let icon: String
    let isGranted: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isGranted ? .green : .gray)
                .frame(width: 30)

            Text(title)

            Spacer()

            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isGranted ? .green : .red)
        }
    }
}
