import SwiftUI
import SharedCore

private func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

// MARK: - Main Window Coordinator

struct OnboardingFlowView: View {
    @ObservedObject var controller: MenuBarController
    @State private var currentStep: OnboardingStep = .welcome

    enum OnboardingStep {
        case welcome
        case captureReview
        case connectDevices
        case ready
        case running
    }

    var body: some View {
        Group {
            switch currentStep {
            case .welcome:
                WelcomeView(onContinue: {
                    currentStep = .captureReview
                })
            case .captureReview:
                CaptureReviewView(
                    onBack: {
                        currentStep = .welcome
                    },
                    onComplete: {
                        currentStep = .connectDevices
                    }
                )
            case .connectDevices:
                ConnectDevicesView(
                    onBack: {
                        currentStep = .captureReview
                    },
                    onComplete: {
                        currentStep = .ready
                    }
                )
            case .ready:
                ReadyView(
                    controller: controller,
                    onBack: {
                        currentStep = .connectDevices
                    },
                    onStart: {
                        controller.startNetworkServices()
                        currentStep = .running
                    }
                )
            case .running:
                RunningStatusView(controller: controller)
            }
        }
        .frame(width: 400, height: 480)
    }
}

// MARK: - Shared Onboarding Chrome

struct OnboardingScaffold<Content: View>: View {
    let step: Int
    let badgeKey: String
    let titleKey: String
    let subtitleKey: String
    let primaryButtonKey: String
    let secondaryButtonKey: String?
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?
    @ViewBuilder let content: Content

    private let totalSteps = 4

