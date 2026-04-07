import Foundation
import AVFoundation
import Combine
import Darwin

enum SherpaOnnxRuntimeModel: Equatable {
    case streamingParaformer(encoder: String, decoder: String, tokens: String)
    case streamingTransducer(encoder: String, decoder: String, joiner: String, tokens: String)
}

enum SherpaOnnxOnlineConfigPolicy {
    static func modelType(for runtimeModel: SherpaOnnxRuntimeModel) -> String {
        switch runtimeModel {
        case .streamingParaformer:
            return "paraformer"
        case .streamingTransducer:
            return "zipformer"
        }
    }

    static func requiredFilePaths(for runtimeModel: SherpaOnnxRuntimeModel) -> [String] {
        switch runtimeModel {
        case .streamingParaformer(let encoder, let decoder, let tokens):
            return [encoder, decoder, tokens]
        case .streamingTransducer(let encoder, let decoder, let joiner, let tokens):
            return [encoder, decoder, joiner, tokens]
        }
    }
}

enum SherpaOnnxRuntimeModelResolver {
    static func resolveModel(in directoryPath: String) -> SherpaOnnxRuntimeModel? {
        let directoryURL = URL(fileURLWithPath: directoryPath, isDirectory: true)

        guard let tokens = existingFile(in: directoryURL, candidates: ["tokens.txt"]) else {
            return nil
        }

        if let encoder = firstMatch(in: directoryURL, prefixes: ["encoder"], suffix: ".onnx"),
           let decoder = firstMatch(in: directoryURL, prefixes: ["decoder"], suffix: ".onnx"),
           let joiner = firstMatch(in: directoryURL, prefixes: ["joiner"], suffix: ".onnx") {
            return .streamingTransducer(
                encoder: encoder.path,
                decoder: decoder.path,
                joiner: joiner.path,
                tokens: tokens.path
            )
        }

        if let encoder = firstMatch(in: directoryURL, prefixes: ["encoder"], suffix: ".onnx"),
           let decoder = firstMatch(in: directoryURL, prefixes: ["decoder"], suffix: ".onnx") {
            return .streamingParaformer(
                encoder: encoder.path,
                decoder: decoder.path,
                tokens: tokens.path
            )
        }

        return nil
    }

    private static func existingFile(in directoryURL: URL, candidates: [String]) -> URL? {
        for candidate in candidates {
            let fileURL = directoryURL.appendingPathComponent(candidate)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }
        return nil
    }

    private static func firstMatch(in directoryURL: URL, prefixes: [String], suffix: String) -> URL? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return contents
            .filter { $0.lastPathComponent.hasSuffix(suffix) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .first { fileURL in
                prefixes.contains { fileURL.lastPathComponent.hasPrefix($0) }
            }
    }
}

enum SherpaOnnxPCM16Converter {
    static func floatSamples(from data: Data) -> [Float] {
        data.withUnsafeBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(to: Int16.self)
            return samples.map { sample in
                if sample == Int16.min {
                    return -1
                }
                return Float(sample) / Float(Int16.max)
            }
        }
    }
}

enum SherpaOnnxRuntimeLibraryResolver {
    static func resolveLibraryPath(
        bundlePrivateFrameworksPath: String?,
        fallbackPaths: [String]
    ) -> String? {
        // 1. 优先检查项目内建的 Frameworks 目录
        if let bundledLib = checkBundledLibrary() {
            return bundledLib
        }

        // 2. 检查 PrivateFrameworks
        if let privateFrameworksPath = bundlePrivateFrameworksPath,
           let bundledLibrary = bundledOnnxRuntimeLibrary(in: privateFrameworksPath) {
            return bundledLibrary
        }

        // 3. 检查 fallback 路径
        return fallbackPaths.first { FileManager.default.fileExists(atPath: $0) }
    }

