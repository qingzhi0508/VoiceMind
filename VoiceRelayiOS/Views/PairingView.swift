import SwiftUI

struct PairingView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pairingCode = ""
    @State private var selectedService: DiscoveredService?
    @State private var showError = false
    @State private var errorMessage = ""

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

                    Text("在 Mac 上打开 VoiceMind 并点击\"配对新设备\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // Discovered Macs
                VStack(alignment: .leading, spacing: 15) {
                    Text("发现的 Mac")
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
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .onChange(of: pairingCode) { newValue in
                            // Limit to 6 digits
                            if newValue.count > 6 {
                                pairingCode = String(newValue.prefix(6))
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
