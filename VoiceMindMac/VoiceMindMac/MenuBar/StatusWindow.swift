import SwiftUI
import SharedCore
import Network

struct StatusWindow: View {
    @ObservedObject var controller: MenuBarController
    @State private var localIPAddress: String = String(localized: "status_loading")

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with App Status
                HeaderSection(
                    pairingState: controller.pairingState,
                    connectionState: controller.connectionState
                )

                // System Information
                SystemInfoSection(
                    localIP: localIPAddress,
                    accessibilityStatus: controller.accessibilityStatus
                )

                // Device Connection Status
                DeviceConnectionSection(
                    pairingState: controller.pairingState,
                    connectionState: controller.connectionState
                )

                // Permissions Section
                PermissionsSection(
                    accessibilityStatus: controller.accessibilityStatus,
                    onRequestAccessibility: {
                        controller.requestAccessibilityPermissionFromUI()
                    }
                )

                // Quick Start Guide (only show when unpaired)
                if case .unpaired = controller.pairingState {
                    QuickStartSection(
                        onStartPairing: {
                            controller.showPairingWindowFromUI()
                        }
                    )
                }

                // Action Buttons
                ActionButtonsSection(
                    pairingState: controller.pairingState,
                    onStartPairing: {
                        controller.showPairingWindowFromUI()
                    },
                    onOpenPermissions: {
                        controller.openPermissionsFromUI()
                    },
                    onUnpair: {
                        controller.unpairDeviceFromUI()
                    }
                )
            }
            .padding()
        }
        .frame(width: 480, height: 560)
        .onAppear {
            fetchLocalIPAddress()
            // Refresh every 5 seconds
            Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                fetchLocalIPAddress()
                controller.refreshPublishedState()
            }
        }
    }

    private func fetchLocalIPAddress() {
        localIPAddress = getLocalIPAddress() ?? String(localized: "status_unavailable")
    }

    private func getLocalIPAddress() -> String? {
        LocalNetworkAccessPolicy.preferredLocalIPv4()
    }
}

// MARK: - Header Section

struct HeaderSection: View {
    let pairingState: PairingState
    let connectionState: ConnectionState

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: statusIcon)
                .font(.system(size: 48))
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "app_title"))
                    .font(.title)
                    .fontWeight(.bold)

                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }

    private var statusIcon: String {
        switch (pairingState, connectionState) {
        case (.paired, .connected):
            return "checkmark.circle.fill"
        case (.paired, .connecting):
            return "arrow.triangle.2.circlepath"
        case (.paired, .disconnected):
            return "exclamationmark.triangle.fill"
        case (.pairing, _):
            return "arrow.triangle.2.circlepath"
        case (.unpaired, _):
            return "link.circle"
        default:
            return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch (pairingState, connectionState) {
        case (.paired, .connected):
            return .green
        case (.paired, .connecting):
            return .orange
        case (.paired, .disconnected):
            return .red
        case (.pairing, _):
            return .blue
        case (.unpaired, _):
            return .gray
        default:
            return .gray
        }
    }

    private var statusText: String {
        switch (pairingState, connectionState) {
        case (.paired, .connected):
            return String(localized: "status_connected_ready")
        case (.paired, .connecting):
            return String(localized: "status_connecting_iphone")
        case (.paired, .disconnected):
            return String(localized: "status_paired_not_connected")
        case (.pairing, _):
            return String(localized: "status_pairing")
        case (.unpaired, _):
            return String(localized: "status_unpaired_need_pair")
        default:
            return String(localized: "status_unknown")
        }
    }
}

// MARK: - System Info Section