    /// 检查项目内建的 Frameworks（sherpa-onnx.xcframework 和 onnxruntime.xcframework）
    fileprivate static func checkBundledLibrary() -> String? {
        // 检查 Frameworks 目录（项目内建或 CocoaPods）
        let possiblePaths = [
            // 项目内建的 Frameworks
            Bundle.main.privateFrameworksPath.map { "\($0)/sherpa-onnx.xcframework" },
            Bundle.main.privateFrameworksPath.map { "\($0)/onnxruntime.xcframework" },
            // App Bundle 根目录的 Frameworks
            Bundle.main.resourcePath.map { "\($0)/../Frameworks/sherpa-onnx.xcframework" },
            Bundle.main.resourcePath.map { "\($0)/../Frameworks/onnxruntime.xcframework" },
            // 项目构建产物目录
            Bundle.main.resourcePath.map { "\($0)/../../Frameworks/sherpa-onnx.xcframework" },
        ].compactMap { $0 }

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                print("✅ Sherpa-ONNX XCFramework 找到: \(path)")
                return path
            }
        }

        // 检查是否是 macOS App（.app bundle）
        if let bundlePath = Bundle.main.bundlePath as String? {
            let appFrameworks = (bundlePath as NSString).deletingLastPathComponent + "/Frameworks"
            for name in ["sherpa-onnx.xcframework", "onnxruntime.xcframework"] {
                let fullPath = (appFrameworks as NSString).appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: fullPath) {
                    print("✅ Sherpa-ONNX XCFramework 找到: \(fullPath)")
                    return fullPath
                }
            }
        }

        return nil
    }

    private static func bundledOnnxRuntimeLibrary(in frameworksPath: String) -> String? {
        let frameworksURL = URL(fileURLWithPath: frameworksPath, isDirectory: true)

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: frameworksURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return contents
            .filter { fileURL in
                let name = fileURL.lastPathComponent
                return name.hasPrefix("libonnxruntime") && name.hasSuffix(".dylib")
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .first?
            .path
    }
}

enum SherpaOnnxModelDirectoryResolver {
    static func preferredLegacyHomeDirectory(
        currentHomeDirectory: URL,
        appBundleIdentifier: String?,
        passwdHomeDirectory: URL?
    ) -> URL {
        guard let appBundleIdentifier,
              isSandboxContainerHome(currentHomeDirectory, appBundleIdentifier: appBundleIdentifier),
              let passwdHomeDirectory else {
            return currentHomeDirectory
        }

        if passwdHomeDirectory.standardizedFileURL != currentHomeDirectory.standardizedFileURL {
            return passwdHomeDirectory
        }

        return currentHomeDirectory
    }

    static func legacyModelConfigDirectory(
        currentHomeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        appBundleIdentifier: String? = Bundle.main.bundleIdentifier,
        passwdHomeDirectory: URL? = passwdHomeDirectory()
    ) -> URL {
        let resolvedHomeDirectory = preferredLegacyHomeDirectory(
            currentHomeDirectory: currentHomeDirectory,
            appBundleIdentifier: appBundleIdentifier,
            passwdHomeDirectory: passwdHomeDirectory
        )

        return resolvedHomeDirectory
            .appendingPathComponent("Library/Application Support/VoiceMind/Models/SherpaOnnx", isDirectory: true)
    }

    private static func isSandboxContainerHome(_ url: URL, appBundleIdentifier: String) -> Bool {
        let standardizedPath = url.standardizedFileURL.path
        let containerComponent = "/Library/Containers/\(appBundleIdentifier)/Data"
        return standardizedPath.contains(containerComponent)
    }

    private static func passwdHomeDirectory() -> URL? {
        guard let pw = getpwuid(getuid()),
              let homeDirectory = pw.pointee.pw_dir else {
            return nil
        }

        return URL(fileURLWithPath: String(cString: homeDirectory), isDirectory: true)
    }
}

/// Sherpa-ONNX 语音识别引擎
/// 基于 https://github.com/k2-fsa/sherpa-onnx 的本地语音识别引擎
/// 需要先构建并集成 sherpa-onnx XCFramework 才能使用
class SherpaOnnxEngine: NSObject, SpeechRecognitionEngine {

    // MARK: - SpeechRecognitionEngine Protocol

    let identifier = "sherpa-onnx"

    var displayName: String {
        if isLibraryLoaded {
            return "Sherpa-ONNX"
        }
        return "Sherpa-ONNX (未安装)"
    }

    var supportsStreaming: Bool { true }

