import SwiftUI
import SharedCore

struct StatusWindow: View {
    @ObservedObject var controller: MenuBarController
    @State private var localIPAddress: String = AppLocalization.localizedString("status_loading")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StatusHeroCard(
                    pairingState: controller.pairingState,
                    connectionState: controller.connectionState
                )

                StatusPanel(
                    title: AppLocalization.localizedString("system_info_title"),
                    description: AppLocalization.localizedString("status_service_title")
                ) {
                    StatusValueRow(
                        icon: "network",
                        title: AppLocalization.localizedString("system_ip_title"),
                        value: localIPAddress,
                        tint: .blue
                    )
                }

                StatusPanel(
                    title: AppLocalization.localizedString("device_connection_title"),
                    description: AppLocalization.localizedString("status_connection_title")
                ) {
                    VStack(spacing: 12) {
                        StatusValueRow(
                            icon: "iphone",
                            title: AppLocalization.localizedString("device_pairing_status"),
                            value: pairingStatusText,
                            tint: pairingStatusTint
                        )

                        if case .paired(_, let deviceName) = controller.pairingState {
                            StatusValueRow(
                                icon: "person.circle",
                                title: AppLocalization.localizedString("device_name"),
                                value: deviceName,
                                tint: .blue
                            )
                        }

                        StatusValueRow(
                            icon: "wifi",
                            title: AppLocalization.localizedString("device_connection_status"),
                            value: connectionStatusText,
                            tint: connectionStatusTint
                        )
                    }
                }

