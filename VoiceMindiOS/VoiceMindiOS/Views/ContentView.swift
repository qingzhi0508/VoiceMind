import SwiftUI
import UIKit

enum ContentTab: Int, CaseIterable {
    case home
    case data
    case settings

    static let defaultTab: ContentTab = .home

    var titleKey: LocalizedStringResource {
        switch self {
        case .home:
            "tab_home_title"
        case .data:
            "tab_data_title"
        case .settings:
            "settings_title"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house.fill"
        case .data:
            "tray.full.fill"
        case .settings:
            "gearshape.fill"
        }
    }
}

private enum AppPageLayout {
    static let horizontalPadding: CGFloat = 16
    static let topPadding: CGFloat = 10
    static let bottomPadding: CGFloat = 6
}

private struct AppCardSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        return content
            .background(
                shape
                    .fill(cardBackground)
            )
            .overlay(
                shape
                    .stroke(cardBorder, lineWidth: 1)
            )
            .shadow(color: cardShadow, radius: 18, x: 0, y: 10)
    }

    private var cardBackground: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color(uiColor: .secondarySystemBackground))
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.88),
                    Color(red: 0.95, green: 0.96, blue: 0.98).opacity(0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.72)
    }

    private var cardShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.18) : Color.black.opacity(0.08)
    }
}

enum PrimaryRecognitionLayoutPolicy {
    static func recognitionControlAlignment(showingTranscriptPreview: Bool) -> Alignment {
        .center
    }
}

enum HomeModeTogglePlacementPolicy {
    static let usesRainbowAccent = true

    static func shouldShowBottomToggle(sendToMacEnabled: Bool) -> Bool {
        sendToMacEnabled
    }

    static func systemImage(for mode: HomeTranscriptionMode) -> String {
        switch mode {
        case .local:
            return "desktopcomputer"
        case .mac:
            return "iphone"
        }
    }
}

enum AppBackgroundStylePolicy {
    static func usesMutedMistBackground(forDarkMode: Bool) -> Bool {
        !forDarkMode
    }

    static func showsRainbowBubbles(forDarkMode: Bool) -> Bool {
        !forDarkMode
    }

    static let usesModernGlassSurfaces = true
}

enum ContentInteractionPolicy {
    static func shouldDismissKeyboardOnBackgroundTap(isTranscriptEditorFocused: Bool) -> Bool {
        isTranscriptEditorFocused
    }
}

enum TranscriptTextViewSyncPolicy {
    static func shouldApplyExternalText(
        currentText: String,
        newText: String,
        isFirstResponder: Bool,
        hasMarkedText: Bool
    ) -> Bool {
        guard currentText != newText else { return false }
        if isFirstResponder && hasMarkedText {
            return false
        }
        return true
    }
}

enum TranscriptHistoryEditingPolicy {
    static func shouldAutoSaveOnBackgroundTap(isEditing: Bool) -> Bool {
        isEditing
    }

    static func savedText(originalText: String, draftText: String) -> String {
        let trimmedDraft = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDraft.isEmpty ? originalText : trimmedDraft
    }
}

enum RecognitionStatusInteractionPolicy {
    static func shouldShowManualSendTarget(
        isPressing: Bool,
        state: RecognitionState
    ) -> Bool {
        false
    }

    static func isInteractionEnabled(
        isEnabled: Bool,
        showsReconnectAction: Bool
    ) -> Bool {
        isEnabled || showsReconnectAction
    }
}

struct ContentView: View {
    enum FocusField: Hashable {
        case transcriptEditor
    }

    @StateObject private var viewModel = ContentViewModel()
    @Binding var hasLaunchedBefore: Bool

    @State private var showOnboarding = false
    @State private var selectedTab = ContentTab.defaultTab
    @FocusState private var focusedField: FocusField?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            backgroundLayer

