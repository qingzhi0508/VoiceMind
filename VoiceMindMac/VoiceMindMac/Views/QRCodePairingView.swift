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
        ZStack {
            MainWindowColors.pageBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    MainWindowStatusChip(
                        title: progressStatusTitle,
                        systemImage: progressIconName,
                        tint: progressColor
                    )

                    Text(AppLocalization.localizedString("qr_pairing_title"))
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(MainWindowColors.title)

                    Text(AppLocalization.localizedString("qr_scan_instruction"))
                        .font(.subheadline)
                        .foregroundColor(MainWindowColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                MainWindowSurface(emphasized: true) {
                    HStack(alignment: .top, spacing: 24) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white)

                            if let image = qrCodeImage {
                                Image(nsImage: image)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(22)
                            } else {
                                ProgressView()
                            }
                        }
                        .frame(width: 240, height: 240)

                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(AppLocalization.localizedString("qr_manual_code_label"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(MainWindowColors.secondaryText)

                                Text(pairingCode)
                                    .font(.system(size: 30, weight: .semibold, design: .monospaced))
                                    .foregroundColor(MainWindowColors.title)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(MainWindowColors.softSurface)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(MainWindowColors.cardBorder, lineWidth: 1)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text(AppLocalization.localizedString("qr_connection_info_label"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(MainWindowColors.secondaryText)

                                VStack(spacing: 8) {
                                    pairingMetaRow(
                                        title: "IP",
                                        value: connectionInfo.ip
                                    )

                                    pairingMetaRow(
                                        title: "Port",
                                        value: "\(connectionInfo.port)"
                                    )
                                }
                            }

                            Text(String(format: AppLocalization.localizedString("qr_time_remaining_format"), "\(pairingTimer.timeRemaining)"))
                                .font(.caption.weight(.medium))
                                .foregroundColor(MainWindowColors.secondaryText)
                        }
                    }
                }

                MainWindowSurface {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: progressIconName)
                            .foregroundColor(progressColor)
                            .font(.title3)

                        Text(progressMessage)
                            .font(.subheadline)
                            .foregroundColor(MainWindowColors.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                HStack {
                    Spacer()

                    Button(AppLocalization.localizedString("cancel_button")) {
                        pairingTimer.stop()
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
        .frame(width: 450, height: 550)
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

    private var progressMessage: String {
        PairingProgressDisplay.message(
            pairingState: controller.pairingState,
            connectionState: controller.connectionState,
            progressMessage: controller.pairingProgressMessage
        ) ?? AppLocalization.localizedString("qr_progress_waiting")
    }

    private var progressStatusTitle: String {
        if case .paired = controller.pairingState {
            return AppLocalization.localizedString("pairing_status_paired")
        }

        return AppLocalization.localizedString("pairing_status_pairing")
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

    @ViewBuilder
    private func pairingMetaRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(MainWindowColors.secondaryText)

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(MainWindowColors.primaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MainWindowColors.softSurface)
        )
    }
}
