import SwiftUI

struct UsageGuideView: View {
    let onStartPairing: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "usage_guide_title"))
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(String(localized: "usage_guide_subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                GuideStep(number: 1, text: String(localized: "usage_guide_step1"))
                GuideStep(number: 2, text: String(format: String(localized: "quickstart_step1_format"), String(localized: "app_title")))
                GuideStep(number: 3, text: String(localized: "usage_guide_step3"))
                GuideStep(number: 4, text: String(localized: "usage_guide_step4"))
                GuideStep(number: 5, text: String(localized: "quickstart_step4"))
            }
            .padding(18)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(14)

            Text(String(localized: "usage_guide_footer"))
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack {
                Button(String(localized: "close_button")) {
                    onClose()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(String(localized: "action_start_pairing")) {
                    onStartPairing()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 520, height: 560)
    }
}