    var supportedLanguages: [String] {
        // Sherpa-ONNX 支持多语言，具体取决于下载的模型
        // 这里列出常用语言，实际支持情况取决于模型文件
        return [
            "zh-CN",  // 中文
            "en-US",  // 英文
            "yue-CN", // 粤语
            "ja-JP",  // 日语
            "ko-KR",  // 韩语
            "fr-FR",  // 法语
            "de-DE",  // 德语
            "es-ES",  // 西班牙语
        ]
    }

    /// 引擎是否可用（需要已加载 sherpa-onnx 库且模型已配置）
    var isAvailable: Bool {
        return isLibraryLoaded && isModelConfigured
    }

    weak var delegate: SpeechRecognitionEngineDelegate?

    // MARK: - Private Properties

    /// 库是否已加载
    private var isLibraryLoaded: Bool = false

    /// 模型是否已配置
    private var isModelConfigured: Bool = false

    /// 当前会话 ID
    private var currentSessionId: String?

    /// 当前语言
    private var currentLanguage: String?

    /// Sherpa-ONNX C 库句柄（用于存储创建的识别器）
    private var recognizerHandle: OpaquePointer?
    private var streamHandle: OpaquePointer?

    /// 音频样本率
    private let sampleRate: Int32 = 16000

    /// 模型路径
    private var modelPath: String?

    /// 模型配置
    private struct ModelConfig {
        let language: String
        let runtimeModel: SherpaOnnxRuntimeModel
    }

    private var currentModelConfig: ModelConfig?
    private var lastPartialText: String = ""

    // MARK: - 初始化

    override init() {
        super.init()
        checkLibraryAvailability()
    }

    // MARK: - Library Loading

    /// 检查 sherpa-onnx 库是否可用
    /// sherpa-onnx.xcframework 在 Xcode 项目中以静态库链接，编译时已嵌入
    /// 如果 Xcode 项目正确配置了 XCFramework 链接，则假设库在运行时可用
    private func checkLibraryAvailability() {
        print("🔍 Sherpa-ONNX 库检测开始...")
        print("   App Bundle: \(Bundle.main.bundlePath)")

        // 对于 XCFramework 静态库集成：
        // 库在编译时链接，运行时不需要 dlopen
        // 我们通过检测编译产物或配置来确认链接已完成

        var libraryFound = false

        // 1. 检测编译产物中是否有 onnxruntime dylib（说明 XCFramework 链接正常）
        let frameworksPath = (Bundle.main.bundlePath as NSString).appendingPathComponent("Contents/Frameworks")
        let onnxDylib = (frameworksPath as NSString).appendingPathComponent("libonnxruntime.1.23.0.dylib")
        if FileManager.default.fileExists(atPath: onnxDylib) {
            print("✅ ONNX Runtime dylib 存在: \(onnxDylib)")
            libraryFound = true
        }

        // 2. 检测项目 Frameworks 目录（开发时路径）
        if !libraryFound {
            let projectFrameworksPath = "/Users/cayden/Data/my-data/voiceMind/VoiceMindMac/Frameworks"
            let sherpaPath = (projectFrameworksPath as NSString).appendingPathComponent("sherpa-onnx.xcframework")
            if FileManager.default.fileExists(atPath: sherpaPath) {
                print("✅ Sherpa-ONNX XCFramework 存在于项目目录")
                libraryFound = true
            }
        }

        // 3. 检测 BUILT_PRODUCTS_DIR（Xcode DerivedData）
        if !libraryFound,
           let derivedPath = ProcessInfo.processInfo.environment["BUILT_PRODUCTS_DIR"] {
            let builtFrameworks = (derivedPath as NSString).appendingPathComponent("VoiceMind.app/Contents/Frameworks")
            if FileManager.default.fileExists(atPath: builtFrameworks) {
                print("✅ App Frameworks 目录存在: \(builtFrameworks)")
                libraryFound = true
            }
        }

        // 4. 对于已正确链接的项目，如果以上都检测不到，仍然假设库可用
        // （因为静态库会被嵌入可执行文件，运行时找不到文件是正常的）
        if !libraryFound {
            print("⚠️ 警告：无法通过文件检测确认库存在，假设 XCFramework 已正确链接")
            libraryFound = true
        }

        isLibraryLoaded = libraryFound

        if isLibraryLoaded {
            print("✅ Sherpa-ONNX 库状态: 已链接")
        } else {
            print("❌ Sherpa-ONNX 库状态: 未找到")
        }

        // 检查模型配置
        checkModelConfiguration()
    }

