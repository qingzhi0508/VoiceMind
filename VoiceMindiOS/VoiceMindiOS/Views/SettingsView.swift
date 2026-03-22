import SwiftUI
import SharedCore

struct SettingsView: View {
    @ObservedObject var viewModel: ContentViewModel
    var showsNavigationTitle = true
    @Environment(\.dismiss) private var dismiss

    @State private var showPermissionAlert = false
    @State private var showLanguageRestartAlert = false
    @State private var showOnboarding = false
    @AppStorage("app_language") private var appLanguage: String = AppLanguageManager.defaultLanguageCode()
    @AppStorage("app_theme") private var appTheme: String = "system"

    private let languages = [
        ("zh-CN", String(localized: "language_zh")),
        ("en-US", String(localized: "language_en"))
    ]

    private let themes = [
        ("system", String(localized: "settings_theme_system")),
        ("light", String(localized: "settings_theme_light")),
        ("dark", String(localized: "settings_theme_dark"))
    ]

    var body: some View {
        List {
            // Theme Section
            Section {
                Picker(String(localized: "settings_theme_header"), selection: $appTheme) {
                    ForEach(themes, id: \.0) { theme in
                        Text(theme.1).tag(theme.0)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Language Section
            Section {
                ForEach(languages, id: \.0) { code, name in
                    Button(action: {
                        appLanguage = code
                        AppLanguageManager.setLanguage(code)
                        viewModel.updateLanguage(code)
                        showLanguageRestartAlert = true
                    }) {
                        HStack {
                            Text(name)
                                .foregroundColor(.primary)

                            Spacer()

                            if appLanguage == code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text(String(localized: "settings_language_header"))
            }

            // Permissions Section
            Section {
                PermissionRow(
                    title: String(localized: "settings_permission_microphone"),
                    icon: "mic.fill",
                    isGranted: viewModel.checkPermissions()
                )

                PermissionRow(
                    title: String(localized: "settings_permission_speech"),
                    icon: "waveform",
                    isGranted: viewModel.checkPermissions()
                )

                if !viewModel.checkPermissions() {
                    Button(action: requestPermissions) {
                        HStack {
                            Spacer()
                            Text(String(localized: "settings_request_permissions"))
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                }
            } header: {
                Text(String(localized: "settings_permissions_header"))
            } footer: {
                Text(String(localized: "settings_permissions_footer"))
            }

            // Pairing Section
            Section {
                Toggle(
                    String(localized: "settings_send_to_mac_title"),
                    isOn: Binding(
                        get: { viewModel.sendResultsToMacEnabled },
                        set: { viewModel.sendResultsToMacEnabled = $0 }
                    )
                )
            } header: {
                Text(String(localized: "settings_send_to_mac_header"))
            } footer: {
                Text(String(localized: "settings_send_to_mac_footer"))
            }

            if viewModel.shouldShowMacPairingOptions {
                Section {
                    if case .paired(_, let deviceName) = viewModel.pairingState {
                        HStack {
                            Text(String(localized: "settings_paired_device"))
                            Spacer()
                            Text(deviceName)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text(String(localized: "settings_connection_status"))
                            Spacer()
                            connectionStatusBadge
                        }

                        if case .disconnected = viewModel.connectionState {
                            Button(action: {
                                viewModel.reconnect()
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "arrow.clockwise")
                                    Text(String(localized: "settings_reconnect"))
                                    Spacer()
                                }
                            }
                        }

                        if let reconnectStatusMessage = viewModel.reconnectStatusMessage {
                            HStack(alignment: .top) {
                                Image(systemName: reconnectStatusIcon)
                                    .foregroundColor(reconnectStatusColor)
                                    .font(.caption)
                                    .padding(.top, 2)
                                Text(reconnectStatusMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }

                        Button(role: .destructive, action: {
                            viewModel.unpair()
                            dismiss()
                        }) {
                            HStack {
                                Spacer()
                                Text(String(localized: "settings_unpair"))
                                Spacer()
                            }
                        }
                    } else {
                        Button(action: {
                            viewModel.openPairing()
                        }) {
                            HStack {
                                Image(systemName: "link.badge.plus")
                                    .foregroundColor(.blue)
                                Text(String(localized: "settings_open_pairing"))
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "settings_pairing_header"))
                } footer: {
                    Text(String(localized: "settings_pairing_footer"))
                }
            }

            // About Section
            Section {
                NavigationLink {
                    IOSDataLogsView(viewModel: viewModel)
                } label: {
                    HStack {
                        Image(systemName: "tray.full")
                            .foregroundColor(.blue)
                        Text(String(localized: "settings_view_logs"))
                    }
                }
            } header: {
                Text(String(localized: "settings_debug_header"))
            }

            // Guide Section
            Section {
                Button(action: {
                    showOnboarding = true
                }) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.blue)
                            .frame(width: 30)

                        Text(String(localized: "onboarding_menu_guide"))
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            } header: {
                Text(String(localized: "settings_guide_header"))
            }

            Section {
                HStack {
                    Text(String(localized: "settings_version"))
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(String(localized: "settings_about_header"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .contentMargins(.top, 8, for: .scrollContent)
        .modifier(SettingsNavigationTitleModifier(isVisible: showsNavigationTitle))
        .alert(String(localized: "settings_permission_alert_title"), isPresented: $showPermissionAlert) {
            Button(String(localized: "ok_button"), role: .cancel) { }
        } message: {
            Text(String(localized: "settings_permission_alert_message"))
        }
        .alert(String(localized: "settings_language_restart_title"), isPresented: $showLanguageRestartAlert) {
            Button(String(localized: "settings_language_restart_button"), role: .cancel) { }
        } message: {
            Text(String(localized: "settings_language_restart_message"))
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(onComplete: {
                showOnboarding = false
            })
        }
    }

    private func requestPermissions() {
        viewModel.requestPermissions { granted in
            if !granted {
                showPermissionAlert = true
            }
        }
    }

    private var connectionStatusBadge: some View {
        Group {
            switch viewModel.connectionState {
            case .connected:
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text(String(localized: "connection_status_connected"))
                        .foregroundColor(.secondary)
                }
            case .connecting:
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    Text(String(localized: "connection_status_connecting"))
                        .foregroundColor(.secondary)
                }
            case .disconnected:
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(String(localized: "connection_status_disconnected"))
                        .foregroundColor(.secondary)
                }
            case .error:
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text(String(localized: "settings_connection_status_error"))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var reconnectStatusIcon: String {
        switch viewModel.connectionState {
        case .connected:
            return "checkmark.circle.fill"
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .error:
            return "exclamationmark.triangle.fill"
        case .disconnected:
            return "antenna.radiowaves.left.and.right.slash"
        }
    }

    private var reconnectStatusColor: Color {
        switch viewModel.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .blue
        case .error:
            return .orange
        case .disconnected:
            return .secondary
        }
    }
}

private struct SettingsNavigationTitleModifier: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        if isVisible {
            content
                .navigationTitle(String(localized: "settings_title"))
                .navigationBarTitleDisplayMode(.inline)
        } else {
            content
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct IOSDataLogsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var selectedFilter: IOSDataFilter = .all

    private enum IOSDataFilter: String, CaseIterable, Identifiable {
        case all = "logs_filter_all"
        case voice = "logs_filter_voice"
        case connection = "logs_filter_connection"

        var id: String { rawValue }
    }

    var body: some View {
        List {
            Section {
                Picker(String(localized: "logs_filter_label"), selection: $selectedFilter) {
                    ForEach(IOSDataFilter.allCases) { filter in
                        Text(String(localized: .init(filter.rawValue))).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                Button(role: .destructive) {
                    viewModel.clearInboundDataRecords()
                } label: {
                    Text(String(localized: "logs_clear"))
                }
                .disabled(viewModel.inboundDataRecords.isEmpty)
            }

            if filteredRecords.isEmpty {
                Section {
                    ContentUnavailableView(
                        String(localized: "logs_empty_title"),
                        systemImage: "tray",
                        description: Text(String(localized: "logs_empty_description"))
                    )
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(filteredRecords) { record in
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(record.title, systemImage: iconName(for: record))
                                    .foregroundColor(color(for: record))
                                Spacer()
                                Text(record.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text(record.detail)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "logs_title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filteredRecords: [InboundDataRecord] {
        switch selectedFilter {
        case .all:
            return viewModel.inboundDataRecords
        case .voice:
            return viewModel.inboundDataRecords.filter { $0.category == .voice }
        case .connection:
            return viewModel.inboundDataRecords.filter { $0.category != .voice }
        }
    }

    private func iconName(for record: InboundDataRecord) -> String {
        if record.severity == .error {
            return "exclamationmark.triangle.fill"
        }

        switch record.category {
        case .voice:
            return "waveform.circle.fill"
        case .pairing:
            return "iphone.and.arrow.forward"
        case .connection:
            return "antenna.radiowaves.left.and.right"
        }
    }

    private func color(for record: InboundDataRecord) -> Color {
        switch record.severity {
        case .info:
            switch record.category {
            case .voice:
                return .purple
            case .pairing:
                return .blue
            case .connection:
                return .green
            }
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

struct PermissionRow: View {
    let title: String
    let icon: String
    let isGranted: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isGranted ? .green : .gray)
                .frame(width: 30)

            Text(title)

            Spacer()

            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isGranted ? .green : .red)
        }
    }
}
