import SwiftUI
import SharedCore

struct SettingsView: View {
    @ObservedObject var viewModel: ContentViewModel
    var showsNavigationTitle = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showPermissionAlert = false
    @State private var showLanguageRestartAlert = false
    @State private var showSupportMailUnavailableAlert = false
    @State private var showOnboarding = false
    @AppStorage("app_language") private var appLanguage: String = AppLanguageManager.defaultLanguageCode()
    @AppStorage("app_theme") private var appTheme: String = "system"
    @AppStorage(AppLightBackgroundTintPolicy.storageKey) private var lightThemeBackgroundHex: String = AppLightBackgroundTintPolicy.defaultHex

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
        let hasPermissions = viewModel.checkPermissions()

        List {
            ForEach(SettingsInformationHierarchyPolicy.rootSections, id: \.self) { section in
                rootSection(for: section, hasPermissions: hasPermissions)
            }
        }
        .modifier(AppListChrome())
        .contentMargins(.top, 8, for: .scrollContent)
        .modifier(SettingsNavigationTitleModifier(isVisible: showsNavigationTitle))
        .modifier(AppPageCanvas())
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
        .alert(String(localized: "settings_support_mail_unavailable_title"), isPresented: $showSupportMailUnavailableAlert) {
            Button(String(localized: "ok_button"), role: .cancel) { }
        } message: {
            Text(String(localized: "settings_support_mail_unavailable_message"))
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(onComplete: {
                showOnboarding = false
            })
        }
        .task {
            await viewModel.refreshTwoDeviceSyncBillingState()
        }
    }

    @ViewBuilder
    private func rootSection(
        for section: SettingsInformationHierarchyPolicy.RootSection,
        hasPermissions: Bool
    ) -> some View {
        switch section {
        case .status:
            NavigationLink {
                SettingsAccountMembershipView(viewModel: viewModel)
            } label: {
                SettingsAccountStatusCard(
                    presentation: SettingsMembershipPresentationPolicy.headerPresentation(
                        for: viewModel.activeTwoDeviceSyncEntitlement
                    ),
                    title: String(localized: .init(SettingsMembershipPresentationPolicy.rootHeaderTitleKey)),
                    subtitle: viewModel.twoDeviceSyncStatusText,
                    detail: viewModel.twoDeviceSyncDetailText
                )
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
        case .pairing:
            SettingsPairingConnectionSection(
                viewModel: viewModel,
                onDismissAfterUnpair: { dismiss() }
            )
        case .appearance:
            SettingsAppearanceLanguageSection(
                appTheme: $appTheme,
                lightThemeBackgroundHex: $lightThemeBackgroundHex,
                appLanguage: $appLanguage,
                themes: themes,
                languages: languages,
                onSelectLanguage: selectLanguage
            )
        case .about:
            SettingsAboutSection()
        case .support:
            SettingsPermissionsSupportSection(
                viewModel: viewModel,
                hasPermissions: hasPermissions,
                versionText: "1.0.0",
                requestPermissions: requestPermissions,
                showOnboarding: { showOnboarding = true },
                contactSupport: contactSupport,
                openPrivacyPolicy: openPrivacyPolicy
            )
        }
    }

    private func requestPermissions() {
        viewModel.requestPermissions { granted in
            if !granted {
                showPermissionAlert = true
            }
        }
    }

    private func selectLanguage(_ code: String) {
        appLanguage = code
        AppLanguageManager.setLanguage(code)
        viewModel.updateLanguage(code)
        showLanguageRestartAlert = true
    }

    private func contactSupport() {
        guard let supportEmailURL = SettingsSupportLinkPolicy.supportEmailURL else {
            showSupportMailUnavailableAlert = true
            return
        }

        openURL(supportEmailURL) { accepted in
            if !accepted {
                showSupportMailUnavailableAlert = true
            }
        }
    }

    private func openPrivacyPolicy() {
        guard let privacyURL = SettingsMembershipLinkPolicy.privacyPolicyURL else {
            return
        }
        openURL(privacyURL)
    }
}

private struct SettingsPairingConnectionSection: View {
    @ObservedObject var viewModel: ContentViewModel
    let onDismissAfterUnpair: () -> Void

    var body: some View {
        Section {
            ForEach(SettingsInformationHierarchyPolicy.pairingItems, id: \.self) { item in
                pairingItem(item)
            }
        } header: {
            Text(String(localized: "settings_pairing_header"))
        } footer: {
            Text(String(localized: "settings_pairing_footer"))
        }
        .modifier(AppGroupedRowSurface())
    }

    @ViewBuilder
    private func pairingItem(_ item: SettingsInformationHierarchyPolicy.PairingItem) -> some View {
        switch item {
        case .sendToMac:
            sendToMacRow
        case .connection:
            connectionRows
        }
    }

