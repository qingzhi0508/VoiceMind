import Foundation
import SwiftUI
import Combine
import StoreKit
import SharedCore
import UIKit

class ContentViewModel: ObservableObject {
    @Published var pairingState: PairingState = .unpaired
    @Published var connectionState: ConnectionState = .disconnected
    @Published var recognitionState: RecognitionState = .idle
    @Published var discoveredServices: [DiscoveredService] = []
    @Published var selectedLanguage: String = "zh-CN"
    @Published var showPairingView = false
    @Published var latestPairingFeedback: String?
    @Published var reconnectStatusMessage: String?
    @Published var pushToTalkStatusMessage: String?
    @Published var inboundDataRecords: [InboundDataRecord] = []
    @Published var reconnectNeedsManualAction = false
    @Published var audioLevel: CGFloat = 0
    @Published var localTranscriptText: String = ""
    @Published var localTranscriptHistory: [LocalTranscriptRecord] = []
    @Published var transcriptAutoScrollVersion: Int = 0
    @Published var showsTranscriptActions: Bool = false
    @Published var textInputDraft: String = ""
    var isLastRecognitionLocal: Bool = false
    var preRecognitionCommittedText: String = ""
    @Published private(set) var twoDeviceSyncAccessState: TwoDeviceSyncAccessState = .limited(
        remaining: TwoDeviceSyncPolicy.defaultFreeSessionLimit,
        used: 0
    )
    @Published var preferredHomeTranscriptionMode: HomeTranscriptionMode {
        didSet {
            UserDefaults.standard.set(
                preferredHomeTranscriptionMode.rawValue,
                forKey: preferredHomeTranscriptionModeKey
            )
            if recognitionState == .idle {
                refreshIdleStatusMessage()
            }
        }
    }
    @Published var sendResultsToMacEnabled: Bool {
        didSet {
            UserDefaults.standard.set(sendResultsToMacEnabled, forKey: sendResultsToMacEnabledKey)
            if !sendResultsToMacEnabled {
                bonjourBrowser.stop()
                discoveredServices = []
                connectionManager.disconnect()
                reconnectStatusMessage = nil
                latestPairingFeedback = nil
                reconnectNeedsManualAction = false
                connectionState = .disconnected
                if recognitionState == .idle {
                    refreshIdleStatusMessage()
                }
            } else {
                bonjourBrowser.start()
                if LocalTranscriptionPolicy.shouldAutoReconnectToMac(
                    sendToMacEnabled: sendResultsToMacEnabled,
                    pairingState: pairingState
                ), connectionState == .disconnected {
                reconnectToPairedDevice()
                } else if recognitionState == .idle {
                    refreshIdleStatusMessage()
                }
            }
        }
    }

    private let lastKnownHostKey = "voicerelay.lastKnownHost"
    private let lastKnownPortKey = "voicerelay.lastKnownPort"
    private let lastKnownDeviceNameKey = "voicerelay.lastKnownDeviceName"
    private let sendResultsToMacEnabledKey = "voicemind.sendResultsToMacEnabled"
    private let localTranscriptHistoryKey = "voicemind.localTranscriptHistory"
    private let preferredHomeTranscriptionModeKey = "voicemind.preferredHomeTranscriptionMode"

    private let connectionManager = ConnectionManager()
    private let speechController = SpeechController()
    private let audioStreamController: AudioStreamController
    private let bonjourBrowser = BonjourBrowser()
    private let purchaseStore = TwoDeviceSyncPurchaseStore.shared
    private let usageLimiter = TwoDeviceSyncUsageLimiter()
    private var cancellables = Set<AnyCancellable>()

    private var currentSessionId: String?
    private var manualSessionId: String?
    private var lastKeywordSessionId: String?
    private var activeInputMode: ActiveInputMode?
    private var committedTranscriptText: String = ""
    private var liveTranscriptText: String = ""

    private enum ActiveInputMode {
        case localRecognition
        case streamingToMac
    }

    private func localized(_ key: String, _ args: CVarArg...) -> String {
        if args.isEmpty {
            return String(localized: .init(key))
        }
        return String(format: String(localized: .init(key)), arguments: args)
    }

    init(audioStreamController: AudioStreamController = AudioStreamController()) {
        self.audioStreamController = audioStreamController
        self.sendResultsToMacEnabled = UserDefaults.standard.bool(forKey: sendResultsToMacEnabledKey)
        self.localTranscriptHistory = Self.loadLocalTranscriptHistory(forKey: localTranscriptHistoryKey)
        self.preferredHomeTranscriptionMode = HomeTranscriptionMode(
            rawValue: UserDefaults.standard.string(forKey: preferredHomeTranscriptionModeKey) ?? ""
        ) ?? .local
        connectionManager.delegate = self
        speechController.delegate = self
        audioStreamController.delegate = self
        bonjourBrowser.delegate = self

        // Load pairing state
        pairingState = connectionManager.pairingState
        bindTwoDeviceSyncState()

        if LocalTranscriptionPolicy.shouldStartBonjourBrowsing(sendToMacEnabled: sendResultsToMacEnabled) {
            bonjourBrowser.start()
        }

        if LocalTranscriptionPolicy.shouldAutoReconnectToMac(
            sendToMacEnabled: sendResultsToMacEnabled,
            pairingState: pairingState
        ) {
            reconnectToPairedDevice()
        }

        refreshIdleStatusMessage()
        Task { [weak self] in
            await self?.refreshTwoDeviceSyncBillingState()
        }
    }

    func preparePrimaryExperience() {
        refreshIdleStatusMessage()
        guard !checkPermissions() else { return }
        requestPermissions { [weak self] _ in
            self?.refreshIdleStatusMessage()
        }
    }

    func pair(with service: DiscoveredService, code: String) {
        print("📱 ContentViewModel.pair 被调用")
        print("   服务: \(service.name) (\(service.host):\(service.port))")
        print("   配对码: \(code)")
        latestPairingFeedback = nil
        appendInboundDataRecord(
            title: localized("log_title_pairing_start"),
            detail: localized(
                "log_detail_pairing_start_format",
                service.name,
                service.host,
                "\(service.port)",
                code
            ),
            category: .pairing
        )
        saveLastKnownConnection(host: service.host, port: service.port, deviceName: service.name)
        connectionManager.pair(with: service, code: code)
    }

