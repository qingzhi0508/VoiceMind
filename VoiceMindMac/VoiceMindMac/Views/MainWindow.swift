import AppKit
import SharedCore
import StoreKit
import SwiftUI

private extension Color {
    static func adaptive(
        light: (red: Double, green: Double, blue: Double, opacity: Double),
        dark: (red: Double, green: Double, blue: Double, opacity: Double)
    ) -> Color {
        Color(
            nsColor: NSColor(
                name: nil,
                dynamicProvider: { appearance in
                    let palette = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
                    return NSColor(
                        calibratedRed: palette.red,
                        green: palette.green,
                        blue: palette.blue,
                        alpha: palette.opacity
                    )
                }
            )
        )
    }
}

enum MainWindowColors {
    static let pageBackground = Color.adaptive(
        light: (0.95, 0.96, 0.985, 1),
        dark: (0.08, 0.1, 0.14, 1)
    )
    static let sidebarBackgroundTop = Color.adaptive(
        light: (0.965, 0.972, 0.988, 1),
        dark: (0.1, 0.12, 0.17, 1)
    )
    static let sidebarBackgroundBottom = Color.adaptive(
        light: (0.935, 0.945, 0.972, 1),
        dark: (0.08, 0.1, 0.15, 1)
    )
    static let canvasBackground = Color.adaptive(
        light: (1, 1, 1, 1),
        dark: (0.11, 0.13, 0.18, 1)
    )
    static let canvasBorder = Color.adaptive(
        light: (0, 0, 0, 0.08),
        dark: (1, 1, 1, 0.08)
    )
    static let title = Color.adaptive(
        light: (0.09, 0.12, 0.2, 1),
        dark: (0.93, 0.95, 0.99, 1)
    )
    static let primaryText = Color.adaptive(
        light: (0.18, 0.22, 0.3, 1),
        dark: (0.82, 0.86, 0.94, 1)
    )
    static let secondaryText = Color.adaptive(
        light: (0.42, 0.48, 0.6, 1),
        dark: (0.61, 0.68, 0.8, 1)
    )
    static let sidebarText = Color.adaptive(
        light: (0.3, 0.36, 0.48, 1),
        dark: (0.74, 0.79, 0.88, 1)
    )
    static let sidebarSelectedFill = Color.adaptive(
        light: (0.84, 0.89, 0.98, 1),
        dark: (0.18, 0.24, 0.35, 1)
    )
    static let sidebarSelectedBorder = Color.adaptive(
        light: (0.48, 0.74, 0.96, 1),
        dark: (0.38, 0.63, 0.95, 1)
    )
    static let spotlightTop = Color.adaptive(
        light: (0.99, 0.96, 0.82, 1),
        dark: (0.28, 0.22, 0.1, 1)
    )
    static let spotlightBottom = Color.adaptive(
        light: (0.98, 0.93, 0.72, 1),
        dark: (0.22, 0.18, 0.08, 1)
    )
    static let cardBorder = Color.adaptive(
        light: (0.84, 0.88, 0.95, 1),
        dark: (0.23, 0.29, 0.39, 1)
    )
    static let softSurface = Color.adaptive(
        light: (0.965, 0.972, 0.988, 1),
        dark: (0.14, 0.17, 0.23, 1)
    )
    static let cardSurface = Color.adaptive(
        light: (0.975, 0.98, 0.992, 1),
        dark: (0.13, 0.15, 0.21, 1)
    )
    static let recentActivitySurface = Color.adaptive(
        light: (0.99, 0.995, 1.0, 1),
        dark: (0.16, 0.19, 0.25, 1)
    )
    static let secondaryButtonSurface = Color.adaptive(
        light: (0.94, 0.96, 0.99, 1),
        dark: (0.18, 0.22, 0.3, 1)
    )
}

enum SettingsSurfaceStylePolicy {
    static let usesNativeGroupedForm = false
    static let cardBorderColor = MainWindowColors.cardBorder
    static let cardFillColor = MainWindowColors.cardSurface
    static let rowFillColor = MainWindowColors.softSurface
    static let secondaryTextColor = MainWindowColors.secondaryText
}

enum MacBillingPresentationPolicy {
    static func showsUnlockOptions(for entitlement: TwoDeviceSyncEntitlement) -> Bool {
        entitlement != .lifetime
    }
}