    var body: some View {
        ZStack {
            MainWindowColors.pageBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("\(step)/\(totalSteps)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 8) {
                        ForEach(1...totalSteps, id: \.self) { index in
                            Capsule()
                                .fill(index == step ? Color.accentColor : Color.primary.opacity(0.14))
                                .frame(width: index == step ? 28 : 10, height: 8)
                        }
                    }
                }

                Text(L(badgeKey))
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.10))
                    .clipShape(Capsule())

                VStack(alignment: .leading, spacing: 12) {
                    Text(L(titleKey))
                        .font(.system(size: 31, weight: .semibold))
                        .foregroundStyle(MainWindowColors.title)

                    Text(L(subtitleKey))
                        .font(.subheadline)
                        .foregroundStyle(MainWindowColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                content

                Spacer(minLength: 0)

                HStack(spacing: 14) {
                    if let secondaryButtonKey, let onSecondary {
                        Button(action: onSecondary) {
                            Text(L(secondaryButtonKey))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    Button(action: onPrimary) {
                        Text(L(primaryButtonKey))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(32)
        }
    }
}

struct HeroFeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(18)
        .background(MainWindowColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }
}

struct SignalPanel: View {
    let title: String
    let details: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)

                    HStack(spacing: 6) {
                        Capsule().fill(Color.accentColor).frame(width: 22, height: 6)
                        Capsule().fill(Color.accentColor.opacity(0.45)).frame(width: 34, height: 6)
                        Capsule().fill(Color.accentColor.opacity(0.75)).frame(width: 16, height: 6)
                    }
                }

                Spacer()

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.accentColor)
            }

            ForEach(details, id: \.self) { detail in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(22)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct DeviceBridgePanel: View {
    var body: some View {
        HStack(spacing: 18) {
            DeviceNode(systemName: "iphone.gen3", title: L("mac_onboarding_device_iphone"), tint: Color(red: 0.18, green: 0.44, blue: 0.95))

            VStack(spacing: 10) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)

                Text(L("mac_onboarding_connect_bridge"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            DeviceNode(systemName: "laptopcomputer", title: L("mac_onboarding_device_mac"), tint: Color(red: 0.06, green: 0.70, blue: 0.62))
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(MainWindowColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }
}

struct DeviceNode: View {
    let systemName: String
    let title: String
    let tint: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }
}

struct PairingStepCard: View {
    let index: Int
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(index)")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(Color.accentColor)
                    Text(title)
                        .font(.headline)
                }

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(18)
        .background(MainWindowColors.softSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            step: 1,
            badgeKey: "mac_onboarding_brand_badge",
            titleKey: "mac_onboarding_welcome_title",
            subtitleKey: "mac_onboarding_welcome_subtitle",
            primaryButtonKey: "mac_onboarding_continue",
            secondaryButtonKey: nil,
            onPrimary: onContinue,
            onSecondary: nil
        ) {
            VStack(spacing: 18) {
                SignalPanel(
                    title: L("mac_onboarding_brand_panel_title"),
                    details: [
                        L("mac_onboarding_brand_panel_point1"),
                        L("mac_onboarding_brand_panel_point2"),
                        L("mac_onboarding_brand_panel_point3")
                    ]
                )

                VStack(spacing: 14) {
                    HeroFeatureCard(
                        icon: "sparkles.rectangle.stack",
                        iconColor: Color(red: 0.18, green: 0.44, blue: 0.95),
                        title: L("mac_onboarding_brand_feature1_title"),
                        detail: L("mac_onboarding_brand_feature1_desc")
                    )

                    HeroFeatureCard(
                        icon: "desktopcomputer.and.macbook",
                        iconColor: Color(red: 0.06, green: 0.70, blue: 0.62),
                        title: L("mac_onboarding_brand_feature2_title"),
                        detail: L("mac_onboarding_brand_feature2_desc")
                    )
                }
            }
        }
    }
}

struct CaptureReviewView: View {
    let onBack: () -> Void
    let onComplete: () -> Void

    var body: some View {
        OnboardingScaffold(
            step: 2,
            badgeKey: "mac_onboarding_capture_badge",
            titleKey: "mac_onboarding_capture_title",
            subtitleKey: "mac_onboarding_capture_subtitle",
            primaryButtonKey: "mac_onboarding_continue",
            secondaryButtonKey: "mac_onboarding_back",
            onPrimary: onComplete,
            onSecondary: onBack
        ) {
            VStack(spacing: 18) {
                SignalPanel(
                    title: L("mac_onboarding_capture_panel_title"),
                    details: [
                        L("mac_onboarding_capture_panel_point1"),
                        L("mac_onboarding_capture_panel_point2"),
                        L("mac_onboarding_capture_panel_point3")
                    ]
                )

                VStack(spacing: 14) {
                    HeroFeatureCard(
                        icon: "text.page.badge.magnifyingglass",
                        iconColor: Color(red: 0.18, green: 0.44, blue: 0.95),
                        title: L("mac_onboarding_capture_feature1_title"),
                        detail: L("mac_onboarding_capture_feature1_desc")
                    )

                    HeroFeatureCard(
                        icon: "checklist.checked",
                        iconColor: Color(red: 0.96, green: 0.53, blue: 0.23),
                        title: L("mac_onboarding_capture_feature2_title"),
                        detail: L("mac_onboarding_capture_feature2_desc")
                    )
                }
            }
        }
    }
}

struct ConnectDevicesView: View {
    let onBack: () -> Void
    let onComplete: () -> Void

    var body: some View {
        OnboardingScaffold(
            step: 3,
            badgeKey: "mac_onboarding_connect_badge",
            titleKey: "mac_onboarding_connect_title",
            subtitleKey: "mac_onboarding_connect_subtitle",
            primaryButtonKey: "mac_onboarding_continue",
            secondaryButtonKey: "mac_onboarding_back",
            onPrimary: onComplete,
            onSecondary: onBack
        ) {
            VStack(spacing: 18) {
                DeviceBridgePanel()

                VStack(spacing: 14) {
                    PairingStepCard(
                        index: 1,
                        title: L("mac_onboarding_connect_step1_title"),
                        detail: L("mac_onboarding_connect_step1_desc"),
                        icon: "wifi"
                    )

                    PairingStepCard(
                        index: 2,
                        title: L("mac_onboarding_connect_step2_title"),
                        detail: L("mac_onboarding_connect_step2_desc"),
                        icon: "qrcode.viewfinder"
                    )

                    PairingStepCard(
                        index: 3,
                        title: L("mac_onboarding_connect_step3_title"),
                        detail: L("mac_onboarding_connect_step3_desc"),
                        icon: "arrow.triangle.branch"
                    )
                }
            }
        }
    }
}

// MARK: - Ready View

struct ReadyView: View {
    @ObservedObject var controller: MenuBarController
    let onBack: () -> Void
    let onStart: () -> Void

    @State private var localIPAddress: String = L("mac_onboarding_fetching_ip")

    var body: some View {
        OnboardingScaffold(
            step: 4,
            badgeKey: "mac_onboarding_start_badge",
            titleKey: "mac_onboarding_start_title",
            subtitleKey: "mac_onboarding_start_subtitle",
            primaryButtonKey: controller.isServiceRunning ? "mac_onboarding_start_continue" : "mac_onboarding_start_button",
            secondaryButtonKey: controller.isServiceRunning ? nil : "mac_onboarding_back",
            onPrimary: onStart,
            onSecondary: controller.isServiceRunning ? nil : onBack
        ) {
            VStack(spacing: 16) {
                InfoCard(
                    icon: "network",
                    title: L("mac_onboarding_start_ip_title"),
                    value: localIPAddress,
                    color: .blue
                )

                InfoCard(
                    icon: "bolt.horizontal.circle",
                    title: L("mac_onboarding_start_mode_title"),
                    value: L("mac_onboarding_start_mode_value"),
                    color: .purple
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text(L("mac_onboarding_start_steps_title"))
                        .font(.headline)

                    InstructionStep(
                        number: 1,
                        text: controller.isServiceRunning ? L("mac_onboarding_start_step1_running") : L("mac_onboarding_start_step1")
                    )
                    InstructionStep(number: 2, text: L("mac_onboarding_start_step2"))
                    InstructionStep(number: 3, text: L("mac_onboarding_start_step3"))
                }
                .padding(18)
                .background(MainWindowColors.softSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(MainWindowColors.cardBorder, lineWidth: 1)
                )
            }
        }
        .onAppear {
            fetchLocalIPAddress()
            if controller.isServiceRunning {
                onStart()
            }
        }
    }

    private func fetchLocalIPAddress() {
        localIPAddress = getLocalIPAddress() ?? L("status_unavailable")
    }

    private func getLocalIPAddress() -> String? {
        LocalNetworkAccessPolicy.preferredLocalIPv4()
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
                    .foregroundColor(color)
            }

            Spacer()
        }
        .padding(16)
        .background(MainWindowColors.softSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(MainWindowColors.title)

            Spacer()
        }
    }
}

