import SwiftUI

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