enum MainWindowSection: String, CaseIterable, Identifiable {
    case home
    case records
    case collaboration
    case data
    case speech
    case about
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return String(localized: "main_nav_home")
        case .records:
            return String(localized: "main_nav_records")
        case .collaboration:
            return String(localized: "main_nav_collaboration")
        case .data:
            return String(localized: "main_nav_logs")
        case .speech:
            return String(localized: "tab_speech")
        case .about:
            return String(localized: "tab_about")
        case .settings:
            return String(localized: "tab_settings")
        }
    }

    var subtitle: String {
        switch self {
        case .home:
            return String(localized: "main_notes_subtitle")
        case .records:
            return String(localized: "main_records_subtitle")
        case .collaboration:
            return String(localized: "main_collaboration_subtitle")
        case .data:
            return String(localized: "data_subtitle")
        case .speech:
            return String(localized: "main_speech_subtitle")
        case .about:
            return String(localized: "about_description")
        case .settings:
            return String(localized: "main_settings_subtitle")
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "note.text"
        case .records:
            return "clock.arrow.circlepath"
        case .collaboration:
            return "dot.radiowaves.left.and.right"
        case .data:
            return "tray.full"
        case .speech:
            return "waveform.circle"
        case .about:
            return "questionmark.circle"
        case .settings:
            return "gearshape"
        }
    }

    static let primaryItems: [MainWindowSection] = MainWindowNavigationPolicy.primarySections
    static let secondaryItems: [MainWindowSection] = [.data, .settings, .about]
}

enum MainWindowContentSection: Equatable {
    case notes
    case records
    case collaboration
    case data
    case speech
    case about
    case settings
}

enum MainWindowNavigationPolicy {
    static let primarySections: [MainWindowSection] = [.home, .records, .collaboration, .speech]

    static func contentSection(for section: MainWindowSection) -> MainWindowContentSection {
        switch section {
        case .home:
            return .notes
        case .records:
            return .records
        case .collaboration:
            return .collaboration
        case .data:
            return .data
        case .speech:
            return .speech
        case .about:
            return .about
        case .settings:
            return .settings
        }
    }
}

enum MainWindowPagePersistencePolicy {
    static let persistentSections: [MainWindowSection] = [
        .home,
        .records,
        .collaboration,
        .data,
        .speech,
        .settings,
        .about
    ]
}

enum SidebarNavigationInteractionPolicy {
    static let usesNativeButtonFocusRing = false
}

struct CollaborationControlsPolicy {
    let pairingState: PairingState
    let isServiceRunning: Bool

    var showsStartPairing: Bool {
        guard isServiceRunning else { return false }
        if case .unpaired = pairingState {
            return true
        }

        return false
    }

    var showsUnpair: Bool {
        if case .paired = pairingState {
            return true
        }

        return false
    }

    var pairedDeviceName: String? {
        if case .paired(_, let deviceName) = pairingState {
            return deviceName
        }

        return nil
    }
}

struct MainWindow: View {
    @ObservedObject var controller: MenuBarController
    @ObservedObject var settings = AppSettings.shared

    @State private var selectedSection: MainWindowSection = .home
    var body: some View {
        ZStack {
            MainWindowColors.pageBackground
                .ignoresSafeArea()

            HStack(spacing: 0) {
                sidebar
                contentArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .preferredColorScheme(settings.themePreference.preferredColorScheme)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange.opacity(0.95),
                                    Color.yellow.opacity(0.8),
                                    Color.green.opacity(0.75)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "waveform")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "app_title"))
                        .font(.system(size: 26, weight: .bold))
                    Text(String(localized: "main_brand_subtitle"))
                        .font(.callout)
                        .foregroundColor(MainWindowColors.secondaryText)
                }
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                ForEach(MainWindowSection.primaryItems) { item in
                    sidebarItem(item)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                ForEach(MainWindowSection.secondaryItems) { item in
                    sidebarItem(item)
                }
            }
        }
        .padding(22)
        .frame(width: 280)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    MainWindowColors.sidebarBackgroundTop,
                    MainWindowColors.sidebarBackgroundBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(MainWindowColors.canvasBorder)
                .frame(width: 1)
        }
    }

    private func sidebarItem(_ item: MainWindowSection) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 24)

            Text(item.title)
                .font(.system(size: 18, weight: .semibold))

            Spacer(minLength: 0)
        }
        .foregroundColor(selectedSection == item ? MainWindowColors.title : MainWindowColors.sidebarText)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(selectedSection == item ? MainWindowColors.sidebarSelectedFill : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selectedSection == item ? MainWindowColors.sidebarSelectedBorder : Color.clear, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            selectedSection = item
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(selectedSection == item ? .isSelected : [])
    }

    private var contentArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(MainWindowColors.canvasBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(MainWindowColors.canvasBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)

            ZStack {
                ForEach(MainWindowPagePersistencePolicy.persistentSections) { section in
                    pageContent(for: section)
                        .opacity(selectedSection == section ? 1 : 0)
                        .allowsHitTesting(selectedSection == section)
                        .accessibilityHidden(selectedSection != section)
                }
            }
            .padding(30)
        }
        .padding(18)
    }

    @ViewBuilder
    private func pageContent(for section: MainWindowSection) -> some View {
        switch MainWindowNavigationPolicy.contentSection(for: section) {
        case .notes:
            WindowPageShell(section: section) {
                NotesTab(controller: controller, showsInlineHeader: false)
            }
        case .records:
            WindowPageShell(section: section) {
                VoiceRecognitionRecordsTab(controller: controller, showsInlineHeader: false)
            }
        case .collaboration:
            HomeDashboardView(
                controller: controller,
                showsWelcomeHeader: false
            )
        case .data:
            WindowPageShell(section: section) {
                DataRecordsTab(controller: controller, showsInlineHeader: false)
            }
        case .speech:
            WindowPageShell(section: section) {
                SpeechRecognitionTab(controller: controller, showsInlineHeader: false)
            }
        case .about:
            WindowPageShell(section: section) {
                AboutTab(
                    showsInlineHeader: false,
                    onOpenGuide: {
                        controller.showUsageGuide()
                    },
                    onRevealDebug: {}
                )
            }
        case .settings:
            WindowPageShell(section: section) {
                SettingsTab(settings: settings, controller: controller)
            }
        }
    }
}

