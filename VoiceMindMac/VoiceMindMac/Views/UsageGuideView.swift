import SwiftUI

struct UsageGuideView: View {
    let onStartPairing: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            MainWindowColors.pageBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    guideBadge

                    Text(AppLocalization.localizedString("usage_guide_title"))
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(MainWindowColors.title)

                    Text(AppLocalization.localizedString("usage_guide_subtitle"))
                        .font(.subheadline)
                        .foregroundColor(MainWindowColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                MainWindowSurface(emphasized: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(AppLocalization.localizedString("quickstart_title"))
                            .font(.title3.weight(.semibold))
                            .foregroundColor(MainWindowColors.title)

                        GuideStep(number: 1, text: AppLocalization.localizedString("usage_guide_step1"))
                        GuideStep(number: 2, text: String(format: AppLocalization.localizedString("quickstart_step1_format"), AppLocalization.localizedString("app_title")))
                        GuideStep(number: 3, text: AppLocalization.localizedString("usage_guide_step3"))
                        GuideStep(number: 4, text: AppLocalization.localizedString("usage_guide_step4"))
                        GuideStep(number: 5, text: AppLocalization.localizedString("quickstart_step4"))
                    }
                }

                MainWindowSurface {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.shield")
                            .font(.title3)
                            .foregroundColor(.accentColor)

                        Text(AppLocalization.localizedString("usage_guide_footer"))
                            .font(.footnote)
                            .foregroundColor(MainWindowColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

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
        }
        .frame(width: 416, height: 448)
    }

    private var guideBadge: some View {
        Text(AppLocalization.localizedString("main_nav_about"))
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.10))
            .clipShape(Capsule())
    }
}

private struct GuideStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.accentColor)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                )

            Text(text)
                .font(.subheadline)
                .foregroundColor(MainWindowColors.title)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