struct SystemInfoSection: View {
    let localIP: String
    let accessibilityStatus: PermissionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "system_info_title"))
                .font(.headline)

            VStack(spacing: 8) {
                InfoRow(
                    icon: "network",
                    title: String(localized: "system_ip_title"),
                    value: localIP,
                    color: .blue
                )

                InfoRow(
                    icon: "lock.shield",
                    title: String(localized: "system_accessibility_title"),
                    value: accessibilityStatus.displayText,
                    color: accessibilityStatus.color
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Device Connection Section

struct DeviceConnectionSection: View {
    let pairingState: PairingState
    let connectionState: ConnectionState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "device_connection_title"))
                .font(.headline)

            VStack(spacing: 8) {
                InfoRow(
                    icon: "iphone",
                    title: String(localized: "device_pairing_status"),
                    value: pairingStatusText,
                    color: pairingStatusColor
                )

                if case .paired(_, let deviceName) = pairingState {
                    InfoRow(
                        icon: "person.circle",
                        title: String(localized: "device_name"),
                        value: deviceName,
                        color: .blue
                    )
                }

                InfoRow(
                    icon: "wifi",
                    title: String(localized: "device_connection_status"),
                    value: connectionStatusText,
                    color: connectionStatusColor
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var pairingStatusText: String {
        switch pairingState {
        case .unpaired:
            return String(localized: "pairing_status_unpaired")
        case .pairing:
            return String(localized: "pairing_status_pairing")
        case .paired:
            return String(localized: "pairing_status_paired")
        }
    }

    private var pairingStatusColor: Color {
        switch pairingState {
        case .unpaired:
            return .gray
        case .pairing:
            return .blue
        case .paired:
            return .green
        }
    }

    private var connectionStatusText: String {
        switch connectionState {
        case .disconnected:
            return String(localized: "connection_status_disconnected")
        case .connecting:
            return String(localized: "connection_status_connecting")
        case .connected:
            return String(localized: "connection_status_connected")
        case .error(let error):
            return String(format: String(localized: "connection_status_error_format"), error.localizedDescription)
        }
    }

    private var connectionStatusColor: Color {
        switch connectionState {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
}

// MARK: - Permissions Section

struct PermissionsSection: View {
    let accessibilityStatus: PermissionStatus
    let onRequestAccessibility: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "permissions_section_title"))
                .font(.headline)

            if accessibilityStatus != .granted {
                VStack(spacing: 8) {
                    PermissionRequestRow(
                        icon: "lock.shield",
                        title: String(localized: "permissions_accessibility_title"),
                        description: String(localized: "permissions_accessibility_desc"),
                        status: accessibilityStatus,
                        onRequest: onRequestAccessibility
                    )
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(String(localized: "permissions_all_granted"))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.orange.opacity(accessibilityStatus != .granted ? 0.1 : 0.05))
        .cornerRadius(12)
    }
}

struct PermissionRequestRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let onRequest: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.orange)
                    Text(title)
                        .fontWeight(.medium)
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(AppLocalization.localizedString("authorize_button")) {
                onRequest()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Quick Start Section

struct QuickStartSection: View {
    let onStartPairing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "quickstart_title"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                GuideStep(number: 1, text: String(format: String(localized: "quickstart_step1_format"), String(localized: "app_title")))
                GuideStep(number: 2, text: String(localized: "quickstart_step2"))
                GuideStep(number: 3, text: String(localized: "quickstart_step3"))
                GuideStep(number: 4, text: String(localized: "quickstart_step4"))
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct GuideStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

// MARK: - Action Buttons Section

struct ActionButtonsSection: View {
    let pairingState: PairingState
    let onStartPairing: () -> Void
    let onOpenPermissions: () -> Void
    let onUnpair: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if case .unpaired = pairingState {
                Button(action: onStartPairing) {
                    HStack {
                        Image(systemName: "link")
                        Text(String(localized: "action_start_pairing"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            HStack(spacing: 12) {
                Button(action: onOpenPermissions) {
                    HStack {
                        Image(systemName: "lock.shield")
                        Text(String(localized: "action_permissions"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if case .paired = pairingState {
                    Button(action: onUnpair) {
                        HStack {
                            Image(systemName: "link.badge.minus")
                            Text(String(localized: "action_unpair"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    StatusWindow(controller: MenuBarController())
}