private struct VoiceRecognitionRecordsTab: View {
    @ObservedObject var controller: MenuBarController
    var showsInlineHeader = true
    @State private var keyword = ""
    @State private var isEditing = false
    @State private var selectedRecordIDs = Set<UUID>()
    @State private var showsDeleteSelectedConfirmation = false
    @State private var showsClearAllConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if showsInlineHeader {
                Text(String(localized: "main_nav_records"))
                    .font(.title.weight(.bold))
                    .foregroundColor(MainWindowColors.title)
            }

            HStack(spacing: 12) {
                Label(
                    String(format: String(localized: "records_summary_count_format"), filteredRecords.count),
                    systemImage: "waveform.badge.magnifyingglass"
                )
                .font(.subheadline.weight(.medium))
                .foregroundColor(MainWindowColors.secondaryText)

                Spacer()

                Button(isEditing ? String(localized: "records_action_done") : String(localized: "records_action_edit")) {
                    if isEditing {
                        selectedRecordIDs.removeAll()
                    }
                    isEditing.toggle()
                }
                .buttonStyle(.bordered)

                TextField(String(localized: "records_search_placeholder"), text: $keyword)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
            }

            if bulkActionPolicy.canClearAll || isEditing {
                HStack(spacing: 12) {
                    if isEditing {
                        Button(String(localized: "records_action_select_all")) {
                            selectedRecordIDs = Set(filteredRecords.map(\.id))
                        }
                        .buttonStyle(.bordered)
                        .disabled(filteredRecords.isEmpty || selectedRecordIDs.count == filteredRecords.count)

                        Button(String(localized: "records_action_delete_selected")) {
                            showsDeleteSelectedConfirmation = true
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!bulkActionPolicy.canDeleteSelection)
                    }

                    Spacer()

                    Button(String(localized: "records_action_clear_all")) {
                        showsClearAllConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(!bulkActionPolicy.canClearAll)
                }
            }

            if filteredRecords.isEmpty {
                ContentUnavailableView(
                    String(localized: "records_empty_title"),
                    systemImage: "text.magnifyingglass",
                    description: Text(AppLocalization.localizedString(recordsEmptyDescriptionKey))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22, pinnedViews: [.sectionHeaders]) {
                        ForEach(groupedRecords, id: \.title) { section in
                            Section {
                                VStack(spacing: 12) {
                                    ForEach(section.records) { record in
                                        voiceRecognitionRecordCard(record)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(section.title)
                                        .font(.headline.weight(.semibold))
                                        .foregroundColor(MainWindowColors.secondaryText)
                                    Spacer()
                                    Text(String(format: String(localized: "records_section_count_format"), section.records.count))
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(MainWindowColors.secondaryText)
                                }
                                .padding(.vertical, 4)
                                .background(MainWindowColors.canvasBackground)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .confirmationDialog(
            String(localized: "records_delete_selected_confirm_title"),
            isPresented: $showsDeleteSelectedConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "records_action_delete_selected"), role: .destructive) {
                controller.deleteVoiceRecognitionRecords(withIDs: selectedRecordIDs)
                selectedRecordIDs.removeAll()
                isEditing = false
            }
            Button(String(localized: "cancel_button"), role: .cancel) {}
        } message: {
            Text(String(format: String(localized: "records_delete_selected_confirm_message_format"), selectedRecordIDs.count))
        }
        .confirmationDialog(
            String(localized: "records_clear_all_confirm_title"),
            isPresented: $showsClearAllConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "records_action_clear_all"), role: .destructive) {
                controller.clearVoiceRecognitionRecords()
                selectedRecordIDs.removeAll()
                isEditing = false
            }
            Button(String(localized: "cancel_button"), role: .cancel) {}
        } message: {
            Text(String(localized: "records_clear_all_confirm_message"))
        }
    }

    private var filteredRecords: [VoiceRecognitionRecord] {
        VoiceRecognitionHistoryQueryPolicy.filteredRecords(
            from: controller.voiceRecognitionRecords,
            referenceDate: .now,
            keyword: keyword
        )
    }

    private var groupedRecords: [GroupedVoiceRecognitionRecords] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let groups = Dictionary(grouping: filteredRecords) { record in
            calendar.startOfDay(for: record.createdAt)
        }

        return groups
            .sorted { $0.key > $1.key }
            .map { date, records in
                GroupedVoiceRecognitionRecords(
                    title: formatter.string(from: date),
                    records: records.sorted { $0.createdAt > $1.createdAt }
                )
            }
    }

