import SwiftUI

struct ContentView: View {
    enum FocusField: Hashable {
        case transcriptEditor
    }

    @StateObject private var viewModel = ContentViewModel()
    @Binding var hasLaunchedBefore: Bool

    @State private var showOnboarding = false
    @State private var selectedPage = 1
    @FocusState private var focusedField: FocusField?

    var body: some View {
        NavigationView {
            ZStack {
                // System Theme Background
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
                                colors: [Color.accentColor.opacity(0.12), Color.clear],
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
                                colors: [Color.purple.opacity(0.08), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .frame(width: 250, height: 250)
                        .offset(x: -80, y: geometry.size.height - 150)
                }

                TabView(selection: $selectedPage) {
                    TranscriptHistoryPage(
                        history: viewModel.localTranscriptHistory,
                        onDelete: { id in
                            viewModel.removeLocalTranscriptRecord(id: id)
                        },
                        onDismissKeyboard: dismissKeyboard
                    )
                    .padding()
                    .tag(0)

                    PrimaryRecognitionPage(
                        viewModel: viewModel,
                        focusedField: $focusedField,
                        onDismissKeyboard: dismissKeyboard
                    )
                        .padding()
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
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
                viewModel.preparePrimaryExperience()
                if !hasLaunchedBefore {
                    showOnboarding = true
                    hasLaunchedBefore = true
                }
            }
            .onChange(of: selectedPage) { _, _ in
                dismissKeyboard()
            }
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
    }
}

struct TranscriptCard: View {
    @Binding var transcriptText: String
    let focusedField: FocusState<ContentView.FocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "transcript_card_title"))
                .font(.headline)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $transcriptText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                    .focused(focusedField, equals: .transcriptEditor)

                if transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "transcript_card_placeholder"))
                            .font(.body)
                            .foregroundColor(.primary)
                        Text(String(localized: "transcript_card_hint"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrimaryRecognitionPage: View {
    @ObservedObject var viewModel: ContentViewModel
    let focusedField: FocusState<ContentView.FocusField?>.Binding
    let onDismissKeyboard: () -> Void

    var body: some View {
        VStack {
            TranscriptCard(
                transcriptText: Binding(
                    get: { viewModel.localTranscriptText },
                    set: { viewModel.updateLocalTranscriptText($0) }
                ),
                focusedField: focusedField
            )
                .padding(.bottom, 16)

            if viewModel.shouldShowMacConnectionCard {
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

            RecognitionStatusView(
                state: viewModel.recognitionState,
                statusMessage: viewModel.pushToTalkStatusMessage,
                isEnabled: viewModel.canStartPushToTalk || viewModel.recognitionState != .idle,
                canManuallySendTextToMac: viewModel.canManuallyForwardCurrentTextToMac,
                showsPairingAction: false,
                showsReconnectAction: false,
                audioLevel: viewModel.audioLevel,
                onPressChanged: { isPressing in
                    if isPressing {
                        onDismissKeyboard()
                    }
                    viewModel.handlePrimaryButtonPressChanged(isPressing)
                },
                onManualSend: {
                    onDismissKeyboard()
                    viewModel.sendCurrentTranscriptToMac()
                }
            )

            Spacer()
        }
    }
}

struct TranscriptHistoryPage: View {
    let history: [LocalTranscriptRecord]
    let onDelete: (UUID) -> Void
    let onDismissKeyboard: () -> Void
    @State private var pendingDeleteRecord: LocalTranscriptRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "transcript_history_page_title"))
                .font(.headline)

            if history.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "transcript_history_empty_title"))
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(String(localized: "transcript_history_empty_hint"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(16)
            } else {
                List {
                    ForEach(history) { record in
                        TranscriptHistoryRow(record: record)
                            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                            .listRowBackground(Color(uiColor: .secondarySystemBackground))
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    pendingDeleteRecord = record
                                } label: {
                                    Text(String(localized: "delete_button"))
                                }
                                .tint(.orange)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        onDismissKeyboard()
                    }
                )
            }

            Text(String(localized: "transcript_history_swipe_hint"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert(
            String(localized: "transcript_history_delete_title"),
            isPresented: Binding(
                get: { pendingDeleteRecord != nil },
                set: { if !$0 { pendingDeleteRecord = nil } }
            ),
            presenting: pendingDeleteRecord
        ) { record in
            Button(String(localized: "delete_button"), role: .destructive) {
                onDelete(record.id)
                pendingDeleteRecord = nil
            }
            Button(String(localized: "cancel_button"), role: .cancel) {
                pendingDeleteRecord = nil
            }
        } message: { record in
            Text(String(format: String(localized: "transcript_history_delete_message"), record.text))
        }
    }
}