    private var sendToMacRow: some View {
        Group {
            Toggle(
                String(localized: "settings_send_to_mac_title"),
                isOn: Binding(
                    get: { viewModel.sendResultsToMacEnabled },
                    set: { viewModel.sendResultsToMacEnabled = $0 }
                )
            )

            Text(String(localized: "settings_send_to_mac_footer"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private var connectionRows: some View {
        Group {
            if viewModel.shouldShowMacPairingOptions {
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
                        Button(action: viewModel.reconnect) {
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
                        onDismissAfterUnpair()
                    }) {
                        HStack {
                            Spacer()
                            Text(String(localized: "settings_unpair"))
                            Spacer()
                        }
                    }
                } else {
                    Button(action: viewModel.openPairing) {
                        HStack {
                            Image(systemName: "link.badge.plus")
                                .foregroundColor(.blue)
                            Text(String(localized: "settings_open_pairing"))
                        }
                    }
                }
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

private struct SettingsAppearanceLanguageSection: View {
    @Binding var appTheme: String
    @Binding var lightThemeBackgroundHex: String
    @Binding var appLanguage: String
    let themes: [(String, String)]
    let languages: [(String, String)]
    let onSelectLanguage: (String) -> Void

    var body: some View {
        Section {
            ForEach(SettingsAppearancePresentationPolicy.visibleItems(appTheme: appTheme), id: \.self) { item in
                appearanceItem(item)
            }
        } header: {
            Text(String(localized: "settings_theme_header"))
        }
        .modifier(AppGroupedRowSurface())
    }

    @ViewBuilder
    private func appearanceItem(_ item: SettingsInformationHierarchyPolicy.AppearanceItem) -> some View {
        switch item {
        case .theme:
            Picker(String(localized: "settings_theme_header"), selection: $appTheme) {
                ForEach(themes, id: \.0) { theme in
                    Text(theme.1).tag(theme.0)
                }
            }
            .pickerStyle(.segmented)
        case .lightBackgroundColor:
            ColorPicker(
                selection: AppLightBackgroundTintPolicy.colorBinding(storedHex: $lightThemeBackgroundHex),
                supportsOpacity: false
            ) {
                HStack {
                    Text(String(localized: "settings_theme_background_color"))
                    Spacer()
                    Text(AppLightBackgroundTintPolicy.normalizedHex(storedHex: lightThemeBackgroundHex))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        case .language:
            Text(String(localized: "settings_language_header"))
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(languages, id: \.0) { code, name in
                Button(action: {
                    onSelectLanguage(code)
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
        }
    }
}

private struct SettingsPermissionsSupportSection: View {
    @ObservedObject var viewModel: ContentViewModel
    let hasPermissions: Bool
    let versionText: String
    let requestPermissions: () -> Void
    let showOnboarding: () -> Void
    let contactSupport: () -> Void
    let openPrivacyPolicy: () -> Void

    var body: some View {
        Section {
            ForEach(SettingsInformationHierarchyPolicy.supportItems, id: \.self) { item in
                supportItem(item)
            }
        } footer: {
            Text(String(localized: "settings_permissions_footer"))
        }
        .modifier(AppGroupedRowSurface())
    }

    @ViewBuilder
    private func supportItem(_ item: SettingsInformationHierarchyPolicy.SupportItem) -> some View {
        switch item {
        case .permissions:
            PermissionRow(
                title: String(localized: "settings_permission_microphone"),
                icon: "mic.fill",
                isGranted: hasPermissions
            )

            PermissionRow(
                title: String(localized: "settings_permission_speech"),
                icon: "waveform",
                isGranted: hasPermissions
            )

            if !hasPermissions {
                Button(action: requestPermissions) {
                    HStack {
                        Spacer()
                        Text(String(localized: "settings_request_permissions"))
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
            }
        case .help:
            Button(action: showOnboarding) {
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
        case .supportEmail:
            Button(action: contactSupport) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.blue)
                        .frame(width: 30)

                    Text(String(localized: "settings_contact_support"))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        case .privacyPolicy:
            Button(action: openPrivacyPolicy) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.blue)
                        .frame(width: 30)

                    Text(String(localized: "settings_privacy_policy"))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        case .logs:
            NavigationLink {
                IOSDataLogsView(viewModel: viewModel)
            } label: {
                HStack {
                    Image(systemName: "tray.full")
                        .foregroundColor(.blue)
                    Text(String(localized: "settings_view_logs"))
                }
            }
        case .version:
            HStack {
                Text(String(localized: "settings_version"))
                Spacer()
                Text(versionText)
                    .foregroundColor(.secondary)
            }
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
        .modifier(AppListChrome())
        .navigationTitle(String(localized: "logs_title"))
        .navigationBarTitleDisplayMode(.inline)
        .modifier(AppPageCanvas())
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

private struct SettingsAboutSection: View {
    var body: some View {
        Section {
            if let websiteURL = SettingsMembershipLinkPolicy.websiteURL {
                Link(destination: websiteURL) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                            .frame(width: 30)

                        Text(String(localized: "settings_website"))
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(String(localized: "settings_about"))
        }
        .modifier(AppGroupedRowSurface())
    }
}