    func unpair() {
        connectionManager.disconnect()
        manualSessionId = nil
        connectionManager.unpair()
        pairingState = .unpaired
        connectionState = .disconnected
        recognitionState = .idle
        reconnectStatusMessage = nil
        pushToTalkStatusMessage = nil
        reconnectNeedsManualAction = false
    }

    func reconnect() {
        print("🔄 手动重连")
        reconnectNeedsManualAction = false
        latestPairingFeedback = localized("reconnect_trying")
        reconnectStatusMessage = localized("reconnect_searching")
        appendInboundDataRecord(
            title: localized("log_title_manual_reconnect"),
            detail: localized("log_detail_manual_reconnect"),
            category: .connection
        )
        connectionManager.disconnect()
        reconnectToPairedDevice()
    }

    func openPairing() {
        showPairingView = true
    }

    func connectToMac(ip: String, port: UInt16, deviceName: String? = nil) {
        latestPairingFeedback = nil
        appendInboundDataRecord(
            title: localized("log_title_direct_connect"),
            detail: localized(
                "log_detail_direct_connect_format",
                ip,
                "\(port)",
                deviceName ?? localized("connection_status_unknown")
            ),
            category: .connection
        )
        saveLastKnownConnection(host: ip, port: port, deviceName: deviceName)
        connectionManager.connectDirectly(ip: ip, port: port)
    }

    func pairWithCode(_ code: String, deviceName: String? = nil) {
        latestPairingFeedback = nil
        appendInboundDataRecord(
            title: localized("log_title_submit_pairing_code"),
            detail: localized(
                "log_detail_submit_pairing_code_format",
                deviceName ?? lastKnownDeviceName ?? localized("connection_status_unknown"),
                code
            ),
            category: .pairing
        )
        connectionManager.setPendingPairingDeviceName(deviceName ?? lastKnownDeviceName)
        connectionManager.pairWithCode(code)
    }

    func clearPairingFeedback() {
        latestPairingFeedback = nil
    }

    func updateLanguage(_ language: String) {
        selectedLanguage = language
        speechController.selectedLanguage = language
    }

    func updateLocalTranscriptText(_ text: String) {
        localTranscriptText = text
        if recognitionState == .idle {
            committedTranscriptText = text
            liveTranscriptText = ""
        }
    }

    private var shouldPlayThroughMacSpeakerOnMac: Bool {
        MacMicrophoneMonitorPolicy.shouldPlayThroughMacSpeaker(
            preferredMode: effectiveHomeTranscriptionMode
        )
    }

    func startPushToTalk() {
        guard canStartPushToTalk else { return }
        showsTranscriptActions = false
        let clearedTranscriptText = LocalTranscriptHistory.beginningNewRecognitionSession(
            from: localTranscriptText
        )
        committedTranscriptText = clearedTranscriptText
        liveTranscriptText = ""
        localTranscriptText = clearedTranscriptText

        if effectiveHomeTranscriptionMode == .mac || effectiveHomeTranscriptionMode == .microphone {
            guard shouldForwardResultToMac else {
                pushToTalkStatusMessage = localized("ptt_connect_to_talk")
                return
            }
            guard authorizeTwoDeviceSyncSessionIfNeeded() else {
                return
            }

            do {
                let sessionId = UUID().uuidString
                manualSessionId = sessionId
                activeInputMode = .streamingToMac
                try audioStreamController.startStreaming(
                    sessionId: sessionId,
                    playThroughMacSpeaker: shouldPlayThroughMacSpeakerOnMac
                )
                recognitionState = .listening
                pushToTalkStatusMessage = localized("ptt_warming_up")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    guard let self, self.manualSessionId == sessionId, self.recognitionState == .listening else { return }
                    self.pushToTalkStatusMessage = self.localized("ptt_capturing")
                    self.triggerHaptic()
                    self.triggerNotificationHaptic()
                }
            } catch {
                recognitionState = .idle
                manualSessionId = nil
                activeInputMode = nil
                pushToTalkStatusMessage = error.localizedDescription
            }
            return
        }

