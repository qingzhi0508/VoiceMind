import SwiftUI
import SharedCore

struct ManualConnectionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ContentViewModel

    @State private var ipAddress = ""
    @State private var port = ""
    @State private var pairingCode = ""
    @State private var isConnecting = false
    @State private var isPairing = false
    @State private var isConnected = false
    @State private var errorMessage: String?
    @State private var connectionTimeoutTask: DispatchWorkItem?
    @State private var pairingTimeoutTask: DispatchWorkItem?
    @State private var progressMessages: [String] = []
    @FocusState private var focusedField: Field?

    private enum Field {
        case ipAddress
        case port
        case pairingCode
    }

    var body: some View {
        NavigationView {
            Form {
                if !isConnected {
                    // Step 1: Connection Info
                    Section(header: Text("第一步：连接到 Mac")) {
                        TextField("IP 地址", text: $ipAddress)
                            .keyboardType(.decimalPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .ipAddress)
                            .placeholder(when: ipAddress.isEmpty) {
                                Text("例如：192.168.1.100").foregroundColor(.gray)
                            }

                        TextField("端口", text: $port)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .port)
                            .placeholder(when: port.isEmpty) {
                                Text("例如：8899").foregroundColor(.gray)
                            }
                            .onChange(of: port) { _, newValue in
                                let digitsOnly = newValue.filter(\.isNumber)
                                if digitsOnly != port {
                                    port = digitsOnly
                                }
                            }
                    }

                    Section(header: Text("说明")) {
                        Text("在 Mac 上点击「开始配对」，然后输入显示的 IP 地址和端口号")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }

                    if !progressMessages.isEmpty {
                        PairingProgressView(title: "当前进度", steps: progressSteps)
                    }

                } else {
                    // Step 2: Pairing Code
                    Section(header: Text("第二步：输入配对码")) {
                        TextField("6位配对码", text: $pairingCode)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.title2, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .focused($focusedField, equals: .pairingCode)
                            .onChange(of: pairingCode) { _, newValue in
                                let digitsOnly = newValue.filter(\.isNumber)
                                let trimmed = String(digitsOnly.prefix(6))

                                if trimmed != pairingCode {
                                    pairingCode = trimmed
                                    return
                                }

                                if trimmed.count == 6 {
                                    focusedField = nil
                                }
                            }
                    }

                    Section(header: Text("说明")) {
                        Text("输入 Mac 上显示的 6 位数字配对码")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }

                    if !progressMessages.isEmpty {
                        PairingProgressView(title: "当前进度", steps: progressSteps)
                    }

                }
            }
            .navigationTitle(isConnected ? "输入配对码" : "手动连接")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
            }
            .onAppear {
                focusedField = isConnected ? .pairingCode : .ipAddress
                appendProgress("等待输入 Mac 的地址和端口。")
            }
            .onChange(of: isConnected) { _, newValue in
                focusedField = newValue ? .pairingCode : .ipAddress
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
        }
    }

    private var progressSteps: [PairingStepItem] {
        [
            PairingStepItem(
                id: "connect",
                title: "建立连接",
                detail: progressMessages.first ?? "输入 Mac 的地址和端口后开始连接。",
                state: connectStepState
            ),
            PairingStepItem(
                id: "code",
                title: "提交配对码",
                detail: pairingCodeStepDetail,
                state: codeStepState
            ),
            PairingStepItem(
                id: "finish",
                title: "完成绑定",
                detail: finishStepDetail,
                state: finishStepState
            )
        ]
    }

    @ViewBuilder
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: isConnected ? pair : connect) {
                HStack {
                    if isConnecting {
                        ProgressView()
                    } else if isPairing {
                        ProgressView()
                    }
                    Text(actionButtonTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(actionButtonDisabled)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.regularMaterial)
        }
    }

    private var actionButtonTitle: String {
        if isConnecting {
            return "连接中..."
        }
        if isPairing {
            return "配对中..."
        }
        return isConnected ? "配对" : "连接"
    }

    private var actionButtonDisabled: Bool {
        if isConnected {
            return pairingCode.count != 6 || isPairing
        }
        return ipAddress.isEmpty || port.isEmpty || isConnecting || isPairing
    }

    private var connectStepState: PairingStepState {
        if let errorMessage, errorMessage.contains("连接") {
            return .failed
        }
        if isConnected || viewModel.connectionState == .connected {
            return .completed
        }
        if isConnecting || viewModel.connectionState == .connecting {
            return .active
        }
        return .pending
    }

    private var codeStepState: PairingStepState {
        if let errorMessage, !errorMessage.contains("连接") {
            return .failed
        }
        if case .paired = viewModel.pairingState {
            return .completed
        }
        if isPairing {
            return .active
        }
        return isConnected ? .pending : .pending
    }

    private var finishStepState: PairingStepState {
        if let errorMessage, !errorMessage.contains("连接") {
            return .failed
        }
        if case .paired = viewModel.pairingState {
            return .completed
        }
        if isPairing {
            return .active
        }
        return .pending
    }

    private var pairingCodeStepDetail: String {
        if let message = progressMessages.last(where: { $0.contains("配对码") || $0.contains("校验") || $0.contains("配对模式") }) {
            return message
        }
        return isConnected ? "连接完成后，输入 6 位配对码并发送给 Mac。" : "等待连接完成后再输入配对码。"
    }

    private var finishStepDetail: String {
        if let message = progressMessages.last(where: { $0.contains("成功") || $0.contains("绑定") || $0.contains("返回") }) {
            return message
        }
        return "等待 Mac 返回配对结果并保存绑定关系。"
    }

    private func connect() {
        guard let portNumber = UInt16(port) else {
            errorMessage = "端口号无效"
            return
        }

        isConnecting = true
        isPairing = false
        isConnected = false
        errorMessage = nil
        connectionTimeoutTask?.cancel()
        viewModel.clearPairingFeedback()
        progressMessages.removeAll()
        appendProgress("已提交连接请求：\(ipAddress):\(portNumber)")
        appendProgress("正在等待 Mac 接受连接...")

        print("📡 尝试连接到: \(ipAddress):\(portNumber)")

        // Connect to Mac
        viewModel.connectToMac(ip: ipAddress, port: portNumber)

        let timeoutTask = DispatchWorkItem {
            guard isConnecting else { return }
            isConnecting = false
            errorMessage = "连接超时，请检查 IP 和端口是否正确，并确保 Mac 已启动服务"
        }
        connectionTimeoutTask = timeoutTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeoutTask)
    }

    private func pair() {
        guard pairingCode.count == 6 else {
            errorMessage = "请输入 6 位配对码"
            return
        }

        errorMessage = nil
        focusedField = nil
        isPairing = true
        pairingTimeoutTask?.cancel()
        viewModel.clearPairingFeedback()
        appendProgress("已发送 6 位配对码。")
        appendProgress("正在等待 Mac 校验配对码并返回结果...")
        print("🔐 发送配对码: \(pairingCode)")

        // Send pairing code
        viewModel.pairWithCode(pairingCode)

        let timeoutTask = DispatchWorkItem {
            guard isPairing else { return }
            isPairing = false
            errorMessage = "配对超时，请检查配对码是否正确，或确认 Mac 仍处于配对状态"
        }
        pairingTimeoutTask = timeoutTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeoutTask)
    }

    private func handleConnectionStateChange(_ state: ConnectionState) {
        switch state {
        case .connecting:
            appendProgress("连接建立中...")
        case .connected:
            appendProgress("连接已建立，可以输入配对码。")
            connectionTimeoutTask?.cancel()
            isConnecting = false
            isConnected = true
            errorMessage = nil
            print("✅ 连接成功")
        case .error(let message):
            appendProgress("Mac 返回连接失败：\(message)")
            connectionTimeoutTask?.cancel()
            isConnecting = false
            isConnected = false
            if isPairing {
                pairingTimeoutTask?.cancel()
                isPairing = false
            }
            errorMessage = "连接失败：\(message)"
            print("❌ 连接失败: \(message)")
        case .disconnected:
            appendProgress("连接已断开。")
            if isConnecting {
                connectionTimeoutTask?.cancel()
                isConnecting = false
                errorMessage = "连接已断开，请重试"
                print("❌ 连接已断开")
            }
        }
    }

    private func handlePairingStateChange(_ state: PairingState) {
        switch state {
        case .paired:
            appendProgress("收到 Mac 的配对成功返回，设备已绑定。")
            pairingTimeoutTask?.cancel()
            isPairing = false
            errorMessage = nil
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

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
