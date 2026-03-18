import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationView {
            VStack {
                // Connection Status Card - 只在非成功连接状态显示
                if case .paired = viewModel.pairingState,
                   case .connected = viewModel.connectionState {
                    EmptyView()
                } else {
                    ConnectionStatusCard(
                        pairingState: viewModel.pairingState,
                        connectionState: viewModel.connectionState,
                        reconnectStatusMessage: viewModel.reconnectStatusMessage,
                        onReconnect: {
                            viewModel.reconnect()
                        }
                    )
                    .padding(.bottom, 20)
                }

                Spacer()

                // Recognition Status
                RecognitionStatusView(
                    state: viewModel.recognitionState,
                    statusMessage: viewModel.pushToTalkStatusMessage,
                    isEnabled: viewModel.canStartPushToTalk || viewModel.canManuallyReconnectFromPrimaryButton || viewModel.recognitionState != .idle,
                    showsReconnectAction: viewModel.canManuallyReconnectFromPrimaryButton,
                    onPressChanged: { isPressing in
                        viewModel.handlePrimaryButtonPressChanged(isPressing)
                    }
                )

                Spacer()

                // Actions
                if case .unpaired = viewModel.pairingState {
                    Button("与 Mac 配对") {
                        viewModel.showPairingView = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom, 20)
                }

            }
            .padding()
            .navigationTitle("VoiceMind")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView(viewModel: viewModel)
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
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
    let statusMessage: String?
    let isEnabled: Bool
    let showsReconnectAction: Bool
    let onPressChanged: (Bool) -> Void

    @State private var isPressing = false

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(buttonBackgroundColor)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Circle()
                            .stroke(buttonBorderColor, lineWidth: isPressing ? 4 : 2)
                    )
                    .scaleEffect(isPressing ? 0.95 : 1)

                Image(systemName: iconName)
                    .font(.system(size: 60))
                    .foregroundColor(iconColor)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled else { return }
                        if !isPressing {
                            isPressing = true
                            onPressChanged(true)
                        }
                    }
                    .onEnded { _ in
                        guard isPressing else { return }
                        isPressing = false
                        onPressChanged(false)
                    }
            )

            Text(statusText)
                .font(.title2)
                .fontWeight(.medium)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if state == .listening {
                WaveformView()
                    .frame(height: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private var iconName: String {
        if showsReconnectAction {
            return "antenna.radiowaves.left.and.right"
        }
        switch state {
        case .idle:
            return "mic.fill"
        case .listening:
            return "waveform"
        case .processing:
            return "waveform.circle"
        case .sending:
            return "arrow.up.circle.fill"
        }
    }

    private var iconColor: Color {
        if showsReconnectAction {
            return isEnabled ? .orange : .gray
        }
        switch state {
        case .idle:
            return isEnabled ? .blue : .gray
        case .listening:
            return .white
        case .processing:
            return .blue
        case .sending:
            return .green
        }
    }

    private var statusText: String {
        if showsReconnectAction {
            return "连接服务"
        }
        switch state {
        case .idle:
            return isEnabled ? "按住说话" : "准备就绪"
        case .listening:
            return "正在聆听..."
        case .processing:
            return "处理中..."
        case .sending:
            return "发送结果..."
        }
    }

    private var buttonBackgroundColor: Color {
        if showsReconnectAction {
            return isEnabled ? Color.orange.opacity(0.15) : Color.gray.opacity(0.12)
        }
        switch state {
        case .idle:
            return isEnabled ? Color.blue.opacity(0.15) : Color.gray.opacity(0.12)
        case .listening:
            return .red
        case .processing:
            return Color.blue.opacity(0.15)
        case .sending:
            return Color.green.opacity(0.18)
        }
    }

    private var buttonBorderColor: Color {
        if showsReconnectAction {
            return isEnabled ? .orange.opacity(0.5) : .gray.opacity(0.4)
        }
        switch state {
        case .idle:
            return isEnabled ? .blue.opacity(0.5) : .gray.opacity(0.4)
        case .listening:
            return .red.opacity(0.8)
        case .processing:
            return .blue.opacity(0.5)
        case .sending:
            return .green.opacity(0.6)
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