        do {
            manualSessionId = try speechController.startManualListening()
            activeInputMode = .localRecognition
            pushToTalkStatusMessage = localized("ptt_local_recording")
        } catch {
            recognitionState = .idle
            manualSessionId = nil
            activeInputMode = nil
            pushToTalkStatusMessage = error.localizedDescription
        }
    }

    func stopPushToTalk() {
        guard recognitionState == .listening else { return }
        switch activeInputMode {
        case .streamingToMac:
            recognitionState = .sending
            pushToTalkStatusMessage = localized("ptt_sending_audio")
            audioStreamController.stopStreaming()
        case .localRecognition:
            speechController.stopListening()
        case nil:
            break
        }
    }

    var canStartPushToTalk: Bool {
        LocalTranscriptionPolicy.canStartPrimaryCapture(
            recognitionState: recognitionState,
            hasPermissions: checkPermissions(),
            sendToMacEnabled: sendResultsToMacEnabled,
            preferredMode: preferredHomeTranscriptionMode,
            pairingState: pairingState,
            connectionState: connectionState
        )
    }

    var canManuallyReconnectFromPrimaryButton: Bool {
        if case .paired = pairingState {
            return reconnectNeedsManualAction && recognitionState == .idle
        }
        return false
    }

    var canOpenPairingFromPrimaryButton: Bool {
        return false
    }

    func handlePrimaryButtonPressChanged(_ isPressing: Bool) {
        if isPressing {
            startPushToTalk()
        } else {
            stopPushToTalk()
        }
    }

    @MainActor
    private lazy var impactGenerator = UIImpactFeedbackGenerator(style: .medium)

    @MainActor
    private lazy var notificationGenerator = UINotificationFeedbackGenerator()

    private func triggerHaptic() {
        DispatchQueue.main.async {
            self.impactGenerator.prepare()
            self.impactGenerator.impactOccurred(intensity: 1.0)
        }
    }

    private func triggerNotificationHaptic() {
        DispatchQueue.main.async {
            self.notificationGenerator.prepare()
            self.notificationGenerator.notificationOccurred(.success)
        }
    }

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        speechController.requestPermissions { [weak self] granted in
            self?.refreshIdleStatusMessage()
            completion(granted)
        }
    }

    func checkPermissions() -> Bool {
        return speechController.checkPermissions()
    }

    var shouldShowMacConnectionCard: Bool {
        false
    }

    var canShowHomeTranscriptionModeToggle: Bool {
        sendResultsToMacEnabled
    }

    var effectiveHomeTranscriptionMode: HomeTranscriptionMode {
        LocalTranscriptionPolicy.effectiveHomeTranscriptionMode(
            sendToMacEnabled: sendResultsToMacEnabled,
            preferredMode: preferredHomeTranscriptionMode
        )
    }

    var shouldShowTranscriptPreviewOnHome: Bool {
        LocalTranscriptionPolicy.shouldShowTranscriptPreviewOnHome(
            mode: effectiveHomeTranscriptionMode,
            recognitionState: recognitionState,
            transcriptText: localTranscriptText
        )
    }

    var shouldPromptForHomeMacAction: Bool {
        LocalTranscriptionPolicy.shouldPromptForHomeMacAction(
            sendToMacEnabled: sendResultsToMacEnabled,
            preferredMode: preferredHomeTranscriptionMode,
            pairingState: pairingState,
            connectionState: connectionState
        )
    }

    private var isPaired: Bool {
        if case .paired = pairingState {
            return true
        }
        return false
    }

    private var shouldForwardResultToMac: Bool {
        if _testShouldForwardResultToMac { return true }
        return LocalTranscriptionPolicy.shouldForwardResultToMac(
            sendToMacEnabled: sendResultsToMacEnabled,
            preferredMode: preferredHomeTranscriptionMode,
            pairingState: pairingState,
            connectionState: connectionState
        )
    }

    var shouldShowMacPairingOptions: Bool {
        LocalTranscriptionPolicy.shouldShowMacPairingOptions(sendToMacEnabled: sendResultsToMacEnabled)
    }

    var canManuallyForwardCurrentTextToMac: Bool {
        guard effectiveHomeTranscriptionMode == .local else { return false }
        return LocalTranscriptionPolicy.canManuallyForwardTextToMac(
            sendToMacEnabled: sendResultsToMacEnabled,
            pairingState: pairingState,
            connectionState: connectionState,
            transcriptText: localTranscriptText
        )
    }

    var canSendTextInput: Bool {
        LocalTranscriptionPolicy.canSendTextInput(
            sendToMacEnabled: sendResultsToMacEnabled,
            pairingState: pairingState,
            connectionState: connectionState,
            transcriptText: textInputDraft
        )
    }

    func sendTextInputToMac() {
        let trimmedText = textInputDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        guard canSendTextInput else {
            pushToTalkStatusMessage = localized("ptt_text_input_requires_mac")
            return
        }

        preRecognitionCommittedText = committedTranscriptText

        let sessionId = sendTranscriptTextToMac(trimmedText, language: selectedLanguage)

        committedTranscriptText = LocalTranscriptHistory.appendingLatestTranscript(
            trimmedText, to: committedTranscriptText
        )
        liveTranscriptText = ""
        localTranscriptText = committedTranscriptText
        textInputDraft = ""

        showsTranscriptActions = true
        isLastRecognitionLocal = false
        lastKeywordSessionId = sessionId
        transcriptAutoScrollVersion += 1
        appendLocalTranscriptRecord(text: trimmedText, language: selectedLanguage)
        pushToTalkStatusMessage = localized("ptt_text_input_sent")
    }

    func toggleHomeTranscriptionMode() {
        guard sendResultsToMacEnabled else {
            preferredHomeTranscriptionMode = .local
            return
        }

        switch preferredHomeTranscriptionMode {
        case .local: preferredHomeTranscriptionMode = .mac
        case .mac: preferredHomeTranscriptionMode = .microphone
        case .microphone: preferredHomeTranscriptionMode = .textInput
        case .textInput: preferredHomeTranscriptionMode = .local
        }
    }

    func setHomeTranscriptionMode(_ mode: HomeTranscriptionMode) {
        preferredHomeTranscriptionMode = mode
    }

    func sendCurrentTranscriptToMac() {
        let trimmedText = localTranscriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        guard canManuallyForwardCurrentTextToMac else {
            pushToTalkStatusMessage = localized("ptt_manual_send_requires_mac")
            return
        }

        sendTranscriptTextToMac(
            trimmedText,
            language: selectedLanguage
        )
    }

    func canSendTranscriptRecordToMac(_ record: LocalTranscriptRecord) -> Bool {
        LocalTranscriptionPolicy.canManuallyForwardTextToMac(
            sendToMacEnabled: sendResultsToMacEnabled,
            pairingState: pairingState,
            connectionState: connectionState,
            transcriptText: record.text
        )
    }

    func sendTranscriptRecordToMac(_ record: LocalTranscriptRecord) {
        guard canSendTranscriptRecordToMac(record) else {
            pushToTalkStatusMessage = localized("ptt_manual_send_requires_mac")
            return
        }

        sendTranscriptTextToMac(
            record.text.trimmingCharacters(in: .whitespacesAndNewlines),
            language: record.language
        )
    }

    @discardableResult
    private func sendTranscriptTextToMac(
        _ text: String,
        language: String
    ) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return "" }
        guard authorizeTwoDeviceSyncSessionIfNeeded() else { return "" }

        let sessionId = UUID().uuidString
        let payload = TextMessagePayload(
            sessionId: sessionId,
            text: trimmedText,
            language: language
        )

        guard let payloadData = try? JSONEncoder().encode(payload) else { return sessionId }

        let timestamp = Date()
        let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
            type: .textMessage,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId
        )

        let envelope = MessageEnvelope(
            type: .textMessage,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId,
            hmac: hmac
        )

        connectionManager.send(envelope)
        recordSuccessfulTwoDeviceSyncSession()
        pushToTalkStatusMessage = localized("ptt_manual_send_success")
        appendInboundDataRecord(
            title: localized("log_manual_send_title"),
            detail: localized("log_manual_send_detail_format", sessionId, language, trimmedText),
            category: .voice
        )
        return sessionId
    }

    private func reconnectToPairedDevice() {
        // Find the paired device in discovered services
        guard case .paired(_, let deviceName) = pairingState else {
            print("⚠️ 无法重连: 未配对")
            return
        }

        print("🔍 查找已配对的设备: \(deviceName)")

        if let service = discoveredServices.first(where: { $0.name == deviceName }) {
            print("✅ 找到设备，开始连接: \(service.host):\(service.port)")
            latestPairingFeedback = localized("reconnect_found_format", service.name)
            reconnectStatusMessage = localized("reconnect_found_format", service.name)
            appendInboundDataRecord(
                title: localized("log_title_paired_device_found"),
                detail: localized(
                    "log_detail_paired_device_found_format",
                    service.name,
                    service.host,
                    "\(service.port)"
                ),
                category: .connection
            )
            connectionManager.connect(to: service)
        } else if let lastKnownHost,
                  let lastKnownPort {
            print("📡 未找到 Bonjour 服务，回退到上次已知地址: \(lastKnownHost):\(lastKnownPort)")
            latestPairingFeedback = localized("reconnect_no_bonjour")
            reconnectStatusMessage = localized("reconnect_fallback")
            appendInboundDataRecord(
                title: localized("log_title_fallback_direct"),
                detail: localized(
                    "log_detail_fallback_direct_format",
                    lastKnownHost,
                    "\(lastKnownPort)"
                ),
                category: .connection,
                severity: .warning
            )
            connectionManager.connectDirectly(ip: lastKnownHost, port: lastKnownPort)
        } else {
            print("⚠️ 未找到已配对的设备，等待 Bonjour 发现...")
            latestPairingFeedback = localized("reconnect_not_found")
            reconnectStatusMessage = localized("reconnect_not_found")
            appendInboundDataRecord(
                title: localized("log_title_no_paired_device"),
                detail: localized("log_detail_no_paired_device"),
                category: .connection,
                severity: .warning
            )
        }
    }

    private var lastKnownHost: String? {
        UserDefaults.standard.string(forKey: lastKnownHostKey)
    }

    private var lastKnownPort: UInt16? {
        let port = UserDefaults.standard.integer(forKey: lastKnownPortKey)
        return port > 0 ? UInt16(port) : nil
    }

    private var lastKnownDeviceName: String? {
        UserDefaults.standard.string(forKey: lastKnownDeviceNameKey)
    }

    private func saveLastKnownConnection(host: String, port: UInt16, deviceName: String?) {
        UserDefaults.standard.set(host, forKey: lastKnownHostKey)
        UserDefaults.standard.set(Int(port), forKey: lastKnownPortKey)
        if let deviceName, !deviceName.isEmpty {
            UserDefaults.standard.set(deviceName, forKey: lastKnownDeviceNameKey)
        }
    }

    func clearInboundDataRecords() {
        inboundDataRecords.removeAll()
    }

    func clearLocalTranscriptHistory() {
        localTranscriptHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: localTranscriptHistoryKey)
    }

    func removeLocalTranscriptRecord(id: UUID) {
        localTranscriptHistory = LocalTranscriptHistory.removing(id: id, from: localTranscriptHistory)
        Self.saveLocalTranscriptHistory(localTranscriptHistory, forKey: localTranscriptHistoryKey)
    }

    func removeLocalTranscriptRecords(ids: Set<UUID>) {
        localTranscriptHistory = LocalTranscriptHistory.removing(ids: ids, from: localTranscriptHistory)
        Self.saveLocalTranscriptHistory(localTranscriptHistory, forKey: localTranscriptHistoryKey)
    }

    func updateLocalTranscriptRecord(id: UUID, text: String) {
        localTranscriptHistory = LocalTranscriptHistory.updating(id: id, text: text, in: localTranscriptHistory)
        Self.saveLocalTranscriptHistory(localTranscriptHistory, forKey: localTranscriptHistoryKey)
    }

    private func appendInboundDataRecord(
        title: String,
        detail: String,
        category: InboundDataCategory,
        severity: InboundDataSeverity = .info
    ) {
        let record = InboundDataRecord(
            timestamp: Date(),
            title: title,
            detail: detail,
            category: category,
            severity: severity
        )
        inboundDataRecords.insert(record, at: 0)

        if inboundDataRecords.count > 200 {
            inboundDataRecords = Array(inboundDataRecords.prefix(200))
        }
    }

    private func refreshIdleStatusMessage() {
        guard recognitionState == .idle else { return }
        let key = LocalTranscriptionPolicy.idleStatusMessageKey(
            hasPermissions: checkPermissions(),
            sendToMacEnabled: sendResultsToMacEnabled,
            preferredMode: preferredHomeTranscriptionMode,
            pairingState: pairingState,
            connectionState: connectionState
        )
        pushToTalkStatusMessage = localized(key)
    }

    func refreshTwoDeviceSyncBillingState() async {
        await purchaseStore.prepare()
        syncTwoDeviceSyncAccessState()
    }

    func purchaseTwoDeviceSync(_ kind: TwoDeviceSyncProductKind) async {
        _ = await purchaseStore.purchase(kind)
        syncTwoDeviceSyncAccessState()
    }

    func restoreTwoDeviceSyncPurchases() async {
        await purchaseStore.restorePurchases()
        syncTwoDeviceSyncAccessState()
    }

    var twoDeviceSyncStatusText: String {
        switch twoDeviceSyncAccessState {
        case .unlimited:
            return localized("billing_two_device_sync_status_unlimited")
        case .limited(let remaining, _):
            return localized("billing_two_device_sync_status_limited_format", remaining)
        case .blocked(let limit):
            return localized("billing_two_device_sync_status_blocked_format", limit)
        }
    }

    var twoDeviceSyncDetailText: String {
        switch twoDeviceSyncAccessState {
        case .unlimited:
            return localized("billing_two_device_sync_detail_unlimited")
        case .limited(_, let used):
            return localized(
                "billing_two_device_sync_detail_limited_format",
                used,
                TwoDeviceSyncPolicy.defaultFreeSessionLimit
            )
        case .blocked(let limit):
            return localized("billing_two_device_sync_detail_blocked_format", limit)
        }
    }

    var activeTwoDeviceSyncEntitlement: TwoDeviceSyncEntitlement {
        purchaseStore.entitlement
    }

    var activeTwoDeviceSyncExpirationDate: Date? {
        purchaseStore.entitlementExpirationDate
    }

    var twoDeviceSyncValidityText: String? {
        let key = SettingsMembershipValidityPolicy.description(
            entitlement: activeTwoDeviceSyncEntitlement,
            expirationDate: activeTwoDeviceSyncExpirationDate,
            formattedDate: formattedTwoDeviceSyncExpirationDate
        )

        guard let key else { return nil }

        switch key {
        case "billing_two_device_sync_validity_lifetime":
            return localized(key)
        case "billing_two_device_sync_validity_until_format":
            guard let formattedTwoDeviceSyncExpirationDate else { return nil }
            return localized(key, formattedTwoDeviceSyncExpirationDate)
        default:
            return nil
        }
    }

    var twoDeviceSyncProducts: [String: String] {
        Dictionary(
            uniqueKeysWithValues: TwoDeviceSyncProductKind.allCases.compactMap { kind in
                guard let price = purchaseStore.displayPrice(for: kind) else {
                    return nil
                }

                return (kind.rawValue, price)
            }
        )
    }

    var isPurchasingTwoDeviceSync: Bool {
        purchaseStore.activePurchaseProductID != nil
    }

    var activeTwoDeviceSyncPurchaseProductID: String? {
        purchaseStore.activePurchaseProductID
    }

    var isRestoringTwoDeviceSyncPurchases: Bool {
        purchaseStore.isRestoringPurchases
    }

    var purchaseErrorMessage: String? {
        purchaseStore.lastErrorMessage
    }

    private var formattedTwoDeviceSyncExpirationDate: String? {
        guard let activeTwoDeviceSyncExpirationDate else { return nil }
        return activeTwoDeviceSyncExpirationDate.formatted(
            Date.FormatStyle(date: .numeric, time: .omitted)
        )
    }

    private func appendLocalTranscriptRecord(text: String, language: String) {
        localTranscriptHistory = LocalTranscriptHistory.appending(
            text: text,
            language: language,
            to: localTranscriptHistory
        )
        Self.saveLocalTranscriptHistory(localTranscriptHistory, forKey: localTranscriptHistoryKey)
    }

    private static func loadLocalTranscriptHistory(forKey key: String) -> [LocalTranscriptRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let history = try? JSONDecoder().decode([LocalTranscriptRecord].self, from: data) else {
            return []
        }
        return history
    }

    private static func saveLocalTranscriptHistory(_ history: [LocalTranscriptRecord], forKey key: String) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func bindTwoDeviceSyncState() {
        purchaseStore.$entitlement
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncTwoDeviceSyncAccessState()
            }
            .store(in: &cancellables)
    }

    private func syncTwoDeviceSyncAccessState() {
        twoDeviceSyncAccessState = usageLimiter.accessState(entitlement: purchaseStore.entitlement)
    }

    private func authorizeTwoDeviceSyncSessionIfNeeded() -> Bool {
        syncTwoDeviceSyncAccessState()

        guard case .blocked = twoDeviceSyncAccessState else {
            return true
        }

        pushToTalkStatusMessage = localized("billing_two_device_sync_limit_reached")
        return false
    }

    private func recordSuccessfulTwoDeviceSyncSession() {
        do {
            _ = try usageLimiter.recordSuccessfulSession(entitlement: purchaseStore.entitlement)
            syncTwoDeviceSyncAccessState()
        } catch {
            pushToTalkStatusMessage = error.localizedDescription
        }
    }

    // MARK: - Transcript Actions (确认/撤销)

    func confirmTranscriptAction() {
        if isLastRecognitionLocal {
            // 本地识别 + 已转发到 Mac：发送确认到 Mac
            if shouldForwardResultToMac && lastKeywordSessionId != nil {
                sendKeywordAction(.confirm)
            }
            // 本地识别：确认后保留文字，只隐藏按钮
            showsTranscriptActions = false
            isLastRecognitionLocal = false
            lastKeywordSessionId = nil
            refreshIdleStatusMessage()
        } else {
            // 远端识别：发送确认到 Mac，保留文字
            sendKeywordAction(.confirm)
            showsTranscriptActions = false
            lastKeywordSessionId = nil
            refreshIdleStatusMessage()
        }
    }

    func undoTranscriptAction() {
        if isLastRecognitionLocal {
            // 本地识别 + 已转发到 Mac：发送撤销到 Mac
            if shouldForwardResultToMac && lastKeywordSessionId != nil {
                sendKeywordAction(.undo)
            }
            // 本地识别：撤销后恢复到识别前的文字
            showsTranscriptActions = false
            isLastRecognitionLocal = false
            committedTranscriptText = preRecognitionCommittedText
            liveTranscriptText = ""
            localTranscriptText = preRecognitionCommittedText
            preRecognitionCommittedText = ""
            lastKeywordSessionId = nil
            refreshIdleStatusMessage()
        } else {
            // 远端识别：发送撤销到 Mac，恢复到识别前的文字
            sendKeywordAction(.undo)
            showsTranscriptActions = false
            committedTranscriptText = preRecognitionCommittedText
            liveTranscriptText = ""
            localTranscriptText = preRecognitionCommittedText
            preRecognitionCommittedText = ""
            lastKeywordSessionId = nil
            refreshIdleStatusMessage()
        }
    }

    private func sendKeywordAction(_ action: KeywordAction) {
        _testLastSentKeywordAction = action
        let sessionId = lastKeywordSessionId ?? UUID().uuidString
        let payload = KeywordPayload(action: action, sessionId: sessionId)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let timestamp = Date()
        let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
            type: .keyword,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId
        )

        let envelope = MessageEnvelope(
            type: .keyword,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId,
            hmac: hmac
        )

        connectionManager.send(envelope)
    }

    private func clearTranscriptActions() {
        showsTranscriptActions = false
        committedTranscriptText = ""
        liveTranscriptText = ""
        localTranscriptText = ""
        lastKeywordSessionId = nil
        refreshIdleStatusMessage()
    }

    // MARK: - Test Helpers

    func simulateMacResult(_ payload: ResultPayload) {
        let trimmed = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        preRecognitionCommittedText = committedTranscriptText
        committedTranscriptText = LocalTranscriptHistory.appendingLatestTranscript(
            trimmed, to: committedTranscriptText
        )
        liveTranscriptText = ""
        localTranscriptText = committedTranscriptText
        showsTranscriptActions = true
        isLastRecognitionLocal = false
        lastKeywordSessionId = payload.sessionId
    }

    func simulateLocalResult(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        preRecognitionCommittedText = committedTranscriptText
        committedTranscriptText = LocalTranscriptHistory.appendingLatestTranscript(
            trimmed, to: committedTranscriptText
        )
        liveTranscriptText = ""
        localTranscriptText = committedTranscriptText
        showsTranscriptActions = true
        isLastRecognitionLocal = true
    }

    func resetTranscriptActionsForNewRecording() {
        showsTranscriptActions = false
    }

    /// 测试用：模拟本地识别结果并转发到 Mac（设置 sessionId + forward 标记）
    func simulateLocalResultWithForward(_ text: String, sessionId: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        preRecognitionCommittedText = committedTranscriptText
        committedTranscriptText = LocalTranscriptHistory.appendingLatestTranscript(
            trimmed, to: committedTranscriptText
        )
        liveTranscriptText = ""
        localTranscriptText = committedTranscriptText
        showsTranscriptActions = true
        isLastRecognitionLocal = true
        lastKeywordSessionId = sessionId
        _testShouldForwardResultToMac = true
    }

    /// 测试用：模拟文字输入发送
    func simulateTextInputSent(_ text: String, sessionId: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        preRecognitionCommittedText = committedTranscriptText
        committedTranscriptText = LocalTranscriptHistory.appendingLatestTranscript(
            trimmed, to: committedTranscriptText
        )
        liveTranscriptText = ""
        localTranscriptText = committedTranscriptText
        textInputDraft = ""
        showsTranscriptActions = true
        isLastRecognitionLocal = false
        lastKeywordSessionId = sessionId
    }

    /// 测试用：记录最近发送的 keyword action
    private(set) var _testLastSentKeywordAction: KeywordAction?

    /// 测试用：强制控制 shouldForwardResultToMac 的返回值
    private var _testShouldForwardResultToMac: Bool = false
}

