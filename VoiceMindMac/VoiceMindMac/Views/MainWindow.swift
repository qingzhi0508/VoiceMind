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
        light: (0.953, 0.953, 0.965, 1),
        dark: (0.095, 0.095, 0.11, 1)
    )
    static let sidebarBackgroundTop = Color.adaptive(
        light: (0.944, 0.946, 0.958, 1),
        dark: (0.108, 0.108, 0.125, 1)
    )
    static let sidebarBackgroundBottom = Color.adaptive(
        light: (0.934, 0.936, 0.949, 1),
        dark: (0.098, 0.098, 0.115, 1)
    )
    static let canvasBackground = Color.adaptive(
        light: (0.985, 0.986, 0.992, 1),
        dark: (0.122, 0.124, 0.142, 1)
    )
    static let canvasBorder = Color.adaptive(
        light: (0, 0, 0, 0.075),
        dark: (1, 1, 1, 0.075)
    )
    static let title = Color.adaptive(
        light: (0.114, 0.114, 0.122, 1),
        dark: (0.93, 0.93, 0.95, 1)
    )
    static let primaryText = Color.adaptive(
        light: (0.212, 0.218, 0.247, 1),
        dark: (0.82, 0.83, 0.87, 1)
    )
    static let secondaryText = Color.adaptive(
        light: (0.43, 0.45, 0.51, 1),
        dark: (0.58, 0.6, 0.67, 1)
    )
    static let sidebarText = Color.adaptive(
        light: (0.295, 0.305, 0.35, 1),
        dark: (0.72, 0.73, 0.79, 1)
    )
    static let sidebarSelectedFill = Color.adaptive(
        light: (1, 1, 1, 0.92),
        dark: (0.18, 0.19, 0.23, 1)
    )
    static let sidebarSelectedBorder = Color.adaptive(
        light: (0, 0, 0, 0.065),
        dark: (1, 1, 1, 0.06)
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
        light: (0, 0, 0, 0.07),
        dark: (1, 1, 1, 0.07)
    )
    static let softSurface = Color.adaptive(
        light: (0.962, 0.964, 0.973, 1),
        dark: (0.152, 0.155, 0.178, 1)
    )
    static let cardSurface = Color.adaptive(
        light: (1, 1, 1, 0.96),
        dark: (0.145, 0.147, 0.165, 1)
    )
    static let recentActivitySurface = Color.adaptive(
        light: (0.975, 0.977, 0.984, 1),
        dark: (0.155, 0.158, 0.182, 1)
    )
    static let secondaryButtonSurface = Color.adaptive(
        light: (0.955, 0.958, 0.97, 1),
        dark: (0.18, 0.185, 0.21, 1)
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
            return AppLocalization.localizedString("main_nav_home")
        case .records:
            return AppLocalization.localizedString("main_nav_records")
        case .collaboration:
            return AppLocalization.localizedString("main_nav_collaboration")
        case .data:
            return AppLocalization.localizedString("main_nav_logs")
        case .speech:
            return AppLocalization.localizedString("tab_speech")
        case .about:
            return AppLocalization.localizedString("tab_about")
        case .settings:
            return AppLocalization.localizedString("tab_settings")
        }
    }

    var subtitle: String {
        switch self {
        case .home:
            return AppLocalization.localizedString("main_notes_subtitle")
        case .records:
            return AppLocalization.localizedString("main_records_subtitle")
        case .collaboration:
            return AppLocalization.localizedString("main_collaboration_subtitle")
        case .data:
            return AppLocalization.localizedString("data_subtitle")
        case .speech:
            return AppLocalization.localizedString("main_speech_subtitle")
        case .about:
            return AppLocalization.localizedString("about_description")
        case .settings:
            return AppLocalization.localizedString("main_settings_subtitle")
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

private struct PersistentPageVisibilityModifier: ViewModifier {
    let isVisible: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isVisible {
            content
        } else {
            content
                .frame(width: 0, height: 0)
                .clipped()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
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

enum MacConnectionPresentationPolicy {
    static func displayState(
        pairingState: PairingState,
        connectionState: ConnectionState
    ) -> ConnectionState {
        switch pairingState {
        case .paired:
            return connectionState
        case .pairing:
            if case .error = connectionState {
                return connectionState
            }
            return .connecting
        case .unpaired:
            if case .error = connectionState {
                return connectionState
            }
            return .disconnected
        }
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .preferredColorScheme(settings.themePreference.preferredColorScheme)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: "waveform")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppLocalization.localizedString("app_title"))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(MainWindowColors.title)
                    Text(AppLocalization.localizedString("main_brand_subtitle"))
                        .font(.subheadline)
                        .foregroundColor(MainWindowColors.secondaryText)
                }
            }
            .padding(.top, 6)

            sidebarGroupTitle("工作区")

            VStack(spacing: 6) {
                ForEach(MainWindowSection.primaryItems) { item in
                    sidebarItem(item)
                }
            }

            Spacer(minLength: 0)

            sidebarGroupTitle("更多")

            VStack(spacing: 6) {
                ForEach(MainWindowSection.secondaryItems) { item in
                    sidebarItem(item)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 24)
        .frame(width: 246)
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
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 20)

            Text(item.title)
                .font(.system(size: 14, weight: .medium))

            Spacer(minLength: 0)
        }
        .foregroundColor(selectedSection == item ? MainWindowColors.title : MainWindowColors.sidebarText)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selectedSection == item ? MainWindowColors.sidebarSelectedFill : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selectedSection == item ? MainWindowColors.sidebarSelectedBorder : Color.clear, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            selectedSection = item
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(selectedSection == item ? .isSelected : [])
    }

    private func sidebarGroupTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundColor(MainWindowColors.secondaryText)
            .padding(.horizontal, 8)
    }

    private var contentArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(MainWindowColors.canvasBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MainWindowColors.canvasBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.035), radius: 12, x: 0, y: 6)

            ZStack {
                ForEach(MainWindowPagePersistencePolicy.persistentSections) { section in
                    pageContent(for: section)
                        .modifier(PersistentPageVisibilityModifier(isVisible: selectedSection == section))
                }
            }
            .padding(34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    @ViewBuilder
    private func pageContent(for section: MainWindowSection) -> some View {
        switch MainWindowNavigationPolicy.contentSection(for: section) {
        case .notes:
            NotesTab(controller: controller, showsInlineHeader: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .records:
            WindowPageShell(section: section) {
                VoiceRecognitionRecordsTab(controller: controller, showsInlineHeader: false)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .collaboration:
            WindowPageShell(section: section) {
                HomeDashboardView(
                    controller: controller,
                    showsWelcomeHeader: false
                )
            }
        case .data:
            WindowPageShell(section: section) {
                DataRecordsTab(controller: controller, showsInlineHeader: false)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .speech:
            WindowPageShell(section: section) {
                SpeechRecognitionTab(controller: controller, showsInlineHeader: false)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .settings:
            WindowPageShell(section: section) {
                SettingsTab(settings: settings, controller: controller)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        VStack(alignment: .leading, spacing: 20) {
            if showsInlineHeader {
                Text(AppLocalization.localizedString("main_nav_records"))
                    .font(.title.weight(.bold))
                    .foregroundColor(MainWindowColors.title)
            }

            MainWindowSurface(emphasized: true) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(AppLocalization.localizedString("main_nav_records"))
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(MainWindowColors.title)

                            Text(AppLocalization.localizedString("main_records_subtitle"))
                                .font(.subheadline)
                                .foregroundColor(MainWindowColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 16)

                        MainWindowStatusChip(
                            title: String(format: AppLocalization.localizedString("records_summary_count_format"), filteredRecords.count),
                            systemImage: "waveform.badge.magnifyingglass",
                            tint: filteredRecords.isEmpty ? MainWindowColors.secondaryText : .blue
                        )
                    }

                    HStack(spacing: 12) {
                        TextField(AppLocalization.localizedString("records_search_placeholder"), text: $keyword)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 280)

                        Spacer(minLength: 0)

                        Button(isEditing ? AppLocalization.localizedString("records_action_done") : AppLocalization.localizedString("records_action_edit")) {
                            if isEditing {
                                selectedRecordIDs.removeAll()
                            }
                            isEditing.toggle()
                        }
                        .buttonStyle(.bordered)
                    }

                    if bulkActionPolicy.canClearAll || isEditing {
                        HStack(spacing: 12) {
                            if isEditing {
                                Button(AppLocalization.localizedString("records_action_select_all")) {
                                    selectedRecordIDs = Set(filteredRecords.map(\.id))
                                }
                                .buttonStyle(.bordered)
                                .disabled(filteredRecords.isEmpty || selectedRecordIDs.count == filteredRecords.count)

                                Button(AppLocalization.localizedString("records_action_delete_selected")) {
                                    showsDeleteSelectedConfirmation = true
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!bulkActionPolicy.canDeleteSelection)
                            }

                            Spacer()

                            Button(AppLocalization.localizedString("records_action_clear_all")) {
                                showsClearAllConfirmation = true
                            }
                            .buttonStyle(.bordered)
                            .disabled(!bulkActionPolicy.canClearAll)
                        }
                    }
                }
            }

            if filteredRecords.isEmpty {
                ContentUnavailableView(
                    AppLocalization.localizedString("records_empty_title"),
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
                                        .foregroundColor(MainWindowColors.title)

                                    Spacer()

                                    Text(String(format: AppLocalization.localizedString("records_section_count_format"), section.records.count))
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(MainWindowColors.secondaryText)
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                                .background(MainWindowColors.canvasBackground)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .confirmationDialog(
            AppLocalization.localizedString("records_delete_selected_confirm_title"),
            isPresented: $showsDeleteSelectedConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppLocalization.localizedString("records_action_delete_selected"), role: .destructive) {
                controller.deleteVoiceRecognitionRecords(withIDs: selectedRecordIDs)
                selectedRecordIDs.removeAll()
                isEditing = false
            }
            Button(AppLocalization.localizedString("cancel_button"), role: .cancel) {}
        } message: {
            Text(String(format: AppLocalization.localizedString("records_delete_selected_confirm_message_format"), selectedRecordIDs.count))
        }
        .confirmationDialog(
            AppLocalization.localizedString("records_clear_all_confirm_title"),
            isPresented: $showsClearAllConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppLocalization.localizedString("records_action_clear_all"), role: .destructive) {
                controller.clearVoiceRecognitionRecords()
                selectedRecordIDs.removeAll()
                isEditing = false
            }
            Button(AppLocalization.localizedString("cancel_button"), role: .cancel) {}
        } message: {
            Text(AppLocalization.localizedString("records_clear_all_confirm_message"))
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
        MainWindowSurface {
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
        }
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
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(MainWindowColors.title)
                Text(section.subtitle)
                    .font(.subheadline)
                    .foregroundColor(MainWindowColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

struct MainWindowSurface<Content: View>: View {
    let emphasized: Bool
    @ViewBuilder let content: Content

    init(emphasized: Bool = false, @ViewBuilder content: () -> Content) {
        self.emphasized = emphasized
        self.content = content()
    }

    var body: some View {
        content
            .padding(emphasized ? 28 : 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: emphasized ? 24 : 20, style: .continuous)
                    .fill(emphasized ? MainWindowColors.cardSurface : MainWindowColors.recentActivitySurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: emphasized ? 24 : 20, style: .continuous)
                    .stroke(MainWindowColors.cardBorder, lineWidth: 1)
            )
    }
}

struct MainWindowStatusChip: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }
}

private struct MainWindowMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        MainWindowSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(title, systemImage: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(MainWindowColors.secondaryText)

                    Spacer()
                }

                Text(value)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(MainWindowColors.title)
                    .lineLimit(2)

                Text(detail)
                    .font(.subheadline)
                    .foregroundColor(MainWindowColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 40, height: 4)
            }
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
                        Text(AppLocalization.localizedString("main_home_welcome"))
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(MainWindowColors.title)
                        Text(AppLocalization.localizedString("main_home_subtitle"))
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
                    Text(AppLocalization.localizedString("main_home_recent_activity"))
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
        MainWindowSurface(emphasized: true) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppLocalization.localizedString("status_connection_title"))
                            .font(.title3.weight(.semibold))
                            .foregroundColor(MainWindowColors.title)

                        Text(spotlightDescription)
                            .font(.subheadline)
                            .foregroundColor(MainWindowColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 18)

                    MainWindowStatusChip(
                        title: connectionSummaryValue,
                        systemImage: "dot.radiowaves.left.and.right",
                        tint: spotlightTint
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
                        title: AppLocalization.localizedString("status_service_label"),
                        value: serviceSummaryValue,
                        tint: controller.isServiceRunning ? .green : .orange,
                        systemImage: "server.rack"
                    )

                    collaborationStatusCard(
                        title: AppLocalization.localizedString("status_ip_label"),
                        value: LocalNetworkAccessPolicy.preferredLocalIPv4() ?? AppLocalization.localizedString("status_unknown_value"),
                        tint: MainWindowColors.secondaryText,
                        systemImage: "network"
                    )

                    if let deviceName = controlsPolicy.pairedDeviceName {
                        collaborationStatusCard(
                            title: AppLocalization.localizedString("status_paired_device_label"),
                            value: deviceName,
                            tint: .blue,
                            systemImage: "iphone"
                        )
                    }
                }

                HStack(spacing: 14) {
                    spotlightAction(
                        title: controller.isServiceRunning
                        ? AppLocalization.localizedString("status_action_stop_service")
                        : AppLocalization.localizedString("status_action_start_service"),
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
                            title: AppLocalization.localizedString("status_action_start_pairing"),
                            role: .secondary
                        ) {
                            controller.showPairingWindowFromUI()
                        }
                    }

                    if controlsPolicy.showsUnpair {
                        spotlightAction(
                            title: AppLocalization.localizedString("status_action_unpair"),
                            role: .secondary
                        ) {
                            controller.unpairDeviceFromUI()
                        }
                    }
                }
            }
        }
    }

    private func collaborationStatusCard(title: String, value: String, tint: Color, systemImage: String) -> some View {
        MainWindowSurface {
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
        }
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

                Text(record.category == .voice ? AppLocalization.localizedString("data_category_voice") : AppLocalization.localizedString("data_category_connection"))
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
        switch MacConnectionPresentationPolicy.displayState(
            pairingState: controller.pairingState,
            connectionState: controller.connectionState
        ) {
        case .connected:
            return AppLocalization.localizedString("status_connection_connected")
        case .connecting:
            return AppLocalization.localizedString("status_connection_connecting")
        case .disconnected:
            return AppLocalization.localizedString("status_connection_disconnected")
        case .error:
            return AppLocalization.localizedString("status_connection_error")
        }
    }

    private var serviceSummaryValue: String {
        controller.isServiceRunning
        ? AppLocalization.localizedString("status_service_running")
        : AppLocalization.localizedString("status_service_stopped")
    }

    private var noteSummaryValue: String {
        String(format: AppLocalization.localizedString("main_home_note_count_format"), controller.noteText.count)
    }

    private var spotlightDescription: String {
        if case .paired(_, let deviceName) = controller.pairingState {
            return String(format: AppLocalization.localizedString("main_home_paired_summary_format"), deviceName)
        }

        return AppLocalization.localizedString("main_home_unpaired_summary")
    }

    private var spotlightTint: Color {
        switch MacConnectionPresentationPolicy.displayState(
            pairingState: controller.pairingState,
            connectionState: controller.connectionState
        ) {
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
        VStack(alignment: .leading, spacing: 20) {
            if showsInlineHeader {
                Text(AppLocalization.localizedString("status_connection_title"))
                    .font(.system(size: 32, weight: .semibold))
            }

            MainWindowSurface(emphasized: true) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppLocalization.localizedString("status_connection_title"))
                                .font(.title3.weight(.semibold))
                                .foregroundColor(MainWindowColors.title)

                            Text(statusSummaryText)
                                .font(.subheadline)
                                .foregroundColor(MainWindowColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 16)

                        MainWindowStatusChip(
                            title: statusChipTitle,
                            systemImage: statusChipSystemImage,
                            tint: statusChipTint
                        )
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 14),
                            GridItem(.flexible(), spacing: 14)
                        ],
                        spacing: 14
                    ) {
                        statusSummaryCard(
                            title: AppLocalization.localizedString("status_label"),
                            valueView: AnyView(connectionStatusView),
                            systemImage: "antenna.radiowaves.left.and.right",
                            tint: statusChipTint
                        )

                        statusSummaryCard(
                            title: AppLocalization.localizedString("status_service_label"),
                            valueView: AnyView(
                                Text(controller.isServiceRunning ? AppLocalization.localizedString("status_service_running") : AppLocalization.localizedString("status_service_stopped"))
                                    .foregroundColor(controller.isServiceRunning ? .green : MainWindowColors.secondaryText)
                            ),
                            systemImage: "server.rack",
                            tint: controller.isServiceRunning ? .green : .orange
                        )

                        statusSummaryCard(
                            title: AppLocalization.localizedString("status_ip_label"),
                            valueView: AnyView(
                                Text(getLocalIPAddress() ?? AppLocalization.localizedString("status_unknown_value"))
                                    .foregroundColor(MainWindowColors.title)
                            ),
                            systemImage: "network",
                            tint: .blue
                        )

                        if case .paired(_, let deviceName) = controller.pairingState {
                            statusSummaryCard(
                                title: AppLocalization.localizedString("status_paired_device_label"),
                                valueView: AnyView(
                                    Text(deviceName)
                                        .foregroundColor(MainWindowColors.title)
                                ),
                                systemImage: "iphone",
                                tint: .blue
                            )
                        }
                    }

                    if let progressMessage = effectivePairingProgressMessage {
                        MainWindowSurface {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: pairingProgressIconName)
                                    .foregroundColor(pairingProgressColor)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(AppLocalization.localizedString("status_pairing_progress_label"))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(MainWindowColors.title)

                                    Text(progressMessage)
                                        .font(.subheadline)
                                        .foregroundColor(MainWindowColors.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()
                            }
                        }
                    }
                }
            }

            MainWindowSurface {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppLocalization.localizedString("status_service_title"))
                            .font(.headline.weight(.semibold))
                            .foregroundColor(MainWindowColors.title)

                        Text(controller.isServiceRunning
                            ? AppLocalization.localizedString("status_service_running")
                            : AppLocalization.localizedString("status_service_stopped"))
                            .font(.subheadline)
                            .foregroundColor(MainWindowColors.secondaryText)
                    }

                    HStack(spacing: 14) {
                        if !controller.isServiceRunning {
                            statusActionButton(
                                title: AppLocalization.localizedString("status_action_start_service"),
                                systemImage: "play.fill",
                                role: .primary
                            ) {
                                controller.startNetworkServices()
                            }
                        } else {
                            statusActionButton(
                                title: AppLocalization.localizedString("status_action_stop_service"),
                                systemImage: "stop.fill",
                                role: .secondary
                            ) {
                                controller.stopNetworkServices()
                            }
                        }
                    }
                }
            }

            if controller.isServiceRunning {
                MainWindowSurface {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AppLocalization.localizedString("main_nav_collaboration"))
                                .font(.headline.weight(.semibold))
                                .foregroundColor(MainWindowColors.title)

                            Text(pairingActionSummary)
                                .font(.subheadline)
                                .foregroundColor(MainWindowColors.secondaryText)
                        }

                        if case .unpaired = controller.pairingState {
                            statusActionButton(
                                title: AppLocalization.localizedString("status_action_start_pairing"),
                                systemImage: "iphone.and.arrow.forward",
                                role: .primary
                            ) {
                                controller.showPairingWindowFromUI()
                            }
                        } else if case .paired(_, let deviceName) = controller.pairingState {
                            HStack {
                                Text(String(format: AppLocalization.localizedString("status_paired_device_format"), deviceName))
                                    .foregroundColor(MainWindowColors.secondaryText)
                                Spacer()
                                statusActionButton(
                                    title: AppLocalization.localizedString("status_action_unpair"),
                                    systemImage: "link.badge.minus",
                                    role: .secondary
                                ) {
                                    controller.unpairDeviceFromUI()
                                }
                                .frame(maxWidth: 180)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        switch MacConnectionPresentationPolicy.displayState(
            pairingState: controller.pairingState,
            connectionState: controller.connectionState
        ) {
        case .disconnected:
            Label(AppLocalization.localizedString("status_connection_disconnected"), systemImage: "circle")
                .foregroundColor(MainWindowColors.secondaryText)
        case .connecting:
            Label(AppLocalization.localizedString("status_connection_connecting"), systemImage: "circle.dotted")
                .foregroundColor(.orange)
        case .connected:
            Label(AppLocalization.localizedString("status_connection_connected"), systemImage: "circle.fill")
                .foregroundColor(.green)
        case .error:
            Label(AppLocalization.localizedString("status_connection_error"), systemImage: "exclamationmark.triangle")
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

    private var statusSummaryText: String {
        switch MacConnectionPresentationPolicy.displayState(
            pairingState: controller.pairingState,
            connectionState: controller.connectionState
        ) {
        case .connected:
            return AppLocalization.localizedString("status_connected_ready")
        case .connecting:
            return AppLocalization.localizedString("status_connection_connecting")
        case .disconnected:
            return AppLocalization.localizedString("status_unpaired_need_pair")
        case .error:
            return AppLocalization.localizedString("status_connection_error")
        }
    }

    private var statusChipTitle: String {
        switch MacConnectionPresentationPolicy.displayState(
            pairingState: controller.pairingState,
            connectionState: controller.connectionState
        ) {
        case .connected:
            return AppLocalization.localizedString("status_connection_connected")
        case .connecting:
            return AppLocalization.localizedString("status_connection_connecting")
        case .disconnected:
            return AppLocalization.localizedString("status_connection_disconnected")
        case .error:
            return AppLocalization.localizedString("status_connection_error")
        }
    }

    private var statusChipSystemImage: String {
        switch MacConnectionPresentationPolicy.displayState(
            pairingState: controller.pairingState,
            connectionState: controller.connectionState
        ) {
        case .connected:
            return "checkmark.circle.fill"
        case .connecting:
            return "circle.dotted"
        case .disconnected:
            return "circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    private var statusChipTint: Color {
        switch MacConnectionPresentationPolicy.displayState(
            pairingState: controller.pairingState,
            connectionState: controller.connectionState
        ) {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return MainWindowColors.secondaryText
        case .error:
            return .red
        }
    }

    private var pairingActionSummary: String {
        switch controller.pairingState {
        case .unpaired:
            return AppLocalization.localizedString("status_unpaired_need_pair")
        case .pairing:
            return AppLocalization.localizedString("status_pairing")
        case .paired(_, let deviceName):
            return String(format: AppLocalization.localizedString("status_paired_device_format"), deviceName)
        }
    }

    private func statusSummaryCard(title: String, valueView: AnyView, systemImage: String, tint: Color) -> some View {
        MainWindowSurface {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(MainWindowColors.secondaryText)

                valueView
                    .font(.body.weight(.semibold))
            }
        }
    }

    private func statusActionButton(
        title: String,
        systemImage: String,
        role: SpotlightButtonRole,
        action: @escaping () -> Void
    ) -> some View {
        let style = SpotlightActionStylePolicy.style(for: role)

        return Button(action: action) {
            Label(title, systemImage: systemImage)
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
}

// MARK: - Settings Tab

struct SettingsTab: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var controller: MenuBarController
    @StateObject private var purchaseStore = TwoDeviceSyncPurchaseStore.shared
    var showsInlineHeader = false
    @State private var serverPortText = ""
    @State private var languageSelection = "zh-CN"
    @State private var uiLanguageSelection = "zh-CN"
    @State private var themeSelection: AppThemePreference = .system

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if showsInlineHeader {
                    Text(AppLocalization.localizedString("tab_settings"))
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                HStack(spacing: 10) {
                    settingsOverviewBadge(
                        title: AppLocalization.localizedString("settings_language_title"),
                        value: localizedLanguageName(for: languageSelection)
                    )

                    settingsOverviewBadge(
                        title: AppLocalization.localizedString("settings_ui_language_title"),
                        value: localizedLanguageName(for: uiLanguageSelection)
                    )

                    settingsOverviewBadge(
                        title: AppLocalization.localizedString("settings_theme_title"),
                        value: AppLocalization.localizedString(themeSelection.localizedTitleKey)
                    )

                    settingsOverviewBadge(
                        title: AppLocalization.localizedString("billing_two_device_sync_header"),
                        value: syncStatusBadgeTitle
                    )
                }

                settingsSectionCard(
                    title: AppLocalization.localizedString("settings_preferences_header"),
                    description: AppLocalization.localizedString("settings_preferences_description")
                ) {
                    VStack(alignment: .leading, spacing: 0) {
                        settingsRow(
                            title: AppLocalization.localizedString("settings_language_picker"),
                            detail: nil
                        ) {
                            Picker(AppLocalization.localizedString("settings_language_picker"), selection: $languageSelection) {
                                Text(AppLocalization.localizedString("settings_language_zh")).tag("zh-CN")
                                Text(AppLocalization.localizedString("settings_language_en")).tag("en-US")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 140)
                        }

                        settingsDivider()

                        settingsRow(
                            title: AppLocalization.localizedString("settings_ui_language_picker"),
                            detail: nil
                        ) {
                            Picker(AppLocalization.localizedString("settings_ui_language_picker"), selection: $uiLanguageSelection) {
                                Text(AppLocalization.localizedString("settings_ui_language_zh")).tag("zh-CN")
                                Text(AppLocalization.localizedString("settings_ui_language_en")).tag("en-US")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 140)
                        }

                        settingsDivider()

                        settingsRow(
                            title: AppLocalization.localizedString("settings_theme_picker"),
                            detail: nil
                        ) {
                            Picker(AppLocalization.localizedString("settings_theme_picker"), selection: $themeSelection) {
                                ForEach(AppThemePreference.allCases) { preference in
                                    Text(AppLocalization.localizedString(preference.localizedTitleKey))
                                        .tag(preference)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 140)
                        }
                    }
                }

                settingsSectionCard(
                    title: AppLocalization.localizedString("billing_two_device_sync_header"),
                    description: AppLocalization.localizedString("billing_two_device_sync_section_description")
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        syncStatusBanner

                        if MacBillingPresentationPolicy.showsUnlockOptions(for: purchaseStore.entitlement) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(AppLocalization.localizedString("billing_two_device_sync_actions_title"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(MainWindowColors.secondaryText)

                                billingPlanButton(
                                    title: billingTitle(for: .monthly),
                                    subtitle: AppLocalization.localizedString("billing_two_device_sync_plan_monthly_caption"),
                                    isSelected: purchaseStore.entitlement == .monthly,
                                    isLoading: purchaseStore.activePurchaseProductID == TwoDeviceSyncProductKind.monthly.rawValue
                                ) {
                                    Task {
                                        _ = await purchaseStore.purchase(.monthly)
                                    }
                                }

                                billingPlanButton(
                                    title: billingTitle(for: .yearly),
                                    subtitle: AppLocalization.localizedString("billing_two_device_sync_plan_yearly_caption"),
                                    isSelected: purchaseStore.entitlement == .yearly,
                                    isLoading: purchaseStore.activePurchaseProductID == TwoDeviceSyncProductKind.yearly.rawValue
                                ) {
                                    Task {
                                        _ = await purchaseStore.purchase(.yearly)
                                    }
                                }

                                billingPlanButton(
                                    title: billingTitle(for: .lifetime),
                                    subtitle: AppLocalization.localizedString("billing_two_device_sync_plan_lifetime_caption"),
                                    isSelected: purchaseStore.entitlement == .lifetime,
                                    isLoading: purchaseStore.activePurchaseProductID == TwoDeviceSyncProductKind.lifetime.rawValue
                                ) {
                                    Task {
                                        _ = await purchaseStore.purchase(.lifetime)
                                    }
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            Button(AppLocalization.localizedString("billing_two_device_sync_restore_button")) {
                                Task {
                                    await purchaseStore.restorePurchases()
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                            .disabled(purchaseStore.activePurchaseProductID != nil || purchaseStore.isRestoringPurchases)

                            if purchaseStore.isRestoringPurchases {
                                ProgressView()
                                    .controlSize(.small)
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
                    title: AppLocalization.localizedString("settings_network_title"),
                    description: AppLocalization.localizedString("settings_network_section_description")
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        settingsRow(
                            title: AppLocalization.localizedString("settings_network_port_label"),
                            detail: AppLocalization.localizedString("settings_network_port_desc")
                        ) {
                            TextField(AppLocalization.localizedString("settings_network_port_placeholder"), text: $serverPortText)
                                .frame(width: 120)
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
        .onChange(of: uiLanguageSelection) { _, newValue in
            guard settings.uiLanguage != newValue else { return }
            DispatchQueue.main.async {
                settings.uiLanguage = newValue
            }
        }
        .onChange(of: themeSelection) { _, newValue in
            guard settings.themePreference != newValue else { return }
            DispatchQueue.main.async {
                settings.themePreference = newValue
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func settingsOverviewBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(MainWindowColors.secondaryText)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(MainWindowColors.title)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MainWindowColors.softSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }

    private func syncLocalSettingsState() {
        languageSelection = settings.language
        uiLanguageSelection = settings.uiLanguage
        themeSelection = settings.themePreference
        serverPortText = String(settings.serverPort)
    }

    private func updateSettingsPortIfNeeded(_ port: UInt16) {
        guard settings.serverPort != port else { return }
        DispatchQueue.main.async {
            settings.serverPort = port
        }
    }

    private func localizedLanguageName(for language: String) -> String {
        switch language {
        case "en-US":
            return AppLocalization.localizedString("settings_language_en")
        default:
            return AppLocalization.localizedString("settings_language_zh")
        }
    }

    private func settingsSectionCard<Content: View>(
        title: String,
        description: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        MainWindowSurface {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(MainWindowColors.title)

                    if let description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(MainWindowColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                content()
            }
        }
    }

    private func settingsRow<Content: View>(
        title: String,
        detail: String? = nil,
        @ViewBuilder trailing: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(MainWindowColors.title)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(SettingsSurfaceStylePolicy.secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            trailing()
        }
    }

    private func settingsDivider() -> some View {
        Divider()
            .overlay(MainWindowColors.cardBorder)
    }

    private var syncStatusBanner: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(syncStatusTint.opacity(0.14))
                    .frame(width: 36, height: 36)

                Image(systemName: syncStatusIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(syncStatusTint)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(macBillingStatusTitle)
                    .font(.body.weight(.semibold))
                    .foregroundColor(MainWindowColors.title)

                Text(macBillingStatusDetail)
                    .font(.callout)
                    .foregroundColor(SettingsSurfaceStylePolicy.secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            MainWindowStatusChip(
                title: syncStatusBadgeTitle,
                systemImage: syncStatusIcon,
                tint: syncStatusTint
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SettingsSurfaceStylePolicy.rowFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SettingsSurfaceStylePolicy.cardBorderColor, lineWidth: 1)
        )
    }

    private func billingPlanButton(
        title: String,
        subtitle: String,
        isSelected: Bool,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundColor(MainWindowColors.title)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(MainWindowColors.secondaryText)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(MainWindowColors.secondaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.green.opacity(0.08) : SettingsSurfaceStylePolicy.rowFillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.green.opacity(0.3) : SettingsSurfaceStylePolicy.cardBorderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(purchaseStore.activePurchaseProductID != nil || purchaseStore.isRestoringPurchases)
    }

    private var macBillingStatusTitle: String {
        switch purchaseStore.entitlement {
        case .free:
            return AppLocalization.localizedString("billing_two_device_sync_status_free_mac")
        case .monthly, .yearly, .lifetime:
            return AppLocalization.localizedString("billing_two_device_sync_status_unlimited")
        }
    }

    private var macBillingStatusDetail: String {
        switch purchaseStore.entitlement {
        case .free:
            return AppLocalization.localizedString("billing_two_device_sync_mac_detail_free")
        case .monthly:
            return AppLocalization.localizedString("billing_two_device_sync_mac_detail_monthly")
        case .yearly:
            return AppLocalization.localizedString("billing_two_device_sync_mac_detail_yearly")
        case .lifetime:
            return AppLocalization.localizedString("billing_two_device_sync_mac_detail_lifetime")
        }
    }

    private func billingTitle(for kind: TwoDeviceSyncProductKind) -> String {
        if let price = purchaseStore.displayPrice(for: kind) {
            switch kind {
            case .monthly:
                return String(format: AppLocalization.localizedString("billing_two_device_sync_monthly_button"), price)
            case .yearly:
                return String(format: AppLocalization.localizedString("billing_two_device_sync_yearly_button"), price)
            case .lifetime:
                return String(format: AppLocalization.localizedString("billing_two_device_sync_lifetime_button"), price)
            }
        }

        switch kind {
        case .monthly:
            return AppLocalization.localizedString("billing_two_device_sync_monthly_fallback")
        case .yearly:
            return AppLocalization.localizedString("billing_two_device_sync_yearly_fallback")
        case .lifetime:
            return AppLocalization.localizedString("billing_two_device_sync_lifetime_fallback")
        }
    }

    private var syncStatusTint: Color {
        switch purchaseStore.entitlement {
        case .free:
            return .orange
        case .monthly, .yearly, .lifetime:
            return .green
        }
    }

    private var syncStatusIcon: String {
        switch purchaseStore.entitlement {
        case .free:
            return "lock.open"
        case .monthly, .yearly, .lifetime:
            return "checkmark.shield"
        }
    }

    private var syncStatusBadgeTitle: String {
        switch purchaseStore.entitlement {
        case .free:
            return AppLocalization.localizedString("billing_two_device_sync_free_badge")
        case .monthly:
            return AppLocalization.localizedString("billing_two_device_sync_monthly_fallback")
        case .yearly:
            return AppLocalization.localizedString("billing_two_device_sync_yearly_fallback")
        case .lifetime:
            return AppLocalization.localizedString("billing_two_device_sync_lifetime_fallback")
        }
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
            AppLocalization.localizedString(titleKey)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if showsInlineHeader {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppLocalization.localizedString("data_title"))
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(AppLocalization.localizedString("data_subtitle"))
                        .font(.callout)
                        .foregroundColor(MainWindowColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            MainWindowSurface(emphasized: true) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(AppLocalization.localizedString("data_title"))
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(MainWindowColors.title)

                            Text(AppLocalization.localizedString("data_subtitle"))
                                .font(.subheadline)
                                .foregroundColor(MainWindowColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 16)

                        MainWindowStatusChip(
                            title: groupBySession
                                ? AppLocalization.localizedString("data_group_by_session")
                                : AppLocalization.localizedString("data_filter_picker"),
                            systemImage: groupBySession ? "square.stack.3d.up" : "line.3.horizontal.decrease.circle",
                            tint: .blue
                        )
                    }

                    HStack(spacing: 12) {
                        summaryBadge(title: AppLocalization.localizedString("data_summary_total"), value: "\(filteredRecords.count)", color: MainWindowColors.title, systemImage: "tray.full")
                        summaryBadge(title: AppLocalization.localizedString("data_summary_voice"), value: "\(filteredVoiceCount)", color: .accentColor, systemImage: "waveform")
                        summaryBadge(title: AppLocalization.localizedString("data_summary_pairing"), value: "\(filteredPairingCount)", color: .blue, systemImage: "link")
                        summaryBadge(title: AppLocalization.localizedString("data_summary_failure"), value: "\(filteredFailureCount)", color: .red, systemImage: "exclamationmark.triangle")
                    }
                }
            }

            MainWindowSurface {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 12) {
                        Text(AppLocalization.localizedString("data_filter_picker"))
                            .font(.headline)
                            .foregroundColor(MainWindowColors.secondaryText)

                        Picker(AppLocalization.localizedString("data_filter_picker"), selection: $selectedFilter) {
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
                        TextField(AppLocalization.localizedString("data_search_placeholder"), text: $searchText)
                            .textFieldStyle(.roundedBorder)

                        Toggle(AppLocalization.localizedString("data_group_by_session"), isOn: $groupBySession)
                            .toggleStyle(.checkbox)
                    }
                }
            }

            if filteredRecords.isEmpty {
                ContentUnavailableView(
                    AppLocalization.localizedString("data_empty_title"),
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
            let sessionKey = extractSessionKey(from: record.detail) ?? AppLocalization.localizedString("data_session_unknown")
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
            return AppLocalization.localizedString("data_empty_search_desc")
        }

        switch selectedFilter {
        case .all:
            return AppLocalization.localizedString("data_empty_all_desc")
        case .voice:
            return AppLocalization.localizedString("data_empty_voice_desc")
        case .pairing:
            return AppLocalization.localizedString("data_empty_pairing_desc")
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(recordBackgroundColor(isFailure: failure))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(failure ? Color.red.opacity(0.45) : MainWindowColors.cardBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline.weight(.semibold))
            Spacer()
            Text(String(format: AppLocalization.localizedString("data_section_count_format"), count))
                .font(.caption.weight(.semibold))
                .foregroundColor(MainWindowColors.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(MainWindowColors.softSurface.opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func summaryBadge(title: String, value: String, color: Color, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(MainWindowColors.secondaryText)
            }

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(MainWindowColors.softSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            return AppLocalization.localizedString("data_severity_info")
        case .warning:
            return AppLocalization.localizedString("data_severity_warning")
        case .error:
            return AppLocalization.localizedString("data_severity_error")
        }
    }

    private func categoryTitle(for category: InboundDataCategory) -> String {
        switch category {
        case .voice:
            return AppLocalization.localizedString("data_category_voice")
        case .pairing:
            return AppLocalization.localizedString("data_category_pairing")
        case .connection:
            return AppLocalization.localizedString("data_category_connection")
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var aboutHero: some View {
        MainWindowSurface(emphasized: true) {
            HStack(alignment: .top, spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(MainWindowColors.softSurface)
                        .frame(width: 108, height: 108)

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(MainWindowColors.cardSurface)
                        .frame(width: 74, height: 74)

                    Image(systemName: "waveform")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(MainWindowColors.title)
                }

                VStack(alignment: .leading, spacing: 12) {
                    if showsInlineHeader {
                        Text(AppLocalization.localizedString("app_title"))
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(MainWindowColors.title)
                    }

                    Text(AppLocalization.localizedString("about_title"))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(MainWindowColors.title)

                    Text(AppLocalization.localizedString("about_description"))
                        .font(.body)
                        .foregroundColor(MainWindowColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        MainWindowStatusChip(
                            title: AppLocalization.localizedString("about_version"),
                            systemImage: "number.circle",
                            tint: MainWindowColors.secondaryText
                        )
                        .onTapGesture(count: 2, perform: onRevealDebug)
                    }

                    HStack(spacing: 12) {
                        Button(AppLocalization.localizedString("about_open_guide")) {
                            onOpenGuide()
                        }
                        .buttonStyle(.borderedProminent)

                        Button(AppLocalization.localizedString("about_website")) {
                            if let url = URL(string: "https://voicemind.top-list.top") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)

                        Button(AppLocalization.localizedString("about_privacy_policy")) {
                            if let url = URL(string: "https://voicemind.top-list.top/privacy.html") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var aboutHighlights: some View {
        HStack(alignment: .top, spacing: 18) {
            aboutHighlightCard(
                systemImage: "laptopcomputer.and.iphone",
                title: AppLocalization.localizedString("main_nav_collaboration"),
                description: AppLocalization.localizedString("about_description")
            )

            aboutHighlightCard(
                systemImage: "book.pages",
                title: AppLocalization.localizedString("about_open_guide"),
                description: AppLocalization.localizedString("main_brand_subtitle")
            )
        }
    }

    private func aboutHighlightCard(systemImage: String, title: String, description: String) -> some View {
            VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentColor)
            }

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(MainWindowColors.title)

            Text(description)
                .font(.subheadline)
                .foregroundColor(MainWindowColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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

    private var controlsPolicy: CollaborationControlsPolicy {
        CollaborationControlsPolicy(
            pairingState: controller.pairingState,
            isServiceRunning: controller.isServiceRunning
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroSection

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ],
                    spacing: 16
                ) {
                    MainWindowMetricCard(
                        title: AppLocalization.localizedString("status_label"),
                        value: connectionSummary,
                        detail: pairingDetail,
                        systemImage: "dot.radiowaves.left.and.right",
                        tint: connectionTint
                    )

                    MainWindowMetricCard(
                        title: AppLocalization.localizedString("speech_engine_title"),
                        value: AppLocalization.localizedString("tab_speech"),
                        detail: AppLocalization.localizedString("main_speech_subtitle"),
                        systemImage: "waveform.circle",
                        tint: .blue
                    )

                    MainWindowMetricCard(
                        title: AppLocalization.localizedString("note_title"),
                        value: String(format: AppLocalization.localizedString("main_home_note_count_format"), controller.noteText.count),
                        detail: controller.isLocalRecording
                            ? AppLocalization.localizedString("note_recording")
                            : AppLocalization.localizedString("main_home_recent_activity"),
                        systemImage: "mic",
                        tint: controller.isLocalRecording ? .red : .green
                    )
                }

                noteWorkspaceCard

                collaborationQuickActions

                recentActivityCard
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var heroSection: some View {
        MainWindowSurface(emphasized: true) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(AppLocalization.localizedString("main_home_welcome"))
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundColor(MainWindowColors.title)

                    Text(AppLocalization.localizedString("main_home_subtitle"))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(MainWindowColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        MainWindowStatusChip(
                            title: connectionSummary,
                            systemImage: "antenna.radiowaves.left.and.right",
                            tint: connectionTint
                        )

                        MainWindowStatusChip(
                            title: controller.isServiceRunning
                                ? AppLocalization.localizedString("status_service_running")
                                : AppLocalization.localizedString("status_service_stopped"),
                            systemImage: "server.rack",
                            tint: controller.isServiceRunning ? .green : .orange
                        )
                    }
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 12) {
                    spotlightHomeButton(
                        title: controller.isServiceRunning
                            ? AppLocalization.localizedString("status_action_stop_service")
                            : AppLocalization.localizedString("status_action_start_service"),
                        role: controller.isServiceRunning ? .secondary : .primary
                    ) {
                        if controller.isServiceRunning {
                            controller.stopNetworkServices()
                        } else {
                            controller.startNetworkServices()
                        }
                    }

                    if controlsPolicy.showsStartPairing {
                        spotlightHomeButton(
                            title: AppLocalization.localizedString("status_action_start_pairing"),
                            role: .secondary
                        ) {
                            controller.showPairingWindowFromUI()
                        }
                    } else if controlsPolicy.showsUnpair {
                        spotlightHomeButton(
                            title: AppLocalization.localizedString("status_action_unpair"),
                            role: .secondary
                        ) {
                            controller.unpairDeviceFromUI()
                        }
                    }
                }
                .frame(width: 220)
            }
        }
    }

    private var noteWorkspaceCard: some View {
        MainWindowSurface {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppLocalization.localizedString("note_title"))
                            .font(.title3.weight(.semibold))
                            .foregroundColor(MainWindowColors.title)

                        Text(AppLocalization.localizedString("main_notes_subtitle"))
                            .font(.subheadline)
                            .foregroundColor(MainWindowColors.secondaryText)
                    }

                    Spacer()

                    Button(action: {
                        controller.clearNote()
                    }) {
                        Label(AppLocalization.localizedString("note_clear"), systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(controller.noteText.isEmpty)
                }

                Group {
                    if NotesTextSelectionPolicy.allowsSelection(for: controller.noteText) {
                        Text(controller.noteText)
                            .textSelection(.enabled)
                    } else {
                        Text(AppLocalization.localizedString("note_placeholder"))
                            .textSelection(.disabled)
                    }
                }
                .font(.body)
                .foregroundColor(controller.noteText.isEmpty ? MainWindowColors.secondaryText : MainWindowColors.title)
                .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(MainWindowColors.softSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(MainWindowColors.cardBorder, lineWidth: 1)
                )

                HStack(spacing: 18) {
                    RecordButton(
                        isRecording: controller.isLocalRecording,
                        onStartRecording: {
                            controller.startLocalRecording()
                        },
                        onStopRecording: {
                            controller.stopLocalRecording()
                        }
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(controller.isLocalRecording ? AppLocalization.localizedString("note_recording") : AppLocalization.localizedString("note_placeholder"))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(controller.isLocalRecording ? .red : MainWindowColors.secondaryText)

                        Text(pairingDetail)
                            .font(.caption)
                            .foregroundColor(MainWindowColors.secondaryText)
                    }

                    Spacer()
                }
            }
        }
    }

    private var collaborationQuickActions: some View {
        MainWindowSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text(AppLocalization.localizedString("main_nav_collaboration"))
                    .font(.title3.weight(.semibold))
                    .foregroundColor(MainWindowColors.title)

                Text(pairingDetail)
                    .font(.subheadline)
                    .foregroundColor(MainWindowColors.secondaryText)

                HStack(spacing: 12) {
                    if controlsPolicy.showsStartPairing {
                        spotlightHomeButton(
                            title: AppLocalization.localizedString("status_action_start_pairing"),
                            role: .primary
                        ) {
                            controller.showPairingWindowFromUI()
                        }
                    }

                    if controlsPolicy.showsUnpair {
                        spotlightHomeButton(
                            title: AppLocalization.localizedString("status_action_unpair"),
                            role: .secondary
                        ) {
                            controller.unpairDeviceFromUI()
                        }
                    }
                }
            }
        }
    }

    private var recentActivityCard: some View {
        MainWindowSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text(AppLocalization.localizedString("main_home_recent_activity"))
                    .font(.title3.weight(.semibold))
                    .foregroundColor(MainWindowColors.title)

                if recentRecords.isEmpty {
                    Text(AppLocalization.localizedString("data_empty_title"))
                        .font(.subheadline)
                        .foregroundColor(MainWindowColors.secondaryText)
                } else {
                    VStack(spacing: 12) {
                        ForEach(recentRecords) { record in
                            recentRecordRow(record)
                        }
                    }
                }
            }
        }
    }

    private func recentRecordRow(_ record: InboundDataRecord) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: recentRecordIcon(for: record))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(recentRecordTint(for: record))
                .frame(width: 30, height: 30)
                .background(recentRecordTint(for: record).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(MainWindowColors.title)

                Text(activityCategoryTitle(for: record))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(MainWindowColors.secondaryText)
            }
            .frame(width: 120, alignment: .leading)

            Text(record.detail)
                .font(.subheadline)
                .foregroundColor(MainWindowColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MainWindowColors.softSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }

    private func activityCategoryTitle(for record: InboundDataRecord) -> String {
        switch record.category {
        case .voice:
            return AppLocalization.localizedString("data_category_voice")
        case .pairing:
            return AppLocalization.localizedString("data_category_pairing")
        case .connection:
            return AppLocalization.localizedString("data_category_connection")
        }
    }

    private func recentRecordIcon(for record: InboundDataRecord) -> String {
        switch record.category {
        case .voice:
            return "waveform.circle.fill"
        case .pairing:
            return "link.circle.fill"
        case .connection:
            return "antenna.radiowaves.left.and.right"
        }
    }

    private func recentRecordTint(for record: InboundDataRecord) -> Color {
        switch record.category {
        case .voice:
            return .accentColor
        case .pairing:
            return .blue
        case .connection:
            return MainWindowColors.secondaryText
        }
    }

    private func spotlightHomeButton(title: String, role: SpotlightButtonRole, action: @escaping () -> Void) -> some View {
        let style = SpotlightActionStylePolicy.style(for: role)

        return Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(style.fillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(style.borderColor, lineWidth: style.borderColor == .clear ? 0 : 1)
        )
        .foregroundColor(style.foregroundColor)
    }

    private var recentRecords: [InboundDataRecord] {
        Array(controller.inboundDataRecords.prefix(3))
    }

    private var connectionSummary: String {
        switch MacConnectionPresentationPolicy.displayState(
            pairingState: controller.pairingState,
            connectionState: controller.connectionState
        ) {
        case .connected:
            return AppLocalization.localizedString("status_connection_connected")
        case .connecting:
            return AppLocalization.localizedString("status_connection_connecting")
        case .disconnected:
            return AppLocalization.localizedString("status_connection_disconnected")
        case .error:
            return AppLocalization.localizedString("status_connection_error")
        }
    }

    private var connectionTint: Color {
        switch MacConnectionPresentationPolicy.displayState(
            pairingState: controller.pairingState,
            connectionState: controller.connectionState
        ) {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return MainWindowColors.secondaryText
        case .error:
            return .red
        }
    }

    private var pairingDetail: String {
        if case .paired(_, let deviceName) = controller.pairingState {
            return String(format: AppLocalization.localizedString("main_home_paired_summary_format"), deviceName)
        }

        return AppLocalization.localizedString("main_home_unpaired_summary")
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