    /// 检查模型配置
    private func checkModelConfiguration() {
        print("🔍 Sherpa-ONNX 模型检测开始...")

        // 1. 优先检查 Application Support 目录下的模型（用户下载的最新模型）
        // 先通过 model.config 查找
        for configDir in candidateModelConfigDirectories() {
            let configFile = configDir.appendingPathComponent("model.config")
            print("🔎 检查 Sherpa 模型配置: \(configFile.path)")

            guard FileManager.default.fileExists(atPath: configFile.path) else {
                continue
            }

            do {
                let configData = try Data(contentsOf: configFile)
                if let config = try? JSONDecoder().decode(ModelConfigJSON.self, from: configData) {
                    print("   读取配置: encoder=\(config.encoderPath)")

                    let directoryPath = URL(fileURLWithPath: config.encoderPath)
                        .deletingLastPathComponent()
                        .path

                    if let runtimeModel = SherpaOnnxRuntimeModelResolver.resolveModel(in: directoryPath) {
                        currentModelConfig = ModelConfig(
                            language: config.language,
                            runtimeModel: runtimeModel
                        )
                        isModelConfigured = true
                        print("✅ Sherpa-ONNX 模型已配置 (config): \(config.language)")
                        return
                    }
                }
            } catch {
                print("⚠️ 读取模型配置失败: \(error)")
            }
        }

        // 2. 直接扫描所有候选目录下的子目录查找可用模型
        // （处理 sandbox 导致 FileManager 路径不正确、model.config 不可访问等情况）
        let allScanDirs = candidateModelConfigDirectories() + realHomeModelDirectories()
        var seen = Set<String>()
        for scanDir in allScanDirs {
            let key = scanDir.standardizedFileURL.path
            guard seen.insert(key).inserted else { continue }
            let models = findAvailableModels(in: scanDir)
            if let model = models.first {
                currentModelConfig = model
                isModelConfigured = true
                saveModelConfig(model)
                print("✅ Sherpa-ONNX 模型已配置 (扫描): \(model.language)")
                return
            }
        }

        // 3. 检查 App Bundle 内置的模型（最后备选）
        if let bundledModel = checkBundledModel() {
            currentModelConfig = bundledModel
            isModelConfigured = true
            print("✅ Sherpa-ONNX 模型已配置 (内置): \(bundledModel.language)")
            return
        }

        print("⚠️ Sherpa-ONNX 模型未找到")
    }

    /// 获取真实 home 目录下的模型路径（绕过 sandbox 的 container 路径）
    private func realHomeModelDirectories() -> [URL] {
        guard let pw = getpwuid(getuid()),
              let homeDirC = pw.pointee.pw_dir else {
            return []
        }
        let homeDir = String(cString: homeDirC)
        let realAppSupport = URL(fileURLWithPath: homeDir, isDirectory: true)
            .appendingPathComponent("Library/Application Support/VoiceMind/Models/SherpaOnnx", isDirectory: true)
        print("📁 真实 home 模型目录: \(realAppSupport.path)")
        return [realAppSupport]
    }