extension ContentViewModel: ConnectionManagerDelegate {
    func connectionManager(_ manager: ConnectionManager, didChangePairingState state: PairingState) {
        DispatchQueue.main.async {
            self.pairingState = state

            if case .paired = state {
                self.reconnectNeedsManualAction = false
                self.latestPairingFeedback = self.localized("pairing_confirmed_binding")
                self.appendInboundDataRecord(
                    title: self.localized("log_pairing_success_title"),
                    detail: self.localized("log_pairing_success_detail"),
                    category: .pairing
                )
                self.showPairingView = false
                // 配对成功后不需要重连，因为连接已经存在
                // 只有在连接断开的情况下才需要重连
                if self.connectionState == .disconnected {
                    print("🔄 配对成功但连接已断开，尝试重连")
                    self.reconnectToPairedDevice()
                } else {
                    print("✅ 配对成功，保持现有连接")
                }
            }
        }
    }

    func connectionManager(_ manager: ConnectionManager, didChangeConnectionState state: ConnectionState) {
        DispatchQueue.main.async {
            self.connectionState = state

            switch state {
            case .connecting:
                self.reconnectNeedsManualAction = false
                self.appendInboundDataRecord(
                    title: self.localized("log_connecting_title"),
                    detail: self.localized("log_connecting_detail"),
                    category: .connection
                )
                if self.reconnectStatusMessage != nil {
                    self.reconnectStatusMessage = self.reconnectStatusMessage ?? self.localized("reconnect_connecting")
                }
            case .connected:
                self.reconnectNeedsManualAction = false
                self.appendInboundDataRecord(
                    title: self.localized("log_connected_title"),
                    detail: self.localized("log_connected_detail"),
                    category: .connection
                )
                self.reconnectStatusMessage = self.localized("reconnect_success")
                if self.recognitionState == .idle {
                    self.refreshIdleStatusMessage()
                }
            case .error(let message):
                if message.contains(self.localized("reconnect_exhausted_snippet")) {
                    self.reconnectNeedsManualAction = true
                }
                self.appendInboundDataRecord(
                    title: self.localized("log_connection_failed_title"),
                    detail: message,
                    category: .connection,
                    severity: .error
                )
                if self.reconnectStatusMessage != nil {
                    self.reconnectStatusMessage = self.localized("reconnect_failed_format", message)
                }
            case .disconnected:
                if case .paired = self.pairingState, !self.reconnectNeedsManualAction {
                    self.reconnectStatusMessage = self.localized("reconnect_waiting")
                }
                self.appendInboundDataRecord(
                    title: self.localized("log_disconnected_title"),
                    detail: self.localized("log_disconnected_detail"),
                    category: .connection,
                    severity: .warning
                )
                if self.recognitionState == .listening, self.activeInputMode == .streamingToMac {
                    self.pushToTalkStatusMessage = self.localized("ptt_connection_lost")
                    self.recognitionState = .idle
                    self.manualSessionId = nil
                    self.activeInputMode = nil
                    self.audioStreamController.stopStreaming()
                } else if self.reconnectNeedsManualAction, self.sendResultsToMacEnabled {
                    self.pushToTalkStatusMessage = self.localized("ptt_hold_to_reconnect")
                } else if self.recognitionState == .idle {
                    self.refreshIdleStatusMessage()
                }
                if LocalTranscriptionPolicy.shouldRetryReconnectOnDisconnect(
                    sendToMacEnabled: self.sendResultsToMacEnabled,
                    pairingState: self.pairingState,
                    reconnectNeedsManualAction: self.reconnectNeedsManualAction
                ) {
                    self.reconnectToPairedDevice()
                }
            }
        }
    }

