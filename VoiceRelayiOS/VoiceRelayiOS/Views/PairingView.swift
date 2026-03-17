import SwiftUI

struct PairingView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pairingCode = ""
    @State private var selectedService: DiscoveredService?
    @State private var showQRCodeScanner = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isPairing = false
    @State private var progressMessages: [String] = []
    @FocusState private var isPairingCodeFocused: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: “laptopcomputer.and.iphone”)
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text(“与 Mac 配对”)
                            .font(.title)
                            .fontWeight(.bold)

                        Text(“优先使用扫码配对，也可以继续使用局域网自动发现。”)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 12) {
                        Button {
                            showQRCodeScanner = true
                        } label: {
                            HStack {
                                Image(systemName: “qrcode.viewfinder”)
                                Text(“扫描二维码配对”)
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        Text(“在 Mac 上点击”配对新设备”，然后扫描弹出的二维码。”)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Discovered Macs
                    VStack(alignment: .leading, spacing: 15) {
                        Text(“或手动选择局域网中的 Mac”)
                            .font(.headline)

                        if viewModel.discoveredServices.isEmpty {
                            HStack {
                                ProgressView()
                                Text(“搜索中...”)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        } else {
                            ForEach(viewModel.discoveredServices) { service in
                                ServiceRow(
                                    service: service,
                                    isSelected: selectedService?.id == service.id
                                )
                                .onTapGesture {
                                    selectedService = service
                                }
                            }
                        }
                    }

                    // Pairing Code Input
                    VStack(alignment: .leading, spacing: 10) {
                        Text(“配对码”)
                            .font(.headline)

                        TextField(“输入 6 位数字”, text: $pairingCode)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
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

                    if !progressMessages.isEmpty {
                        PairingProgressView(title: “当前进度”, steps: progressSteps)
                    }

                    // 添加底部间距，为按钮留出空间
                    Spacer()
                        .frame(height: 80)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(“取消”) {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                pairButtonBar
            }
            .alert(“配对失败”, isPresented: $showError) {
                Button(“确定”, role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showQRCodeScanner) {
                QRCodeScannerView(viewModel: viewModel)
            }
            .onAppear {
                isPairingCodeFocused = true
                appendProgress(“请选择一台已发现的 Mac，并输入 6 位配对码。”)
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
                    errorMessage = newValue
                    showError = true
                }
            }
        }
    }

    private var progressSteps: [PairingStepItem] {
        [
            PairingStepItem(
                id: "select",
                title: "选择设备",
                detail: selectionStepDetail,
                state: selectionStepState
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

    private var selectionStepState: PairingStepState {
        if selectedService != nil && pairingCode.count == 6 {
            return .completed
        }
        return isPairing ? .active : .pending
    }

    private var connectionStepState: PairingStepState {
        // 检查是否有连接失败的反馈
        if let latestPairingFeedback = viewModel.latestPairingFeedback,
           latestPairingFeedback.contains("失败") || latestPairingFeedback.contains("连接") && latestPairingFeedback.contains("断开") {
            return .failed
        }

        // 如果选择步骤还没完成，连接步骤应该是 pending
        if selectionStepState != .completed {
            return .pending
        }

        switch viewModel.connectionState {
        case .connected:
            return .completed
        case .connecting:
            return .active
        case .error:
            return .failed
        case .disconnected:
            // 只有在配对过程中且选择步骤已完成时，才显示为 active
            return isPairing ? .active : .pending
        }
    }

    private var finishStepState: PairingStepState {
        if let latestPairingFeedback = viewModel.latestPairingFeedback,
           (latestPairingFeedback.contains("不正确") || latestPairingFeedback.contains("不在配对模式") || latestPairingFeedback.contains("失败")) {
            return .failed
        }
        if case .paired = viewModel.pairingState {
            return .completed
        }
        return isPairing ? .active : .pending
    }

    private var selectionStepDetail: String {
        if let service = selectedService {
            return "已选择 \(service.name)，配对码长度 \(pairingCode.count)/6。"
        }
        return "从局域网列表中选择一台 Mac。"
    }

    private var connectionStepDetail: String {
        if let message = progressMessages.last(where: { $0.contains("连接") }) {
            return message
        }
        return "连接成功后会自动发送配对请求。"
    }

    private var finishStepDetail: String {
        if let message = progressMessages.last(where: { $0.contains("成功") || $0.contains("返回") || $0.contains("配对") }) {
            return message
        }
        return "等待 Mac 校验配对码并完成绑定。"
    }

    private var canPair: Bool {
        selectedService != nil && pairingCode.count == 6 && !isPairing
    }

    private var pairButtonBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: startPairing) {
                HStack {
                    if isPairing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isPairing ? "配对中..." : "配对")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canPair)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.regularMaterial)
        }
    }

    private func startPairing() {
        guard let service = selectedService else { return }

        print("🚀 开始配对流程")
        print("   选择的服务: \(service.name)")
        print("   地址: \(service.host):\(service.port)")
        print("   配对码: \(pairingCode)")

        isPairing = true
        errorMessage = ""
        showError = false
        viewModel.clearPairingFeedback()
        progressMessages.removeAll()
        appendProgress("已选择 Mac：\(service.name)")
        appendProgress("正在连接 \(service.host):\(service.port)...")
        appendProgress("连接成功后会自动发送配对码。")
        viewModel.pair(with: service, code: pairingCode)
    }

    private func handleConnectionStateChange(_ state: ConnectionState) {
        print("🔄 连接状态变化: \(state)")

        switch state {
        case .connecting:
            if isPairing {
                appendProgress("正在建立连接...")
            }
        case .connected:
            if isPairing {
                appendProgress("连接已建立，正在等待 Mac 处理配对请求。")
            }
        case .error(let message):
            if isPairing {
                appendProgress("连接失败：\(message)")
                isPairing = false
                errorMessage = "连接失败：\(message)"
                showError = true
            }
        case .disconnected:
            if isPairing {
                appendProgress("连接已断开。")
            }
        }
    }

    private func handlePairingStateChange(_ state: PairingState) {
        switch state {
        case .paired:
            if isPairing {
                appendProgress("收到 Mac 的配对成功返回，正在完成绑定。")
                isPairing = false
                dismiss()
            }
        case .unpaired, .pairing:
            break
        }
    }

    private func appendProgress(_ message: String) {
        guard progressMessages.last != message else { return }
        progressMessages.append(message)
    }
}

struct ServiceRow: View {
    let service: DiscoveredService
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: "laptopcomputer")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(.headline)

                Text("\(service.host):\(service.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}