// MARK: - Running Status View

struct RunningStatusView: View {
    @ObservedObject var controller: MenuBarController
    @State private var localIPAddress: String = L("status_loading")
    @State private var refreshTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                StatusHeader(
                    pairingState: controller.pairingState,
                    connectionState: controller.connectionState
                )

                SystemInfoCard(
                    localIP: localIPAddress
                )

                DeviceConnectionCard(
                    pairingState: controller.pairingState,
                    connectionState: controller.connectionState
                )

                QuickActionsCard(
                    pairingState: controller.pairingState,
                    onStartPairing: {
                        controller.showPairingWindowFromUI()
                    },
                    onUnpair: {
                        controller.unpairDeviceFromUI()
                    },
                    onStopService: {
                        controller.stopNetworkServices()
                    }
                )
            }
            .padding(20)
        }
        .onAppear {
            fetchLocalIPAddress()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            fetchLocalIPAddress()
            controller.refreshPublishedState()
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func fetchLocalIPAddress() {
        localIPAddress = getLocalIPAddress() ?? L("status_unavailable")
    }

    private func getLocalIPAddress() -> String? {
        LocalNetworkAccessPolicy.preferredLocalIPv4()
    }
}

struct StatusHeader: View {
    let pairingState: PairingState
    let connectionState: ConnectionState

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 64, height: 64)

                Image(systemName: statusIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L("mac_onboarding_product_name"))
                    .font(.title2.weight(.semibold))

                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .background(MainWindowColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }

    private var statusIcon: String {
        switch (pairingState, connectionState) {
        case (.paired, .connected): return "checkmark.circle.fill"
        case (.paired, .connecting): return "arrow.triangle.2.circlepath"
        case (.paired, .disconnected): return "exclamationmark.triangle.fill"
        case (.pairing, _): return "arrow.triangle.2.circlepath"
        case (.unpaired, _): return "link.circle"
        default: return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch (pairingState, connectionState) {
        case (.paired, .connected): return .green
        case (.paired, .connecting): return .orange
        case (.paired, .disconnected): return .red
        case (.pairing, _): return .blue
        case (.unpaired, _): return .gray
        default: return .gray
        }
    }

    private var statusText: String {
        switch (pairingState, connectionState) {
        case (.paired, .connected): return L("status_connected_ready")
        case (.paired, .connecting): return L("status_connecting_iphone")
        case (.paired, .disconnected): return L("status_paired_not_connected")
        case (.pairing, _): return L("status_pairing")
        case (.unpaired, _): return L("status_unpaired_need_pair")
        default: return L("status_unknown")
        }
    }
}