    func connectionManager(_ manager: ConnectionManager, didReceiveMessage envelope: MessageEnvelope) {
        switch envelope.type {
        case .startListen:
            handleStartListen(envelope)
        case .stopListen:
            handleStopListen(envelope)
        case .result:
            handleMacRecognitionResult(envelope)
        case .partialResult:
            handleMacPartialResult(envelope)
        case .error:
            handleRemoteError(envelope)
        default:
            break
        }
    }

    private func handleStartListen(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(StartListenPayload.self, from: envelope.payload) else {
            return
        }

        print("🎤 收到 startListen 消息，使用音频流模式")
        currentSessionId = payload.sessionId

        // 使用音频流模式（发送到 Mac 端识别）
        do {
            try audioStreamController.startStreaming(
                sessionId: payload.sessionId,
                playThroughMacSpeaker: false
            )
        } catch {
            print("❌ 启动音频流失败: \(error.localizedDescription)")
        }
    }

    private func handleStopListen(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(StopListenPayload.self, from: envelope.payload) else {
            return
        }

        // Only stop if session ID matches
        guard payload.sessionId == currentSessionId else {
            return
        }

        print("🛑 收到 stopListen 消息，停止音频流")
        audioStreamController.stopStreaming()
    }

    private func handlePairingError(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(ErrorPayload.self, from: envelope.payload) else {
            return
        }

        let requiresRePairing = PairingErrorRecoveryPolicy.requiresRePairing(for: payload.code)
        let message: String
        if let dedicatedMessageKey = PairingErrorRecoveryPolicy.messageKey(for: payload.code) {
            message = localized(dedicatedMessageKey)
        } else {
            switch payload.code {
            case "invalid_code":
            message = localized("pairing_code_incorrect")
            case "not_pairing":
            message = localized("pairing_not_in_pairing_mode")
            case "pairing_failed":
            message = localized("pairing_save_failed")
            default:
                message = localized("pairing_mac_error_format", payload.message)
            }
        }

        DispatchQueue.main.async {
            if requiresRePairing {
                self.connectionManager.unpair()
                self.showPairingView = true
            }
            self.latestPairingFeedback = message
            self.appendInboundDataRecord(
                title: self.localized("log_error_from_mac_title"),
                detail: message,
                category: .pairing,
                severity: .error
            )
        }
    }

