import SwiftUI
import CoreImage.CIFilterBuiltins
import Combine
import SharedCore



class PairingTimer: ObservableObject {
    @Published var timeRemaining = 120
    private var timer: Timer?
    var onTimeout: (() -> Void)?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.stop()
                self.onTimeout?()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stop()
    }
}

struct QRCodePairingView: View {
    @ObservedObject var controller: MenuBarController
    let connectionInfo: ConnectionInfo
    let pairingCode: String
    let onCancel: () -> Void

    @StateObject private var pairingTimer = PairingTimer()
    @State private var qrCodeImage: NSImage?

    var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "qr_pairing_title"))
                .font(.title)

            Text(String(localized: "qr_scan_instruction"))
                .font(.headline)

            // QR Code
            if let image = qrCodeImage {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .background(Color.white)
                    .cornerRadius(10)
            } else {
                ProgressView()
                    .frame(width: 250, height: 250)
            }

            VStack(spacing: 8) {
                Text(String(localized: "qr_manual_code_label"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(pairingCode)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }

            VStack(spacing: 4) {
                Text(String(localized: "qr_connection_info_label"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: String(localized: "qr_ip_label_format"), connectionInfo.ip))
                    .font(.system(.caption, design: .monospaced))
                Text(String(format: String(localized: "qr_port_label_format"), "\(connectionInfo.port)"))
                    .font(.system(.caption, design: .monospaced))
            }

            GroupBox(label: Label(String(localized: "qr_progress_title"), systemImage: "list.bullet.clipboard")) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: progressIconName)
                        .foregroundColor(progressColor)
                        .font(.title3)

                    Text(
                        PairingProgressDisplay.message(
                            pairingState: controller.pairingState,
                            connectionState: controller.connectionState,
                            progressMessage: controller.pairingProgressMessage
                        ) ?? String(localized: "qr_progress_waiting")
                    )
                        .font(.callout)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
            }

            Text(String(format: String(localized: "qr_time_remaining_format"), "\(pairingTimer.timeRemaining)"))
                .font(.caption)
                .foregroundColor(.secondary)

            Button(AppLocalization.localizedString("cancel_button")) {
                pairingTimer.stop()
                onCancel()
            }
            .buttonStyle(.bordered)
        }
        .frame(width: 450, height: 550)
        .padding()
        .onAppear {
            generateQRCode()
            pairingTimer.onTimeout = { [onCancel] in
                onCancel()
            }
            pairingTimer.start()
        }
        .onDisappear {
            pairingTimer.stop()
        }
    }

    private var progressIconName: String {
        if case .paired = controller.pairingState {
            return "checkmark.circle.fill"
        }

        return "hourglass.circle.fill"
    }

    private var progressColor: Color {
        if case .paired = controller.pairingState {
            return .green
        }

        return .orange
    }

    private func generateQRCode() {
        guard let qrString = connectionInfo.toQRCodeString() else {
            print("❌ 无法生成二维码数据")
            return
        }

        print("📱 二维码内容: \(qrString)")

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(qrString.utf8)
        filter.correctionLevel = "M"

        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)

            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                qrCodeImage = NSImage(cgImage: cgImage, size: NSSize(width: 250, height: 250))
            }
        }
    }
}