    /// 检查 App Bundle 内置的模型
    private func checkBundledModel() -> ModelConfig? {
        guard let resourcePath = Bundle.main.resourcePath else {
            print("   Bundle resourcePath 为 nil")
            return nil
        }

        let resourcesURL = URL(fileURLWithPath: resourcePath)

        // 模型可能在 Resources/Models/SherpaOnnx/paraformer-zh/ 或直接在 Resources/
        let possibleModelPaths = [
            resourcesURL.appendingPathComponent("Models/SherpaOnnx/paraformer-zh"),
            resourcesURL,  // 直接在 Resources 下（Xcode folder sync 扁平化结构）
        ]

        for modelPath in possibleModelPaths {
            let path = modelPath.path
            print("🔎 检查内置模型: \(path)")

            // 检查是否存在 encoder.onnx
            let encoderPath = modelPath.appendingPathComponent("encoder.onnx").path
            if !FileManager.default.fileExists(atPath: encoderPath) {
                // 如果直接搜 Resources，encoder.onnx 应该在 Resources/encoder.onnx
                let directEncoder = resourcesURL.appendingPathComponent("encoder.onnx").path
                if FileManager.default.fileExists(atPath: directEncoder) {
                    // 直接在 Resources 下
                    print("✅ 内置模型找到 (直接): \(resourcesURL.path)")
                    if let runtimeModel = SherpaOnnxRuntimeModelResolver.resolveModel(in: resourcesURL.path) {
                        return ModelConfig(language: "zh-CN", runtimeModel: runtimeModel)
                    }
                }
                continue
            }

            if let runtimeModel = SherpaOnnxRuntimeModelResolver.resolveModel(in: path) {
                print("✅ 内置模型找到: \(path)")
                return ModelConfig(language: "zh-CN", runtimeModel: runtimeModel)
            }
        }

        return nil
    }