struct SystemInfoCard: View {
    let localIP: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("system_info_title"))
                .font(.headline.weight(.semibold))

            VStack(spacing: 8) {
                SimpleInfoRow(icon: "network", title: L("system_ip_title"), value: localIP, color: .blue)
                SimpleInfoRow(icon: "doc.text", title: L("mac_onboarding_start_mode_title"), value: L("mac_onboarding_results_location"), color: .purple)
            }
        }
        .padding(18)
        .background(MainWindowColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }
}

struct DeviceConnectionCard: View {
    let pairingState: PairingState
    let connectionState: ConnectionState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("device_connection_title"))
                .font(.headline.weight(.semibold))

            VStack(spacing: 8) {
                SimpleInfoRow(icon: "iphone", title: L("device_pairing_status"), value: pairingStatusText, color: pairingStatusColor)

                if case .paired(_, let deviceName) = pairingState {
                    SimpleInfoRow(icon: "person.circle", title: L("device_name"), value: deviceName, color: .blue)
                }

                SimpleInfoRow(icon: "wifi", title: L("device_connection_status"), value: connectionStatusText, color: connectionStatusColor)
            }
        }
        .padding(18)
        .background(MainWindowColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }

    private var pairingStatusText: String {
        switch pairingState {
        case .unpaired: return L("pairing_status_unpaired")
        case .pairing: return L("pairing_status_pairing")
        case .paired: return L("pairing_status_paired")
        }
    }

    private var pairingStatusColor: Color {
        switch pairingState {
        case .unpaired: return .gray
        case .pairing: return .blue
        case .paired: return .green
        }
    }

    private var connectionStatusText: String {
        switch MacConnectionPresentationPolicy.displayState(
            pairingState: pairingState,
            connectionState: connectionState
        ) {
        case .disconnected: return L("connection_status_disconnected")
        case .connecting: return L("connection_status_connecting")
        case .connected: return L("connection_status_connected")
        case .error: return L("status_connection_error")
        }
    }

    private var connectionStatusColor: Color {
        switch MacConnectionPresentationPolicy.displayState(
            pairingState: pairingState,
            connectionState: connectionState
        ) {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
}

struct QuickActionsCard: View {
    let pairingState: PairingState
    let onStartPairing: () -> Void
    let onUnpair: () -> Void
    let onStopService: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if case .unpaired = pairingState {
                Button(action: onStartPairing) {
                    HStack {
                        Image(systemName: "link")
                        Text(L("status_action_start_pairing"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 12) {
                if case .paired = pairingState {
                    Button(action: onUnpair) {
                        HStack {
                            Image(systemName: "link.badge.minus")
                            Text(L("status_action_unpair"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }

            Button(action: onStopService) {
                HStack {
                    Image(systemName: "stop.circle")
                    Text(L("status_action_stop_service"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
        .padding(18)
        .background(MainWindowColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }
}

struct SimpleInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}
