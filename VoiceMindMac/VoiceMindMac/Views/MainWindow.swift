import AppKit
import SharedCore
import SwiftUI

struct MainWindow: View {
    @ObservedObject var controller: MenuBarController
    @ObservedObject var settings = AppSettings.shared

    @State private var selectedTab = 0
    @State private var debugUnlocked = false

    var body: some View {
        TabView(selection: $selectedTab) {
            StatusTab(controller: controller)
                .tabItem {
                    Label(String(localized: "tab_status"), systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(0)

            SettingsTab(settings: settings, controller: controller)
                .tabItem {
                    Label(String(localized: "tab_settings"), systemImage: "gearshape")
                }
                .tag(1)

            SpeechRecognitionTab(controller: controller)
                .tabItem {
                    Label(String(localized: "tab_speech"), systemImage: "waveform.circle")
                }
                .tag(2)

            DataRecordsTab(controller: controller)
                .tabItem {
                    Label(String(localized: "tab_data"), systemImage: "tray.full")
                }
                .tag(3)

            PermissionsTab()
                .tabItem {
                    Label(String(localized: "tab_permissions"), systemImage: "lock.shield")
                }
                .tag(4)

            AboutTab(
                onOpenGuide: {
                    controller.showUsageGuide()
                },
                onRevealDebug: {
                    debugUnlocked = true
                    selectedTab = 6
                }
            )
                .tabItem {
                    Label(String(localized: "tab_about"), systemImage: "info.circle")
                }
                .tag(5)

            if debugUnlocked {
                PermissionsDebugView()
                    .tabItem {
                        Label(String(localized: "tab_debug"), systemImage: "ladybug")
                    }
                    .tag(6)
            }
        }
        .frame(width: 600, height: 600)
    }
}

// MARK: - Status Tab

struct StatusTab: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(spacing: 20) {
            Text("🎤 \(String(localized: "app_title"))")
                .font(.system(size: 32, weight: .bold))

            // Connection Status
            GroupBox(label: Label(String(localized: "status_connection_title"), systemImage: "network")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(String(localized: "status_label"))
                        Spacer()
                        connectionStatusView
                    }

                    if case .paired(_, let deviceName) = controller.pairingState {
                        Divider()
                        HStack {
                            Text(String(localized: "status_paired_device_label"))
                            Spacer()
                            Text(deviceName)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let progressMessage = effectivePairingProgressMessage {
                        Divider()
                        HStack(alignment: .top) {
                            Text(String(localized: "status_pairing_progress_label"))
                            Spacer()
                            Label {
                                Text(progressMessage)
                                    .multilineTextAlignment(.trailing)
                            } icon: {
                                Image(systemName: pairingProgressIconName)
                            }
                            .foregroundColor(pairingProgressColor)
                        }
                    }

                    Divider()
                    HStack {
                        Text(String(localized: "status_ip_label"))
                        Spacer()
                        Text(getLocalIPAddress() ?? String(localized: "status_unknown_value"))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }

            // Service Status
            GroupBox(label: Label(String(localized: "status_service_title"), systemImage: "server.rack")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(String(localized: "status_service_label"))
                        Spacer()
                        Text(controller.isServiceRunning ? String(localized: "status_service_running") : String(localized: "status_service_stopped"))
                            .foregroundColor(controller.isServiceRunning ? .green : .secondary)
                    }
                }
                .padding()
            }

            // Notes Section with Local Recording
            GroupBox(label: Label(String(localized: "note_title"), systemImage: "note.text")) {
                VStack(alignment: .leading, spacing: 12) {
                    // Note text display
                    Text(controller.noteText.isEmpty ? String(localized: "note_placeholder") : controller.noteText)
                        .font(.body)
                        .foregroundColor(controller.noteText.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)

                    // Recording button
                    HStack {
                        Spacer()

                        RecordButton(
                            isRecording: controller.isLocalRecording,
                            action: {
                                controller.toggleLocalRecording()
                            }
                        )

                        Button(action: {
                            controller.clearNote()
                        }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(controller.noteText.isEmpty)
                    }
                }
                .padding()
            }

            Spacer()

            // Control Buttons
            HStack(spacing: 15) {
                if !controller.isServiceRunning {
                    Button(action: {
                        controller.startNetworkServices()
                    }) {
                        Label(String(localized: "status_action_start_service"), systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(action: {
                        controller.stopNetworkServices()
                    }) {
                        Label(String(localized: "status_action_stop_service"), systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)

            // Pairing Button
            if controller.isServiceRunning {
                if case .unpaired = controller.pairingState {
                    Button(action: {
                        controller.showPairingWindowFromUI()
                    }) {
                        Label(String(localized: "status_action_start_pairing"), systemImage: "iphone.and.arrow.forward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                } else if case .paired(_, let deviceName) = controller.pairingState {
                    HStack {
                        Text(String(format: String(localized: "status_paired_device_format"), deviceName))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(AppLocalization.localizedString("status_action_unpair")) {
                            controller.unpairDeviceFromUI()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        switch controller.connectionState {
        case .disconnected:
            Label(String(localized: "status_connection_disconnected"), systemImage: "circle")
                .foregroundColor(.secondary)
        case .connecting:
            Label(String(localized: "status_connection_connecting"), systemImage: "circle.dotted")
                .foregroundColor(.orange)
        case .connected:
            Label(String(localized: "status_connection_connected"), systemImage: "circle.fill")
                .foregroundColor(.green)
        case .error:
            Label(String(localized: "status_connection_error"), systemImage: "exclamationmark.triangle")
                .foregroundColor(.red)
        }
    }

    private var pairingProgressIconName: String {
        if case .paired = controller.pairingState {
            return "checkmark.circle.fill"
        }

        return "hourglass.circle.fill"
    }

    private var pairingProgressColor: Color {
        if case .paired = controller.pairingState {
            return .green
        }

        return .orange
    }

    private var effectivePairingProgressMessage: String? {
        PairingProgressDisplay.message(
            pairingState: controller.pairingState,
            connectionState: controller.connectionState,
            progressMessage: controller.pairingProgressMessage
        )
    }

    private func getLocalIPAddress() -> String? {
        LocalNetworkAccessPolicy.preferredLocalIPv4()
    }
}

// MARK: - Settings Tab

struct SettingsTab: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var controller: MenuBarController
    @State private var serverPortText = ""

    var body: some View {
        Form {
            Section(header: Text(String(localized: "settings_text_injection_title"))) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "settings_text_injection_clipboard_title"))
                        .font(.body)
                        .fontWeight(.medium)

                    Text(String(localized: "settings_text_injection_clipboard_desc"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text(String(localized: "settings_language_title"))) {
                Picker(String(localized: "settings_language_picker"), selection: $settings.language) {
                    Text(String(localized: "settings_language_zh")).tag("zh-CN")
                    Text(String(localized: "settings_language_en")).tag("en-US")
                }
            }

            Section(header: Text(String(localized: "settings_network_title"))) {
                HStack {
                    Text(String(localized: "settings_network_port_label"))
                    Spacer()
                    TextField(String(localized: "settings_network_port_placeholder"), text: $serverPortText)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            serverPortText = String(settings.serverPort)
                        }
                        .onChange(of: serverPortText) { _, newValue in
                            let digitsOnly = newValue.filter(\.isNumber)
                            if digitsOnly != serverPortText {
                                serverPortText = digitsOnly
                                return
                            }

                            guard let port = UInt16(digitsOnly), port >= 1024 else { return }
                            if settings.serverPort != port {
                                settings.serverPort = port
                            }
                        }
                }

                Text(String(localized: "settings_network_port_desc"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Data Records Tab

struct DataRecordsTab: View {
    @ObservedObject var controller: MenuBarController
    @State private var selectedFilter: DataRecordFilter = .all
    @State private var searchText = ""
    @State private var groupBySession = true

    private enum DataRecordFilter: String, CaseIterable, Identifiable {
        case all
        case voice
        case pairing

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .all:
                return "data_filter_all"
            case .voice:
                return "data_filter_voice"
            case .pairing:
                return "data_filter_pairing"
            }
        }

        var title: String {
            String(localized: .init(titleKey))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "data_title"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(String(localized: "data_subtitle"))
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .center, spacing: 12) {
                Text(String(localized: "data_filter_picker"))
                    .font(.headline)
                    .foregroundColor(.secondary)

                Picker(String(localized: "data_filter_picker"), selection: $selectedFilter) {
                    ForEach(DataRecordFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                Spacer(minLength: 0)

                Button(AppLocalization.localizedString("data_action_clear")) {
                    controller.clearInboundDataRecords()
                }
                .buttonStyle(.bordered)
                .disabled(controller.inboundDataRecords.isEmpty)
            }

            HStack(spacing: 12) {
                TextField(String(localized: "data_search_placeholder"), text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Toggle(String(localized: "data_group_by_session"), isOn: $groupBySession)
                    .toggleStyle(.checkbox)
            }

            HStack(spacing: 12) {
                summaryBadge(title: String(localized: "data_summary_total"), value: "\(filteredRecords.count)", color: .secondary)
                summaryBadge(title: String(localized: "data_summary_voice"), value: "\(filteredVoiceCount)", color: .accentColor)
                summaryBadge(title: String(localized: "data_summary_pairing"), value: "\(filteredPairingCount)", color: .blue)
                summaryBadge(title: String(localized: "data_summary_failure"), value: "\(filteredFailureCount)", color: .red)
            }

            if filteredRecords.isEmpty {
                ContentUnavailableView(
                    String(localized: "data_empty_title"),
                    systemImage: "tray",
                    description: Text(emptyStateDescription)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                            if groupBySession {
                                ForEach(groupedRecords, id: \.title) { section in
                                    Section {
                                        ForEach(section.records) { record in
                                            recordCard(record)
                                                .id(record.id)
                                        }
                                    } header: {
                                        sectionHeader(section.title, count: section.records.count)
                                    }
                                }
                            } else {
                                ForEach(filteredRecords) { record in
                                    recordCard(record)
                                        .id(record.id)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: controller.inboundDataRecords.count) { _, _ in
                        guard let latestRecord = filteredRecords.first else { return }
                        proxy.scrollTo(latestRecord.id, anchor: .top)
                    }
                }
            }
        }
        .padding()
    }

    private var filteredRecords: [InboundDataRecord] {
        switch selectedFilter {
        case .all:
            return searchedRecords(controller.inboundDataRecords)
        case .voice:
            return searchedRecords(controller.inboundDataRecords.filter(\.isVoice))
        case .pairing:
            return searchedRecords(controller.inboundDataRecords.filter { !$0.isVoice })
        }
    }

    private var groupedRecords: [GroupedDataRecords] {
        var groups: [GroupedDataRecords] = []

        for record in filteredRecords {
            let sessionKey = extractSessionKey(from: record.detail) ?? String(localized: "data_session_unknown")
            if let index = groups.firstIndex(where: { $0.title == sessionKey }) {
                groups[index].records.append(record)
            } else {
                groups.append(GroupedDataRecords(title: sessionKey, records: [record]))
            }
        }

        return groups
    }

    private var filteredVoiceCount: Int {
        filteredRecords.filter { $0.category == .voice }.count
    }

    private var filteredPairingCount: Int {
        filteredRecords.filter { $0.category != .voice }.count
    }

    private var filteredFailureCount: Int {
        filteredRecords.filter { $0.severity == .error }.count
    }

    private var emptyStateDescription: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "data_empty_search_desc")
        }

        switch selectedFilter {
        case .all:
            return String(localized: "data_empty_all_desc")
        case .voice:
            return String(localized: "data_empty_voice_desc")
        case .pairing:
            return String(localized: "data_empty_pairing_desc")
        }
    }

    private func searchedRecords(_ records: [InboundDataRecord]) -> [InboundDataRecord] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return records }

        return records.filter {
            $0.title.localizedCaseInsensitiveContains(keyword)
            || $0.detail.localizedCaseInsensitiveContains(keyword)
        }
    }

    private func extractSessionKey(from detail: String) -> String? {
        detail
            .split(separator: "\n")
            .first(where: { $0.hasPrefix("Session: ") })
            .map { String($0.dropFirst("Session: ".count)) }
    }

    @ViewBuilder
    private func recordCard(_ record: InboundDataRecord) -> some View {
        let failure = record.severity == .error

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(record.title, systemImage: iconName(for: record, isFailure: failure))
                    .font(.headline)
                    .foregroundColor(recordColor(for: record, isFailure: failure))

                Spacer()

                Text(severityTitle(for: record.severity))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(severityBadgeColor(for: record.severity).opacity(0.15))
                    .foregroundColor(severityBadgeColor(for: record.severity))
                    .clipShape(Capsule())

                Text(record.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(record.detail)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .foregroundColor(failure ? .primary : .secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(recordBackgroundColor(isFailure: failure))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(failure ? Color.red.opacity(0.45) : Color.clear, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(String(format: String(localized: "data_section_count_format"), count))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func summaryBadge(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func isFailureRecord(_ record: InboundDataRecord) -> Bool {
        record.severity == .error
    }

    private func recordColor(for record: InboundDataRecord, isFailure: Bool) -> Color {
        if isFailure {
            return .red
        }

        switch record.category {
        case .voice:
            return .accentColor
        case .pairing:
            return .blue
        case .connection:
            return .primary
        }
    }

    private func recordBackgroundColor(isFailure: Bool) -> Color {
        if isFailure {
            return Color.red.opacity(0.08)
        }

        return Color(NSColor.controlBackgroundColor)
    }

    private func iconName(for record: InboundDataRecord, isFailure: Bool) -> String {
        if isFailure {
            return "exclamationmark.triangle.fill"
        }

        switch record.category {
        case .voice:
            return "waveform.circle.fill"
        case .pairing:
            return "iphone.and.arrow.forward"
        case .connection:
            return "tray.and.arrow.down.fill"
        }
    }

    private func severityBadgeColor(for severity: InboundDataSeverity) -> Color {
        switch severity {
        case .info:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private func severityTitle(for severity: InboundDataSeverity) -> String {
        switch severity {
        case .info:
            return String(localized: "data_severity_info")
        case .warning:
            return String(localized: "data_severity_warning")
        case .error:
            return String(localized: "data_severity_error")
        }
    }

    private func categoryTitle(for category: InboundDataCategory) -> String {
        switch category {
        case .voice:
            return String(localized: "data_category_voice")
        case .pairing:
            return String(localized: "data_category_pairing")
        case .connection:
            return String(localized: "data_category_connection")
        }
    }
}

private struct GroupedDataRecords {
    let title: String
    var records: [InboundDataRecord]
}

// MARK: - Permissions Tab

struct PermissionsTab: View {
    @State private var accessibilityGranted = false
    @State private var inputMonitoringGranted = false

    var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "permissions_tab_title"))
                .font(.title)
                .padding(.top)

            GroupBox {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(accessibilityGranted ? .green : .red)
                        Text(String(localized: "permissions_tab_accessibility_title"))
                        Spacer()
                        Text(accessibilityGranted ? String(localized: "permissions_tab_granted") : String(localized: "permissions_tab_denied"))
                            .foregroundColor(.secondary)
                    }

                    Text(String(localized: "permissions_tab_accessibility_desc"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    HStack {
                        Image(systemName: inputMonitoringGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(inputMonitoringGranted ? .green : .red)
                        Text(String(localized: "permissions_tab_input_title"))
                        Spacer()
                        Text(inputMonitoringGranted ? String(localized: "permissions_tab_granted") : String(localized: "permissions_tab_denied"))
                            .foregroundColor(.secondary)
                    }

                    Text(String(localized: "permissions_tab_input_desc"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            HStack(spacing: 15) {
                Button(AppLocalization.localizedString("permissions_tab_check")) {
                    checkPermissions()
                }
                .buttonStyle(.bordered)

                Button(AppLocalization.localizedString("permissions_tab_request")) {
                    requestPermissions()
                }
                .buttonStyle(.borderedProminent)

                Button(AppLocalization.localizedString("permissions_tab_open_settings")) {
                    PermissionsManager.openSystemPreferences(for: .accessibility)
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        accessibilityGranted = PermissionsManager.checkAccessibility() == .granted
        inputMonitoringGranted = PermissionsManager.checkInputMonitoring() == .granted
    }

    private func requestPermissions() {
        PermissionsManager.requestAccessibility()
        PermissionsManager.requestInputMonitoring()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            checkPermissions()
        }
    }
}

// MARK: - About Tab

struct AboutTab: View {
    let onOpenGuide: () -> Void
    let onRevealDebug: () -> Void

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                Text(String(localized: "app_title"))
                    .font(.title)

                Text(String(localized: "about_version"))
                    .foregroundColor(.secondary)
                    .onTapGesture(count: 2, perform: onRevealDebug)

                Divider()
                    .frame(maxWidth: 260)

                Text(String(localized: "about_title"))
                    .font(.headline)

                Text(String(localized: "about_description"))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 360)

                Button(String(localized: "about_open_guide")) {
                    onOpenGuide()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Record Button

struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            if isRecording {
                action()
            } else {
                action()
            }
        }) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.accentColor)
                    .frame(width: 60, height: 60)
                    .shadow(color: isRecording ? .red.opacity(0.5) : .accentColor.opacity(0.3), radius: isRecording ? 10 : 5)

                if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        if !isRecording {
                            action()
                        }
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    if isRecording {
                        action()
                    }
                }
        )
    }
}