    private func handleMacRecognitionResult(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(ResultPayload.self, from: envelope.payload) else {
            print("❌ 无法解码远端识别结果")
            return
        }

        print("📝 收到远端识别结果: \(payload.text)")

        DispatchQueue.main.async {
            // 保存识别前的文字，用于撤销恢复
            self.preRecognitionCommittedText = self.committedTranscriptText
            // 提交文本到转写区域（跟本地识别一样的逻辑）
            let committedText = LocalTranscriptHistory.appendingLatestTranscript(
                payload.text,
                to: self.committedTranscriptText
            )
            self.committedTranscriptText = committedText
            self.liveTranscriptText = ""
            self.localTranscriptText = committedText
            self.transcriptAutoScrollVersion += 1
            self.appendLocalTranscriptRecord(text: payload.text, language: payload.language)

            self.recognitionState = .idle
            self.currentSessionId = nil
            self.manualSessionId = nil
            self.activeInputMode = nil
            self.showsTranscriptActions = !payload.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            self.pushToTalkStatusMessage = self.localized("ptt_mac_result_received")
            self.lastKeywordSessionId = payload.sessionId
            self.appendInboundDataRecord(
                title: self.localized("log_mac_result_title"),
                detail: self.localized("log_mac_result_detail_format", payload.sessionId, payload.language, payload.text),
                category: .voice
            )
        }
    }