                if case .unpaired = controller.pairingState {
                    StatusPanel(
                        title: AppLocalization.localizedString("quickstart_title"),
                        description: AppLocalization.localizedString("status_unpaired_need_pair")
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            StatusGuideStep(number: 1, text: String(format: AppLocalization.localizedString("quickstart_step1_format"), AppLocalization.localizedString("app_title")))
                            StatusGuideStep(number: 2, text: AppLocalization.localizedString("quickstart_step2"))
                            StatusGuideStep(number: 3, text: AppLocalization.localizedString("quickstart_step3"))
                            StatusGuideStep(number: 4, text: AppLocalization.localizedString("quickstart_step4"))
                        }
                    }
                }

                StatusPanel(
                    title: AppLocalization.localizedString("action_start_pairing"),
                    description: AppLocalization.localizedString("main_nav_collaboration")
                ) {
                    VStack(spacing: 12) {
                        if case .unpaired = controller.pairingState {
                            StatusActionButton(
                                title: AppLocalization.localizedString("action_start_pairing"),
                                systemImage: "link",
                                emphasized: true,
                                action: { controller.showPairingWindowFromUI() }
                            )
                        }

                        if case .paired = controller.pairingState {
                            StatusActionButton(
                                title: AppLocalization.localizedString("action_unpair"),
                                systemImage: "link.badge.minus",
                                emphasized: false,
                                action: { controller.unpairDeviceFromUI() }
                            )
                        }
                    }
                }
            }
            .padding(18)
        }
        .frame(width: 480, height: 520)
        .background(StatusWindowPalette.pageBackground)
        .onAppear {
            fetchLocalIPAddress()
            Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                fetchLocalIPAddress()
                controller.refreshPublishedState()
            }
        }
    }

    private func fetchLocalIPAddress() {
        localIPAddress = LocalNetworkAccessPolicy.preferredLocalIPv4() ?? AppLocalization.localizedString("status_unavailable")
    }

    private var pairingStatusText: String {
        switch controller.pairingState {
        case .unpaired:
            return AppLocalization.localizedString("pairing_status_unpaired")
        case .pairing:
            return AppLocalization.localizedString("pairing_status_pairing")
        case .paired:
            return AppLocalization.localizedString("pairing_status_paired")
        }
    }

    private var pairingStatusTint: Color {
        switch controller.pairingState {
        case .unpaired:
            return StatusWindowPalette.secondaryText
        case .pairing:
            return .orange
        case .paired:
            return .green
        }
    }

    private var connectionStatusText: String {
        switch MacConnectionPresentationPolicy.displayState(
            pairingState: controller.pairingState,
            connectionState: controller.connectionState
        ) {
        case .disconnected:
            return AppLocalization.localizedString("connection_status_disconnected")
        case .connecting:
            return AppLocalization.localizedString("connection_status_connecting")
        case .connected:
            return AppLocalization.localizedString("connection_status_connected")
        case .error(let error):
            return String(format: AppLocalization.localizedString("connection_status_error_format"), error.localizedDescription)
        }
    }

    private var connectionStatusTint: Color {
        switch MacConnectionPresentationPolicy.displayState(
            pairingState: controller.pairingState,
            connectionState: controller.connectionState
        ) {
        case .disconnected:
            return StatusWindowPalette.secondaryText
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
}

private enum StatusWindowPalette {
    static let pageBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let softBackground = Color(nsColor: .underPageBackgroundColor)
    static let border = Color.black.opacity(0.08)
    static let title = Color.primary
    static let secondaryText = Color.secondary
    static let accent = Color.accentColor
}

private struct StatusHeroCard: View {
    let pairingState: PairingState
    let connectionState: ConnectionState

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                Circle()
                    .fill(statusTint.opacity(0.14))
                    .frame(width: 58, height: 58)

                Image(systemName: statusIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(statusTint)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.localizedString("app_title"))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(StatusWindowPalette.title)

                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(StatusWindowPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(StatusWindowPalette.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(StatusWindowPalette.border, lineWidth: 1)
        )
    }

    private var statusIcon: String {
        switch (pairingState, connectionState) {
        case (.paired, .connected):
            return "checkmark.circle.fill"
        case (.paired, .connecting), (.pairing, _):
            return "arrow.triangle.2.circlepath"
        case (.paired, .disconnected):
            return "exclamationmark.triangle.fill"
        case (.unpaired, _):
            return "link.circle"
        default:
            return "questionmark.circle"
        }
    }

    private var statusTint: Color {
        switch (pairingState, connectionState) {
        case (.paired, .connected):
            return .green
        case (.paired, .connecting), (.pairing, _):
            return .orange
        case (.paired, .disconnected):
            return .red
        case (.unpaired, _):
            return StatusWindowPalette.accent
        default:
            return StatusWindowPalette.secondaryText
        }
    }

    private var statusText: String {
        switch (pairingState, connectionState) {
        case (.paired, .connected):
            return AppLocalization.localizedString("status_connected_ready")
        case (.paired, .connecting):
            return AppLocalization.localizedString("status_connecting_iphone")
        case (.paired, .disconnected):
            return AppLocalization.localizedString("status_paired_not_connected")
        case (.pairing, _):
            return AppLocalization.localizedString("status_pairing")
        case (.unpaired, _):
            return AppLocalization.localizedString("status_unpaired_need_pair")
        default:
            return AppLocalization.localizedString("status_unknown")
        }
    }
}

private struct StatusPanel<Content: View>: View {
    let title: String
    let description: String
    @ViewBuilder let content: Content

    init(title: String, description: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.description = description
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(StatusWindowPalette.title)

                Text(description)
                    .font(.caption)
                    .foregroundColor(StatusWindowPalette.secondaryText)
            }

            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(StatusWindowPalette.cardBackground.opacity(0.92))
        )
    }
}

private struct StatusValueRow: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(tint)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(tint.opacity(0.12))
                )

            Text(title)
                .foregroundColor(StatusWindowPalette.secondaryText)

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .foregroundColor(StatusWindowPalette.title)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }
}

private struct StatusGuideStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundColor(StatusWindowPalette.accent)
                .frame(width: 24, height: 24)
                .background(StatusWindowPalette.accent.opacity(0.12))
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .foregroundColor(StatusWindowPalette.title)

            Spacer()
        }
    }
}

private struct StatusActionButton: View {
    let title: String
    let systemImage: String
    let emphasized: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(emphasized ? StatusWindowPalette.accent : StatusWindowPalette.softBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(emphasized ? StatusWindowPalette.accent.opacity(0.08) : StatusWindowPalette.border, lineWidth: 1)
        )
        .foregroundColor(emphasized ? .white : StatusWindowPalette.title)
    }
}

#Preview {
    StatusWindow(controller: MenuBarController())
}
