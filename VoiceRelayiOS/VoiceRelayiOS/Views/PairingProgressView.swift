import SwiftUI

enum PairingStepState {
    case pending
    case active
    case completed
    case failed

    var color: Color {
        switch self {
        case .pending:
            return .gray.opacity(0.35)
        case .active:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }

    var iconName: String {
        switch self {
        case .pending:
            return "circle"
        case .active:
            return "clock.arrow.circlepath"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
}

struct PairingStepItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let state: PairingStepState
}

struct PairingProgressView: View {
    let title: String
    let steps: [PairingStepItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Image(systemName: step.state.iconName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(step.state.color)
                            .frame(width: 20, height: 20)

                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(connectorColor(after: step.state))
                                .frame(width: 2, height: 28)
                                .padding(.top, 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text(step.detail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.08))
        .cornerRadius(12)
    }

    private func connectorColor(after state: PairingStepState) -> Color {
        switch state {
        case .completed:
            return .green.opacity(0.6)
        case .active:
            return .blue.opacity(0.45)
        case .failed:
            return .red.opacity(0.45)
        case .pending:
            return .gray.opacity(0.2)
        }
    }
}