    private func handleMacPartialResult(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(PartialResultPayload.self, from: envelope.payload) else {
            return
        }
        print("📝 收到远端部分结果: \(payload.text)")
        DispatchQueue.main.async {
            self.liveTranscriptText = payload.text
            self.localTranscriptText = LocalTranscriptHistory.renderingActiveTranscript(
                committedText: self.committedTranscriptText,
                liveTranscriptText: self.liveTranscriptText
            )
            self.transcriptAutoScrollVersion += 1
        }
    }

    private func handleRemoteError(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(ErrorPayload.self, from: envelope.payload) else {
            return
        }

        let recognitionErrors = [
            "recognition_error",
            "recognition_start_failed",
            "recognition_stop_failed",
            "audio_processing_failed"
        ]

        if recognitionErrors.contains(payload.code) {
            print("❌ 远端识别错误: \(payload.message)")
            DispatchQueue.main.async {
                self.recognitionState = .idle
                self.currentSessionId = nil
                self.manualSessionId = nil
                self.activeInputMode = nil
                self.pushToTalkStatusMessage = self.localized("ptt_mac_error")
                self.appendInboundDataRecord(
                    title: self.localized("log_mac_error_title"),
                    detail: payload.message,
                    category: .voice,
                    severity: .error
                )
            }
            return
        }

        // 非识别错误走原有配对错误处理
        handlePairingError(envelope)
    }
}

extension ContentViewModel: SpeechControllerDelegate {
    func speechController(_ controller: SpeechController, didChangeState state: RecognitionState) {
        DispatchQueue.main.async {
            self.recognitionState = state

            switch state {
            case .idle:
                self.refreshIdleStatusMessage()
            case .listening:
                self.pushToTalkStatusMessage = self.localized("ptt_local_recording")
            case .processing:
                self.pushToTalkStatusMessage = self.localized("ptt_local_processing")
            case .sending:
                self.pushToTalkStatusMessage = self.shouldForwardResultToMac
                ? self.localized("ptt_sending_result")
                : self.localized("ptt_local_processing")
            }
        }
    }

    func speechController(_ controller: SpeechController, didUpdateTranscript text: String, language: String, isFinal: Bool) {
        DispatchQueue.main.async {
            self.liveTranscriptText = text
            self.localTranscriptText = LocalTranscriptHistory.renderingActiveTranscript(
                committedText: self.committedTranscriptText,
                liveTranscriptText: self.liveTranscriptText
            )
            self.transcriptAutoScrollVersion += 1
        }
    }

