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
    @State private var errorMessage: String?

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
            .onChange(of: scanner.scannedCode) { newValue in
                if let code = newValue {
                    handleScannedCode(code)
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

    private func startScanning() {
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

        print("📡 连接到: \(info.ip):\(info.port)")

        // Connect to Mac
        viewModel.connectToMac(ip: info.ip, port: info.port)

        // Wait for connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isConnecting = false
            if viewModel.connectionState == .connected {
                print("✅ 连接成功，显示配对码输入")
                showPairingCodeInput = true
            } else {
                print("❌ 连接失败")
                errorMessage = "连接失败，请重试"
                scanner.scannedCode = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    errorMessage = nil
                    startScanning()
                }
            }
        }
    }

    private func pairWithCode(_ code: String) {
        print("🔐 使用配对码: \(code)")
        viewModel.pairWithCode(code)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if case .paired = viewModel.pairingState {
                print("✅ 配对成功")
                dismiss()
            } else {
                print("❌ 配对失败")
                errorMessage = "配对失败，请检查配对码"
            }
        }
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

                Button(action: {
                    onPair(pairingCode)
                    dismiss()
                }) {
                    Text("配对")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(pairingCode.count == 6 ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(pairingCode.count != 6)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                        dismiss()
                    }
                }
            }
            .onAppear {
                isPairingCodeFocused = true
            }
        }
    }
}