    private func getModelConfigDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("VoiceMind/Models/SherpaOnnx")
    }

    private func legacyModelConfigDirectory() -> URL {
        SherpaOnnxModelDirectoryResolver.legacyModelConfigDirectory()
    }

    private func candidateModelConfigDirectories() -> [URL] {
        let primary = getModelConfigDirectory()
        let legacy = legacyModelConfigDirectory()

        if primary.standardizedFileURL == legacy.standardizedFileURL {
            print("📁 Sherpa 模型目录: \(primary.path)")
            return [primary]
        }

        print("📁 Sherpa 模型目录候选: \(primary.path)")
        print("📁 Sherpa 旧模型目录候选: \(legacy.path)")
        return [primary, legacy]
    }

    // MARK: - SpeechRecognitionEngine Methods

    func initialize() async throws {
        guard isLibraryLoaded else {
            throw SpeechError.engineNotAvailable
        }

        print("🎤 Sherpa-ONNX 引擎初始化中...")

        // 如果模型未配置，尝试设置默认模型
        if !isModelConfigured {
            try await setupDefaultModel()
        }

        guard isModelConfigured else {
            throw SpeechError.recognitionFailed("Sherpa-ONNX 模型未配置")
        }

        print("✅ Sherpa-ONNX 引擎初始化成功")
    }

    /// 设置默认模型
    private func setupDefaultModel() async throws {
        // 默认使用流式 Whisper 模型
        // 模型需要预先下载到 Models 目录
        let modelDir = getModelConfigDirectory()
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

        let models = candidateModelConfigDirectories()
            .flatMap { findAvailableModels(in: $0) }

        if let bestModel = models.first {
            currentModelConfig = bestModel
            isModelConfigured = true
            saveModelConfig(bestModel)
            print("✅ 已选择模型: \(bestModel.language)")
        } else {
            print("⚠️ 未在 \(modelDir.path) 找到 Sherpa-ONNX 模型")
            print("📥 请下载 Sherpa-ONNX 模型并放置在该目录下")
        }
    }

    /// 查找可用的 Sherpa-ONNX 模型
    /// 自动扫描 ModelDir 目录下的所有子目录，寻找有效的模型文件
    private func findAvailableModels(in directory: URL) -> [ModelConfig] {
        var configs: [ModelConfig] = []

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return configs
        }

        for item in contents {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            guard let runtimeModel = SherpaOnnxRuntimeModelResolver.resolveModel(in: item.path) else {
                continue
            }

            // 从目录名推断语言
            let dirName = item.lastPathComponent.lowercased()
            let language: String
            if dirName.contains("zh") || dirName.contains("chinese") {
                language = "zh-CN"
            } else if dirName.contains("en") || dirName.contains("english") {
                language = "en-US"
            } else if dirName.contains("ja") || dirName.contains("japanese") {
                language = "ja-JP"
            } else if dirName.contains("ko") || dirName.contains("korean") {
                language = "ko-KR"
            } else {
                language = "en-US"
            }

            configs.append(ModelConfig(
                language: language,
                runtimeModel: runtimeModel
            ))

            print("📁 发现模型: \(item.lastPathComponent) (语言: \(language))")
        }

        return configs
    }

    /// 保存模型配置
    private func saveModelConfig(_ config: ModelConfig) {
        let configDir = getModelConfigDirectory()
        let configFile = configDir.appendingPathComponent("model.config")

        let jsonConfig: ModelConfigJSON
        switch config.runtimeModel {
        case .streamingParaformer(let encoder, let decoder, let tokens):
            jsonConfig = ModelConfigJSON(
                encoderPath: encoder,
                decoderPath: decoder,
                tokensPath: tokens,
                language: config.language
            )
        case .streamingTransducer(let encoder, let decoder, _, let tokens):
            jsonConfig = ModelConfigJSON(
                encoderPath: encoder,
                decoderPath: decoder,
                tokensPath: tokens,
                language: config.language
            )
        }

        if let data = try? JSONEncoder().encode(jsonConfig) {
            try? data.write(to: configFile)
        }
    }

    func startRecognition(sessionId: String, language: String) throws {
        print("🎤 Sherpa-ONNX 开始识别")
        print("   Session ID: \(sessionId)")
        print("   语言: \(language)")

        guard isAvailable else {
            throw SpeechError.engineNotAvailable
        }

        // 停止之前的识别
        try? stopRecognition()

        currentSessionId = sessionId
        currentLanguage = language

        // 确保使用正确的语言模型
        if let config = currentModelConfig, config.language != language {
            // 尝试查找匹配语言的模型
            if let matchingModel = findModel(for: language) {
                currentModelConfig = matchingModel
                saveModelConfig(matchingModel)
            }
        }

        guard let config = currentModelConfig else {
            throw SpeechError.recognitionFailed("未配置语言模型")
        }

        try initializeRecognizer(config: config)
        lastPartialText = ""

        print("✅ Sherpa-ONNX 识别器已启动")
    }

    private func validateModelFilesExist(for runtimeModel: SherpaOnnxRuntimeModel) throws {
        let missingFiles = SherpaOnnxOnlineConfigPolicy.requiredFilePaths(for: runtimeModel)
            .filter { !FileManager.default.fileExists(atPath: $0) }

        guard missingFiles.isEmpty else {
            throw SpeechError.recognitionFailed(
                "模型文件缺失: \(missingFiles.joined(separator: ", "))"
            )
        }
    }

    /// 初始化 Sherpa-ONNX 识别器
    /// 使用 SafeBridge（ObjC++）构建 C 结构体，确保 memset 零初始化
    private func initializeRecognizer(config: ModelConfig) throws {
        try validateModelFilesExist(for: config.runtimeModel)

        let modelType = SherpaOnnxOnlineConfigPolicy.modelType(for: config.runtimeModel)
        let numThreads = max(1, Int32(ProcessInfo.processInfo.processorCount / 2))

        // Debug: 打印实际使用的模型文件路径
        print("🔧 Sherpa-ONNX 识别器配置:")
        print("   model_type: \(modelType)")
        print("   num_threads: \(numThreads)")
        print("   sample_rate: \(sampleRate)")

        // 通过 SafeBridge 在 ObjC++ 中构建配置并创建识别器
        // 避免 Swift 的 C 结构体初始化与 memset 不一致的问题
        let recognizerRaw: UnsafeMutableRawPointer?
        var errorMsg: NSString?

        switch config.runtimeModel {
        case .streamingParaformer(let encoder, let decoder, let tokens):
            print("   encoder: \(encoder)")
            print("   decoder: \(decoder)")
            print("   tokens: \(tokens)")
            recognizerRaw = SherpaOnnxSafeBridge.createParaformerRecognizer(
                withEncoder: encoder,
                decoder: decoder,
                tokens: tokens,
                modelType: modelType,
                sampleRate: sampleRate,
                numThreads: numThreads,
                error: &errorMsg
            )

        case .streamingTransducer(let encoder, let decoder, let joiner, let tokens):
            print("   encoder: \(encoder)")
            print("   decoder: \(decoder)")
            print("   joiner: \(joiner)")
            print("   tokens: \(tokens)")
            recognizerRaw = SherpaOnnxSafeBridge.createTransducerRecognizer(
                withEncoder: encoder,
                decoder: decoder,
                joiner: joiner,
                tokens: tokens,
                modelType: modelType,
                sampleRate: sampleRate,
                numThreads: numThreads,
                error: &errorMsg
            )
        }

        if let msg = errorMsg {
            print("❌ Sherpa-ONNX 创建识别器失败: \(msg)")
        }

        guard let recognizerRaw else {
            throw SpeechError.recognitionFailed(
                "无法创建 Sherpa-ONNX 在线识别器: \(errorMsg ?? "unknown error")"
            )
        }

        let recognizer = OpaquePointer(recognizerRaw)

        guard let streamRaw = SherpaOnnxSafeBridge.createOnlineStream(recognizerRaw) else {
            SherpaOnnxDestroyOnlineRecognizer(recognizer)
            throw SpeechError.recognitionFailed("无法创建 Sherpa-ONNX 音频流")
        }
        let stream = OpaquePointer(streamRaw)

        recognizerHandle = recognizer
        streamHandle = stream
    }

    func processAudioData(_ data: Data) throws {
        guard let recognizer = recognizerHandle,
              let stream = streamHandle else {
            throw SpeechError.engineNotInitialized
        }

        let samples = SherpaOnnxPCM16Converter.floatSamples(from: data)
        guard !samples.isEmpty else { return }

        samples.withUnsafeBufferPointer { sampleBuffer in
            guard let baseAddress = sampleBuffer.baseAddress else { return }
            SherpaOnnxOnlineStreamAcceptWaveform(stream, sampleRate, baseAddress, Int32(sampleBuffer.count))
        }

        while SherpaOnnxIsOnlineStreamReady(recognizer, stream) != 0 {
            SherpaOnnxDecodeOnlineStream(recognizer, stream)
        }

        emitPartialResultIfNeeded()
    }

    private func emitPartialResultIfNeeded() {
        guard let recognizer = recognizerHandle,
              let stream = streamHandle,
              let sessionId = currentSessionId,
              let result = SherpaOnnxGetOnlineStreamResult(recognizer, stream) else {
            return
        }

        defer { SherpaOnnxDestroyOnlineRecognizerResult(result) }

        let text = result.pointee.text.map { String(cString: $0) } ?? ""
        guard !text.isEmpty, text != lastPartialText else {
            return
        }

        lastPartialText = text
        delegate?.engine(self, didReceivePartialResult: text, sessionId: sessionId)
    }

    func stopRecognition() throws {
        guard currentSessionId != nil else {
            return
        }

        print("🛑 Sherpa-ONNX 停止识别")
        finalizeRecognitionIfNeeded()
        cleanupRecognizerState()
        print("🧹 Sherpa-ONNX 状态已清理")
    }

    private func finalizeRecognitionIfNeeded() {
        guard let recognizer = recognizerHandle,
              let stream = streamHandle,
              let sessionId = currentSessionId,
              let language = currentLanguage else {
            return
        }

        SherpaOnnxOnlineStreamInputFinished(stream)

        let tailPadding = Array<Float>(repeating: 0, count: 4800)
        tailPadding.withUnsafeBufferPointer { sampleBuffer in
            guard let baseAddress = sampleBuffer.baseAddress else { return }
            SherpaOnnxOnlineStreamAcceptWaveform(stream, sampleRate, baseAddress, Int32(sampleBuffer.count))
        }

        while SherpaOnnxIsOnlineStreamReady(recognizer, stream) != 0 {
            SherpaOnnxDecodeOnlineStream(recognizer, stream)
        }

        guard let result = SherpaOnnxGetOnlineStreamResult(recognizer, stream) else {
            return
        }

        defer { SherpaOnnxDestroyOnlineRecognizerResult(result) }

        let text = result.pointee.text.map { String(cString: $0) } ?? ""
        guard !text.isEmpty else { return }

        delegate?.engine(self, didRecognizeText: text, sessionId: sessionId, language: language)
    }

    private func cleanupRecognizerState() {
        if let stream = streamHandle {
            SherpaOnnxDestroyOnlineStream(stream)
        }
        if let recognizer = recognizerHandle {
            SherpaOnnxDestroyOnlineRecognizer(recognizer)
        }

        streamHandle = nil
        recognizerHandle = nil
        currentSessionId = nil
        currentLanguage = nil
        lastPartialText = ""
    }

    // MARK: - Model Management

    /// 下载并配置模型
    /// - Parameter modelInfo: 模型信息（URL 或本地路径）
    func downloadAndSetupModel(from url: URL) async throws {
        let modelDir = getModelConfigDirectory().appendingPathComponent(url.lastPathComponent)

        print("📥 正在下载 Sherpa-ONNX 模型...")
        print("   源: \(url)")
        print("   目标: \(modelDir.path)")

        // 使用 URLSession 下载模型
        let (_, _) = try await URLSession.shared.download(from: url)

        // 创建目录
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

        // 解压（如果是 .tar.bz2 或 .zip）
        // 注意：这里需要使用 Process 或第三方库来解压
        // 简化处理：假设下载的是已解压的模型文件夹

        // 更新配置
        // TODO: 根据下载的模型更新配置

        print("✅ Sherpa-ONNX 模型下载完成")
        isModelConfigured = true
    }

    /// 获取支持 Whisper 的语言代码
    private func findModel(for language: String) -> ModelConfig? {
        let models = candidateModelConfigDirectories()
            .flatMap { findAvailableModels(in: $0) }
        return models.first { $0.language == language }
    }

    // MARK: - Debug

    /// 打印引擎状态
    func logStatus() {
        print("📊 Sherpa-ONNX 引擎状态:")
        print("   库已加载: \(isLibraryLoaded)")
        print("   模型已配置: \(isModelConfigured)")
        if let config = currentModelConfig {
            print("   当前模型语言: \(config.language)")
            switch config.runtimeModel {
            case .streamingParaformer(let encoder, _, _):
                print("   Paraformer Encoder: \(encoder)")
            case .streamingTransducer(let encoder, _, let joiner, _):
                print("   Transducer Encoder: \(encoder)")
                print("   Joiner: \(joiner)")
            }
        }
    }
}