    func speechController(_ controller: SpeechController, didRecognizeText text: String, language: String) {
        DispatchQueue.main.async {
            // 保存识别前的文字，用于撤销恢复
            self.preRecognitionCommittedText = self.committedTranscriptText
            let committedText = LocalTranscriptHistory.appendingLatestTranscript(
                text,
                to: self.committedTranscriptText
            )
            self.committedTranscriptText = committedText
            self.liveTranscriptText = ""
            self.localTranscriptText = committedText
            self.transcriptAutoScrollVersion += 1
            self.appendLocalTranscriptRecord(text: text, language: language)

            // 本地识别完成后显示确认/撤销按钮
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                self.showsTranscriptActions = true
                self.isLastRecognitionLocal = true
            }

            let shouldForward = self.shouldForwardResultToMac
            let sessionId = self.currentSessionId ?? self.manualSessionId

            // 保存 sessionId，用于确认/撤销时发送 keyword action 到 Mac
            if !trimmed.isEmpty, let sessionId {
                self.lastKeywordSessionId = sessionId
            }

            print("📋 [ForwardDebug] shouldForward=\(shouldForward), sessionId=\(sessionId ?? "nil"), sendToMacEnabled=\(self.sendResultsToMacEnabled), pairingState=\(self.pairingState), connectionState=\(self.connectionState)")

            if shouldForward, let sessionId, self.authorizeTwoDeviceSyncSessionIfNeeded() {
                let payload = TextMessagePayload(
                    sessionId: sessionId,
                    text: text,
                    language: language
                )

                guard let payloadData = try? JSONEncoder().encode(payload) else { return }

                let timestamp = Date()
                let hmac = self.connectionManager.hmacValidator?.generateHMACForEnvelope(
                    type: .textMessage,
                    payload: payloadData,
                    timestamp: timestamp,
                    deviceId: self.connectionManager.deviceId
                )

                let envelope = MessageEnvelope(
                    type: .textMessage,
                    payload: payloadData,
                    timestamp: timestamp,
                    deviceId: self.connectionManager.deviceId,
                    hmac: hmac
                )

                self.connectionManager.send(envelope)
                self.recordSuccessfulTwoDeviceSyncSession()
                self.pushToTalkStatusMessage = self.localized("ptt_local_saved_and_sent")
            } else {
                self.pushToTalkStatusMessage = self.localized("ptt_local_saved")
            }

            self.currentSessionId = nil
            self.manualSessionId = nil
            self.activeInputMode = nil
            self.appendInboundDataRecord(
                title: self.localized("log_speech_result_title"),
                detail: self.localized("log_speech_result_detail_format", sessionId ?? "-", language, text),
                category: .voice
            )
        }
    }

    func speechController(_ controller: SpeechController, didFailWithError error: Error) {
        print("Speech recognition error: \(error)")
        pushToTalkStatusMessage = error.localizedDescription
        liveTranscriptText = ""
        localTranscriptText = committedTranscriptText
        appendInboundDataRecord(
            title: localized("log_speech_error_title"),
            detail: error.localizedDescription,
            category: .voice,
            severity: .error
        )

        // Send error to Mac only when the current session is actively forwarding.
        if activeInputMode == .streamingToMac, currentSessionId != nil || manualSessionId != nil {
            let payload = ErrorPayload(
                code: "SPEECH_ERROR",
                message: error.localizedDescription
            )

            guard let payloadData = try? JSONEncoder().encode(payload) else { return }

            let timestamp = Date()
            let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
                type: .error,
                payload: payloadData,
                timestamp: timestamp,
                deviceId: connectionManager.deviceId
            )

            let envelope = MessageEnvelope(
                type: .error,
                payload: payloadData,
                timestamp: timestamp,
                deviceId: connectionManager.deviceId,
                hmac: hmac
            )

            connectionManager.send(envelope)
            currentSessionId = nil
            manualSessionId = nil
        }
        activeInputMode = nil
    }
}

extension ContentViewModel: BonjourBrowserDelegate {
    func browser(_ browser: BonjourBrowser, didFindService service: DiscoveredService) {
        DispatchQueue.main.async {
            if !self.discoveredServices.contains(where: { $0.id == service.id }) {
            self.discoveredServices.append(service)
            self.appendInboundDataRecord(
                title: self.localized("log_bonjour_found_title"),
                detail: self.localized("log_bonjour_found_detail_format", service.name, service.host, "\(service.port)"),
                category: .connection
            )
            }

            // Auto-connect if this is our paired device
            if case .paired(_, let deviceName) = self.pairingState,
               service.name == deviceName,
               self.connectionState != .connected,
               !self.reconnectNeedsManualAction {
                self.reconnectStatusMessage = self.localized("reconnect_found_auto")
                self.connectionManager.connect(to: service)
            } else if case .paired(_, let deviceName) = self.pairingState,
                      service.name == deviceName,
                      self.reconnectNeedsManualAction {
                self.reconnectNeedsManualAction = false
                self.reconnectStatusMessage = self.localized("reconnect_found_again")
                self.connectionManager.connect(to: service)
            }
        }
    }

    func browser(_ browser: BonjourBrowser, didRemoveService service: DiscoveredService) {
        DispatchQueue.main.async {
            self.discoveredServices.removeAll { $0.id == service.id }
            self.appendInboundDataRecord(
                title: self.localized("log_bonjour_removed_title"),
                detail: self.localized("log_bonjour_removed_detail_format", service.name),
                category: .connection,
                severity: .warning
            )
        }
    }
}

// MARK: - AudioStreamControllerDelegate

extension ContentViewModel: AudioStreamControllerDelegate {
    func audioStreamController(_ controller: AudioStreamController, didStartStream payload: AudioStartPayload) {
        print("📤 发送 audioStart 消息")
        DispatchQueue.main.async {
            self.recognitionState = .listening
            self.pushToTalkStatusMessage = self.localized("ptt_capturing")
            self.audioLevel = 0
        }
        appendInboundDataRecord(
            title: localized("log_audio_start_title"),
            detail: localized("log_audio_start_detail_format", payload.sessionId, payload.language, "\(payload.sampleRate)"),
            category: .voice
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else {
            print("❌ 无法编码 audioStart payload")
            return
        }

        let timestamp = Date()
        let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
            type: .audioStart,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId
        )

        let envelope = MessageEnvelope(
            type: .audioStart,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId,
            hmac: hmac
        )

        connectionManager.send(envelope)
        recordSuccessfulTwoDeviceSyncSession()
    }

    func audioStreamController(_ controller: AudioStreamController, didCaptureAudio payload: AudioDataPayload) {
        guard let payloadData = try? JSONEncoder().encode(payload) else {
            return
        }

        let timestamp = Date()
        let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
            type: .audioData,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId
        )

        let envelope = MessageEnvelope(
            type: .audioData,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId,
            hmac: hmac
        )

        connectionManager.send(envelope)
    }

    func audioStreamController(_ controller: AudioStreamController, didEndStream payload: AudioEndPayload) {
        print("📤 发送 audioEnd 消息")
        DispatchQueue.main.async {
            self.manualSessionId = nil
            self.recognitionState = .idle
            self.pushToTalkStatusMessage = self.effectiveHomeTranscriptionMode == .microphone
                ? self.localized("ptt_mic_session_ended")
                : self.localized("ptt_sent_mac_processing")
            self.audioLevel = 0
            self.activeInputMode = nil
        }
        appendInboundDataRecord(
            title: localized("log_audio_end_title"),
            detail: localized("log_audio_end_detail_format", payload.sessionId),
            category: .voice
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else {
            print("❌ 无法编码 audioEnd payload")
            return
        }

        let timestamp = Date()
        let hmac = connectionManager.hmacValidator?.generateHMACForEnvelope(
            type: .audioEnd,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId
        )

        let envelope = MessageEnvelope(
            type: .audioEnd,
            payload: payloadData,
            timestamp: timestamp,
            deviceId: connectionManager.deviceId,
            hmac: hmac
        )

        connectionManager.send(envelope)
    }

    func audioStreamController(_ controller: AudioStreamController, didUpdateAudioLevel level: CGFloat) {
        DispatchQueue.main.async {
            self.audioLevel = level
        }
    }
}
