import SwiftUI

struct PairingView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pairingCode = ""
    @State private var selectedService: DiscoveredService?
    @State private var showQRCodeScanner = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isPairingCodeFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "laptopcomputer.and.iphone")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("与 Mac 配对")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("优先使用扫码配对，也可以继续使用局域网自动发现。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                VStack(spacing: 12) {
                    Button {
                        showQRCodeScanner = true
                    } label: {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("扫描二维码配对")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    Text("在 Mac 上点击“配对新设备”，然后扫描弹出的二维码。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Discovered Macs
                VStack(alignment: .leading, spacing: 15) {
                    Text("或手动选择局域网中的 Mac")
                        .font(.headline)

                    if viewModel.discoveredServices.isEmpty {
                        HStack {
                            ProgressView()
                            Text("搜索中...")
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
                    Text("配对码")
                        .font(.headline)

                    TextField("输入 6 位数字", text: $pairingCode)
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

                Spacer()

                // Pair Button
                Button(action: startPairing) {
                    Text("配对")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canPair ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!canPair)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("配对失败", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showQRCodeScanner) {
                QRCodeScannerView(viewModel: viewModel)
            }
            .onAppear {
                isPairingCodeFocused = true
            }
        }
    }

    private var canPair: Bool {
        selectedService != nil && pairingCode.count == 6
    }

    private func startPairing() {
        guard let service = selectedService else { return }

        viewModel.pair(with: service, code: pairingCode)
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
