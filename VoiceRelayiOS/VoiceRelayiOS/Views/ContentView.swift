import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Connection Status Card
                ConnectionStatusCard(
                    pairingState: viewModel.pairingState,
                    connectionState: viewModel.connectionState,
                    reconnectStatusMessage: viewModel.reconnectStatusMessage,
                    onReconnect: {
                        viewModel.reconnect()
                    }
                )

                // Recognition Status
                RecognitionStatusView(state: viewModel.recognitionState)

                Spacer()

                // Actions
                if case .unpaired = viewModel.pairingState {
                    Button("与 Mac 配对") {
                        viewModel.showPairingView = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                // Settings
                NavigationLink("设置") {
                    SettingsView(viewModel: viewModel)
                }
            }
            .padding()
            .navigationTitle("VoiceMind")
            .sheet(isPresented: $viewModel.showPairingView) {
                PairingView(viewModel: viewModel)
            }
        }
    }
}

struct ConnectionStatusCard: View {
    let pairingState: PairingState
    let connectionState: ConnectionState
    let reconnectStatusMessage: String?
    let onReconnect: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                Text(statusText)
                    .font(.headline)

                Spacer()

                // 显示重连按钮（仅在已配对但断开连接时）
                if case .paired = pairingState,
                   case .disconnected = connectionState {
                    Button(action: onReconnect) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("重连")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // 显示加载指示器（连接中）
                if case .connecting = connectionState {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if case .paired(_, let deviceName) = pairingState {
                HStack {
                    Text("已配对: \(deviceName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            // 显示错误信息
            if case .error(let message) = connectionState {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            if let reconnectStatusMessage,
               case .paired = pairingState {
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
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch (pairingState, connectionState) {
        case (.unpaired, _):
            return .gray
        case (.paired, .connected):
            return .green
        case (.paired, .connecting):
            return .orange
        case (.paired, .disconnected):
            return .red
        case (.paired, .error):
            return .red
        default:
            return .gray
        }
    }

    private var statusText: String {
        switch (pairingState, connectionState) {
        case (.unpaired, _):
            return "未配对"
        case (.paired, .connected):
            return "已连接"
        case (.paired, .connecting):
            return "连接中..."
        case (.paired, .disconnected):
            return "已断开"
        case (.paired, .error):
            return "连接错误"
        default:
            return "未知"
        }
    }

    private var reconnectStatusIcon: String {
        switch connectionState {
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
        switch connectionState {
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

struct RecognitionStatusView: View {
    let state: RecognitionState

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(iconColor)

            Text(statusText)
                .font(.title2)
                .fontWeight(.medium)

            if state == .listening {
                WaveformView()
                    .frame(height: 40)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var iconName: String {
        switch state {
        case .idle:
            return "mic.circle"
        case .listening:
            return "mic.circle.fill"
        case .processing:
            return "waveform.circle"
        case .sending:
            return "arrow.up.circle.fill"
        }
    }

    private var iconColor: Color {
        switch state {
        case .idle:
            return .gray
        case .listening:
            return .red
        case .processing:
            return .blue
        case .sending:
            return .green
        }
    }

    private var statusText: String {
        switch state {
        case .idle:
            return "准备就绪"
        case .listening:
            return "正在聆听..."
        case .processing:
            return "处理中..."
        case .sending:
            return "发送结果..."
        }
    }
}

struct WaveformView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height / 2

                path.move(to: CGPoint(x: 0, y: midHeight))

                for x in stride(from: 0, through: width, by: 1) {
                    let relativeX = x / width
                    let sine = sin((relativeX + phase) * .pi * 4)
                    let y = midHeight + sine * (height / 4)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color.red, lineWidth: 2)
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}
