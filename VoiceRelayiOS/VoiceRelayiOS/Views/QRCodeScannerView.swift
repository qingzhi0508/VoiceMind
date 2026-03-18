import SwiftUI
import AVFoundation
import SharedCore

struct QRCodeScannerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ContentViewModel

    @StateObject private var scanner = QRCodeScannerController()
    @State private var showManualInput = false
    @State private var showPairingCodeInput = false
    @State private var pairingCode = ""
    @State private var connectionInfo: ConnectionInfo?
    @State private var isConnecting = false
    @State private var isPairing = false
    @State private var errorMessage: String?
    @State private var progressMessages: [String] = []
    @State private var connectionTimeoutTask: DispatchWorkItem?
    @State private var pairingTimeoutTask: DispatchWorkItem?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(String(localized: "qr_scan_title"))
                    .font(.headline)
                    .padding(.top)

                // Camera Preview
                ZStack {
                    if let previewLayer = scanner.previewLayer {
                        CameraPreview(previewLayer: previewLayer)
                            .frame(height: 300)
                            .cornerRadius(12)
                    } else {
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 300)
                            .cornerRadius(12)
                            .overlay(
                                VStack {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white)
                                    Text(String(localized: "qr_camera_starting"))
                                        .foregroundColor(.white)
                                        .padding(.top)
                                }
                            )
                    }

                    // Scanning frame
                    Rectangle()
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 250, height: 250)
                }
                .padding()

                if let error = scanner.error ?? errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                        .multilineTextAlignment(.center)
                }

                if isConnecting {
                    HStack {
                        ProgressView()
                        Text(String(localized: "qr_connecting"))
                    }
                }

                if !progressMessages.isEmpty {
                    PairingProgressView(title: String(localized: "qr_progress_title"), steps: progressSteps)
                }

                Button(String(localized: "qr_manual_input")) {
                    showManualInput = true
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .navigationTitle(String(localized: "qr_nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel_button")) {
                        scanner.stopScanning()
                        dismiss()
                    }
                }
            }
            .onAppear {
                startScanning()
            }
            .onDisappear {
                scanner.stopScanning()
            }
            .onChange(of: scanner.scannedCode) { _, newValue in
                if let code = newValue {
                    handleScannedCode(code)
                }
            }
            .onChange(of: viewModel.connectionState) { _, newValue in
                handleConnectionStateChange(newValue)
            }
            .onChange(of: viewModel.pairingState) { _, newValue in
                handlePairingStateChange(newValue)
            }
            .onChange(of: viewModel.latestPairingFeedback) { _, newValue in
                guard let newValue else { return }
                appendProgress(newValue)
                if newValue.contains(keywordIncorrect) || newValue.contains(keywordNotInPairingMode) || newValue.contains(keywordFailed) {
                    isPairing = false
                    pairingTimeoutTask?.cancel()
                    errorMessage = newValue
                }
            }
            .sheet(isPresented: $showManualInput) {
                ManualConnectionView(viewModel: viewModel)
            }
            .sheet(isPresented: $showPairingCodeInput) {
                PairingCodeInputView(
                    connectionInfo: connectionInfo,
                    onPair: { code in
                        pairWithCode(code)
                    },
                    onCancel: {
                        showPairingCodeInput = false
                        scanner.scannedCode = nil
                        startScanning()
                    }
                )
            }
        }
    }

    private var progressSteps: [PairingStepItem] {
        [
            PairingStepItem(
                id: "scan",
                title: String(localized: "qr_scan_step_title"),
                detail: scanStepDetail,
                state: scanStepState
            ),
            PairingStepItem(
                id: "connect",
                title: String(localized: "qr_connect_step_title"),
                detail: connectionStepDetail,
                state: connectionStepState
            ),
            PairingStepItem(
                id: "finish",
                title: String(localized: "qr_finish_step_title"),
                detail: finishStepDetail,
                state: finishStepState
            )
        ]
    }

    private var scanStepState: PairingStepState {
        if let errorMessage, errorMessage.contains(keywordQR) {
            return .failed
        }
        return connectionInfo == nil ? .active : .completed
    }

    private var connectionStepState: PairingStepState {
        if let errorMessage, errorMessage.contains(keywordConnection) {
            return .failed
        }
        switch viewModel.connectionState {
        case .connected:
            return .completed
        case .connecting:
            return .active
        case .error:
            return .failed
        case .disconnected:
            return isConnecting ? .active : .pending
        }
    }

    private var finishStepState: PairingStepState {
        if let feedback = viewModel.latestPairingFeedback,
           (feedback.contains(keywordIncorrect) || feedback.contains(keywordNotInPairingMode) || feedback.contains(keywordFailed)) {
            return .failed
        }
        if case .paired = viewModel.pairingState {
            return .completed
        }
        return isPairing ? .active : .pending
    }

    private var scanStepDetail: String {
        if let message = progressMessages.first(where: { $0.contains(keywordQR) || $0.contains(keywordScan) || $0.contains(keywordConnectionInfo) }) {
            return message
        }
        return String(localized: "qr_scan_step_detail_default")
    }

    private var connectionStepDetail: String {
        if let message = progressMessages.last(where: { $0.contains(keywordConnection) }) {
            return message
        }
        return String(localized: "qr_connect_step_detail_default")
    }

    private var finishStepDetail: String {
        if let message = progressMessages.last(where: { $0.contains(keywordPairingCode) || $0.contains(keywordBinding) || $0.contains(keywordReturn) || $0.contains(keywordSuccess) }) {
            return message
        }
        return String(localized: "qr_finish_step_detail_default")
    }

    private func startScanning() {
        appendProgress(String(localized: "qr_progress_waiting_scan"))
        scanner.requestCameraPermission { granted in
            if granted {
                _ = scanner.startScanning()
            } else {
                errorMessage = String(localized: "qr_error_camera_permission")
            }
        }
    }

    private func handleScannedCode(_ code: String) {
        print("📱 扫描到二维码: \(code)")

        guard let info = ConnectionInfo.fromQRCodeString(code) else {
            errorMessage = String(localized: "qr_error_invalid_code")
            appendProgress(String(localized: "qr_progress_qr_parse_failed"))
            scanner.scannedCode = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                errorMessage = nil
                startScanning()
            }
            return
        }

        connectionInfo = info
        isConnecting = true
        errorMessage = nil
        connectionTimeoutTask?.cancel()
        viewModel.clearPairingFeedback()
        progressMessages.removeAll()
        appendProgress(String(format: String(localized: "qr_progress_qr_parsed_format"), info.deviceName))
        appendProgress(String(format: String(localized: "qr_progress_qr_connecting_format"), info.ip, "\(info.port)"))

        print("📡 连接到: \(info.ip):\(info.port)")

        // Connect to Mac
        viewModel.connectToMac(ip: info.ip, port: info.port, deviceName: info.deviceName)

        let timeoutTask = DispatchWorkItem {
            guard isConnecting else { return }
            isConnecting = false
            errorMessage = String(localized: "qr_error_timeout")
            appendProgress(String(localized: "qr_progress_timeout"))
            scanner.scannedCode = nil
            connectionInfo = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                errorMessage = nil
                startScanning()
            }
        }
        connectionTimeoutTask = timeoutTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeoutTask)
    }

    private func pairWithCode(_ code: String) {
        print("🔐 使用配对码: \(code)")
        isPairing = true
        errorMessage = nil
        pairingTimeoutTask?.cancel()
        viewModel.clearPairingFeedback()
        appendProgress(String(localized: "qr_progress_sent_code"))
        appendProgress(String(localized: "qr_progress_waiting_validate"))
        viewModel.pairWithCode(code, deviceName: connectionInfo?.deviceName)

        let timeoutTask = DispatchWorkItem {
            guard isPairing else { return }
            isPairing = false
            errorMessage = String(localized: "qr_error_pairing_timeout")
            appendProgress(String(localized: "qr_progress_pairing_timeout"))
        }
        pairingTimeoutTask = timeoutTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeoutTask)
    }

    private func handleConnectionStateChange(_ state: ConnectionState) {
        switch state {
        case .connecting:
            appendProgress(String(localized: "qr_progress_connecting_state"))
        case .connected:
            connectionTimeoutTask?.cancel()
            isConnecting = false
            appendProgress(String(localized: "qr_progress_connected_enter_code"))
            if connectionInfo != nil, !showPairingCodeInput, !isPairing {
                print("✅ 连接成功，显示配对码输入")
                showPairingCodeInput = true
            }
        case .error(let message):
            connectionTimeoutTask?.cancel()
            isConnecting = false
            appendProgress(String(format: String(localized: "qr_progress_connection_failed_format"), message))
            errorMessage = String(format: String(localized: "qr_error_connection_failed_format"), message)
            scanner.scannedCode = nil
            connectionInfo = nil
        case .disconnected:
            if isConnecting || isPairing {
                appendProgress(String(localized: "qr_progress_disconnected"))
            }
            isConnecting = false
        }
    }

    private func handlePairingStateChange(_ state: PairingState) {
        switch state {
        case .paired:
            pairingTimeoutTask?.cancel()
            isPairing = false
            appendProgress(String(localized: "qr_progress_pairing_success"))
            print("✅ 配对成功")
            dismiss()
        case .unpaired, .pairing:
            break
        }
    }

    private func appendProgress(_ message: String) {
        guard progressMessages.last != message else { return }
        progressMessages.append(message)
    }

    private var keywordConnection: String { String(localized: "keyword_connection") }
    private var keywordQR: String { String(localized: "keyword_qr") }
    private var keywordScan: String { String(localized: "keyword_scan") }
    private var keywordConnectionInfo: String { String(localized: "keyword_connection_info") }
    private var keywordPairingCode: String { String(localized: "keyword_pairing_code") }
    private var keywordBinding: String { String(localized: "keyword_binding") }
    private var keywordReturn: String { String(localized: "keyword_return") }
    private var keywordSuccess: String { String(localized: "keyword_success") }
    private var keywordFailed: String { String(localized: "keyword_failed") }
    private var keywordIncorrect: String { String(localized: "keyword_incorrect") }
    private var keywordNotInPairingMode: String { String(localized: "keyword_not_in_pairing_mode") }
}

