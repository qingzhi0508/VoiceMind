import SwiftUI

struct PairingWindow: View {
    let code: String
    let onCancel: () -> Void

    @State private var timeRemaining = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(AppLocalization.localizedString("pair_with_iphone_waiting"), systemImage: "link")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.10))
                        .clipShape(Capsule())

                    Spacer()

                    Text(String(format: AppLocalization.localizedString("pair_with_iphone_time_format"), "\(timeRemaining)"))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                Text(AppLocalization.localizedString("pair_with_iphone_title"))
                    .font(.system(size: 28, weight: .semibold))

                Text(AppLocalization.localizedString("pair_with_iphone_instruction"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 14) {
                Text(code)
                    .font(.system(size: 44, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )

                HStack {
                    Label(AppLocalization.localizedString("pair_with_iphone_waiting"), systemImage: "iphone.and.arrow.forward")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }

            HStack(spacing: 12) {
                Button(AppLocalization.localizedString("cancel_button")) {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .frame(width: 420, height: 300, alignment: .topLeading)
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
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