    private var recordsEmptyDescriptionKey: String {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? "records_empty_desc"
        : "records_empty_search_desc"
    }

    private var bulkActionPolicy: VoiceRecognitionRecordsBulkActionPolicy {
        VoiceRecognitionRecordsBulkActionPolicy(
            isEditing: isEditing,
            totalRecordCount: filteredRecords.count,
            selectedRecordCount: selectedRecordIDs.count
        )
    }

    private func voiceRecognitionRecordCard(_ record: VoiceRecognitionRecord) -> some View {
        HStack(alignment: .top, spacing: 14) {
            if isEditing {
                Image(systemName: selectedRecordIDs.contains(record.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(selectedRecordIDs.contains(record.id) ? .accentColor : MainWindowColors.secondaryText)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(record.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(MainWindowColors.title)

                        Text(AppLocalization.localizedString(record.source.localizedTitleKey))
                            .font(.caption.weight(.medium))
                            .foregroundColor(MainWindowColors.secondaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(MainWindowColors.softSurface)
                            )
                    }

                    Spacer()
                }

                Text(record.text)
                    .font(.body)
                    .foregroundColor(MainWindowColors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(MainWindowColors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            guard isEditing else { return }
            if selectedRecordIDs.contains(record.id) {
                selectedRecordIDs.remove(record.id)
            } else {
                selectedRecordIDs.insert(record.id)
            }
        }
    }
}

struct VoiceRecognitionRecordsBulkActionPolicy {
    let isEditing: Bool
    let totalRecordCount: Int
    let selectedRecordCount: Int

    var canDeleteSelection: Bool {
        isEditing && selectedRecordCount > 0
    }

    var canClearAll: Bool {
        totalRecordCount > 0
    }
}

private struct GroupedVoiceRecognitionRecords {
    let title: String
    let records: [VoiceRecognitionRecord]
}

private struct WindowPageShell<Content: View>: View {
    let section: MainWindowSection
    @ViewBuilder let content: Content

    init(section: MainWindowSection, @ViewBuilder content: () -> Content) {
        self.section = section
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(section.title)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(MainWindowColors.title)
                Text(section.subtitle)
                    .font(.callout)
                    .foregroundColor(MainWindowColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct HomeDashboardView: View {
    @ObservedObject var controller: MenuBarController
    var showsWelcomeHeader = true

    private var controlsPolicy: CollaborationControlsPolicy {
        CollaborationControlsPolicy(
            pairingState: controller.pairingState,
            isServiceRunning: controller.isServiceRunning
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if showsWelcomeHeader {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "main_home_welcome"))
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(MainWindowColors.title)
                        Text(String(localized: "main_home_subtitle"))
                            .font(.callout)
                            .foregroundColor(MainWindowColors.secondaryText)
                    }

                    Spacer()

                    HStack(spacing: 22) {
                        dashboardStat(icon: "flame", value: connectionSummaryValue, tint: .orange)
                        dashboardStat(icon: "dot.radiowaves.left.and.right", value: serviceSummaryValue, tint: .blue)
                        dashboardStat(icon: "note.text", value: noteSummaryValue, tint: .green)
                    }
                }
            } else {
                HStack(spacing: 22) {
                    dashboardStat(icon: "flame", value: connectionSummaryValue, tint: .orange)
                    dashboardStat(icon: "dot.radiowaves.left.and.right", value: serviceSummaryValue, tint: .blue)
                    dashboardStat(icon: "note.text", value: noteSummaryValue, tint: .green)
                }
            }

            collaborationControlsCard

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(String(localized: "main_home_recent_activity"))
                        .font(.title3.weight(.semibold))
                        .foregroundColor(MainWindowColors.title)
                    Spacer()
                }

                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(recentRecords) { record in
                            recentRecordCard(record)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var collaborationControlsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "status_connection_title"))
                        .font(.title3.weight(.semibold))
                        .foregroundColor(MainWindowColors.title)

                    Text(spotlightDescription)
                        .font(.callout)
                        .foregroundColor(MainWindowColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 18)

                Image(systemName: "iphone.and.arrow.forward")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(12)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                    )
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ],
                spacing: 14
            ) {
                collaborationStatusCard(
                    title: String(localized: "status_label"),
                    value: connectionSummaryValue,
                    tint: spotlightTint,
                    systemImage: "antenna.radiowaves.left.and.right"
                )

                collaborationStatusCard(
                    title: String(localized: "status_service_label"),
                    value: serviceSummaryValue,
                    tint: controller.isServiceRunning ? .green : .orange,
                    systemImage: "server.rack"
                )

                if let deviceName = controlsPolicy.pairedDeviceName {
                    collaborationStatusCard(
                        title: String(localized: "status_paired_device_label"),
                        value: deviceName,
                        tint: .blue,
                        systemImage: "iphone"
                    )
                }

                collaborationStatusCard(
                    title: String(localized: "status_ip_label"),
                    value: LocalNetworkAccessPolicy.preferredLocalIPv4() ?? String(localized: "status_unknown_value"),
                    tint: MainWindowColors.secondaryText,
                    systemImage: "network"
                )
            }

