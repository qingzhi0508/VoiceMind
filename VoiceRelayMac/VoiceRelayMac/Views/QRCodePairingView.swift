import SwiftUI
import CoreImage.CIFilterBuiltins
import SharedCore

struct QRCodePairingView: View {
    let connectionInfo: ConnectionInfo
    let pairingCode: String
    let onCancel: () -> Void

    @State private var timeRemaining = 120
    @State private var qrCodeImage: NSImage?

    var body: some View {
        VStack(spacing: 20) {
            Text("扫码配对")
                .font(.title)

            Text("使用 iPhone 扫描此二维码")
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
                Text("或手动输入配对码：")
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
                Text("连接信息：")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("IP: \(connectionInfo.ip)")
                    .font(.system(.caption, design: .monospaced))
                Text("端口: \(connectionInfo.port)")
                    .font(.system(.caption, design: .monospaced))
            }

            Text("剩余时间: \(timeRemaining)秒")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("取消") {
                onCancel()
            }
            .buttonStyle(.bordered)
        }
        .frame(width: 450, height: 550)
        .padding()
        .onAppear {
            generateQRCode()
            startTimer()
        }
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
            // Scale up the QR code
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)

            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                qrCodeImage = NSImage(cgImage: cgImage, size: NSSize(width: 250, height: 250))
            }
        }
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer.invalidate()
                onCancel()
            }
        }
    }
}