            // Decorative Elements
            GeometryReader { geometry in
                ZStack {
                    if AppBackgroundStylePolicy.showsRainbowBubbles(forDarkMode: colorScheme == .dark) {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 1.00, green: 0.64, blue: 0.72).opacity(0.28),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 240
                                )
                            )
                            .frame(width: 360, height: 360)
                            .offset(x: geometry.size.width - 130, y: -40)

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 0.48, green: 0.78, blue: 1.00).opacity(0.24),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 230
                                )
                            )
                            .frame(width: 330, height: 330)
                            .offset(x: -90, y: geometry.size.height - 210)

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 0.93, green: 0.82, blue: 1.00).opacity(0.21),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 200
                                )
                            )
                            .frame(width: 290, height: 290)
                            .offset(x: geometry.size.width * 0.14, y: geometry.size.height * 0.30)

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 1.00, green: 0.88, blue: 0.45).opacity(0.16),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 180
                                )
                            )
                            .frame(width: 240, height: 240)
                            .offset(x: geometry.size.width * 0.62, y: geometry.size.height * 0.46)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard ContentInteractionPolicy.shouldDismissKeyboardOnBackgroundTap(
                        isTranscriptEditorFocused: focusedField == .transcriptEditor
                    ) else {
                        return
                    }
                    dismissKeyboard()
                }
            }

            TabView(selection: $selectedTab) {
                NavigationStack {
                    PrimaryRecognitionPage(
                        viewModel: viewModel,
                        isTranscriptFocused: Binding(
                            get: { focusedField == .transcriptEditor },
                            set: { focusedField = $0 ? .transcriptEditor : nil }
                        ),
                        onDismissKeyboard: dismissKeyboard
                    )
                    .padding(.horizontal, AppPageLayout.horizontalPadding)
                    .padding(.top, AppPageLayout.topPadding)
                    .padding(.bottom, AppPageLayout.bottomPadding)
                    .toolbar(.hidden, for: .navigationBar)
                }
                .tabItem {
                    Label(String(localized: ContentTab.home.titleKey), systemImage: ContentTab.home.systemImage)
                }
                .tag(ContentTab.home)

                NavigationStack {
                    TranscriptHistoryPage(
                        canSendToMac: { record in
                            viewModel.canSendTranscriptRecordToMac(record)
                        },
                        onSendToMac: { record in
                            viewModel.sendTranscriptRecordToMac(record)
                        },
                        history: viewModel.localTranscriptHistory,
                        onDelete: { id in
                            viewModel.removeLocalTranscriptRecord(id: id)
                        },
                        onUpdate: { id, text in
                            viewModel.updateLocalTranscriptRecord(id: id, text: text)
                        },
                        onDismissKeyboard: dismissKeyboard
                    )
                    .padding(.horizontal, AppPageLayout.horizontalPadding)
                    .padding(.top, AppPageLayout.topPadding)
                    .padding(.bottom, AppPageLayout.bottomPadding)
                    .toolbar(.hidden, for: .navigationBar)
                }
                .tabItem {
                    Label(String(localized: ContentTab.data.titleKey), systemImage: ContentTab.data.systemImage)
                }
                .tag(ContentTab.data)

                NavigationStack {
                    SettingsView(viewModel: viewModel, showsNavigationTitle: false)
                }
                .tabItem {
                    Label(String(localized: ContentTab.settings.titleKey), systemImage: ContentTab.settings.systemImage)
                }
                .tag(ContentTab.settings)
            }
            .overlay(alignment: .bottomTrailing) {
                if HomeModeTogglePlacementPolicy.shouldShowBottomToggle(
                    sendToMacEnabled: viewModel.sendResultsToMacEnabled
                ) {
                    Button {
                        dismissKeyboard()
                        viewModel.toggleHomeTranscriptionMode()
                    } label: {
                        Image(systemName: HomeModeTogglePlacementPolicy.systemImage(for: viewModel.effectiveHomeTranscriptionMode))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(
                                        AngularGradient(
                                            colors: [
                                                Color(red: 1.00, green: 0.36, blue: 0.37),
                                                Color(red: 1.00, green: 0.67, blue: 0.20),
                                                Color(red: 0.98, green: 0.92, blue: 0.23),
                                                Color(red: 0.26, green: 0.84, blue: 0.48),
                                                Color(red: 0.24, green: 0.69, blue: 1.00),
                                                Color(red: 0.47, green: 0.46, blue: 1.00),
                                                Color(red: 0.86, green: 0.35, blue: 0.95),
                                                Color(red: 1.00, green: 0.36, blue: 0.37)
                                            ],
                                            center: .center
                                        )
                                    )
                            )
                        .overlay(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.42),
                                            Color.white.opacity(0.04)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .padding(1.2)
                                .blendMode(.screen)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.42), lineWidth: 0.9)
                        )
                        .shadow(color: Color(red: 0.71, green: 0.39, blue: 1.00).opacity(0.24), radius: 10, x: 0, y: 4)
                        .shadow(color: Color(red: 0.22, green: 0.71, blue: 1.00).opacity(0.18), radius: 6, x: 0, y: 2)
                    }
                    .padding(.trailing, 18)
                    .padding(.bottom, 12)
                }
            }
            .sheet(isPresented: $viewModel.showPairingView) {
                PairingView(viewModel: viewModel)
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(onComplete: {
                    showOnboarding = false
                    hasLaunchedBefore = true
                })
            }
            .onAppear {
                viewModel.preparePrimaryExperience()
                if !hasLaunchedBefore {
                    showOnboarding = true
                    hasLaunchedBefore = true
                }
            }
            .onChange(of: selectedTab) { _, _ in
                dismissKeyboard()
            }
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if AppBackgroundStylePolicy.usesMutedMistBackground(forDarkMode: colorScheme == .dark) {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.94, blue: 0.96),
                        Color(red: 0.88, green: 0.91, blue: 0.95),
                        Color(red: 0.92, green: 0.93, blue: 0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.56),
                        Color.clear,
                        Color(red: 0.86, green: 0.89, blue: 0.94).opacity(0.24)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Rectangle()
                    .fill(Color.white.opacity(0.24))
                    .blur(radius: 90)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
            }
            .ignoresSafeArea()
        } else {
            LinearGradient(
                colors: [
                    Color(UIColor.systemGroupedBackground),
                    Color(UIColor.secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
    }
}

struct TranscriptCard: View {
    @Binding var transcriptText: String
    @Binding var isFocused: Bool
    let autoScrollVersion: Int
    let isEditable: Bool
    let recognitionState: RecognitionState
    let liveStatusMessage: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            TranscriptTextView(
                text: $transcriptText,
                isFocused: $isFocused,
                autoScrollVersion: autoScrollVersion,
                isEditable: isEditable
            )
            .frame(height: 150)
            .padding(.horizontal, 2)

            if transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if recognitionState != .idle {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(liveStatusMessage ?? String(localized: "transcript_card_live_placeholder"))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                        }
                    } else {
                        Text(String(localized: "transcript_card_placeholder"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 12)
                .padding(.leading, 8)
                .allowsHitTesting(false)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(uiColor: .secondarySystemBackground),
                            Color(uiColor: .tertiarySystemBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrimaryRecognitionPage: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var isTranscriptFocused: Bool
    let onDismissKeyboard: () -> Void
    @State private var showsMacActionAlert = false

    var body: some View {
        ZStack(
            alignment: PrimaryRecognitionLayoutPolicy.recognitionControlAlignment(
                showingTranscriptPreview: viewModel.shouldShowTranscriptPreviewOnHome
            )
        ) {
            RecognitionStatusView(
                state: viewModel.recognitionState,
                statusMessage: viewModel.pushToTalkStatusMessage,
                isEnabled: viewModel.canStartPushToTalk || viewModel.recognitionState != .idle,
                showsPairingAction: false,
                showsReconnectAction: viewModel.shouldPromptForHomeMacAction,
                audioLevel: viewModel.audioLevel,
                onPressChanged: { isPressing in
                    if isPressing {
                        onDismissKeyboard()
                    }
                    viewModel.handlePrimaryButtonPressChanged(isPressing)
                },
                onReconnectAction: {
                    onDismissKeyboard()
                    showsMacActionAlert = true
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            VStack(spacing: 0) {
                if viewModel.shouldShowTranscriptPreviewOnHome {
                    TranscriptCard(
                        transcriptText: Binding(
                            get: { viewModel.localTranscriptText },
                            set: { viewModel.updateLocalTranscriptText($0) }
                        ),
                        isFocused: $isTranscriptFocused,
                        autoScrollVersion: viewModel.transcriptAutoScrollVersion,
                        isEditable: false,
                        recognitionState: viewModel.recognitionState,
                        liveStatusMessage: viewModel.pushToTalkStatusMessage
                    )
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top)
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.96, anchor: .top)),
                            removal: .opacity
                        )
                    )
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: viewModel.shouldShowTranscriptPreviewOnHome)
        .alert(
            String(localized: "home_mac_action_alert_title"),
            isPresented: $showsMacActionAlert
        ) {
            Button(String(localized: "reconnect_button")) {
                viewModel.reconnect()
            }
            Button(String(localized: "home_mac_action_pair_button")) {
                viewModel.openPairing()
            }
            Button(String(localized: "cancel_button"), role: .cancel) {}
        } message: {
            Text(String(localized: "home_mac_action_alert_message"))
        }
    }
}

struct TranscriptHistoryPage: View {
    let canSendToMac: (LocalTranscriptRecord) -> Bool
    let onSendToMac: (LocalTranscriptRecord) -> Void
    let history: [LocalTranscriptRecord]
    let onDelete: (UUID) -> Void
    let onUpdate: (UUID, String) -> Void
    let onDismissKeyboard: () -> Void
    @State private var editingRecordID: UUID?
    @State private var draftText = ""
    @State private var isEditingFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if history.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "transcript_history_empty_title"))
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(String(localized: "transcript_history_empty_hint"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
                .modifier(AppCardSurface())
            } else {
                List {
                    ForEach(history) { record in
                        if editingRecordID == record.id {
                            EditableTranscriptHistoryRow(
                                text: $draftText,
                                isFocused: $isEditingFocused
                            )
                            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                            .listRowBackground(Color(uiColor: .secondarySystemBackground))
                        } else {
                            TranscriptHistoryRow(record: record)
                                .contentShape(Rectangle())
                                .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                                .listRowBackground(Color(uiColor: .secondarySystemBackground))
                                .swipeActions(
                                    edge: TranscriptHistorySendPolicy.swipeEdge,
                                    allowsFullSwipe: TranscriptHistorySendPolicy.allowsFullSwipe
                                ) {
                                    if canSendToMac(record) {
                                        Button {
                                            onSendToMac(record)
                                        } label: {
                                            Label(String(localized: "send_button"), systemImage: "paperplane.fill")
                                        }
                                        .tint(.blue)
                                    }
                                }
                                .swipeActions(
                                    edge: TranscriptHistoryDeletePolicy.swipeEdge,
                                    allowsFullSwipe: TranscriptHistoryDeletePolicy.allowsFullSwipe
                                ) {
                                    Button(role: .destructive) {
                                        onDelete(record.id)
                                    } label: {
                                        Text(String(localized: "delete_button"))
                                    }
                                }
                                .onTapGesture(count: 2) {
                                    saveEditingIfNeeded()
                                    beginEditing(record)
                                }
                                .onTapGesture {
                                    handleNonEditingRowTap()
                                }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .contentMargins(.top, 0, for: .scrollContent)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        onDismissKeyboard()
                    }
                )
            }

            Text(String(localized: "transcript_history_swipe_hint"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    guard TranscriptHistoryEditingPolicy.shouldAutoSaveOnBackgroundTap(
                        isEditing: editingRecordID != nil
                    ) else {
                        return
                    }
                    saveEditingIfNeeded()
                }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onDisappear {
            saveEditingIfNeeded()
        }
    }

    private func beginEditing(_ record: LocalTranscriptRecord) {
        editingRecordID = record.id
        draftText = record.text
        isEditingFocused = true
    }

    private func handleNonEditingRowTap() {
        guard editingRecordID != nil else { return }
        saveEditingIfNeeded()
    }

    private func saveEditingIfNeeded() {
        guard let editingRecordID else { return }
        guard let record = history.first(where: { $0.id == editingRecordID }) else {
            clearEditingState()
            return
        }

        let savedText = TranscriptHistoryEditingPolicy.savedText(
            originalText: record.text,
            draftText: draftText
        )
        if savedText != record.text {
            onUpdate(editingRecordID, savedText)
        }
        clearEditingState()
    }

    private func clearEditingState() {
        editingRecordID = nil
        draftText = ""
        isEditingFocused = false
    }
}

enum TranscriptHistoryDeletePolicy {
    static let swipeEdge: HorizontalEdge = .trailing
    static let usesTrailingSwipe = true
    static let allowsFullSwipe = true
    static let requiresConfirmation = false
}

enum TranscriptHistorySendPolicy {
    static let swipeEdge: HorizontalEdge = .leading
    static let usesLeadingSwipe = true
    static let allowsFullSwipe = false
}

struct TranscriptHistoryRow: View {
    let record: LocalTranscriptRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.text)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = record.text
                    } label: {
                        Label(String(localized: "copy_button"), systemImage: "doc.on.doc")
                    }
                }

            Text(record.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct EditableTranscriptHistoryRow: View {
    @Binding var text: String
    @Binding var isFocused: Bool

    var body: some View {
        TranscriptTextView(
            text: $text,
            isFocused: $isFocused,
            autoScrollVersion: 0,
            isEditable: true
        )
        .frame(minHeight: 132)
        .padding(.vertical, 4)
    }
}

struct ConnectionStatusCard: View {
    let pairingState: PairingState
    let connectionState: ConnectionState
    let reconnectStatusMessage: String?
    let onReconnect: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                Text(statusText)
                    .font(.headline)

                Spacer()

                // 显示重连按钮（仅在已配对但断开连接时）
                if case .paired = pairingState,
                   case .disconnected = connectionState {
                    Button(action: onReconnect) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text(String(localized: "reconnect_button"))
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // 显示加载指示器（连接中）
                if case .connecting = connectionState {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if case .paired(_, let deviceName) = pairingState {
                HStack {
                    Text(String(format: String(localized: "paired_device_format"), deviceName))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            // 显示错误信息
            if case .error(let message) = connectionState {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            if let reconnectStatusMessage,
               case .paired = pairingState {
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
        }
        .padding()
        .modifier(AppCardSurface())
    }

    private var statusColor: Color {
        switch (pairingState, connectionState) {
        case (.unpaired, _):
            return .gray
        case (.paired, .connected):
            return .green
        case (.paired, .connecting):
            return .orange
        case (.paired, .disconnected):
            return .red
        case (.paired, .error):
            return .red
        default:
            return .gray
        }
    }

    private var statusText: String {
        switch (pairingState, connectionState) {
        case (.unpaired, _):
            return String(localized: "connection_status_unpaired")
        case (.paired, .connected):
            return String(localized: "connection_status_connected")
        case (.paired, .connecting):
            return String(localized: "connection_status_connecting")
        case (.paired, .disconnected):
            return String(localized: "connection_status_disconnected")
        case (.paired, .error):
            return String(localized: "connection_status_error")
        default:
            return String(localized: "connection_status_unknown")
        }
    }

    private var reconnectStatusIcon: String {
        switch connectionState {
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
        switch connectionState {
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

struct RecognitionStatusView: View {
    let state: RecognitionState
    let statusMessage: String?
    let isEnabled: Bool
    let showsPairingAction: Bool
    let showsReconnectAction: Bool
    let audioLevel: CGFloat
    let onPressChanged: (Bool) -> Void
    let onReconnectAction: () -> Void

    @State private var isPressing = false
    @State private var hasStartedPressAction = false
    @State private var pendingPressWorkItem: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(buttonBackgroundColor)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Circle()
                            .stroke(buttonBorderColor, lineWidth: isPressing ? 4 : 2)
                    )
                    .scaleEffect(isPressing ? 0.95 : 1)

                Image(systemName: iconName)
                    .font(.system(size: 60))
                    .foregroundColor(iconColor)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isInteractionEnabled else { return }
                        if !isPressing {
                            isPressing = true
                            startPendingPressAction()
                        }
                    }
                    .onEnded { _ in
                        guard isPressing else { return }
                        finishInteraction()
                    }
            )

            Text(statusText)
                .font(.title2)
                .fontWeight(.medium)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if state == .listening {
                WaveformView(level: audioLevel)
                    .frame(height: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private var isInteractionEnabled: Bool {
        RecognitionStatusInteractionPolicy.isInteractionEnabled(
            isEnabled: isEnabled,
            showsReconnectAction: showsReconnectAction
        )
    }

    private func startPendingPressAction() {
        let workItem = DispatchWorkItem {
            guard isPressing else { return }
            if showsReconnectAction {
                onReconnectAction()
                finishInteraction(resetOnly: true)
                return
            }
            guard isEnabled else { return }
            hasStartedPressAction = true
            onPressChanged(true)
        }

        pendingPressWorkItem?.cancel()
        pendingPressWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func finishInteraction(resetOnly: Bool = false) {
        pendingPressWorkItem?.cancel()
        pendingPressWorkItem = nil

        if resetOnly {
            isPressing = false
            hasStartedPressAction = false
            return
        }

        if hasStartedPressAction {
            onPressChanged(false)
        }

        isPressing = false
        hasStartedPressAction = false
    }

    private var iconName: String {
        if showsPairingAction {
            return "speaker.wave.2.fill"
        }
        if showsReconnectAction {
            return "antenna.radiowaves.left.and.right"
        }
        switch state {
        case .idle:
            return "mic.fill"
        case .listening:
            return "waveform"
        case .processing:
            return "waveform.circle"
        case .sending:
            return "arrow.up.circle.fill"
        }
    }

    private var iconColor: Color {
        if showsPairingAction {
            return isEnabled ? .orange : .gray
        }
        if showsReconnectAction {
            return .orange
        }
        switch state {
        case .idle:
            return isEnabled ? .blue : .gray
        case .listening:
            return .white
        case .processing:
            return .blue
        case .sending:
            return .green
        }
    }

    private var statusText: String {
        if showsPairingAction {
            return String(localized: "recognition_pair_now")
        }
        if showsReconnectAction {
            return String(localized: "recognition_mac_unavailable")
        }
        switch state {
        case .idle:
            return isEnabled ? String(localized: "recognition_hold_to_talk") : String(localized: "recognition_ready")
        case .listening:
            return String(localized: "recognition_listening")
        case .processing:
            return String(localized: "recognition_processing")
        case .sending:
            return String(localized: "recognition_sending")
        }
    }

    private var buttonBackgroundColor: Color {
        if showsPairingAction {
            return isEnabled ? Color.orange.opacity(0.18) : Color.gray.opacity(0.12)
        }
        if showsReconnectAction {
            return Color.orange.opacity(0.18)
        }
        switch state {
        case .idle:
            return isEnabled ? Color.blue.opacity(0.15) : Color.gray.opacity(0.12)
        case .listening:
            return .red
        case .processing:
            return Color.blue.opacity(0.15)
        case .sending:
            return Color.green.opacity(0.18)
        }
    }

    private var buttonBorderColor: Color {
        if showsPairingAction {
            return isEnabled ? .orange.opacity(0.6) : .gray.opacity(0.4)
        }
        if showsReconnectAction {
            return .orange.opacity(0.6)
        }
        switch state {
        case .idle:
            return isEnabled ? .blue.opacity(0.5) : .gray.opacity(0.4)
        case .listening:
            return .red.opacity(0.8)
        case .processing:
            return .blue.opacity(0.5)
        case .sending:
            return .green.opacity(0.6)
        }
    }
}

struct WaveformView: View {
    let level: CGFloat

    @State private var smoothedLevel: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geometry in
                let amplitude = max(0.12, min(smoothedLevel * 2.2, 1.4))
                let phase = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let centerY = size.height / 2
                    let width = size.width
                    let particleCount = 40
                    let spacing = width / CGFloat(particleCount - 1)
                    let baseRadius: CGFloat = 2.2

                    for index in 0..<particleCount {
                        let x = CGFloat(index) * spacing
                        let progress = x / width
                        let wave = sin((progress * 8 + phase) * .pi * 2)
                        let wave2 = sin((progress * 3 + phase * 0.7) * .pi * 2) * 0.35
                        let yOffset = (wave + wave2) * amplitude * (size.height * 0.28)
                        let y = centerY + yOffset

                        let intensity = min(1, max(0.2, amplitude))
                        let radius = baseRadius + intensity * 1.8
                        let alpha = 0.25 + intensity * 0.6
                        let hue = 0.55 + 0.08 * sin(phase + Double(progress) * 2)
                        let color = Color(hue: hue, saturation: 0.55, brightness: 0.95).opacity(alpha)

                        let rect = CGRect(
                            x: x - radius,
                            y: y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }
            }
        }
        .onAppear {
            smoothedLevel = level
        }
        .onChange(of: level) { _, newValue in
            withAnimation(.linear(duration: 0.04)) {
                smoothedLevel = newValue
            }
        }
    }
}

struct TranscriptTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let autoScrollVersion: Int
    let isEditable: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textColor = UIColor.label
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 2, bottom: 34, right: 2)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.text = text
        textView.isEditable = isEditable
        textView.isSelectable = true
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        uiView.isEditable = isEditable
        uiView.isSelectable = true

        if TranscriptTextViewSyncPolicy.shouldApplyExternalText(
            currentText: uiView.text,
            newText: text,
            isFirstResponder: uiView.isFirstResponder,
            hasMarkedText: uiView.markedTextRange != nil
        ) {
            uiView.text = text
        }

        if isEditable && isFocused {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        } else if uiView.isFirstResponder && uiView.markedTextRange == nil {
            uiView.resignFirstResponder()
        }

        if context.coordinator.lastAutoScrollVersion != autoScrollVersion {
            context.coordinator.lastAutoScrollVersion = autoScrollVersion
            autoScrollIfNeeded(uiView)
        }
    }

    private func autoScrollIfNeeded(_ uiView: UITextView) {
        uiView.layoutIfNeeded()

        let visibleHeight = uiView.bounds.height - uiView.textContainerInset.top - uiView.textContainerInset.bottom
        let contentHeight = uiView.contentSize.height - uiView.textContainerInset.top - uiView.textContainerInset.bottom

        guard TranscriptAutoScrollPolicy.shouldAutoScroll(
            contentHeight: contentHeight,
            visibleHeight: visibleHeight
        ) else {
            return
        }

        let bottomOffset = max(
            -uiView.adjustedContentInset.top,
            uiView.contentSize.height - uiView.bounds.height + uiView.adjustedContentInset.bottom
        )

        DispatchQueue.main.async {
            uiView.setContentOffset(CGPoint(x: 0, y: bottomOffset), animated: true)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: TranscriptTextView
        var lastAutoScrollVersion: Int

        init(parent: TranscriptTextView) {
            self.parent = parent
            self.lastAutoScrollVersion = parent.autoScrollVersion
        }

        func textViewDidChange(_ textView: UITextView) {
            guard parent.isEditable else { return }
            parent.text = textView.text ?? ""
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            guard parent.isEditable else { return }
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            guard parent.isEditable else { return }
            parent.isFocused = false
        }
    }
}