            HStack(spacing: 14) {
                spotlightAction(
                    title: controller.isServiceRunning
                    ? String(localized: "status_action_stop_service")
                    : String(localized: "status_action_start_service"),
                    role: controller.isServiceRunning ? .secondary : .primary
                ) {
                    if controller.isServiceRunning {
                        controller.stopNetworkServices()
                    } else {
                        controller.startNetworkServices()
                    }
                }

                if controlsPolicy.showsStartPairing {
                    spotlightAction(
                        title: String(localized: "status_action_start_pairing"),
                        role: .secondary
                    ) {
                        controller.showPairingWindowFromUI()
                    }
                }

                if controlsPolicy.showsUnpair {
                    spotlightAction(
                        title: String(localized: "status_action_unpair"),
                        role: .secondary
                    ) {
                        controller.unpairDeviceFromUI()
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(MainWindowColors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }

    private func collaborationStatusCard(title: String, value: String, tint: Color, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundColor(tint)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(MainWindowColors.secondaryText)
            }

            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(MainWindowColors.title)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MainWindowColors.softSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }

    private func dashboardStat(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(tint)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundColor(MainWindowColors.secondaryText)
        }
    }

    private func spotlightAction(title: String, role: SpotlightButtonRole, action: @escaping () -> Void) -> some View {
        let style = SpotlightActionStylePolicy.style(for: role)

        return Button(action: action) {
            Text(title)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(style.fillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(style.borderColor, lineWidth: style.borderColor == .clear ? 0 : 1)
        )
        .foregroundColor(style.foregroundColor)
    }

    private func recentRecordCard(_ record: InboundDataRecord) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label(record.timestamp.formatted(date: .omitted, time: .shortened), systemImage: "calendar")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(MainWindowColors.secondaryText)

                Text(record.category == .voice ? String(localized: "data_category_voice") : String(localized: "data_category_connection"))
                    .font(.caption)
                    .foregroundColor(MainWindowColors.secondaryText)
            }
            .frame(width: 140, alignment: .leading)

            Text(record.detail)
                .font(.body)
                .foregroundColor(MainWindowColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(MainWindowColors.recentActivitySurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }

    private var recentRecords: [InboundDataRecord] {
        Array(controller.inboundDataRecords.prefix(6))
    }

    private var connectionSummaryValue: String {
        switch controller.connectionState {
        case .connected:
            return String(localized: "status_connection_connected")
        case .connecting:
            return String(localized: "status_connection_connecting")
        case .disconnected:
            return String(localized: "status_connection_disconnected")
        case .error:
            return String(localized: "status_connection_error")
        }
    }

    private var serviceSummaryValue: String {
        controller.isServiceRunning
        ? String(localized: "status_service_running")
        : String(localized: "status_service_stopped")
    }

    private var noteSummaryValue: String {
        String(format: String(localized: "main_home_note_count_format"), controller.noteText.count)
    }

    private var spotlightDescription: String {
        if case .paired(_, let deviceName) = controller.pairingState {
            return String(format: String(localized: "main_home_paired_summary_format"), deviceName)
        }

        return String(localized: "main_home_unpaired_summary")
    }

    private var spotlightTint: Color {
        switch controller.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .secondary
        case .error:
            return .red
        }
    }
}

enum SpotlightButtonRole {
    case primary
    case secondary
}

struct SpotlightActionStyle {
    let fillColor: Color
    let foregroundColor: Color
    let borderColor: Color
    let shadowOpacity: Double
}

enum SpotlightActionStylePolicy {
    static func style(for role: SpotlightButtonRole) -> SpotlightActionStyle {
        switch role {
        case .primary:
            return SpotlightActionStyle(
                fillColor: Color(red: 0.19, green: 0.47, blue: 0.96),
                foregroundColor: .white,
                borderColor: .clear,
                shadowOpacity: 0
            )
        case .secondary:
            return SpotlightActionStyle(
                fillColor: MainWindowColors.secondaryButtonSurface,
                foregroundColor: MainWindowColors.title,
                borderColor: MainWindowColors.cardBorder,
                shadowOpacity: 0
            )
        }
    }
}

// MARK: - Status Tab

struct StatusTab: View {
    @ObservedObject var controller: MenuBarController
    var showsInlineHeader = true

