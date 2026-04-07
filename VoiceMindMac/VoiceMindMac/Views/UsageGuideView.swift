import SwiftUI

struct UsageGuideView: View {
    let onStartPairing: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.localizedString("usage_guide_title"))
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(AppLocalization.localizedString("usage_guide_subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                GuideStep(number: 1, text: AppLocalization.localizedString("usage_guide_step1"))
                GuideStep(number: 2, text: String(format: AppLocalization.localizedString("quickstart_step1_format"), AppLocalization.localizedString("app_title")))
                GuideStep(number: 3, text: AppLocalization.localizedString("usage_guide_step3"))
                GuideStep(number: 4, text: AppLocalization.localizedString("usage_guide_step4"))
                GuideStep(number: 5, text: AppLocalization.localizedString("quickstart_step4"))
            }
            .padding(18)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(14)

            Text(AppLocalization.localizedString("usage_guide_footer"))
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack {
                Button(AppLocalization.localizedString("close_button")) {
                    onClose()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(AppLocalization.localizedString("action_start_pairing")) {
                    onStartPairing()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 416, height: 448)
    }
}