struct PairingCodeInputView: View {
    let connectionInfo: ConnectionInfo?
    let onPair: (String) -> Void
    let onCancel: () -> Void

    @State private var pairingCode = ""
    @Environment(\.dismiss) var dismiss
    @FocusState private var isPairingCodeFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text(String(localized: "qr_pairing_code_title"))
                    .font(.title2)
                    .padding(.top)

                if let info = connectionInfo {
                    VStack(spacing: 8) {
                        Text(String(localized: "qr_connected_to"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(info.deviceName)
                            .font(.headline)
                        Text("\(info.ip):\(info.port)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }

                VStack(spacing: 10) {
                    Text(String(localized: "qr_pairing_code_hint"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField(String(localized: "qr_pairing_code_placeholder"), text: $pairingCode)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 36, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .focused($isPairingCodeFocused)
                        .onChange(of: pairingCode) { _, newValue in
                            let digitsOnly = newValue.filter(\.isNumber)
                            let trimmed = String(digitsOnly.prefix(6))

                            if trimmed != pairingCode {
                                pairingCode = trimmed
                                return
                            }

                            if trimmed.count == 6 {
                                isPairingCodeFocused = false
                            }
                        }
                }
                .padding()

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel_button")) {
                        onCancel()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                pairButtonBar
            }
            .onAppear {
                isPairingCodeFocused = true
            }
        }
    }

    private var pairButtonBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: {
                onPair(pairingCode)
                dismiss()
            }) {
                Text(String(localized: "pairing_button_pair"))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(pairingCode.count != 6)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.regularMaterial)
        }
    }
}