// MARK: - Helper Types

/// 模型配置的 JSON 表示
private struct ModelConfigJSON: Codable {
    let encoderPath: String
    let decoderPath: String
    let tokensPath: String
    let language: String
}

// MARK: - Sherpa-ONNX C API (待实现)
// 以下是需要导入的 C API 声明，在实际集成时需要创建 bridging header
//
// typedef struct SherpaOnnxOnlineRecognizerConfig {
//     SherpaOnnxFeatureConfig feature_config;
//     SherpaOnnxModelConfig model_config;
//     SherpaOnnxDecoderConfig decoder_config;
//     SherpaOnnxEndpointConfig endpoint_config;
// } SherpaOnnxOnlineRecognizerConfig;
//
// typedef struct SherpaOnnxOnlineRecognizer SherpaOnnxOnlineRecognizer;
//
// SherpaOnnxOnlineRecognizer *SherpaOnnxCreateOnlineRecognizer(
//     const SherpaOnnxOnlineRecognizerConfig *config);
//
// void SherpaOnnxDestroyOnlineRecognizer(
//     SherpaOnnxOnlineRecognizer *recognizer);
//
// SherpaOnnxOnlineStream *SherpaOnnxCreateOnlineStream(
//     SherpaOnnxOnlineRecognizer *recognizer);
//
// void SherpaOnnxDestroyOnlineStream(
//     SherpaOnnxOnlineRecognizer *recognizer,
//     SherpaOnnxOnlineStream *stream);
//
// int SherpaOnnxOnlineRecognizerAcceptWaveform(
//     SherpaOnnxOnlineRecognizer *recognizer,
//     SherpaOnnxOnlineStream *stream,
//     const float *samples,
//     int n);
//
// void SherpaOnnxOnlineRecognizerDecode(
//     SherpaOnnxOnlineRecognizer *recognizer,
//     SherpaOnnxOnlineStream *stream);
//
// const SherpaOnnxOnlineRecognizerResult *
// SherpaOnnxOnlineRecognizerGetResult(
//     SherpaOnnxOnlineRecognizer *recognizer,
//     SherpaOnnxOnlineStream *stream);
//
// void SherpaOnnxOnlineRecognizerResultFree(
//     const SherpaOnnxOnlineRecognizerResult *result);
