import SwiftUI

struct PairingView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_theme") private var appTheme: String = "system"
    @AppStorage(AppLightBackgroundTintPolicy.storageKey) private var lightThemeBackgroundHex: String = AppLightBackgroundTintPolicy.defaultHex
    @Environment(\.colorScheme) private var colorScheme

    @State private var pairingCode = ""
    @State private var selectedService: DiscoveredService?
    @State private var showQRCodeScanner = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isPairing = false
    @State private var progressMessages: [String] = []
    @State private var pairingTimeoutTask: DispatchWorkItem?
    @FocusState private var isPairingCodeFocused: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "laptopcomputer.and.iphone")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text(String(localized: "pairing_title"))
                            .font(.title)
                            .fontWeight(.bold)

                        Text(String(localized: "pairing_subtitle"))
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
                                Image(systemName: "qrcode.viewfinder")
                                Text(String(localized: "pairing_scan_button"))
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        Text(String(localized: "pairing_scan_hint"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Discovered Macs
                    VStack(alignment: .leading, spacing: 15) {
                        Text(String(localized: "pairing_or_manual_title"))
                            .font(.headline)

                        if viewModel.discoveredServices.isEmpty {
                            HStack {
                                ProgressView()
                                Text(String(localized: "pairing_searching"))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(searchingSurface)
                        } else {
                            ForEach(viewModel.discoveredServices) { service in
                                ServiceRow(
                                    service: service,
                                    isSelected: selectedService?.id == service.id,
                                    appTheme: appTheme,
                                    lightThemeBackgroundHex: lightThemeBackgroundHex
                                )
                                .onTapGesture {
                                    selectedService = service
                                }
                            }
                        }
                    }

                    // Pairing Code Input
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "pairing_code_title"))
                            .font(.headline)

                        TextField(String(localized: "pairing_code_placeholder"), text: $pairingCode)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(inputSurface)
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
                        PairingProgressView(title: String(localized: "pairing_progress_title"), steps: progressSteps)
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
                    Button(String(localized: "cancel_button")) {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                pairButtonBar
            }
            .alert(String(localized: "pairing_failed_title"), isPresented: $showError) {
                Button(String(localized: "ok_button"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showQRCodeScanner) {
                QRCodeScannerView(viewModel: viewModel)
            }
            .onAppear {
                isPairingCodeFocused = true
                appendProgress(String(localized: "pairing_initial_progress"))
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
                title: String(localized: "pairing_step_select_title"),
                detail: selectionStepDetail,
                state: selectionStepState
            ),
            PairingStepItem(
                id: "connect",
                title: String(localized: "pairing_step_connect_title"),
                detail: connectionStepDetail,
                state: connectionStepState
            ),
            PairingStepItem(
                id: "finish",
                title: String(localized: "pairing_step_finish_title"),
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
           latestPairingFeedback.contains(keywordFailed) || latestPairingFeedback.contains(keywordConnection) && latestPairingFeedback.contains(keywordDisconnected) {
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
           (latestPairingFeedback.contains(keywordIncorrect) || latestPairingFeedback.contains(keywordNotInPairingMode) || latestPairingFeedback.contains(keywordFailed)) {
            return .failed
        }
        if case .paired = viewModel.pairingState {
            return .completed
        }
        return isPairing ? .active : .pending
    }

    private var selectionStepDetail: String {
        if let service = selectedService {
            return String(format: String(localized: "pairing_select_detail_format"), service.name, "\(pairingCode.count)")
        }
        return String(localized: "pairing_select_detail_default")
    }

    private var connectionStepDetail: String {
        if let message = progressMessages.last(where: { $0.contains(keywordConnection) }) {
            return message
        }
        return String(localized: "pairing_connection_detail_default")
    }

    private var finishStepDetail: String {
        if let message = progressMessages.last(where: { $0.contains(keywordSuccess) || $0.contains(keywordReturn) || $0.contains(keywordPairingCode) }) {
            return message
        }
        return String(localized: "pairing_finish_detail_default")
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
                    Text(isPairing ? String(localized: "pairing_button_pairing") : String(localized: "pairing_button_pair"))
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
            .background(bottomBarSurface)
        }
    }

    private var searchingSurface: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                AppSurfaceStylePolicy.softPanelFill(
                    appTheme: appTheme,
                    colorScheme: colorScheme,
                    lightBackgroundHex: lightThemeBackgroundHex
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        AppSurfaceStylePolicy.softPanelStroke(
                            appTheme: appTheme,
                            colorScheme: colorScheme,
                            lightBackgroundHex: lightThemeBackgroundHex
                        ),
                        lineWidth: 1
                    )
            )
    }

    private var inputSurface: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                AppSurfaceStylePolicy.softPanelFill(
                    appTheme: appTheme,
                    colorScheme: colorScheme,
                    lightBackgroundHex: lightThemeBackgroundHex
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        AppSurfaceStylePolicy.softPanelStroke(
                            appTheme: appTheme,
                            colorScheme: colorScheme,
                            lightBackgroundHex: lightThemeBackgroundHex
                        ),
                        lineWidth: 1
                    )
            )
    }

    private var bottomBarSurface: some View {
        AppSurfaceStylePolicy.bottomBarFill(
            appTheme: appTheme,
            colorScheme: colorScheme,
            lightBackgroundHex: lightThemeBackgroundHex
        )
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
        pairingTimeoutTask?.cancel()
        viewModel.clearPairingFeedback()
        progressMessages.removeAll()
        appendProgress(String(format: String(localized: "pairing_progress_selected_mac_format"), service.name))
        appendProgress(String(format: String(localized: "pairing_progress_connecting_format"), service.host, "\(service.port)"))
        appendProgress(String(localized: "pairing_progress_send_after_connect"))
        viewModel.pair(with: service, code: pairingCode)

        let timeoutTask = DispatchWorkItem {
            guard isPairing else { return }
            appendProgress(String(localized: "pairing_timeout_no_response"))
            isPairing = false
            errorMessage = String(localized: "pairing_error_timeout")
            showError = true
        }
        pairingTimeoutTask = timeoutTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeoutTask)
    }

    private func handleConnectionStateChange(_ state: ConnectionState) {
        print("🔄 连接状态变化: \(state)")

        switch state {
        case .connecting:
            if isPairing {
                appendProgress(String(localized: "pairing_progress_connecting_state"))
            }
        case .connected:
            if isPairing {
                appendProgress(String(localized: "pairing_progress_connected_waiting"))
            }
        case .error(let message):
            if isPairing {
                pairingTimeoutTask?.cancel()
                appendProgress(String(format: String(localized: "pairing_progress_connection_failed_format"), message))
                isPairing = false
                errorMessage = String(format: String(localized: "pairing_error_connection_failed_format"), message)
                showError = true
            }
        case .disconnected:
            if isPairing {
                appendProgress(String(localized: "pairing_progress_disconnected"))
                pairingTimeoutTask?.cancel()
                isPairing = false
                errorMessage = String(localized: "pairing_error_disconnected_retry")
                showError = true
            }
        }
    }

    private func handlePairingStateChange(_ state: PairingState) {
        switch state {
        case .paired:
            if isPairing {
                pairingTimeoutTask?.cancel()
                appendProgress(String(localized: "pairing_progress_pairing_success"))
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

    private var keywordConnection: String { String(localized: "keyword_connection") }
    private var keywordDisconnected: String { String(localized: "keyword_disconnected") }
    private var keywordFailed: String { String(localized: "keyword_failed") }
    private var keywordIncorrect: String { String(localized: "keyword_incorrect") }
    private var keywordNotInPairingMode: String { String(localized: "keyword_not_in_pairing_mode") }
    private var keywordSuccess: String { String(localized: "keyword_success") }
    private var keywordReturn: String { String(localized: "keyword_return") }
    private var keywordPairingCode: String { String(localized: "keyword_pairing_code") }
}

struct ServiceRow: View {
    let service: DiscoveredService
    let isSelected: Bool
    let appTheme: String
    let lightThemeBackgroundHex: String
    @Environment(\.colorScheme) private var colorScheme

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
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isSelected
                    ? Color.blue.opacity(0.12)
                    : AppSurfaceStylePolicy.softPanelFill(
                        appTheme: appTheme,
                        colorScheme: colorScheme,
                        lightBackgroundHex: lightThemeBackgroundHex
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isSelected
                    ? Color.blue.opacity(0.24)
                    : AppSurfaceStylePolicy.softPanelStroke(
                        appTheme: appTheme,
                        colorScheme: colorScheme,
                        lightBackgroundHex: lightThemeBackgroundHex
                    ),
                    lineWidth: 1
                )
        )
    }
}
