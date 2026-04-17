import SwiftUI

struct SpeechRecognitionTab: View {
    @ObservedObject var controller: MenuBarController
    var showsInlineHeader = true
    @StateObject private var engineListStore = SpeechRecognitionEngineListStore()
    @StateObject private var modelManager = SherpaOnnxModelManager.shared
    @StateObject private var qwen3Manager = Qwen3AsrModelManager.shared

    // Volcengine config state
    @AppStorage("volcengineAppId") private var volcengineAppId = ""
    @AppStorage("volcengineAccessKey") private var volcengineAccessKey = ""
    @AppStorage("volcengineResourceId") private var volcengineResourceId = "volc.bigasr.sauc.duration"
    @State private var volcengineTestResult: String?
    @State private var isTestingVolcengine = false

    // Expandable config state (mutually exclusive)
    @State private var expandedSection: ExpandedSection? = nil

    private enum ExpandedSection: Equatable {
        case volcengine
        case qwen3
    }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            if showsInlineHeader {
                Text(AppLocalization.localizedString("speech_engine_title"))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(MainWindowColors.title)
            }

            speechHero

            engineSelectionSection

            // Hint bar
            hintBar

            Spacer()
        }
        .padding(.bottom, 8)
        }
        .onAppear {
            refreshEngines()
        }
    }

    private var speechHero: some View {
        MainWindowSurface(emphasized: true) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppLocalization.localizedString("speech_engine_title"))
                        .font(.title3.weight(.semibold))
                        .foregroundColor(MainWindowColors.title)

                    Text(AppLocalization.localizedString("main_speech_subtitle"))
                        .font(.subheadline)
                        .foregroundColor(MainWindowColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    MainWindowStatusChip(
                        title: selectedEngineDisplayName,
                        systemImage: "waveform.circle",
                        tint: .blue
                    )

                    MainWindowStatusChip(
                        title: modelStatusSummary,
                        systemImage: "internaldrive",
                        tint: engineStatusTint
                    )
                }
            }
        }
    }

    // MARK: - Hint Bar

    private var hintBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundColor(MainWindowColors.secondaryText)
            Text(hintText)
                .font(.caption)
                .foregroundColor(MainWindowColors.secondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MainWindowColors.softSurface.opacity(0.5))
        )
    }

    private var hintText: String {
        if expandedSection == .volcengine {
            return "配置火山引擎 ASR 的 API 密钥，保存后即可使用云端语音识别"
        }
        if expandedSection == .qwen3 {
            return "选择并下载 Qwen3-ASR 本地模型，下载完成后即可离线使用"
        }
        if selectedEngineId == "apple-speech" {
            return "当前使用 Apple Speech 系统内置引擎，无需额外配置"
        }
        if isSherpaModelSelected {
            return "当前使用 Sherpa-ONNX 本地引擎，所有识别均在本地完成"
        }
        if selectedEngineId == "volcengine" {
            return volcengineIsConfigured
                ? "当前使用火山引擎云端识别，点击配置按钮修改设置"
                : "火山引擎需要配置 API 密钥后才能使用，请点击「配置」按钮"
        }
        if isQwen3ModelSelected {
            return "当前使用 Qwen3-ASR 本地引擎，所有识别均在本地完成"
        }
        return "选择一个语音识别引擎开始使用"
    }

    // MARK: - Engine + Model Selection

    @ViewBuilder
    private var engineSelectionSection: some View {
        MainWindowSurface {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(AppLocalization.localizedString("speech_engine_select_title"), systemImage: "waveform.circle")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(MainWindowColors.title)

                    Text(AppLocalization.localizedString("main_speech_subtitle"))
                        .font(.subheadline)
                        .foregroundColor(MainWindowColors.secondaryText)
                }

                // Apple Speech
                engineRowCompact(
                    title: "Apple Speech",
                    subtitle: "系统内置",
                    systemImage: "apple.logo",
                    isSelected: selectedEngineId == "apple-speech" && !isSherpaModelSelected && !isQwen3ModelSelected,
                    statusLabel: "可用",
                    statusTint: .green,
                    action: selectAppleSpeech,
                    configButton: nil
                )

                Divider()

                // Sherpa-ONNX
                VStack(alignment: .leading, spacing: 10) {
                    engineRowCompact(
                        title: "Sherpa-ONNX",
                        subtitle: "\(installedSherpaModelCount)/\(SherpaOnnxModelDefinition.catalog.count) 模型",
                        systemImage: "cpu",
                        isSelected: isSherpaModelSelected,
                        statusLabel: isSherpaModelSelected ? "已选择" : (installedSherpaModelCount > 0 ? "可用" : "未安装"),
                        statusTint: isSherpaModelSelected ? .green : (installedSherpaModelCount > 0 ? .blue : .orange),
                        action: {},
                        configButton: nil
                    )

                    ForEach(SherpaOnnxModelDefinition.catalog) { model in
                        sherpaModelRow(model)
                    }
                }

                Divider()

                // Volcengine ASR
                VStack(alignment: .leading, spacing: 10) {
                    engineRowCompact(
                        title: "火山引擎 ASR",
                        subtitle: "云端识别",
                        systemImage: "cloud",
                        isSelected: selectedEngineId == "volcengine",
                        statusLabel: volcengineIsConfigured ? "已配置" : "未配置",
                        statusTint: volcengineIsConfigured ? .green : .orange,
                        action: selectVolcengine,
                        configButton: {
                            toggleSection(.volcengine)
                        }
                    )

                    if expandedSection == .volcengine {
                        volcengineConfigPanel
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Divider()

                // Qwen3-ASR
                VStack(alignment: .leading, spacing: 10) {
                    engineRowCompact(
                        title: "Qwen3-ASR",
                        subtitle: "\(installedQwen3ModelCount)/\(Qwen3AsrModelDefinition.catalog.count) 模型",
                        systemImage: "brain",
                        isSelected: isQwen3ModelSelected,
                        statusLabel: isQwen3ModelSelected ? "已选择" : (installedQwen3ModelCount > 0 ? "可用" : "未下载"),
                        statusTint: isQwen3ModelSelected ? .green : (installedQwen3ModelCount > 0 ? .blue : .orange),
                        action: {},
                        configButton: {
                            toggleSection(.qwen3)
                        }
                    )

                    if expandedSection == .qwen3 {
                        qwen3ConfigPanel
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    // MARK: - Engine Row (Compact)

    private func engineRowCompact(
        title: String,
        subtitle: String,
        systemImage: String,
        isSelected: Bool,
        statusLabel: String,
        statusTint: Color,
        action: @escaping () -> Void,
        configButton: (() -> Void)?
    ) -> some View {
        HStack(spacing: 12) {
            RadioButton(isSelected: isSelected, action: action)

            Image(systemName: systemImage)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(MainWindowColors.title)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(MainWindowColors.secondaryText)
            }

            Spacer()

            miniPill(title: statusLabel, tint: statusTint)

            if let configAction = configButton {
                Button(action: configAction) {
                    Image(systemName: expandedSection == sectionForConfig(configButton) ? "chevron.up" : "gearshape")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.accentColor)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.accentColor.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.06) : MainWindowColors.softSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : MainWindowColors.cardBorder, lineWidth: 1)
        )
    }

    private func sectionForConfig(_ configButton: (() -> Void)?) -> ExpandedSection? {
        // This is a helper — we determine the section from context
        return nil // Not used directly; we check expandedSection in the caller
    }

    private func toggleSection(_ section: ExpandedSection) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedSection == section {
                expandedSection = nil
            } else {
                expandedSection = section
            }
        }
    }

    // MARK: - Volcengine Config Panel

    private var volcengineConfigPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("App ID")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(MainWindowColors.secondaryText)
                    TextField("X-Api-App-Key", text: $volcengineAppId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Access Key")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(MainWindowColors.secondaryText)
                    TextField("X-Api-Access-Key", text: $volcengineAccessKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resource ID")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(MainWindowColors.secondaryText)
                    Picker("", selection: $volcengineResourceId) {
                        Text("BigModel 1.0").tag("volc.bigasr.sauc.duration")
                        Text("SeedASR 2.0 - 小时版").tag("volc.seedasr.sauc.duration")
                        Text("SeedASR 2.0 - 并发版").tag("volc.seedasr.sauc.concurrent")
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 13))
                }

                Spacer()

                Button(action: testVolcengineConnection) {
                    HStack(spacing: 4) {
                        if isTestingVolcengine {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("测试连接")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isTestingVolcengine || volcengineAppId.isEmpty || volcengineAccessKey.isEmpty)
            }

            if let result = volcengineTestResult {
                Text(result)
                    .font(.caption)
                    .foregroundColor(result.hasPrefix("✅") ? .green : .red)
            }

            // Action buttons
            HStack {
                Spacer()
                Button("收起") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        expandedSection = nil
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MainWindowColors.softSurface.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MainWindowColors.cardBorder.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Qwen3 Config Panel

    private var qwen3ConfigPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Qwen3AsrModelDefinition.catalog) { model in
                qwen3ModelRow(model)
            }

            // Action buttons
            HStack {
                Spacer()
                Button("收起") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        expandedSection = nil
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MainWindowColors.softSurface.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MainWindowColors.cardBorder.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Sherpa Model Row

    @ViewBuilder
    private func sherpaModelRow(_ model: SherpaOnnxModelDefinition) -> some View {
        let state = modelManager.modelStates[model.id] ?? .notDownloaded

        HStack(alignment: .center, spacing: 12) {
            RadioButton(
                isSelected: modelManager.selectedModelId == model.id,
                action: {
                    if case .installed = state {
                        modelManager.selectModel(model.id)
                    }
                }
            )
            .disabled(state != .installed)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(model.displayName)
                        .font(.headline)
                        .foregroundColor(MainWindowColors.title)

                    statePill(for: state)
                }

                HStack(spacing: 8) {
                    Text(model.estimatedSize)
                        .font(.caption)
                        .foregroundColor(MainWindowColors.secondaryText)

                    Text(model.languages.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(MainWindowColors.secondaryText)
                }

                if case .failed(let msg) = state {
                    Text("失败: \(msg)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            }

            Spacer()

            modelActionButton(state: state, modelId: model.id) {
                modelManager.download(model: model)
            } cancel: {
                modelManager.cancelDownload(modelId: model.id)
            } delete: {
                modelManager.deleteModel(model: model)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MainWindowColors.softSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Qwen3 Model Row

    @ViewBuilder
    private func qwen3ModelRow(_ model: Qwen3AsrModelDefinition) -> some View {
        let state = qwen3Manager.modelStates[model.id] ?? .notDownloaded

        HStack(alignment: .center, spacing: 12) {
            RadioButton(
                isSelected: qwen3Manager.selectedModelId == model.id,
                action: {
                    if case .installed = state {
                        qwen3Manager.selectModel(model.id)
                    }
                }
            )
            .disabled(state != .installed)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(model.displayName)
                        .font(.headline)
                        .foregroundColor(MainWindowColors.title)

                    statePill(for: state)
                }

                HStack(spacing: 8) {
                    Text(model.estimatedSize)
                        .font(.caption)
                        .foregroundColor(MainWindowColors.secondaryText)

                    Text(model.languages.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(MainWindowColors.secondaryText)
                }

                if case .failed(let msg) = state {
                    Text("失败: \(msg)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            }

            Spacer()

            modelActionButton(state: state, modelId: model.id) {
                qwen3Manager.download(model: model)
            } cancel: {
                qwen3Manager.cancelDownload(modelId: model.id)
            } delete: {
                qwen3Manager.deleteModel(model: model)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MainWindowColors.softSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MainWindowColors.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Shared UI Components

    @ViewBuilder
    private func statePill(for state: ModelState) -> some View {
        switch state {
        case .installed:
            miniPill(title: "已安装", tint: .green)
        case .notDownloaded:
            miniPill(title: "需下载", tint: .orange)
        case .downloading(let progress):
            miniPill(title: String(format: "下载中 %.0f%%", progress * 100), tint: .blue)
        case .extracting:
            miniPill(title: "解压中", tint: .blue)
        case .failed:
            miniPill(title: "失败", tint: .red)
        }
    }

    private func miniPill(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.10))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func modelActionButton(state: ModelState, modelId: String,
                                   download: @escaping () -> Void,
                                   cancel: @escaping () -> Void,
                                   delete: @escaping () -> Void) -> some View {
        switch state {
        case .notDownloaded, .failed:
            Button(action: download) {
                Label("下载", systemImage: "arrow.down.circle")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        case .downloading(let progress):
            VStack(alignment: .trailing, spacing: 8) {
                Button(action: cancel) {
                    Label("取消", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)

                ProgressView(value: progress)
                    .frame(width: 96)
            }

        case .extracting:
            ProgressView()
                .controlSize(.small)

        case .installed:
            Button(action: delete) {
                Label("删除", systemImage: "trash")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundColor(.red)
        }
    }

    // MARK: - Actions

    private func selectAppleSpeech() {
        modelManager.selectedModelId = nil
        qwen3Manager.selectedModelId = nil
        do {
            try SpeechRecognitionManager.shared.selectEngine(identifier: "apple-speech")
            engineListStore.reload()
            UserDefaults.standard.selectedSpeechEngine = "apple-speech"
            NotificationCenter.default.post(name: .speechEngineDidChange, object: nil)
        } catch {
            print("❌ 选择 Apple Speech 失败: \(error)")
        }
    }

    private func selectVolcengine() {
        guard volcengineIsConfigured else { return }
        modelManager.selectedModelId = nil
        qwen3Manager.selectedModelId = nil
        do {
            try SpeechRecognitionManager.shared.selectEngine(identifier: "volcengine")
            engineListStore.reload()
            UserDefaults.standard.selectedSpeechEngine = "volcengine"
            NotificationCenter.default.post(name: .speechEngineDidChange, object: nil)
        } catch {
            print("❌ 选择火山引擎 ASR 失败: \(error)")
        }
    }

    private func testVolcengineConnection() {
        isTestingVolcengine = true
        volcengineTestResult = nil

        Task {
            do {
                let result = try await VolcengineConnectionTester.test(
                    appId: volcengineAppId,
                    accessKey: volcengineAccessKey,
                    resourceId: volcengineResourceId
                )
                volcengineTestResult = result
            } catch {
                volcengineTestResult = "❌ \(error.localizedDescription)"
            }
            isTestingVolcengine = false
        }
    }

    // MARK: - Computed

    private var isSherpaModelSelected: Bool {
        modelManager.selectedModelId != nil
    }

    private var isQwen3ModelSelected: Bool {
        qwen3Manager.selectedModelId != nil
    }

    private var volcengineIsConfigured: Bool {
        !volcengineAppId.isEmpty && !volcengineAccessKey.isEmpty
    }

    private var engineStatusTint: Color {
        if isSherpaModelSelected || isQwen3ModelSelected { return .green }
        if selectedEngineId == "volcengine" { return .blue }
        return .orange
    }

    private func refreshEngines() {
        engineListStore.reload()
    }
}

private extension SpeechRecognitionTab {
    var availableEngines: [SpeechRecognitionEngine] {
        engineListStore.availableEngines
    }

    var selectedEngineId: String {
        engineListStore.selectedEngineId
    }

    var selectedEngineDisplayName: String {
        if let selectedModelId = modelManager.selectedModelId,
           let model = SherpaOnnxModelDefinition.catalog.first(where: { $0.id == selectedModelId }) {
            return model.displayName
        }
        if let selectedModelId = qwen3Manager.selectedModelId,
           let model = Qwen3AsrModelDefinition.catalog.first(where: { $0.id == selectedModelId }) {
            return model.displayName
        }

        return availableEngines.first(where: { $0.identifier == selectedEngineId })?.displayName
            ?? AppLocalization.localizedString("speech_engine_title")
    }

    var modelStatusSummary: String {
        if isSherpaModelSelected {
            return "Sherpa-ONNX"
        }
        if isQwen3ModelSelected {
            return "Qwen3-ASR"
        }
        if selectedEngineId == "volcengine" {
            return "火山引擎"
        }
        return "Apple Speech"
    }

    var installedSherpaModelCount: Int {
        SherpaOnnxModelDefinition.catalog.filter {
            if case .installed = modelManager.modelStates[$0.id] ?? .notDownloaded {
                return true
            }
            return false
        }.count
    }

    var installedQwen3ModelCount: Int {
        Qwen3AsrModelDefinition.catalog.filter {
            if case .installed = qwen3Manager.modelStates[$0.id] ?? .notDownloaded {
                return true
            }
            return false
        }.count
    }
}

// Radio button component
struct RadioButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                .foregroundColor(isSelected ? .accentColor : MainWindowColors.secondaryText)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Volcengine WebSocket Connection Tester

private class VolcengineConnectionTester: NSObject, URLSessionWebSocketDelegate {
    private var continuation: CheckedContinuation<String, Error>?

    static func test(appId: String, accessKey: String, resourceId: String) async throws -> String {
        let tester = VolcengineConnectionTester()

        return try await withCheckedThrowingContinuation { continuation in
            tester.continuation = continuation

            guard let url = URL(string: VolcengineBinaryProtocol.websocketURL) else {
                continuation.resume(throwing: NSError(domain: "VolcengineTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"]))
                return
            }

            var request = URLRequest(url: url)
            let connectId = UUID().uuidString
            for (key, value) in VolcengineBinaryProtocol.buildRequestHeaders(
                appId: appId, accessKey: accessKey, resourceId: resourceId, connectId: connectId
            ) {
                request.setValue(value, forHTTPHeaderField: key)
            }

            let session = URLSession(configuration: .default, delegate: tester, delegateQueue: nil)
            let wsTask = session.webSocketTask(with: request)
            wsTask.resume()

            // 10 秒超时
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                // 如果 continuation 还没 resume，说明超时
                tester.resumeOnce("❌ 连接超时")
                wsTask.cancel(with: .normalClosure, reason: nil)
                session.invalidateAndCancel()
            }
        }
    }

    private func resumeOnce(_ result: String) {
        guard let cont = continuation else { return }
        continuation = nil
        if result.hasPrefix("✅") {
            cont.resume(returning: result)
        } else {
            cont.resume(throwing: NSError(domain: "VolcengineTest", code: -1, userInfo: [NSLocalizedDescriptionKey: String(result.dropFirst(2))]))
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        resumeOnce("✅ 连接成功")
        webSocketTask.cancel(with: .normalClosure, reason: nil)
        session.invalidateAndCancel()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            resumeOnce("❌ \(error.localizedDescription)")
        }
        session.invalidateAndCancel()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        if continuation != nil {
            resumeOnce("❌ 连接被关闭 (\(closeCode.rawValue))")
        }
        session.invalidateAndCancel()
    }
}
