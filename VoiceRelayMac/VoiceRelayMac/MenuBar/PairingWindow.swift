import SwiftUI

struct PairingWindow: View {
    let code: String
    let onCancel: () -> Void

    @State private var timeRemaining = 120

    var body: some View {
        VStack(spacing: 20) {
            Text("与 iPhone 配对")
                .font(.title)

            Text("在 iPhone 上输入此代码：")
                .font(.headline)

            Text(code)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)

            Text("等待 iPhone 连接...")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("剩余时间: \(timeRemaining)秒")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("取消") {
                onCancel()
            }
        }
        .frame(width: 400, height: 300)
        .padding()
        .onAppear {
            startTimer()
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