struct TranscriptHistoryRow: View {
    let record: LocalTranscriptRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.text)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = record.text
                    } label: {
                        Label(String(localized: "copy_button"), systemImage: "doc.on.doc")
                    }
                }

            Text(record.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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
    let canManuallySendTextToMac: Bool
    let showsPairingAction: Bool
    let showsReconnectAction: Bool
    let audioLevel: CGFloat
    let onPressChanged: (Bool) -> Void
    let onManualSend: () -> Void

    @State private var isPressing = false
    @State private var isSendTargetActive = false
    @State private var hasStartedPressAction = false
    @State private var pendingPressWorkItem: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                if shouldShowManualSendTarget {
                    VStack(spacing: 8) {
                        Image(systemName: isSendTargetActive ? "paperplane.circle.fill" : "paperplane.circle")
                            .font(.system(size: 34))
                            .foregroundColor(isSendTargetActive ? .green : .secondary)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(isSendTargetActive ? Color.green.opacity(0.16) : Color(uiColor: .secondarySystemBackground))
                            )

                        Text(String(localized: isSendTargetActive ? "recognition_release_to_send" : "recognition_drag_up_to_send"))
                            .font(.caption)
                            .foregroundColor(isSendTargetActive ? .green : .secondary)
                    }
                    .offset(y: -125)
                    .transition(.opacity.combined(with: .scale))
                }

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
                    .onChanged { value in
                        guard isInteractionEnabled else { return }
                        if !isPressing {
                            isPressing = true
                            startPendingPressAction()
                        }

                        updateManualSendTarget(with: value.translation)
                    }
                    .onEnded { _ in
                        guard isPressing else { return }
                        finishInteraction()
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

    private var isInteractionEnabled: Bool {
        isEnabled || canManuallySendTextToMac
    }

    private var shouldShowManualSendTarget: Bool {
        isPressing && state == .idle && canManuallySendTextToMac
    }

    private func startPendingPressAction() {
        let workItem = DispatchWorkItem {
            guard isPressing, !isSendTargetActive, isEnabled else { return }
            hasStartedPressAction = true
            onPressChanged(true)
        }

        pendingPressWorkItem?.cancel()
        pendingPressWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func updateManualSendTarget(with translation: CGSize) {
        guard state == .idle, canManuallySendTextToMac, !hasStartedPressAction else {
            isSendTargetActive = false
            return
        }

        let reachedTarget = translation.height < -90 && abs(translation.width) < 90
        isSendTargetActive = reachedTarget

        if reachedTarget {
            pendingPressWorkItem?.cancel()
            pendingPressWorkItem = nil
        }
    }

    private func finishInteraction() {
        pendingPressWorkItem?.cancel()
        pendingPressWorkItem = nil

        if isSendTargetActive {
            if hasStartedPressAction {
                onPressChanged(false)
            }
            onManualSend()
        } else if hasStartedPressAction {
            onPressChanged(false)
        }

        isPressing = false
        isSendTargetActive = false
        hasStartedPressAction = false
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
        if isSendTargetActive {
            return String(localized: "recognition_release_to_send")
        }
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
