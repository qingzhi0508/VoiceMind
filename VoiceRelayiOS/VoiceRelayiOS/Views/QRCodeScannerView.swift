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
                Text("扫描 Mac 上的二维码")
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
                                    Text("正在启动相机...")
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
                        Text("连接中...")
                    }
                }

                if !progressMessages.isEmpty {
                    PairingProgressView(title: "当前进度", steps: progressSteps)
                }

                Button("手动输入连接信息") {
                    showManualInput = true
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .navigationTitle("扫码配对")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
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
                if newValue.contains("不正确") || newValue.contains("不在配对模式") || newValue.contains("失败") {
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
                title: "扫描二维码",
                detail: scanStepDetail,
                state: scanStepState
            ),
            PairingStepItem(
                id: "connect",
                title: "建立连接",
                detail: connectionStepDetail,
                state: connectionStepState
            ),
            PairingStepItem(
                id: "finish",
                title: "完成绑定",
                detail: finishStepDetail,
                state: finishStepState
            )
        ]
    }

    private var scanStepState: PairingStepState {
        if let errorMessage, errorMessage.contains("二维码") {
            return .failed
        }
        return connectionInfo == nil ? .active : .completed
    }

    private var connectionStepState: PairingStepState {
        if let errorMessage, errorMessage.contains("连接") {
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
           (feedback.contains("不正确") || feedback.contains("不在配对模式") || feedback.contains("失败")) {
            return .failed
        }
        if case .paired = viewModel.pairingState {
            return .completed
        }
        return isPairing ? .active : .pending
    }

    private var scanStepDetail: String {
        if let message = progressMessages.first(where: { $0.contains("二维码") || $0.contains("扫码") || $0.contains("连接信息") }) {
            return message
        }
        return "扫描 Mac 上展示的二维码，读取连接信息。"
    }

    private var connectionStepDetail: String {
        if let message = progressMessages.last(where: { $0.contains("连接") }) {
            return message
        }
        return "扫码成功后会自动连接到 Mac。"
    }

    private var finishStepDetail: String {
        if let message = progressMessages.last(where: { $0.contains("配对") || $0.contains("绑定") || $0.contains("返回") || $0.contains("成功") }) {
            return message
        }
        return "连接成功后输入配对码，等待 Mac 完成绑定。"
    }

    private func startScanning() {
        appendProgress("正在等待扫码，读取 Mac 的连接信息。")
        scanner.requestCameraPermission { granted in
            if granted {
                _ = scanner.startScanning()
            } else {
                errorMessage = "需要相机权限才能扫描二维码"
            }
        }
    }

    private func handleScannedCode(_ code: String) {
        print("📱 扫描到二维码: \(code)")

        guard let info = ConnectionInfo.fromQRCodeString(code) else {
            errorMessage = "无效的二维码格式"
            appendProgress("二维码解析失败，请重新扫描。")
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
        appendProgress("二维码解析成功，已识别设备：\(info.deviceName)")
        appendProgress("正在连接 \(info.ip):\(info.port)...")

        print("📡 连接到: \(info.ip):\(info.port)")

        // Connect to Mac
        viewModel.connectToMac(ip: info.ip, port: info.port, deviceName: info.deviceName)

        let timeoutTask = DispatchWorkItem {
            guard isConnecting else { return }
            isConnecting = false
            errorMessage = "连接超时，请重新扫描二维码或稍后重试"
            appendProgress("连接超时，请重新扫描二维码。")
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
        appendProgress("已提交 6 位配对码。")
        appendProgress("正在等待 Mac 校验配对码并返回结果...")
        viewModel.pairWithCode(code, deviceName: connectionInfo?.deviceName)

        let timeoutTask = DispatchWorkItem {
            guard isPairing else { return }
            isPairing = false
            errorMessage = "配对超时，请确认 Mac 仍处于配对状态"
            appendProgress("配对超时，请重新输入配对码。")
        }
        pairingTimeoutTask = timeoutTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeoutTask)
    }

    private func handleConnectionStateChange(_ state: ConnectionState) {
        switch state {
        case .connecting:
            appendProgress("正在建立连接...")
        case .connected:
            connectionTimeoutTask?.cancel()
            isConnecting = false
            appendProgress("连接已建立，请输入 Mac 上显示的 6 位配对码。")
            if connectionInfo != nil, !showPairingCodeInput, !isPairing {
                print("✅ 连接成功，显示配对码输入")
                showPairingCodeInput = true
            }
        case .error(let message):
            connectionTimeoutTask?.cancel()
            isConnecting = false
            appendProgress("连接失败：\(message)")
            errorMessage = "连接失败：\(message)"
            scanner.scannedCode = nil
            connectionInfo = nil
        case .disconnected:
            if isConnecting || isPairing {
                appendProgress("连接已断开。")
            }
            isConnecting = false
        }
    }

    private func handlePairingStateChange(_ state: PairingState) {
        switch state {
        case .paired:
            pairingTimeoutTask?.cancel()
            isPairing = false
            appendProgress("收到 Mac 的配对成功返回，设备已绑定。")
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
                Text("输入配对码")
                    .font(.title2)
                    .padding(.top)

                if let info = connectionInfo {
                    VStack(spacing: 8) {
                        Text("已连接到:")
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
                    Text("请输入 Mac 上显示的 6 位数字")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("配对码", text: $pairingCode)
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
                    Button("取消") {
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
                Text("配对")
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
