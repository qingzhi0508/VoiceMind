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
                    Section(header: Text(String(localized: "manual_step1_title"))) {
                        TextField(String(localized: "manual_ip_label"), text: $ipAddress)
                            .keyboardType(.decimalPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .ipAddress)
                            .placeholder(when: ipAddress.isEmpty) {
                                Text(String(localized: "manual_ip_placeholder")).foregroundColor(.gray)
                            }

                        TextField(String(localized: "manual_port_label"), text: $port)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .port)
                            .placeholder(when: port.isEmpty) {
                                Text(String(localized: "manual_port_placeholder")).foregroundColor(.gray)
                            }
                            .onChange(of: port) { _, newValue in
                                let digitsOnly = newValue.filter(\.isNumber)
                                if digitsOnly != port {
                                    port = digitsOnly
                                }
                            }
                    }

                    Section(header: Text(String(localized: "manual_section_instruction"))) {
                        Text(String(localized: "manual_instruction_connect"))
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
                        PairingProgressView(title: String(localized: "manual_progress_title"), steps: progressSteps)
                    }

                } else {
                    // Step 2: Pairing Code
                    Section(header: Text(String(localized: "manual_step2_title"))) {
                        TextField(String(localized: "manual_pairing_code_label"), text: $pairingCode)
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

                    Section(header: Text(String(localized: "manual_section_instruction"))) {
                        Text(String(localized: "manual_instruction_pairing"))
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
                        PairingProgressView(title: String(localized: "manual_progress_title"), steps: progressSteps)
                    }

                }
            }
            .navigationTitle(isConnected ? String(localized: "manual_nav_title_pair") : String(localized: "manual_nav_title_connect"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel_button")) {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
            }
            .onAppear {
                focusedField = isConnected ? .pairingCode : .ipAddress
                appendProgress(String(localized: "manual_progress_waiting_input"))
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
                if newValue.contains(keywordIncorrect) || newValue.contains(keywordNotInPairingMode) || newValue.contains(keywordFailed) {
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
                title: String(localized: "manual_step_connect_title"),
                detail: progressMessages.first ?? String(localized: "manual_step_connect_detail_default"),
                state: connectStepState
            ),
            PairingStepItem(
                id: "code",
                title: String(localized: "manual_step_code_title"),
                detail: pairingCodeStepDetail,
                state: codeStepState
            ),
            PairingStepItem(
                id: "finish",
                title: String(localized: "manual_step_finish_title"),
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
            return String(localized: "manual_action_connecting")
        }
        if isPairing {
            return String(localized: "manual_action_pairing")
        }
        return isConnected ? String(localized: "manual_action_pair") : String(localized: "manual_action_connect")
    }

    private var actionButtonDisabled: Bool {
        if isConnected {
            return pairingCode.count != 6 || isPairing
        }
        return ipAddress.isEmpty || port.isEmpty || isConnecting || isPairing
    }

    private var connectStepState: PairingStepState {
        if let errorMessage, errorMessage.contains(keywordConnection) {
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
        if let errorMessage, !errorMessage.contains(keywordConnection) {
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
        if let errorMessage, !errorMessage.contains(keywordConnection) {
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
        if let message = progressMessages.last(where: { $0.contains(keywordPairingCode) || $0.contains(keywordValidation) || $0.contains(keywordPairingMode) }) {
            return message
        }
        return isConnected ? String(localized: "manual_pairing_code_step_detail_connected") : String(localized: "manual_pairing_code_step_detail_waiting")
    }

    private var finishStepDetail: String {
        if let message = progressMessages.last(where: { $0.contains(keywordSuccess) || $0.contains(keywordBinding) || $0.contains(keywordReturn) }) {
            return message
        }
        return String(localized: "manual_finish_step_detail_default")
    }

    private func connect() {
        guard let portNumber = UInt16(port) else {
            errorMessage = String(localized: "manual_error_invalid_port")
            return
        }

        isConnecting = true
        isPairing = false
        isConnected = false
        errorMessage = nil
        connectionTimeoutTask?.cancel()
        viewModel.clearPairingFeedback()
        progressMessages.removeAll()
        appendProgress(String(format: String(localized: "manual_progress_connection_request_format"), "\(ipAddress):\(portNumber)"))
        appendProgress(String(localized: "manual_progress_waiting_accept"))

        print("📡 尝试连接到: \(ipAddress):\(portNumber)")

        // Connect to Mac
        viewModel.connectToMac(ip: ipAddress, port: portNumber)

        let timeoutTask = DispatchWorkItem {
            guard isConnecting else { return }
            isConnecting = false
            errorMessage = String(localized: "manual_error_timeout")
        }
        connectionTimeoutTask = timeoutTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeoutTask)
    }

    private func pair() {
        guard pairingCode.count == 6 else {
            errorMessage = String(localized: "manual_error_pairing_code_required")
            return
        }

        errorMessage = nil
        focusedField = nil
        isPairing = true
        pairingTimeoutTask?.cancel()
        viewModel.clearPairingFeedback()
        appendProgress(String(localized: "manual_progress_sent_code"))
        appendProgress(String(localized: "manual_progress_waiting_validate"))
        print("🔐 发送配对码: \(pairingCode)")

        // Send pairing code
        viewModel.pairWithCode(pairingCode)

        let timeoutTask = DispatchWorkItem {
            guard isPairing else { return }
            isPairing = false
            errorMessage = String(localized: "manual_error_pairing_timeout")
        }
        pairingTimeoutTask = timeoutTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeoutTask)
    }

    private func handleConnectionStateChange(_ state: ConnectionState) {
        switch state {
        case .connecting:
            appendProgress(String(localized: "manual_progress_connecting"))
        case .connected:
            appendProgress(String(localized: "manual_progress_connected"))
            connectionTimeoutTask?.cancel()
            isConnecting = false
            isConnected = true
            errorMessage = nil
            print("✅ 连接成功")
        case .error(let message):
            appendProgress(String(format: String(localized: "manual_progress_connection_failed_format"), message))
            connectionTimeoutTask?.cancel()
            isConnecting = false
            isConnected = false
            if isPairing {
                pairingTimeoutTask?.cancel()
                isPairing = false
            }
            errorMessage = String(format: String(localized: "manual_error_connection_failed_format"), message)
            print("❌ 连接失败: \(message)")
        case .disconnected:
            appendProgress(String(localized: "manual_progress_disconnected"))
            if isConnecting {
                connectionTimeoutTask?.cancel()
                isConnecting = false
                errorMessage = String(localized: "manual_error_disconnected_retry")
                print("❌ 连接已断开")
            }
        }
    }

    private func handlePairingStateChange(_ state: PairingState) {
        switch state {
        case .paired:
            appendProgress(String(localized: "manual_progress_pairing_success"))
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

    private var keywordConnection: String { String(localized: "keyword_connection") }
    private var keywordPairingCode: String { String(localized: "keyword_pairing_code") }
    private var keywordValidation: String { String(localized: "keyword_validation") }
    private var keywordPairingMode: String { String(localized: "keyword_pairing_mode") }
    private var keywordSuccess: String { String(localized: "keyword_success") }
    private var keywordBinding: String { String(localized: "keyword_binding") }
    private var keywordReturn: String { String(localized: "keyword_return") }
    private var keywordFailed: String { String(localized: "keyword_failed") }
    private var keywordIncorrect: String { String(localized: "keyword_incorrect") }
    private var keywordNotInPairingMode: String { String(localized: "keyword_not_in_pairing_mode") }
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
