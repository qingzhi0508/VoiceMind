import SwiftUI
import SharedCore

struct ManualConnectionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ContentViewModel

    @State private var ipAddress = ""
    @State private var port = ""
    @State private var pairingCode = ""
    @State private var isConnecting = false
    @State private var isConnected = false
    @State private var errorMessage: String?
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
                                Text("例如：8080").foregroundColor(.gray)
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

                    Section {
                        Button(action: connect) {
                            if isConnecting {
                                HStack {
                                    ProgressView()
                                    Text("连接中...")
                                }
                            } else {
                                Text("连接")
                            }
                        }
                        .disabled(ipAddress.isEmpty || port.isEmpty || isConnecting)
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

                    Section {
                        Button(action: pair) {
                            Text("配对")
                        }
                        .disabled(pairingCode.count != 6)
                    }
                }
            }
            .navigationTitle(isConnected ? "输入配对码" : "手动连接")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                focusedField = isConnected ? .pairingCode : .ipAddress
            }
            .onChange(of: isConnected) { _, newValue in
                focusedField = newValue ? .pairingCode : .ipAddress
            }
        }
    }

    private func connect() {
        guard let portNumber = UInt16(port) else {
            errorMessage = "端口号无效"
            return
        }

        isConnecting = true
        errorMessage = nil

        print("📡 尝试连接到: \(ipAddress):\(portNumber)")

        // Connect to Mac
        viewModel.connectToMac(ip: ipAddress, port: portNumber)

        // Wait for connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isConnecting = false
            if viewModel.connectionState == .connected {
                print("✅ 连接成功")
                isConnected = true
                errorMessage = nil
            } else {
                print("❌ 连接失败")
                errorMessage = "连接失败，请检查 IP 和端口是否正确，并确保 Mac 已启动服务"
            }
        }
    }

    private func pair() {
        guard pairingCode.count == 6 else {
            errorMessage = "请输入 6 位配对码"
            return
        }

        errorMessage = nil
        focusedField = nil
        print("🔐 发送配对码: \(pairingCode)")

        // Send pairing code
        viewModel.pairWithCode(pairingCode)

        // Wait for pairing result
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if case .paired = viewModel.pairingState {
                print("✅ 配对成功")
                dismiss()
            } else {
                print("❌ 配对失败")
                errorMessage = "配对失败，请检查配对码是否正确"
            }
        }
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
