import SwiftUI

struct PairingWindow: View {
    let code: String
    let onCancel: () -> Void

    @State private var timeRemaining = 120

    var body: some View {
        VStack(spacing: 20) {
            Text(AppLocalization.localizedString("pair_with_iphone_title"))
                .font(.title)

            Text(AppLocalization.localizedString("pair_with_iphone_instruction"))
                .font(.headline)

            Text(code)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)

            Text(AppLocalization.localizedString("pair_with_iphone_waiting"))
                .font(.caption)
                .foregroundColor(.secondary)

            Text(String(format: AppLocalization.localizedString("pair_with_iphone_time_format"), "\(timeRemaining)"))
                .font(.caption)
                .foregroundColor(.secondary)

            Button(AppLocalization.localizedString("cancel_button")) {
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