    var body: some View {
        VStack(spacing: 20) {
            if showsInlineHeader {
                Text("🎤 \(String(localized: "app_title"))")
                    .font(.system(size: 32, weight: .bold))
            }

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
                                .foregroundColor(MainWindowColors.secondaryText)
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
                            .foregroundColor(MainWindowColors.secondaryText)
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
                            .foregroundColor(controller.isServiceRunning ? .green : MainWindowColors.secondaryText)
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
                            .foregroundColor(MainWindowColors.secondaryText)
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
                .foregroundColor(MainWindowColors.secondaryText)
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
    @StateObject private var purchaseStore = TwoDeviceSyncPurchaseStore.shared
    var showsInlineHeader = false
    @State private var serverPortText = ""
    @State private var languageSelection = "zh-CN"
    @State private var themeSelection: AppThemePreference = .system

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
            if showsInlineHeader {
                Text(String(localized: "tab_settings"))
                    .font(.title2)
                    .fontWeight(.semibold)
            }

                settingsSectionCard(
                    title: String(localized: "settings_language_title")
                ) {
                    settingsPickerRow(
                        title: String(localized: "settings_language_picker")
                    ) {
                        Picker(String(localized: "settings_language_picker"), selection: $languageSelection) {
                            Text(String(localized: "settings_language_zh")).tag("zh-CN")
                            Text(String(localized: "settings_language_en")).tag("en-US")
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 260)
                    }
                }

                settingsSectionCard(
                    title: String(localized: "settings_theme_title")
                ) {
                    settingsPickerRow(
                        title: String(localized: "settings_theme_picker")
                    ) {
                        Picker(String(localized: "settings_theme_picker"), selection: $themeSelection) {
                            ForEach(AppThemePreference.allCases) { preference in
                                Text(AppLocalization.localizedString(preference.localizedTitleKey))
                                    .tag(preference)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                settingsSectionCard(
                    title: String(localized: "billing_two_device_sync_header")
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        settingsInfoRow(
                            title: macBillingStatusTitle,
                            detail: macBillingStatusDetail
                        )

                        if MacBillingPresentationPolicy.showsUnlockOptions(for: purchaseStore.entitlement) {
                            settingsPickerRow(
                                title: String(localized: "billing_two_device_sync_actions_title")
                            ) {
                                VStack(alignment: .leading, spacing: 10) {
                                    billingActionButton(
                                        title: billingTitle(for: .monthly),
                                        isLoading: purchaseStore.activePurchaseProductID == TwoDeviceSyncProductKind.monthly.rawValue
                                    ) {
                                        Task {
                                            _ = await purchaseStore.purchase(.monthly)
                                        }
                                    }

                                    billingActionButton(
                                        title: billingTitle(for: .yearly),
                                        isLoading: purchaseStore.activePurchaseProductID == TwoDeviceSyncProductKind.yearly.rawValue
                                    ) {
                                        Task {
                                            _ = await purchaseStore.purchase(.yearly)
                                        }
                                    }

                                    billingActionButton(
                                        title: billingTitle(for: .lifetime),
                                        isLoading: purchaseStore.activePurchaseProductID == TwoDeviceSyncProductKind.lifetime.rawValue
                                    ) {
                                        Task {
                                            _ = await purchaseStore.purchase(.lifetime)
                                        }
                                    }
                                }
                            }
                        }

                        billingActionButton(
                            title: String(localized: "billing_two_device_sync_restore_button"),
                            isLoading: purchaseStore.isRestoringPurchases
                        ) {
                            Task {
                                await purchaseStore.restorePurchases()
                            }
                        }

                        if let lastErrorMessage = purchaseStore.lastErrorMessage, !lastErrorMessage.isEmpty {
                            Text(lastErrorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                settingsSectionCard(
                    title: String(localized: "settings_network_title")
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        settingsInputRow(title: String(localized: "settings_network_port_label")) {
                            TextField(String(localized: "settings_network_port_placeholder"), text: $serverPortText)
                                .frame(width: 140)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: serverPortText) { _, newValue in
                                    let digitsOnly = newValue.filter(\.isNumber)
                                    if digitsOnly != serverPortText {
                                        serverPortText = digitsOnly
                                        return
                                    }

                                    guard let port = UInt16(digitsOnly), port >= 1024 else { return }
                                    updateSettingsPortIfNeeded(port)
                                }
                        }

                        Text(String(localized: "settings_network_port_desc"))
                            .font(.caption)
                            .foregroundColor(SettingsSurfaceStylePolicy.secondaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .onAppear {
            syncLocalSettingsState()
        }
        .task {
            await purchaseStore.prepare()
        }
        .onChange(of: languageSelection) { _, newValue in
            guard settings.language != newValue else { return }
            DispatchQueue.main.async {
                settings.language = newValue
            }
        }
        .onChange(of: themeSelection) { _, newValue in
            guard settings.themePreference != newValue else { return }
            DispatchQueue.main.async {
                settings.themePreference = newValue
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func syncLocalSettingsState() {
        languageSelection = settings.language
        themeSelection = settings.themePreference
        serverPortText = String(settings.serverPort)
    }

    private func updateSettingsPortIfNeeded(_ port: UInt16) {
        guard settings.serverPort != port else { return }
        DispatchQueue.main.async {
            settings.serverPort = port
        }
    }

    private func settingsSectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(MainWindowColors.title)

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(SettingsSurfaceStylePolicy.cardFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(SettingsSurfaceStylePolicy.cardBorderColor, lineWidth: 1)
        )
    }

    private func settingsInfoRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundColor(MainWindowColors.title)

            Text(detail)
                .font(.callout)
                .foregroundColor(SettingsSurfaceStylePolicy.secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SettingsSurfaceStylePolicy.rowFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SettingsSurfaceStylePolicy.cardBorderColor, lineWidth: 1)
        )
    }

    private func settingsPickerRow<Content: View>(
        title: String,
        @ViewBuilder control: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundColor(MainWindowColors.title)

            control()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SettingsSurfaceStylePolicy.rowFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SettingsSurfaceStylePolicy.cardBorderColor, lineWidth: 1)
        )
    }

    private func settingsInputRow<Content: View>(
        title: String,
        @ViewBuilder control: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 18) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundColor(MainWindowColors.title)

            Spacer(minLength: 0)

            control()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SettingsSurfaceStylePolicy.rowFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SettingsSurfaceStylePolicy.cardBorderColor, lineWidth: 1)
        )
    }

    private var macBillingStatusTitle: String {
        switch purchaseStore.entitlement {
        case .free:
            return String(localized: "billing_two_device_sync_status_free_mac")
        case .monthly, .yearly, .lifetime:
            return String(localized: "billing_two_device_sync_status_unlimited")
        }
    }

    private var macBillingStatusDetail: String {
        switch purchaseStore.entitlement {
        case .free:
            return String(localized: "billing_two_device_sync_mac_detail_free")
        case .monthly:
            return String(localized: "billing_two_device_sync_mac_detail_monthly")
        case .yearly:
            return String(localized: "billing_two_device_sync_mac_detail_yearly")
        case .lifetime:
            return String(localized: "billing_two_device_sync_mac_detail_lifetime")
        }
    }

    private func billingTitle(for kind: TwoDeviceSyncProductKind) -> String {
        if let price = purchaseStore.displayPrice(for: kind) {
            switch kind {
            case .monthly:
                return String(format: String(localized: "billing_two_device_sync_monthly_button"), price)
            case .yearly:
                return String(format: String(localized: "billing_two_device_sync_yearly_button"), price)
            case .lifetime:
                return String(format: String(localized: "billing_two_device_sync_lifetime_button"), price)
            }
        }

        switch kind {
        case .monthly:
            return String(localized: "billing_two_device_sync_monthly_fallback")
        case .yearly:
            return String(localized: "billing_two_device_sync_yearly_fallback")
        case .lifetime:
            return String(localized: "billing_two_device_sync_lifetime_fallback")
        }
    }

    private func billingActionButton(
        title: String,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.bordered)
        .disabled(purchaseStore.activePurchaseProductID != nil || purchaseStore.isRestoringPurchases)
    }
}

// MARK: - Data Records Tab

struct DataRecordsTab: View {
    @ObservedObject var controller: MenuBarController
    var showsInlineHeader = true
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
            if showsInlineHeader {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "data_title"))
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(String(localized: "data_subtitle"))
                        .font(.callout)
                        .foregroundColor(MainWindowColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                Text(String(localized: "data_filter_picker"))
                    .font(.headline)
                    .foregroundColor(MainWindowColors.secondaryText)

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
                    .foregroundColor(MainWindowColors.secondaryText)
            }

            Text(record.detail)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .foregroundColor(failure ? MainWindowColors.title : MainWindowColors.primaryText)
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
                .foregroundColor(MainWindowColors.secondaryText)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(MainWindowColors.softSurface.opacity(0.95))
    }

    @ViewBuilder
    private func summaryBadge(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(MainWindowColors.secondaryText)
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(MainWindowColors.softSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
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
            return MainWindowColors.title
        }
    }

    private func recordBackgroundColor(isFailure: Bool) -> Color {
        if isFailure {
            return Color.red.opacity(0.08)
        }

        return MainWindowColors.cardSurface
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
            return MainWindowColors.secondaryText
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

enum NotesTextSelectionPolicy {
    static func allowsSelection(for text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var showsInlineHeader = true
    let onOpenGuide: () -> Void
    let onRevealDebug: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                aboutHero
                aboutHighlights
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var aboutHero: some View {
        HStack(alignment: .top, spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.95),
                                Color.yellow.opacity(0.78),
                                Color.green.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 108, height: 108)

                Image(systemName: "waveform")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white.opacity(0.96))
            }

            VStack(alignment: .leading, spacing: 12) {
                if showsInlineHeader {
                    Text(String(localized: "app_title"))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(MainWindowColors.title)
                }

                Text(String(localized: "about_title"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(MainWindowColors.title)

                Text(String(localized: "about_description"))
                    .font(.body)
                    .foregroundColor(MainWindowColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Label(String(localized: "about_version"), systemImage: "number.circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(MainWindowColors.secondaryText)
                        .onTapGesture(count: 2, perform: onRevealDebug)

                    Button(String(localized: "about_open_guide")) {
                        onOpenGuide()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(MainWindowColors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }

    private var aboutHighlights: some View {
        HStack(alignment: .top, spacing: 18) {
            aboutHighlightCard(
                systemImage: "desktopcomputer.and.iphone",
                title: String(localized: "main_nav_collaboration"),
                description: String(localized: "about_description")
            )

            aboutHighlightCard(
                systemImage: "book.pages",
                title: String(localized: "about_open_guide"),
                description: String(localized: "main_brand_subtitle")
            )
        }
    }

    private func aboutHighlightCard(systemImage: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.accentColor)

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(MainWindowColors.title)

            Text(description)
                .font(.subheadline)
                .foregroundColor(MainWindowColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(MainWindowColors.softSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Notes Tab

struct NotesTab: View {
    @ObservedObject var controller: MenuBarController
    var showsInlineHeader = true

    var body: some View {
        VStack(spacing: 20) {
            if showsInlineHeader {
                Text(String(localized: "note_title"))
                    .font(.title)
                    .padding(.top)
            }

            // Note text display
            Group {
                if NotesTextSelectionPolicy.allowsSelection(for: controller.noteText) {
                    Text(controller.noteText)
                        .textSelection(.enabled)
                } else {
                    Text(String(localized: "note_placeholder"))
                        .textSelection(.disabled)
                }
            }
            .font(.body)
            .foregroundColor(controller.noteText.isEmpty ? MainWindowColors.secondaryText : MainWindowColors.title)
            .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
            .padding()
            .background(MainWindowColors.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(MainWindowColors.cardBorder, lineWidth: 1)
            )
            .cornerRadius(12)

            Spacer()

            // Recording button
            VStack(spacing: 12) {
                RecordButton(
                    isRecording: controller.isLocalRecording,
                    onStartRecording: {
                        controller.startLocalRecording()
                    },
                    onStopRecording: {
                        controller.stopLocalRecording()
                    }
                )

                Text(controller.isLocalRecording ? String(localized: "note_recording") : String(localized: "note_placeholder"))
                    .font(.caption)
                    .foregroundColor(controller.isLocalRecording ? .red : MainWindowColors.secondaryText)

                Button(action: {
                    controller.clearNote()
                }) {
                    Label(String(localized: "note_clear"), systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(controller.noteText.isEmpty)
            }
            .padding(.bottom, 40)
        }
        .padding()
    }
}

// MARK: - Record Button

struct RecordButton: View {
    let isRecording: Bool
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void

    @State private var isPressActive = false

    var body: some View {
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
        .frame(width: 60, height: 60)
        .contentShape(Circle())
        .overlay(
            RecordButtonPressCaptureView(
                onPressBegan: {
                    if RecordButtonInteractionPolicy.shouldStartRecording(
                        isPressActive: isPressActive,
                        isRecording: isRecording
                    ) {
                        isPressActive = true
                        onStartRecording()
                    }
                },
                onPressEnded: {
                    let shouldStop = RecordButtonInteractionPolicy.shouldStopRecording(
                        isPressActive: isPressActive,
                        isRecording: isRecording
                    )
                    isPressActive = false
                    if shouldStop {
                        onStopRecording()
                    }
                }
            )
        )
    }
}

enum RecordButtonInteractionPolicy {
    static let shouldStopRecordingOnPointerDrag = false
    static let usesBlockingEventTrackingLoop = false

    static func shouldStartRecording(isPressActive: Bool, isRecording: Bool) -> Bool {
        !isPressActive && !isRecording
    }

    static func shouldStopRecording(isPressActive: Bool, isRecording: Bool) -> Bool {
        isPressActive && isRecording
    }
}

private struct RecordButtonPressCaptureView: NSViewRepresentable {
    let onPressBegan: () -> Void
    let onPressEnded: () -> Void

    func makeNSView(context: Context) -> PressCaptureNSView {
        let view = PressCaptureNSView()
        view.onPressBegan = onPressBegan
        view.onPressEnded = onPressEnded
        return view
    }

    func updateNSView(_ nsView: PressCaptureNSView, context: Context) {
        nsView.onPressBegan = onPressBegan
        nsView.onPressEnded = onPressEnded
    }
}

private final class PressCaptureNSView: NSView {
    var onPressBegan: (() -> Void)?
    var onPressEnded: (() -> Void)?
    private var isTrackingPress = false
    private var localMouseUpMonitor: Any?
    private var globalMouseUpMonitor: Any?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard !isTrackingPress else { return }
        isTrackingPress = true
        startMouseUpMonitoring()
        onPressBegan?()
    }

    override func mouseUp(with event: NSEvent) {
        finishTracking()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window == nil {
            finishTracking()
        }
    }

    private func finishTracking() {
        guard isTrackingPress else { return }
        isTrackingPress = false
        stopMouseUpMonitoring()
        onPressEnded?()
    }

    private func startMouseUpMonitoring() {
        stopMouseUpMonitoring()

        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            self?.finishTracking()
            return event
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            self?.finishTracking()
        }
    }

    private func stopMouseUpMonitoring() {
        if let localMouseUpMonitor {
            NSEvent.removeMonitor(localMouseUpMonitor)
            self.localMouseUpMonitor = nil
        }

        if let globalMouseUpMonitor {
            NSEvent.removeMonitor(globalMouseUpMonitor)
            self.globalMouseUpMonitor = nil
        }
    }

    deinit {
        stopMouseUpMonitoring()
    }
}
