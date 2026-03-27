import SwiftUI

struct SettingsAccountStatusCard: View {
    let presentation: SettingsMembershipPresentationPolicy.HeaderPresentation
    let title: String
    let subtitle: String
    let detail: String?

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tintColor.opacity(0.14))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tintColor)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var symbolName: String {
        switch presentation {
        case .regularUser:
            return "person.crop.circle"
        case .memberUser:
            return "person.crop.circle.badge.checkmark"
        }
    }

    private var tintColor: Color {
        switch presentation {
        case .regularUser:
            return .blue
        case .memberUser:
            return .green
        }
    }
}
