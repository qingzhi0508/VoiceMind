import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @Binding var hasLaunchedBefore: Bool

    @State private var showOnboarding = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [
                        Color(UIColor.systemGroupedBackground),
                        Color(UIColor.secondarySystemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Decorative Elements
                GeometryReader { geometry in
                    // Top right decorative circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.blue.opacity(0.08), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 300, height: 300)
                        .offset(x: geometry.size.width - 100, y: -50)

                    // Bottom left decorative circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.06), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .frame(width: 250, height: 250)
                        .offset(x: -80, y: geometry.size.height - 150)
                }

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
                        isEnabled: viewModel.canStartPushToTalk || viewModel.canManuallyReconnectFromPrimaryButton || viewModel.canOpenPairingFromPrimaryButton || viewModel.recognitionState != .idle,
                        showsPairingAction: viewModel.canOpenPairingFromPrimaryButton,
                        showsReconnectAction: viewModel.canManuallyReconnectFromPrimaryButton,
                        audioLevel: viewModel.audioLevel,
                        onPressChanged: { isPressing in
                            viewModel.handlePrimaryButtonPressChanged(isPressing)
                        }
                    )

                    Spacer()
                }
                .padding()
            }
            .navigationTitle(String(localized: "app_title"))
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
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(onComplete: {
                    showOnboarding = false
                    hasLaunchedBefore = true
                })
            }
            .onAppear {
                if !hasLaunchedBefore {
                    showOnboarding = true
                    hasLaunchedBefore = true
                }
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
                            Text(String(localized: "reconnect_button"))
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
                    Text(String(format: String(localized: "paired_device_format"), deviceName))
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
            return String(localized: "connection_status_unpaired")
        case (.paired, .connected):
            return String(localized: "connection_status_connected")
        case (.paired, .connecting):
            return String(localized: "connection_status_connecting")
        case (.paired, .disconnected):
            return String(localized: "connection_status_disconnected")
        case (.paired, .error):
            return String(localized: "connection_status_error")
        default:
            return String(localized: "connection_status_unknown")
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
    let showsPairingAction: Bool
    let showsReconnectAction: Bool
    let audioLevel: CGFloat
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
                WaveformView(level: audioLevel)
                    .frame(height: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private var iconName: String {
        if showsPairingAction {
            return "speaker.wave.2.fill"
        }
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
        if showsPairingAction {
            return isEnabled ? .orange : .gray
        }
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
        if showsPairingAction {
            return String(localized: "recognition_pair_now")
        }
        if showsReconnectAction {
            return String(localized: "recognition_connect_service")
        }
        switch state {
        case .idle:
            return isEnabled ? String(localized: "recognition_hold_to_talk") : String(localized: "recognition_ready")
        case .listening:
            return String(localized: "recognition_listening")
        case .processing:
            return String(localized: "recognition_processing")
        case .sending:
            return String(localized: "recognition_sending")
        }
    }

    private var buttonBackgroundColor: Color {
        if showsPairingAction {
            return isEnabled ? Color.orange.opacity(0.18) : Color.gray.opacity(0.12)
        }
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
        if showsPairingAction {
            return isEnabled ? .orange.opacity(0.6) : .gray.opacity(0.4)
        }
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
    let level: CGFloat

    @State private var smoothedLevel: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geometry in
                let amplitude = max(0.12, min(smoothedLevel * 2.2, 1.4))
                let phase = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let centerY = size.height / 2
                    let width = size.width
                    let particleCount = 40
                    let spacing = width / CGFloat(particleCount - 1)
                    let baseRadius: CGFloat = 2.2

                    for index in 0..<particleCount {
                        let x = CGFloat(index) * spacing
                        let progress = x / width
                        let wave = sin((progress * 8 + phase) * .pi * 2)
                        let wave2 = sin((progress * 3 + phase * 0.7) * .pi * 2) * 0.35
                        let yOffset = (wave + wave2) * amplitude * (size.height * 0.28)
                        let y = centerY + yOffset

                        let intensity = min(1, max(0.2, amplitude))
                        let radius = baseRadius + intensity * 1.8
                        let alpha = 0.25 + intensity * 0.6
                        let hue = 0.55 + 0.08 * sin(phase + Double(progress) * 2)
                        let color = Color(hue: hue, saturation: 0.55, brightness: 0.95).opacity(alpha)

                        let rect = CGRect(
                            x: x - radius,
                            y: y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }
            }
        }
        .onAppear {
            smoothedLevel = level
        }
        .onChange(of: level) { _, newValue in
            withAnimation(.linear(duration: 0.04)) {
                smoothedLevel = newValue
            }
        }
    }
}
